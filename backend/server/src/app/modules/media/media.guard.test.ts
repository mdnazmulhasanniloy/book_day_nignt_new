import test from 'node:test';
import assert from 'node:assert/strict';
import express, { RequestHandler } from 'express';
import cookieParser from 'cookie-parser';
import type { AddressInfo } from 'node:net';
import { createMediaGuard } from './media.guard';

const deny =
  (status: number, msg: string): RequestHandler =>
  (_req, res) => {
    res.status(status).json({ success: false, message: msg });
  };
const pass: RequestHandler = (_req, _res, next) => next();

const build = (chains: {
  bearer: RequestHandler[];
  cookie: RequestHandler[];
}) => {
  const app = express();
  app.use(cookieParser());
  const guard = createMediaGuard({
    ...chains,
    cookieName: 'access_token',
    onMissing: (_req, res) => {
      res.status(401).json({ success: false, message: 'Authentication required' });
    },
  });
  let reached = 0;
  const ok: RequestHandler = (_req, res) => {
    reached++;
    res.json({ success: true });
  };
  app.post('/media', guard, ok);
  app.delete('/media', guard, ok);
  const server = app.listen(0);
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  return { base, server, reached: () => reached };
};

test('no credentials: 401 on POST and DELETE, handler never reached', async () => {
  const t = build({ bearer: [pass], cookie: [pass] });
  for (const method of ['POST', 'DELETE']) {
    const r = await fetch(`${t.base}/media`, { method });
    assert.equal(r.status, 401);
  }
  assert.equal(t.reached(), 0);
  t.server.close();
});

test('invalid/expired bearer token is rejected, handler not reached', async () => {
  const t = build({ bearer: [deny(401, 'Token is invalid')], cookie: [pass] });
  for (const method of ['POST', 'DELETE']) {
    const r = await fetch(`${t.base}/media`, {
      method,
      headers: { Authorization: 'Bearer garbage' },
    });
    assert.equal(r.status, 401);
  }
  assert.equal(t.reached(), 0);
  t.server.close();
});

test('valid bearer token reaches the handler (mobile flow)', async () => {
  const t = build({ bearer: [pass, pass], cookie: [deny(401, 'x')] });
  const r = await fetch(`${t.base}/media`, {
    method: 'POST',
    headers: { Authorization: 'Bearer good' },
  });
  assert.equal(r.status, 200);
  assert.equal(t.reached(), 1);
  t.server.close();
});

test('blocked account (403 from chain) is stopped, later steps skipped', async () => {
  let laterRan = false;
  const t = build({
    bearer: [
      pass,
      deny(403, 'forbidden'),
      (_q, _s, n) => {
        laterRan = true;
        n();
      },
    ],
    cookie: [pass],
  });
  const r = await fetch(`${t.base}/media`, {
    method: 'DELETE',
    headers: { Authorization: 'Bearer good' },
  });
  assert.equal(r.status, 403);
  assert.equal(laterRan, false);
  assert.equal(t.reached(), 0);
  t.server.close();
});

test('admin cookie session: valid passes, missing CSRF (403) and non-admin rejected', async () => {
  const good = build({ bearer: [deny(401, 'x')], cookie: [pass] });
  const ok = await fetch(`${good.base}/media`, {
    method: 'POST',
    headers: { Cookie: 'access_token=abc' },
  });
  assert.equal(ok.status, 200);
  good.server.close();

  const bad = build({ bearer: [pass], cookie: [deny(403, 'csrf')] });
  const r = await fetch(`${bad.base}/media`, {
    method: 'DELETE',
    headers: { Cookie: 'access_token=abc' },
  });
  assert.equal(r.status, 403);
  assert.equal(bad.reached(), 0);
  bad.server.close();
});

test('a throwing middleware fails closed (no pass-through)', async () => {
  const t = build({
    bearer: [
      () => {
        throw new Error('redis down');
      },
    ],
    cookie: [pass],
  });
  const r = await fetch(`${t.base}/media`, {
    method: 'POST',
    headers: { Authorization: 'Bearer x' },
  });
  assert.equal(r.status, 500);
  assert.equal(t.reached(), 0);
  t.server.close();
});
