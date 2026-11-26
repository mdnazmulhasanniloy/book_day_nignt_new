import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { validateReqBody } from '@/app/utils/system.utils';
import { deleteMediaSchema } from '@/app/modules/media/media.schema';
import { startTestServer } from '@/testing/fakes';

// T-014 (S-18): validateReqBody must run on DELETE when a schema is passed.
// Same wiring as `DELETE /media`: express.json, then validateReqBody(deleteMediaSchema).

describe('validateReqBody on DELETE (T-014)', () => {
  let srv: Awaited<ReturnType<typeof startTestServer>>;

  before(async () => {
    const app = express();
    app.use(express.json());
    app.delete('/media', validateReqBody(deleteMediaSchema), (req, res) => {
      res.status(200).json({ success: true, body: req.body });
    });
    app.delete('/noschema/:id', (req, res) => {
      res.status(200).json({ success: true, body: req.body ?? null });
    });
    app.get('/g', validateReqBody(deleteMediaSchema), (_req, res) => {
      res.status(200).json({ success: true });
    });
    srv = await startTestServer(app);
  });
  after(() => srv.close());

  const del = (path: string, body?: unknown) =>
    fetch(`${srv.baseUrl}${path}`, {
      method: 'DELETE',
      headers: { 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });

  it('returns 422 for an invalid body (wrong type)', async () => {
    const res = await del('/media', { urls: 'not-an-array' });
    assert.equal(res.status, 422);
    const json = (await res.json()) as { success: boolean; errors: { field: string }[] };
    assert.equal(json.success, false);
    assert.equal(json.errors[0].field, 'urls');
  });

  it('returns 422 when the body is missing', async () => {
    const res = await del('/media');
    assert.equal(res.status, 422);
  });

  it('returns 422 for unknown keys (strict schema)', async () => {
    const res = await del('/media', { urls: ['a'], extra: 1 });
    assert.equal(res.status, 422);
  });

  it('passes a valid body through unchanged (shape the Flutter and admin clients send)', async () => {
    const res = await del('/media', { urls: ['https://x.test/a.png', 'https://x.test/b.png'] });
    assert.equal(res.status, 200);
    const json = (await res.json()) as { body: { urls: string[] } };
    assert.deepEqual(json.body.urls, ['https://x.test/a.png', 'https://x.test/b.png']);
  });

  it('a DELETE route without a schema is unaffected', async () => {
    const res = await del('/noschema/1');
    assert.equal(res.status, 200);
  });

  it('GET behaviour is unchanged (schema not enforced)', async () => {
    const res = await fetch(`${srv.baseUrl}/g`);
    assert.equal(res.status, 200);
  });
});
