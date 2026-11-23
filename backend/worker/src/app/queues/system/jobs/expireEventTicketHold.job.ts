import { Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IExpireEventTicketHold } from '@/app/queues/system/system.types';
import { QUEUE_JOBS } from '@/const';
import prisma from '@/app/configs/db.configs';
import logger from '@/app/configs/logger.configs';

/**
 * Releases the ticket tier stock of an unpaid Event order (T-008, CR-04).
 *
 * Idempotent: the PENDING_PAYMENT to PAYMENT_FAILED move is the guard, so the
 * decrement happens at most once however many times the job runs. Orders that
 * are already PAID, PAYMENT_FAILED or otherwise settled are left untouched.
 * Orders without a tier link (bought before T-006) are still marked failed but
 * release no stock.
 *
 * This mirrors `releaseEventTierStock` in the server webhook helpers (the
 * worker is a separate package and cannot import server code). Keep the two in
 * step.
 */
const expireEventTicketHoldTransaction = async (
  orderId: string
): Promise<'RELEASED' | 'EXPIRED_NO_TIER' | 'SKIPPED'> =>
  prisma.$transaction(async (tx) => {
    const purchase = await tx.eventPurchase.findUnique({
      where: { orderId },
      select: { ticketTierId: true, personCount: true },
    });
    // Not an Event order (or unknown id): nothing of ours to expire.
    if (!purchase) return 'SKIPPED';

    const moved = await tx.order.updateMany({
      where: { id: orderId, status: 'PENDING_PAYMENT' },
      data: { status: 'PAYMENT_FAILED' },
    });
    if (moved.count !== 1) return 'SKIPPED';

    if (!purchase.ticketTierId) return 'EXPIRED_NO_TIER';

    await tx.$executeRaw`
      UPDATE "EventTicketTier"
      SET "soldCount" = GREATEST("soldCount" - ${purchase.personCount}, 0),
          "updatedAt" = NOW()
      WHERE "id" = ${purchase.ticketTierId}`;
    return 'RELEASED';
  });

const handler: IJobHandler<IExpireEventTicketHold> = {
  name: QUEUE_JOBS.EXPIRE_EVENT_TICKET_HOLD,
  handler: async (data: IExpireEventTicketHold, _job: Job) => {
    const { orderId } = data;
    const outcome = await expireEventTicketHoldTransaction(orderId);
    logger.info(`[expireEventTicketHold] Order ${orderId}: ${outcome}`);
  },
};

export default handler;
