import { Prisma, Service } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import {
  parseFixedCstWallClock,
} from '@/app/modules/purchase/purchase.helpers';
import {
  IClubAvailabilityService,
  IClubPurchaseResult,
  ICreateClubPurchaseService,
  ICreateEventPurchaseService,
  ICreateModulePurchaseService,
  IEventPurchaseResult,
  IModulePurchaseResult,
} from '@/app/modules/purchase/purchase.types';
import { getSystemQueue } from '@/app/queues/system/system.queue';
import { QUEUE_JOBS } from '@/const';
import {
  IExpireClubBookingHold,
  IExpireEventModuleHold,
} from '@/app/queues/system/system.types';

/**
 * Reads active Club packages that have capacity and no active overlapping
 * booking for an already-validated fixed-CST interval.
 * @param query Validated Club availability query.
 * @returns Available packages and the reason when no table can be offered.
 */
export const getClubPurchaseAvailabilityService = async ({
  query,
}: IClubAvailabilityService) => {
  try {
    // The project persists fixed-CST wall-clock values as timestamps. Preserve
    // the submitted -06:00 clock fields rather than using host-local time.
    const startAt = parseFixedCstWallClock(query.startAt);
    const endAt = parseFixedCstWallClock(query.endAt);

    const realNow = new Date();
    const availablePackages = await prisma.clubPackage.findMany({
      where: {
        clubId: query.clubId,
        isActive: true,
        capacity: { gte: query.guestCount },
        clubBookings: {
          none: {
            startAt: { lt: endAt },
            endAt: { gt: startAt },
            OR: [
              { status: 'BOOKED' },
              { status: 'HOLD', holdExpiresAt: { gt: realNow } },
            ],
          },
        },
      },
      orderBy: { sortOrder: 'asc' },
    });
    if (availablePackages.length > 0) {
      return { availablePackages, reason: 'AVAILABLE' as const, maxCapacity: null };
    }

    const capacity = await prisma.clubPackage.aggregate({
      where: { clubId: query.clubId, isActive: true },
      _max: { capacity: true },
    });
    const maxCapacity = capacity._max.capacity;
    const reason = maxCapacity === null
      ? 'NO_ACTIVE_TABLES'
      : query.guestCount > maxCapacity
        ? 'CAPACITY_EXCEEDED'
        : 'TIME_UNAVAILABLE';
    return { availablePackages, reason, maxCapacity } as const;
  } catch (error) {
    throw error;
  }
};

/**
 * Persists the pending Club Order and ten-minute table Hold. Middleware has
 * already validated the buyer, package, interval, capacity, opening hours, and
 * request idempotency input. Returns domain records only for controller use.
 * @param userId Authenticated buyer identifier.
 * @param payload Validated Club purchase payload.
 * @param idempotencyKey Validated buyer-scoped idempotency key.
 * @returns Persisted Order and ClubBooking with replay information.
 */
