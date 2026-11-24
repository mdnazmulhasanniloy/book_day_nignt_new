import prisma from '@/app/configs/db.configs';
import { Prisma } from '@prisma/client';
import { mapPrismaError } from '@/app/utils/prismaError.utils';
import { IInterestService, IInterestState } from '@/app/modules/interest/interest.types';

const EVENT_NOT_FOUND = 'Event not found or unavailable';

/** Genuine count: COUNT(*) on read, never a stored counter. */
export const countEventInterests = ({ eventId }: { eventId: string }): Promise<number> =>
  prisma.eventInterest.count({ where: { eventId } });

const assertMarkableEvent = async ({ eventId }: { eventId: string }): Promise<void> => {
  const event = await prisma.event.findFirst({
    where: { id: eventId, deactivatedAt: null, eventStatus: { not: 'CANCELED' } },
    select: { id: true },
  });
  if (!event) {
    throw { statusCode: 404, message: EVENT_NOT_FOUND, errorType: 'NOT_FOUND' };
  }
};

/**
 * Idempotent: one row per (userId, eventId). createMany with skipDuplicates is
 * INSERT ... ON CONFLICT DO NOTHING, so a concurrent duplicate is success and
 * never raises P2002 (a P2002 is still treated as success as a safety net).
 */
export const addInterestService = async ({ userId, eventId }: IInterestService): Promise<IInterestState> => {
  await assertMarkableEvent({ eventId });
  try {
    await prisma.eventInterest.createMany({ data: [{ userId, eventId }], skipDuplicates: true });
  } catch (error) {
    const isDuplicate =
      error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
    if (!isDuplicate) {
      // P2003 (event deleted in between) becomes 404, anything else is rethrown.
      throw mapPrismaError(error, { foreignKey: 'notFound', notFoundMessage: EVENT_NOT_FOUND });
    }
  }
  return { isInterested: true, interestedCount: await countEventInterests({ eventId }) };
};

/** Idempotent: removing a row that does not exist is success. */
export const removeInterestService = async ({ userId, eventId }: IInterestService): Promise<IInterestState> => {
  await assertMarkableEvent({ eventId });
  await prisma.eventInterest.deleteMany({ where: { userId, eventId } });
  return { isInterested: false, interestedCount: await countEventInterests({ eventId }) };
};
