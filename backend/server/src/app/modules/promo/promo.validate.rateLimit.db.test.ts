import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import {
  assertSafeTestDatabaseUrl,
  closeTestPrisma,
  dbTestSkipReason,
  getTestPrisma,
} from '@/testing/testDb';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-019 (S-09): real promo router, real limiter, fake Redis. The old response shape is kept.

const run = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();

describe('POST /promo/validate rate limit (T-019)', { skip: dbTestSkipReason() }, () => {
  let appPrisma: PrismaClient;
  let srv: Awaited<ReturnType<typeof startTestServer>>;
  const code = `T19${run}`;

  const validate = (ip: string, body: unknown) =>
    fetch(`${srv.baseUrl}/api/v1/promo/validate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-forwarded-for': ip },
      body: JSON.stringify(body),
    });

  before(async () => {
    process.env.DATABASE_URL = assertSafeTestDatabaseUrl(process.env.TEST_DATABASE_URL);
    installFakeRedis();
    appPrisma = (await import('@/app/configs/db.configs')).default;
    await getTestPrisma().promoCode.create({
      data: { code, discountType: 'PERCENTAGE', discountValue: 10 },
    });
    const routes = (await import('@/app/modules/promo/promo.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.set('trust proxy', 1);
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    try {
      await getTestPrisma().promoCode.deleteMany({ where: { code } });
    } finally {
      await srv?.close();
      await appPrisma?.$disconnect();
      await closeTestPrisma();
    }
  });

  it('a valid code still validates under the limit with the old response shape', async () => {
    const r = await validate('10.9.0.1', { code, originalAmount: 200 });
    assert.equal(r.status, 200);
    const b = (await r.json()) as { success: boolean; message: string; data: Record<string, unknown>; traceId?: string };
    assert.equal(b.success, true);
    assert.equal(b.message, 'Promo code is valid');
    assert.equal(b.data.code, code);
    assert.equal(b.data.discountAmount, 20);
  });

  it('an unknown code is still 404 (not limited yet)', async () => {
    assert.equal((await validate('10.9.0.2', { code: `NOPE${run}`, originalAmount: 10 })).status, 404);
  });

  it('the 21st guess from one IP is 429 with Retry-After, another IP is unaffected', async () => {
    for (let i = 0; i < 20; i++) await validate('10.9.0.3', { code: `NOPE${run}${i}`, originalAmount: 10 });
    const r = await validate('10.9.0.3', { code, originalAmount: 100 });
    assert.equal(r.status, 429);
    assert.ok(Number(r.headers.get('retry-after')) >= 1);
    assert.equal(((await r.json()) as { errorType: string }).errorType, 'RATE_LIMITED');
    assert.equal((await validate('10.9.0.4', { code, originalAmount: 100 })).status, 200);
  });
});