export const createClubPurchaseService = async ({
  userId,
  payload,
  idempotencyKey,
}: ICreateClubPurchaseService): Promise<IClubPurchaseResult> => {
  try {
    const startAt = parseFixedCstWallClock(payload.startAt);
    const endAt = parseFixedCstWallClock(payload.endAt);
    const existingOrder = await prisma.order.findUnique({
      where: {
        buyerUserId_idempotencyKey: { buyerUserId: userId, idempotencyKey },
      },
      include: { clubBooking: true },
    });

    // The durable unique buyer/key pair is the replay record. Middleware owns
    // request-equivalence checks; this branch only returns persisted records.
    if (existingOrder?.clubBooking) {
      return {
        order: existingOrder,
        booking: existingOrder.clubBooking,
        replayed: true,
      };
    }

    const realNow = new Date();
    const result = await prisma.$transaction(
      async (tx) => {
        // Expiry time alone does not release PostgreSQL's active HOLD/BOOKED
        // exclusion constraint. Persist EXPIRED before acquiring another Hold.
        await tx.clubBooking.updateMany({
          where: {
            clubPackageId: payload.clubPackageId,
            status: 'HOLD',
            holdExpiresAt: { lte: realNow },
          },
          data: { status: 'EXPIRED' },
        });

        // These transaction reads provide values for persistence. Middleware
        // has already handled all client-facing purchasability validation.
        const clubPackage = await tx.clubPackage.findUniqueOrThrow({
          where: { id: payload.clubPackageId },
          include: { club: true },
        });
        const buyer = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          include: { profile: true },
        });
        const commission = await tx.applicationCharge.findUniqueOrThrow({
          where: { serviceType: Service.CLUB },
        });
        const serviceCharge = await tx.serviceCharge.findUniqueOrThrow({
          where: { id: 'GLOBAL' },
        });

        // Snapshot commercial values before Order insertion; later package and
        // configuration edits cannot alter this immutable financial history.
        const grossAmount = clubPackage.price;
        const serviceChargeAmount = serviceCharge.amount;
        const buyerTotal = grossAmount.add(serviceChargeAmount);
        const commissionRate = commission.chargePercentage;
        const commissionAmount = grossAmount
          .mul(commissionRate)
          .div(100)
          .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const sellerEarnings = grossAmount.sub(commissionAmount);

        // A payment-ready Order and its table claim are only useful together,
        // so they are written inside the same serializable transaction.
        const order = await tx.order.create({
          data: {
            buyerUserId: userId,
            sellerUserId: clubPackage.club.userId,
            serviceType: Service.CLUB,
            idempotencyKey,
            buyerName: buyer.name,
            buyerPhoneNumber: buyer.phoneNumber,
            buyerDateOfBirth: buyer.profile?.dateOfBirth,
            buyerGender: buyer.profile?.gender,
            buyerImage: buyer.profile?.profileAvatar,
            grossAmount,
            serviceChargeAmount,
            buyerTotal,
            commissionRate,
            commissionAmount,
            sellerEarnings,
            currency: clubPackage.currency,
          },
        });
        const booking = await tx.clubBooking.create({
          data: {
            orderId: order.id,
            clubId: clubPackage.clubId,
            clubPackageId: clubPackage.id,
            startAt,
            endAt,
            // The booking Hold expires 10 minutes from the real current instant;
            // fixed CST wall-clock conversion is for business-time values and
            // must not be used as the expiration base.
            holdExpiresAt: new Date(realNow.getTime() + 10 * 60 * 1000),
            guestCount: payload.guestCount,
            clubName: clubPackage.club.name,
            clubLocation: clubPackage.club.location,
            packageName: clubPackage.name,
            packageCapacity: clubPackage.capacity,
          },
        });
        return { order, booking, replayed: false };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
    );

    // Schedule delayed expiration job strictly AFTER the database transaction commits.
    // The hold logic runs 10 minutes from now. We override job attempts to allow grace period retries.
    // Fixed backoff of 1 minute allows up to 5 additional retries (for max 15m lifetime).
    if (!result.replayed) {
      const payload: IExpireClubBookingHold = { bookingId: result.booking.id };
      await getSystemQueue().add(
        QUEUE_JOBS.EXPIRE_CLUB_BOOKING_HOLD,
        payload,
        {
          jobId: result.booking.id,
          delay: 10 * 60 * 1000,
          attempts: 6,
          backoff: { type: 'fixed', delay: 60 * 1000 },
        }
      );
    }

    return result;
  } catch (error) {
    throw error;
  }
};

/**
 * Persists a pending Event Order, immutable EventPurchase snapshot, and all
 * attendee snapshots. Middleware owns Event/profile/age prerequisites; this
 * service performs the final atomic persistence and returns domain records.
 * @param userId Authenticated buyer identifier.
 * @param payload Validated Event purchase payload.
 * @param idempotencyKey Validated buyer-scoped idempotency key.
 * @returns Persisted Order, EventPurchase, attendees, and replay information.
 */
