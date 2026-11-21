import { DelayedError, Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IExpireEventModuleHold } from '@/app/queues/system/system.types';
import { QUEUE_JOBS } from '@/const';
import prisma from '@/app/configs/db.configs';
import logger from '@/app/configs/logger.configs';

async function expireModuleHoldTransaction(
  bookingId: string,
  reason: string
): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const current = await tx.eventModulePurchase.findUnique({
      where: { id: bookingId },
    });

    if (!current || current.status !== 'HOLD') {
      return;
    }

    await tx.eventModulePurchase.update({
      where: { id: bookingId },
      data: { status: 'EXPIRED' },
    });

    const module = await tx.eventModule.findUnique({
      where: { id: current.moduleId },
    });

    if (module) {
      const restored = module.remaining + current.quantity;
      await tx.eventModule.update({
        where: { id: module.id },
        data: {
          remaining: restored,
          ...(module.status === 'SOLD_OUT' && restored > 0
            ? { status: 'AVAILABLE' }
            : {}),
        },
      });
    }

    logger.info(
      `[expireEventModuleHold] Expired module booking ${bookingId} due to: ${reason}`
    );
  });
}

const handler: IJobHandler<IExpireEventModuleHold> = {
  name: QUEUE_JOBS.EXPIRE_EVENT_MODULE_HOLD,
  handler: async (data: IExpireEventModuleHold, _job: Job) => {
    const { bookingId } = data;

    const booking = await prisma.eventModulePurchase.findUnique({
      where: { id: bookingId },
      include: { order: { include: { paymentTransaction: true } } },
    });

    if (!booking) {
      logger.warn(`[expireEventModuleHold] Booking ${bookingId} not found`);
      return;
    }

    if (booking.status !== 'HOLD') {
      logger.info(
        `[expireEventModuleHold] Booking ${bookingId} is no longer HOLD (status: ${booking.status})`
      );
      return;
    }

    const payment = booking.order.paymentTransaction;

    if (!payment || payment.status === 'FAILED') {
      await expireModuleHoldTransaction(booking.id, payment?.status || 'NONE');
      return;
    }

    if (payment.status === 'PAID') {
      logger.info(
        `[expireEventModuleHold] Booking ${bookingId} payment is PAID, no expiration`
      );
      return;
    }

    const MAX_LIFETIME_MS = 15 * 60 * 1000;
    const timeSinceCreationMs = Date.now() - booking.createdAt.getTime();

    if (timeSinceCreationMs >= MAX_LIFETIME_MS) {
      await expireModuleHoldTransaction(booking.id, 'PENDING_TIMEOUT');
      return;
    }

    logger.info(
      `[expireEventModuleHold] Booking ${bookingId} payment PENDING, retrying in 60s`
    );
    await _job.moveToDelayed(Date.now() + 60 * 1000, _job.token);
    throw new DelayedError();
  },
};

export default handler;
