import type { Prisma } from '@prisma/client';

/**
 * Moves an order from PENDING_PAYMENT to PAYMENT_FAILED and gives back the
 * ticket-tier stock it held (T-007, CR-04 / BUG-B24).
 *
 * WHY THE GUARD: the conditional `updateMany ... status = PENDING_PAYMENT` is the
 * idempotency lock. It runs inside the caller's transaction, so only one delivery
 * (a repeated webhook, or failed then canceled for the same order) sees count = 1;
 * every other caller gets 0 and releases nothing. A PAID or already failed order is
 * never touched.
 *
 * WHY NO GUESSING: only an EventPurchase that stores `ticketTierId` releases stock.
 * Old orders and purchases made without a tier have no link and release nothing.
 *
 * `soldCount` is lowered with GREATEST(..., 0) so leaked or hand-edited counts can
 * never push it below zero. Refunds do not go through here.
 *
 * Returns the number of seats released (0 when nothing was released).
 */
export const releaseEventTierStock = async ({
  tx,
  orderId,
}: {
  tx: Prisma.TransactionClient;
  orderId: string;
}): Promise<number> => {
  const moved = await tx.order.updateMany({
    where: { id: orderId, status: 'PENDING_PAYMENT' },
    data: { status: 'PAYMENT_FAILED' },
  });
  if (moved.count !== 1) return 0;

  const purchase = await tx.eventPurchase.findUnique({
    where: { orderId },
    select: { ticketTierId: true, personCount: true },
  });
  if (!purchase?.ticketTierId) return 0;

  await tx.$executeRaw`
    UPDATE "EventTicketTier"
    SET "soldCount" = GREATEST("soldCount" - ${purchase.personCount}, 0),
        "updatedAt" = NOW()
    WHERE "id" = ${purchase.ticketTierId}`;
  return purchase.personCount;
};

export type ReacquireTierStockResult =
  | 'NOT_APPLICABLE'
  | 'REACQUIRED'
  | 'TIER_FULL';

/**
 * A payment_intent.succeeded that arrives for an order already moved to
 * PAYMENT_FAILED (Stripe can succeed on a retry after a payment_failed event).
 * If its stock was released, take it again so the order is not PAID with its
 * seats given away or double counted:
 * - NOT_APPLICABLE: order is not PAYMENT_FAILED or has no tier link (nothing changed).
 * - REACQUIRED: seats were free; order is PAID again and soldCount counts it once.
 * - TIER_FULL: no room left; nothing is changed, the caller flags it for manual
 *   review. No automatic refund here.
 *
 * The order row is locked by the conditional update first, so two concurrent
 * deliveries cannot both reacquire.
 */
export const reacquireEventTierStock = async ({
  tx,
  orderId,
}: {
  tx: Prisma.TransactionClient;
  orderId: string;
}): Promise<ReacquireTierStockResult> => {
  const purchase = await tx.eventPurchase.findUnique({
    where: { orderId },
    select: { ticketTierId: true, personCount: true },
  });
  if (!purchase?.ticketTierId) return 'NOT_APPLICABLE';

  const moved = await tx.order.updateMany({
    where: { id: orderId, status: 'PAYMENT_FAILED' },
    data: { status: 'PAID' },
  });
  if (moved.count !== 1) return 'NOT_APPLICABLE';

  const taken = await tx.$executeRaw`
    UPDATE "EventTicketTier"
    SET "soldCount" = "soldCount" + ${purchase.personCount},
        "updatedAt" = NOW()
    WHERE "id" = ${purchase.ticketTierId}
      AND "soldCount" + ${purchase.personCount} <= "capacity"`;
  if (taken !== 1) {
    await tx.order.updateMany({
      where: { id: orderId, status: 'PAID' },
      data: { status: 'PAYMENT_FAILED' },
    });
    return 'TIER_FULL';
  }
  return 'REACQUIRED';
};