export const createEventPurchaseService = async ({
  userId,
  payload,
  idempotencyKey,
  buyerAge,
}: ICreateEventPurchaseService): Promise<IEventPurchaseResult> => {
  try {
    const existingOrder = await prisma.order.findUnique({
      where: {
        buyerUserId_idempotencyKey: { buyerUserId: userId, idempotencyKey },
      },
      include: { eventPurchase: { include: { attendees: true } } },
    });
    if (existingOrder?.eventPurchase) {
      return {
        order: existingOrder,
        eventPurchase: existingOrder.eventPurchase,
        attendees: existingOrder.eventPurchase.attendees,
        replayed: true,
      };
    }

    return await prisma.$transaction(
      async (tx) => {
        const event = await tx.event.findUniqueOrThrow({
          where: { id: payload.eventId },
        });
        const buyer = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          include: { profile: true },
        });
        const commission = await tx.applicationCharge.findUniqueOrThrow({
          where: { serviceType: Service.EVENT },
        });
        const serviceCharge = await tx.serviceCharge.findUniqueOrThrow({
          where: { id: 'GLOBAL' },
        });

        // Buyer identity and age are server-derived snapshots; the Flutter
        // client cannot provide or later alter ticket/PDF history fields.
        const personCount = payload.friends.length + 1;
        let pricePerPerson = event.eventPrice;

        if (payload.ticketTierId) {
          const tier = await tx.eventTicketTier.findUnique({
            where: { id: payload.ticketTierId },
          });
          if (!tier || !tier.isActive || tier.eventId !== payload.eventId) {
            throw { statusCode: 404, message: 'Ticket tier not found' };
          }
          if (tier.soldCount + personCount > tier.capacity) {
            throw { statusCode: 409, message: 'Ticket tier is sold out' };
          }
          pricePerPerson = tier.price;
          await tx.eventTicketTier.update({
            where: { id: tier.id },
            data: { soldCount: { increment: personCount } },
          });
        }

        let grossAmount = pricePerPerson.mul(personCount);

        // Apply promo code discount if provided
        if (payload.promoCode) {
          const promo = await tx.promoCode.findUnique({
            where: { code: payload.promoCode.trim().toUpperCase() },
          });
          if (
            promo &&
            promo.isActive &&
            (!promo.expiresAt || new Date() <= promo.expiresAt) &&
            (promo.maxUses === null || promo.usedCount < promo.maxUses) &&
            (!promo.eventId || promo.eventId === payload.eventId)
          ) {
            let discountAmount = new Prisma.Decimal(0);
            if (promo.discountType === 'PERCENTAGE') {
              discountAmount = grossAmount.mul(promo.discountValue).div(100);
            } else {
              discountAmount = Prisma.Decimal.min(grossAmount, promo.discountValue);
            }
            grossAmount = Prisma.Decimal.max(new Prisma.Decimal(0), grossAmount.sub(discountAmount));
            await tx.promoCode.update({
              where: { id: promo.id },
              data: { usedCount: { increment: 1 } },
            });
          }
        }

        const serviceChargeAmount = serviceCharge.amount;
        const buyerTotal = grossAmount.add(serviceChargeAmount);
        const commissionRate = commission.chargePercentage;
        const commissionAmount = grossAmount
          .mul(commissionRate)
          .div(100)
          .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
        const sellerEarnings = grossAmount.sub(commissionAmount);

        // One transaction prevents partial ticket history and snapshots the
        // commercial terms before later Event, profile, or config edits.
        const order = await tx.order.create({
          data: {
            buyerUserId: userId,
            sellerUserId: event.userId,
            serviceType: Service.EVENT,
            idempotencyKey,
            buyerName: buyer.name,
            buyerPhoneNumber: buyer.phoneNumber,
            buyerDateOfBirth: buyer.profile!.dateOfBirth,
            buyerGender: buyer.profile!.gender,
            buyerImage: buyer.profile!.profileAvatar,
            grossAmount,
            serviceChargeAmount,
            buyerTotal,
            commissionRate,
            commissionAmount,
            sellerEarnings,
            currency: event.currency,
          },
        });
        const eventPurchase = await tx.eventPurchase.create({
          data: {
            orderId: order.id,
            eventId: event.id,
            personCount,
            eventName: event.eventName,
            eventLocation: event.location,
            eventStartAt: event.startAt,
            eventEndAt: event.endAt,
            pricePerPerson,
            // This is based on the immutable EventPurchase start snapshot so
            // UI and future workers are insulated from live Event edits.
            transferEligibleAt: new Date(
              event.startAt.getTime() - 6 * 60 * 60 * 1000
            ),
          },
        });
        await tx.eventPurchaseAttendee.createMany({
          data: [
            {
              eventPurchaseId: eventPurchase.id,
              attendeeType: 'BUYER',
              position: 1,
              name: buyer.name,
              phoneNumber: buyer.phoneNumber,
              gender: buyer.profile!.gender,
              age: buyerAge,
              image: buyer.profile!.profileAvatar,
            },
            ...payload.friends.map((friend, index) => ({
              eventPurchaseId: eventPurchase.id,
              attendeeType: 'FRIEND' as const,
              position: index + 2,
              ...friend,
            })),
          ],
        });
        const attendees = await tx.eventPurchaseAttendee.findMany({
          where: { eventPurchaseId: eventPurchase.id },
          orderBy: { position: 'asc' },
        });
        return { order, eventPurchase, attendees, replayed: false };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
    );
  } catch (error) {
    throw error;
  }
};

/**
 * Persists a pending Event VIP-module Order + HOLD booking, decrementing module
 * remaining inventory until payment succeeds or the hold expires.
 */
