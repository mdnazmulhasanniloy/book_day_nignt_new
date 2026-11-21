import { Job, DelayedError } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IExpireClubBookingHold } from '@/app/queues/system/system.types';
import { QUEUE_JOBS } from '@/const';
import prisma from '@/app/configs/db.configs';
import logger from '@/app/configs/logger.configs';
import { getNotificationQueue } from '@/app/queues/notification/notification.queue';
import { getEmailQueue } from '@/app/queues/email/email.queue';

/**
 * Notifies pending waiting list members that a spot has opened up at the club.
 */
async function notifyWaitingList(clubId: string) {
  try {
    const waitingUsers = await prisma.clubWaitingList.findMany({
      where: { clubId, status: 'PENDING' },
      include: { user: true, club: true },
      take: 10,
    });

    if (waitingUsers.length === 0) return;

    await prisma.clubWaitingList.updateMany({
      where: { id: { in: waitingUsers.map((w) => w.id) } },
      data: { status: 'NOTIFIED', notifiedAt: new Date() },
    });

    const club = waitingUsers[0].club;
    const userIds = waitingUsers.map((w) => w.userId);

    const notificationQueue = getNotificationQueue();
    await notificationQueue.add(QUEUE_JOBS.SEND_FCM_NOTIFICATION, {
      userIds,
      notificationType: 'CLUB_SEAT_AVAILABLE',
      title: 'Table Available!',
      description: `A table just opened up at ${club.name}. Book now before it's gone!`,
      metaData: { clubId },
    });

    const emailQueue = getEmailQueue();
    for (const item of waitingUsers) {
      if (item.user.email) {
        await emailQueue.add(QUEUE_JOBS.SEND_CLUB_WAITING_LIST_EMAIL, {
          userName: item.user.name || 'Club Lover',
          userEmail: item.user.email,
          clubId,
          clubName: club.name,
          clubLocation: club.location || '',
          clubThumbnail: club.thumbnail || '',
          traceId: `waiting-list-${item.id}`,
        });
      }
    }
    logger.info(
      `[notifyWaitingList] Notified ${waitingUsers.length} waiting users for club ${clubId}`
    );
  } catch (err) {
    logger.error('[notifyWaitingList] Failed to notify waiting list', err);
  }
}

/**
 * Executes the expiration transition transactionally.
 * Re-checks status to ensure we don't incorrectly revert a booking modified concurrently.
 */
async function expireHoldTransaction(
  bookingId: string,
  reason: string
): Promise<string | null> {
  return await prisma.$transaction(async (tx) => {
    const current = await tx.clubBooking.findUnique({
      where: { id: bookingId },
    });
    if (current && current.status === 'HOLD') {
      await tx.clubBooking.update({
        where: { id: bookingId },
        data: { status: 'EXPIRED' },
      });
      logger.info(
        `[expireClubBookingHold] Expired booking ${bookingId} due to payment status: ${reason}`
      );
      return current.clubId;
    }
    return null;
  });
}

/**
 * Job: expireClubBookingHold
 * Why it exists: To ensure that Club bookings (which block out tables) do not remain in HOLD indefinitely if the user drops off before paying.
 * Delayed 10 minutes: Normal checkout time.
 * Execution-time re-check: The payment/booking state might have changed (e.g. they paid right at 9m59s). We must evaluate the real state.
 * SUCCESS is not expired: If paid, we leave it alone; the authoritative payment webhook handles finalizing to BOOKED.
 * Limited grace period: A pending checkout shouldn't lock a table forever. Max lifetime is 15 minutes.
 * Cleanup net: The database overlap check still uses `holdExpiresAt`, so if this worker dies, the overlap check ignores stale holds anyway.
 */
const handler: IJobHandler<IExpireClubBookingHold> = {
  name: QUEUE_JOBS.EXPIRE_CLUB_BOOKING_HOLD,
  handler: async (data: IExpireClubBookingHold, _job: Job) => {
    const { bookingId } = data;

    // The worker must re-evaluate current database state at execution time.
    // We use the booking ID as the minimal stable identifier.
    const booking = await prisma.clubBooking.findUnique({
      where: { id: bookingId },
      include: { order: { include: { paymentTransaction: true } } },
    });

    if (!booking) {
      logger.warn(`[expireClubBookingHold] Booking ${bookingId} not found`);
      return;
    }

    // SUCCESS is not expired by this worker. If the booking is already EXPIRED, BOOKED or any other state,
    // this is a no-op, keeping the job safely idempotent.
    if (booking.status !== 'HOLD') {
      logger.info(
        `[expireClubBookingHold] Booking ${bookingId} is no longer HOLD (status: ${booking.status})`
      );
      return;
    }

    const order = booking.order;
    const payment = order.paymentTransaction;

    // CASE A / B: Payment never initiated OR payment failed/canceled.
    if (!payment || payment.status === 'FAILED') {
      const expiredClubId = await expireHoldTransaction(
        booking.id,
        payment?.status || 'NONE'
      );
      if (expiredClubId) {
        await notifyWaitingList(expiredClubId);
      }
      return;
    }

    // CASE C: Payment succeeded
    // No mutation required. Authoritative webhook handles the final state.
    if (payment.status === 'PAID') {
      logger.info(
        `[expireClubBookingHold] Booking ${bookingId} payment is PAID, no expiration mutation here.`
      );
      return;
    }

    // CASE D: Payment is PENDING.
    // Unresolved payment receives a limited grace period. Absolute maximum reservation lifetime is 15 minutes.
    const MAX_LIFETIME_MS = 15 * 60 * 1000;
    const createdAtTime = booking.createdAt.getTime();
    const nowTime = Date.now();
    const timeSinceCreationMs = nowTime - createdAtTime;

    if (timeSinceCreationMs >= MAX_LIFETIME_MS) {
      const expiredClubId = await expireHoldTransaction(
        booking.id,
        'PENDING_TIMEOUT'
      );
      if (expiredClubId) {
        await notifyWaitingList(expiredClubId);
      }
      return;
    }

    // Grace period has not ended. Move to delayed to retry cleanly without polluting error logs.
    logger.info(
      `[expireClubBookingHold] Booking ${bookingId} payment PENDING, retrying in 60s within grace period`
    );
    await _job.moveToDelayed(Date.now() + 60 * 1000, _job.token);
    throw new DelayedError();
  },
};

export default handler;
