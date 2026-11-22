import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { closeTestPrisma, dbTestSkipReason, getTestPrisma, withRollback } from '@/testing/testDb';
import { createEvent, createOrder, createTier, createUser } from '@/testing/fixtures';

// Template 4: database-backed. Skipped without TEST_DATABASE_URL; rolled back after each test.
describe('db example', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  it('fixtures insert, and nothing persists after rollback', async () => {
    const email = await withRollback(async (tx) => {
      const seller = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const buyer = await createUser(tx);
      const event = await createEvent(tx, seller.id);
      const tier = await createTier(tx, event.id);
      const order = await createOrder(tx, buyer.id, seller.id);
      assert.equal(tier.soldCount, 0);
      assert.equal(Number(order.buyerTotal), 11);
      return buyer.email;
    });
    assert.equal(await getTestPrisma().user.count({ where: { email } }), 0);
  });
});