export const createModulePurchaseService = async ({
  userId,
  payload,
  idempotencyKey,
}: ICreateModulePurchaseService): Promise<IModulePurchaseResult> => {
  const existingOrder = await prisma.order.findUnique({
    where: {
      buyerUserId_idempotencyKey: { buyerUserId: userId, idempotencyKey },
    },
    include: { eventModulePurchase: true },
  });

  if (existingOrder?.eventModulePurchase) {
    return {
      order: existingOrder,
      booking: existingOrder.eventModulePurchase,
      replayed: true,
    };
  }

  const realNow = new Date();

  const result = await prisma.$transaction(
    async (tx) => {
      const event = await tx.event.findUnique({
        where: { id: payload.eventId },
      });

      if (!event || event.deactivatedAt !== null) {
        throw { statusCode: 404, message: 'Event not found' };
      }

      if (event.bookingsClosed) {
        throw { statusCode: 409, message: 'Ticket sales are closed for this event' };
      }

      const module = await tx.eventModule.findFirst({
        where: {
          id: payload.moduleId,
          eventId: payload.eventId,
          isActive: true,
        },
      });

      if (!module) {
        throw { statusCode: 404, message: 'Module not found' };
      }

      if (
        module.status === 'UNAVAILABLE' ||
        module.status === 'SOLD_OUT' ||
        module.remaining <= 0
      ) {
        throw { statusCode: 409, message: 'Module is sold out or unavailable' };
      }

      if (payload.quantity > module.remaining) {
        throw {
          statusCode: 409,
          message: `Only ${module.remaining} remaining for this module`,
        };
      }

      if (payload.guestCount > module.maxGuests) {
        throw {
          statusCode: 422,
          message: `guestCount cannot exceed maxGuests (${module.maxGuests})`,
        };
      }

      const buyer = await tx.user.findUniqueOrThrow({
        where: { id: userId },
        include: { profile: true },
      });
      const commission = await tx.applicationCharge.findUniqueOrThrow({
        where: { serviceType: Service.EVENT },
      });
      const serviceCharge = await tx.serviceCharge.findUniqueOrThrow({
        where: { id: 'GLOBAL' },
      });

      let grossAmount = module.startingPrice.mul(payload.quantity);

      if (payload.promoCode) {
        const promo = await tx.promoCode.findUnique({
          where: { code: payload.promoCode.trim().toUpperCase() },
        });
        if (
          promo &&
          promo.isActive &&
          (!promo.expiresAt || new Date() <= promo.expiresAt) &&
          (promo.maxUses === null || promo.usedCount < promo.maxUses) &&
          (!promo.eventId || promo.eventId === payload.eventId)
        ) {
          let discountAmount = new Prisma.Decimal(0);
          if (promo.discountType === 'PERCENTAGE') {
            discountAmount = grossAmount.mul(promo.discountValue).div(100);
          } else {
            discountAmount = Prisma.Decimal.min(
              grossAmount,
              promo.discountValue
            );
          }
          grossAmount = Prisma.Decimal.max(
            new Prisma.Decimal(0),
            grossAmount.sub(discountAmount)
          );
          await tx.promoCode.update({
            where: { id: promo.id },
            data: { usedCount: { increment: 1 } },
          });
        }
      }

      const serviceChargeAmount = serviceCharge.amount;
      const buyerTotal = grossAmount.add(serviceChargeAmount);
      const commissionRate = commission.chargePercentage;
      const commissionAmount = grossAmount
        .mul(commissionRate)
        .div(100)
        .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
      const sellerEarnings = grossAmount.sub(commissionAmount);

      const nextRemaining = module.remaining - payload.quantity;
      await tx.eventModule.update({
        where: { id: module.id },
        data: {
          remaining: nextRemaining,
          ...(nextRemaining <= 0 ? { status: 'SOLD_OUT' } : {}),
        },
      });

      const order = await tx.order.create({
        data: {
          buyerUserId: userId,
          sellerUserId: event.userId,
          serviceType: Service.EVENT,
          idempotencyKey,
          buyerName: buyer.name,
          buyerPhoneNumber: buyer.phoneNumber,
          buyerDateOfBirth: buyer.profile?.dateOfBirth,
          buyerGender: buyer.profile?.gender,
          buyerImage: buyer.profile?.profileAvatar,
          grossAmount,
          serviceChargeAmount,
          buyerTotal,
          commissionRate,
          commissionAmount,
          sellerEarnings,
          currency: module.currency,
        },
      });

      const booking = await tx.eventModulePurchase.create({
        data: {
          orderId: order.id,
          eventId: event.id,
          moduleId: module.id,
          quantity: payload.quantity,
          guestCount: payload.guestCount,
          dateTime: payload.dateTime ? new Date(payload.dateTime) : null,
          holdExpiresAt: new Date(realNow.getTime() + 10 * 60 * 1000),
          moduleName: module.name,
          venueArea: module.venueArea,
          unitPrice: module.startingPrice,
          status: 'HOLD',
        },
      });

      return { order, booking, replayed: false };
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }
  );

  if (!result.replayed) {
    const jobPayload: IExpireEventModuleHold = {
      bookingId: result.booking.id,
    };
    await getSystemQueue().add(
      QUEUE_JOBS.EXPIRE_EVENT_MODULE_HOLD,
      jobPayload,
      {
        jobId: `module-hold-${result.booking.id}`,
        delay: 10 * 60 * 1000,
        attempts: 6,
        backoff: { type: 'fixed', delay: 60 * 1000 },
      }
    );
  }

  return result;
};
