import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import type { AccountRole, PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';
import { createClub, createEvent, createUser } from '@/testing/fixtures';

// T-018 (S-02, B-26): role and ownership checks on POST/PUT/DELETE /promo.
// Real promo router, real auth middlewares, real global error handler, fake Redis.
// Approved judgement (api-spec-diff-v2.md): the live app treats 403 like 401, so a
// foreign or unknown eventId/clubId/promo is 404, and only the role gate is 403.

const run = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

describe('promo management permissions (T-018)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const db = () => getTestPrisma();
  const tokens: Record<string, string> = {};
  const ids: Record<string, string> = {};
  let n = 0;
  type Body = { success: boolean; message: string; errorType?: string; data?: { id: string; code: string } };

  const call = (who: string | null, method: string, path: string, body?: unknown) =>
    fetch(`${srv.baseUrl}/api/v1${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(who ? { authorization: `Bearer ${tokens[who]}` } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
  const newCode = () => `T18${run}${++n}`;
  const payload = (extra: Record<string, unknown> = {}) => ({
    code: newCode(),
    discountType: 'PERCENTAGE',
    discountValue: 10,
    ...extra,
  });
  const mkPromo = (data: { createdByUserId?: string | null; eventId?: string | null; clubId?: string | null }) =>
    db().promoCode.create({
      data: { code: newCode(), discountType: 'PERCENTAGE', discountValue: 10, ...data },
    });
  const exists = async (id: string) => (await db().promoCode.findUnique({ where: { id } })) !== null;

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    const [{ current_database: name }] = await appPrisma.$queryRaw<{ current_database: string }[]>`select current_database()`;
    assert.match(name, /_test$/, 'app prisma client must target the test DB');

    const jwt = await import('@/app/utils/jwt.utils');
    const mk = async (tag: string, role: AccountRole) => {
      const u = await createUser(db(), {
        name: `T018 ${tag}`,
        email: `t018-${run}-${tag}@example.test`,
        accountRole: role,
        isVerified: true,
      });
      ids[tag] = u.id;
      tokens[tag] = jwt.generateAccessTokenForUser({
        sub: u.id,
        role: u.accountRole,
        isVerified: true,
        accountStatus: u.accountStatus,
        rememberMe: true,
      } as never);
    };
    await mk('user', 'USER');
    await mk('ownerA', 'CLUB_OWNER');
    await mk('ownerB', 'CLUB_OWNER');
    await mk('admin', 'ADMIN');
    ids.clubA = (await createClub(db(), ids.ownerA)).id;
    ids.clubB = (await createClub(db(), ids.ownerB)).id;
    ids.eventA = (await createEvent(db(), ids.ownerA)).id;
    ids.eventB = (await createEvent(db(), ids.ownerB)).id;

    const routes = (await import('@/app/modules/promo/promo.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      const owners = Object.values(ids).length
        ? [ids.user, ids.ownerA, ids.ownerB, ids.admin].filter(Boolean)
        : [];
      await db().promoCode.deleteMany({ where: { code: { startsWith: `T18${run}` } } });
      await db().event.deleteMany({ where: { userId: { in: owners } } });
      await db().club.deleteMany({ where: { userId: { in: owners } } });
      await db().user.deleteMany({ where: { id: { in: owners } } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  describe('role gate (USER is rejected with 403)', () => {
    it('USER cannot create', async () => {
      const r = await call('user', 'POST', '/promo', payload({ clubId: ids.clubA }));
      assert.equal(r.status, 403);
      assert.equal(((await r.json()) as Body).success, false);
    });
    it('USER cannot update, even a promo they created themselves', async () => {
      const p = await mkPromo({ createdByUserId: ids.user });
      const r = await call('user', 'PUT', `/promo/${p.id}`, { isActive: false });
      assert.equal(r.status, 403);
      assert.equal((await db().promoCode.findUnique({ where: { id: p.id } }))?.isActive, true);
    });
    it('USER cannot delete, even a legacy global code', async () => {
      const p = await mkPromo({});
      const r = await call('user', 'DELETE', `/promo/${p.id}`);
      assert.equal(r.status, 403);
      assert.equal(await exists(p.id), true);
    });
    it('no token -> 401', async () => {
      assert.equal((await call(null, 'POST', '/promo', payload())).status, 401);
    });
  });

  describe('owner own promos still work', () => {
    it('create for own club and own event, update, delete', async () => {
      const c = await call('ownerA', 'POST', '/promo', payload({ clubId: ids.clubA }));
      assert.equal(c.status, 201);
      const created = ((await c.json()) as Body).data!;
      const e = await call('ownerA', 'POST', '/promo', payload({ eventId: ids.eventA }));
      assert.equal(e.status, 201);
      const u = await call('ownerA', 'PUT', `/promo/${created.id}`, { discountValue: 20, eventId: ids.eventA });
      assert.equal(u.status, 200);
      const d = await call('ownerA', 'DELETE', `/promo/${created.id}`);
      assert.equal(d.status, 200);
      assert.equal(await exists(created.id), false);
    });
    it('owner create with neither id stays allowed (approved judgement, owner app can submit it) and owner manages it', async () => {
      const c = await call('ownerA', 'POST', '/promo', payload());
      assert.equal(c.status, 201);
      const created = ((await c.json()) as Body).data!;
      const row = await db().promoCode.findUnique({ where: { id: created.id } });
      assert.equal(row?.createdByUserId, ids.ownerA);
      assert.equal((await call('ownerA', 'PUT', `/promo/${created.id}`, { isActive: false })).status, 200);
      assert.equal((await call('ownerB', 'PUT', `/promo/${created.id}`, { isActive: false })).status, 404);
      assert.equal((await call('ownerA', 'DELETE', `/promo/${created.id}`)).status, 200);
    });
  });

  describe('ownership (404, no information leak)', () => {
    it("owner cannot create a promo for another owner's club or event", async () => {
      const a = await call('ownerA', 'POST', '/promo', payload({ clubId: ids.clubB }));
      const b = await call('ownerA', 'POST', '/promo', payload({ eventId: ids.eventB }));
      assert.equal(a.status, 404);
      assert.equal(b.status, 404);
      assert.equal(((await a.json()) as Body).errorType, 'NOT_FOUND');
      assert.equal(await db().promoCode.count({ where: { OR: [{ clubId: ids.clubB }, { eventId: ids.eventB }] } }), 0);
    });
    it('foreign target body equals unknown target body', async () => {
      const f = (await (await call('ownerA', 'POST', '/promo', payload({ eventId: ids.eventB }))).json()) as Body;
      const u = (await (await call('ownerA', 'POST', '/promo', payload({ eventId: randomUUID() }))).json()) as Body;
      assert.equal(f.message, u.message);
      assert.equal(f.errorType, u.errorType);
    });
    it("owner A cannot edit or delete owner B's promo (404, row untouched)", async () => {
      for (const data of [{ createdByUserId: ids.ownerB, clubId: ids.clubB }, { createdByUserId: ids.ownerB }, { eventId: ids.eventB }]) {
        const p = await mkPromo(data);
        assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { isActive: false })).status, 404);
        assert.equal((await call('ownerA', 'DELETE', `/promo/${p.id}`)).status, 404);
        const row = await db().promoCode.findUnique({ where: { id: p.id } });
        assert.equal(row?.isActive, true);
      }
    });
    it("owner cannot point their own promo at another owner's club or event", async () => {
      const p = await mkPromo({ createdByUserId: ids.ownerA, clubId: ids.clubA });
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { clubId: ids.clubB })).status, 404);
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { eventId: ids.eventB })).status, 404);
      assert.equal((await db().promoCode.findUnique({ where: { id: p.id } }))?.clubId, ids.clubA);
    });
    it('unknown promo id -> 404', async () => {
      assert.equal((await call('ownerA', 'PUT', `/promo/${randomUUID()}`, { isActive: false })).status, 404);
      assert.equal((await call('ownerA', 'DELETE', `/promo/${randomUUID()}`)).status, 404);
    });
  });

  describe('unknown eventId / clubId -> 404, not 500', () => {
    it('create with unknown eventId', async () => {
      const r = await call('ownerA', 'POST', '/promo', payload({ eventId: randomUUID() }));
      assert.equal(r.status, 404);
      assert.equal(((await r.json()) as Body).errorType, 'NOT_FOUND');
    });
    it('create with unknown clubId', async () => {
      assert.equal((await call('ownerA', 'POST', '/promo', payload({ clubId: randomUUID() }))).status, 404);
    });
    it('update with unknown eventId / clubId', async () => {
      const p = await mkPromo({ createdByUserId: ids.ownerA });
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { eventId: randomUUID() })).status, 404);
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { clubId: randomUUID() })).status, 404);
    });
    it('admin create with unknown eventId -> 404 too', async () => {
      assert.equal((await call('admin', 'POST', '/promo', payload({ eventId: randomUUID() }))).status, 404);
    });
  });

  describe('legacy global codes (no eventId, clubId or createdByUserId)', () => {
    it('owner cannot edit or delete them (404); admin can', async () => {
      const p = await mkPromo({});
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { isActive: false })).status, 404);
      assert.equal((await call('ownerA', 'DELETE', `/promo/${p.id}`)).status, 404);
      assert.equal(await exists(p.id), true);
      assert.equal((await call('admin', 'PUT', `/promo/${p.id}`, { isActive: false })).status, 200);
      assert.equal((await call('admin', 'DELETE', `/promo/${p.id}`)).status, 200);
      assert.equal(await exists(p.id), false);
    });
    it('rows with both eventId and clubId set keep working for their owner', async () => {
      const p = await mkPromo({ createdByUserId: ids.ownerA, eventId: ids.eventA, clubId: ids.clubA });
      assert.equal((await call('ownerA', 'PUT', `/promo/${p.id}`, { isActive: false })).status, 200);
      assert.equal((await call('ownerA', 'DELETE', `/promo/${p.id}`)).status, 200);
    });
  });

  describe('admin', () => {
    it('can create a global code', async () => {
      const r = await call('admin', 'POST', '/promo', payload());
      assert.equal(r.status, 201);
    });
    it('can create for any existing club or event', async () => {
      assert.equal((await call('admin', 'POST', '/promo', payload({ clubId: ids.clubB }))).status, 201);
      assert.equal((await call('admin', 'POST', '/promo', payload({ eventId: ids.eventA }))).status, 201);
    });
  });

  describe('POST /promo/validate is untouched', () => {
    it('stays public and works without a token', async () => {
      const p = await mkPromo({ createdByUserId: ids.ownerA, clubId: ids.clubA });
      const r = await call(null, 'POST', '/promo/validate', { code: p.code, originalAmount: 100, clubId: ids.clubA });
      assert.equal(r.status, 200);
      const b = (await r.json()) as { data: { finalAmount: number } };
      assert.equal(b.data.finalAmount, 90);
    });
    it('works for a USER token too', async () => {
      const p = await mkPromo({});
      const r = await call('user', 'POST', '/promo/validate', { code: p.code, originalAmount: 50 });
      assert.equal(r.status, 200);
    });
  });
});
