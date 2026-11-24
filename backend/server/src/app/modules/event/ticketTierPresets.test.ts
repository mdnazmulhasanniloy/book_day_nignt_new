import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { installFakeRedis, startTestServer } from '@/testing/fakes';

// T-016 (CR-03): GET /ticket-tier-presets is public (api-spec: no auth middleware).
// Static list kept in code; names come from tracker items A2.5 to A2.7.

describe('GET /ticket-tier-presets (T-016)', () => {
  let srv: Awaited<ReturnType<typeof startTestServer>>;

  before(async () => {
    installFakeRedis();
    const routes = (await import('@/app/modules/event/event.routes')).default;
    const { globalErrorMiddleware } = await import('@/app/middlewares/globalError.middlewares');
    const app = express();
    app.use(express.json());
    app.use('/api/v1', routes);
    app.use(globalErrorMiddleware);
    srv = await startTestServer(app);
  });

  after(async () => {
    await srv?.close();
  });

  it('answers 200 without any auth header', async () => {
    const r = await fetch(`${srv.baseUrl}/api/v1/ticket-tier-presets`);
    assert.equal(r.status, 200);
    const b = (await r.json()) as {
      success: boolean;
      message: string;
      traceId?: string;
      data: {
        ticketPresets: string[];
        passPresets: string[];
        presets: { name: string; tierType: string; sortOrder: number }[];
        sectionHelp: string;
        tierHelp: string;
      };
    };
    assert.equal(b.success, true);
    assert.deepEqual(b.data.ticketPresets, [
      'Super Early',
      'Early',
      'Advance',
      'Regular',
      'Late',
      'Super Late',
    ]);
    assert.deepEqual(b.data.passPresets, [
      'Blind Pass',
      'Early Pass',
      'Standard Pass',
      'Late Pass',
    ]);
    assert.equal(b.data.presets.length, 10);
    assert.deepEqual(b.data.presets[0], { name: 'Super Early', tierType: 'TICKET', sortOrder: 0 });
    assert.deepEqual(b.data.presets[6], { name: 'Blind Pass', tierType: 'PASS', sortOrder: 0 });
    assert.ok(b.data.sectionHelp.length > 10);
    assert.ok(b.data.tierHelp.length > 10);
  });

  it('ignores an invalid bearer token (public endpoint)', async () => {
    const r = await fetch(`${srv.baseUrl}/api/v1/ticket-tier-presets`, {
      headers: { authorization: 'Bearer not-a-token' },
    });
    assert.equal(r.status, 200);
  });
});
