import { after, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { closeTestPrisma, dbTestSkipReason, withRollback } from '@/testing/testDb';
import { createEvent, createOrder, createTier, createUser } from '@/testing/fixtures';

// T-005: EventPurchase.ticketTierId / ticketTierName (CR-04, BUG-B24).
describe('tier on purchase (migration 5)', { skip: dbTestSkipReason() }, () => {
  after(closeTestPrisma);

  const setup = async (tx: Parameters<Parameters<typeof withRollback>[0]>[0]) => {
    const seller = await createUser(tx, { accountRole: 'CLUB_OWNER' });
    const buyer = await createUser(tx);
    const event = await createEvent(tx, seller.id);
    const tier = await createTier(tx, event.id, { soldCount: 3 });
    const order = await createOrder(tx, buyer.id, seller.id);
    const now = new Date();
    const purchase = await tx.eventPurchase.create({
      data: {
        orderId: order.id,
        eventId: event.id,
        personCount: 1,
        eventName: 'E',
        eventLocation: 'L',
        eventStartAt: now,
        eventEndAt: new Date(now.getTime() + 3600000),
        pricePerPerson: 10,
        transferEligibleAt: new Date(now.getTime() - 6 * 3600000),
        ticketTierId: tier.id,
        ticketTierName: tier.tierName,
      },
    });
    return { tier, purchase };
  };

  it('stores the tier id and name and leaves soldCount alone', async () => {
    await withRollback(async (tx) => {
      const { tier, purchase } = await setup(tx);
      assert.equal(purchase.ticketTierId, tier.id);
      assert.equal(purchase.ticketTierName, 'General');
      assert.equal((await tx.eventTicketTier.findUniqueOrThrow({ where: { id: tier.id } })).soldCount, 3);
    });
  });

  it('snapshot trigger rejects an UPDATE of ticketTierId or ticketTierName', async () => {
    for (const col of ['ticketTierId', 'ticketTierName']) {
      await assert.rejects(
        withRollback(async (tx) => {
          const { purchase } = await setup(tx);
          if (col === 'ticketTierId') {
            await tx.$executeRawUnsafe(`UPDATE "EventPurchase" SET "ticketTierId" = NULL WHERE id = $1`, purchase.id);
          } else {
            await tx.$executeRawUnsafe(`UPDATE "EventPurchase" SET "ticketTierName" = 'X' WHERE id = $1`, purchase.id);
          }
        }),
        /immutable/
      );
    }
  });

  it('deleting a referenced tier is refused: the SET NULL action is an UPDATE and the snapshot trigger rejects it', async () => {
    await assert.rejects(
      withRollback(async (tx) => {
        const { tier } = await setup(tx);
        await tx.$executeRawUnsafe(`DELETE FROM "EventTicketTier" WHERE id = $1`, tier.id);
      }),
      /immutable/
    );
  });

  it('a purchase made without a tier keeps NULL columns', async () => {
    await withRollback(async (tx) => {
      const seller = await createUser(tx, { accountRole: 'CLUB_OWNER' });
      const buyer = await createUser(tx);
      const event = await createEvent(tx, seller.id);
      const order = await createOrder(tx, buyer.id, seller.id);
      const now = new Date();
      const p = await tx.eventPurchase.create({
        data: { orderId: order.id, eventId: event.id, personCount: 1, eventName: 'E', eventLocation: 'L',
          eventStartAt: now, eventEndAt: new Date(now.getTime() + 3600000), pricePerPerson: 10, transferEligibleAt: new Date(now.getTime() - 6 * 3600000) },
      });
      assert.equal(p.ticketTierId, null);
      assert.equal(p.ticketTierName, null);
    });
  });
});
