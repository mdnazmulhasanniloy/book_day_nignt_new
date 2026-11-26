import prisma from '@/app/configs/db.configs';
import {
  IValidatePromoCodeParams,
  IValidatePromoCodeResponse,
  ICreatePromoCodeParams,
  IListPromoCodesParams,
  IUpdatePromoCodeParams,
  IDeletePromoCodeParams,
} from '@/app/modules/promo/promo.types';
import { DiscountType, Prisma, PromoCode } from '@prisma/client';

const ownedPromoAccessFilter = (userId: string): Prisma.PromoCodeWhereInput => ({
  OR: [
    { createdByUserId: userId },
    { event: { is: { userId } } },
    { club: { is: { userId } } },
    {
      AND: [
        { eventId: null },
        { clubId: null },
        { createdByUserId: null },
      ],
    },
  ],
});

const findOwnedPromoOrThrow = async ({
  id,
  userId,
}: {
  id: string;
  userId: string;
}): Promise<PromoCode> => {
  const promo = await prisma.promoCode.findFirst({
    where: {
      id,
      ...ownedPromoAccessFilter(userId),
    },
  });

  if (!promo) {
    throw { statusCode: 404, message: 'Promo code not found' };
  }

  return promo;
};

/**
 * Service to validate a promo code and calculate discount amount.
 */
export const validatePromoCodeService = async ({
  code,
  originalAmount,
  eventId,
  clubId,
}: IValidatePromoCodeParams): Promise<IValidatePromoCodeResponse> => {
  const normalizedCode = code.trim().toUpperCase();

  const promo = await prisma.promoCode.findUnique({
    where: { code: normalizedCode },
  });

  if (!promo || !promo.isActive) {
    throw { statusCode: 404, message: 'Invalid or inactive promo code' };
  }

  if (promo.expiresAt && new Date() > promo.expiresAt) {
    throw { statusCode: 400, message: 'This promo code has expired' };
  }

  if (promo.maxUses !== null && promo.usedCount >= promo.maxUses) {
    throw { statusCode: 400, message: 'This promo code has reached its usage limit' };
  }

  if (promo.eventId && eventId && promo.eventId !== eventId) {
    throw { statusCode: 400, message: 'Promo code is not applicable for this event' };
  }

  if (promo.clubId && clubId && promo.clubId !== clubId) {
    throw { statusCode: 400, message: 'Promo code is not applicable for this club' };
  }

  const numericDiscountValue = Number(promo.discountValue);
  let discountAmount = 0;

  if (promo.discountType === DiscountType.PERCENTAGE) {
    discountAmount = (originalAmount * numericDiscountValue) / 100;
  } else {
    discountAmount = Math.min(originalAmount, numericDiscountValue);
  }

  // Round to 2 decimal places
  discountAmount = Math.round(discountAmount * 100) / 100;
  const finalAmount = Math.max(0, Math.round((originalAmount - discountAmount) * 100) / 100);

  return {
    isValid: true,
    code: promo.code,
    discountType: promo.discountType,
    discountValue: numericDiscountValue,
    discountAmount,
    finalAmount,
  };
};

/**
 * Service to create a new promo code.
 */
export const createPromoCodeService = async (
  params: ICreatePromoCodeParams
): Promise<PromoCode> => {
  const {
    userId,
    code,
    discountType,
    discountValue,
    eventId,
    clubId,
    maxUses,
    expiresAt,
  } = params;
  const normalizedCode = code.trim().toUpperCase();

  const existing = await prisma.promoCode.findUnique({
    where: { code: normalizedCode },
  });

  if (existing) {
    throw { statusCode: 409, message: `Promo code '${normalizedCode}' already exists` };
  }

  return prisma.promoCode.create({
    data: {
      code: normalizedCode,
      discountType,
      discountValue,
      eventId: eventId || null,
      clubId: clubId || null,
      createdByUserId: userId,
      maxUses: maxUses || null,
      expiresAt: expiresAt || null,
      isActive: true,
    },
  });
};

/**
 * Lists promo codes created by the caller, including global codes with no
 * eventId/clubId, plus codes attached to the caller's events or clubs.
 */
export const listPromoCodesService = async ({
  userId,
  query,
}: IListPromoCodesParams) => {
  const { page, limit } = query;
  const skip = (page - 1) * limit;

  const where: Prisma.PromoCodeWhereInput = ownedPromoAccessFilter(userId);

  const [data, total] = await Promise.all([
    prisma.promoCode.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    }),
    prisma.promoCode.count({ where }),
  ]);

  return {
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
    data,
  };
};

/**
 * Updates a promo owned by the caller.
 */
export const updatePromoCodeService = async ({
  id,
  userId,
  payload,
}: IUpdatePromoCodeParams): Promise<PromoCode> => {
  const existing = await findOwnedPromoOrThrow({ id, userId });

  const nextDiscountType = payload.discountType ?? existing.discountType;
  const nextDiscountValue =
    payload.discountValue !== undefined
      ? payload.discountValue
      : Number(existing.discountValue);

  if (nextDiscountType === DiscountType.PERCENTAGE && nextDiscountValue > 100) {
    throw {
      statusCode: 422,
      message: 'Percentage discount cannot exceed 100%',
    };
  }

  let nextCode = existing.code;
  if (payload.code !== undefined) {
    nextCode = payload.code.trim().toUpperCase();
    if (nextCode !== existing.code) {
      const conflict = await prisma.promoCode.findUnique({
        where: { code: nextCode },
      });
      if (conflict) {
        throw {
          statusCode: 409,
          message: `Promo code '${nextCode}' already exists`,
        };
      }
    }
  }

  const data: Prisma.PromoCodeUpdateInput = {};
  if (payload.code !== undefined) data.code = nextCode;
  if (payload.discountType !== undefined) data.discountType = payload.discountType;
  if (payload.discountValue !== undefined) data.discountValue = payload.discountValue;
  if (payload.eventId !== undefined) {
    data.event = payload.eventId
      ? { connect: { id: payload.eventId } }
      : { disconnect: true };
  }
  if (payload.clubId !== undefined) {
    data.club = payload.clubId
      ? { connect: { id: payload.clubId } }
      : { disconnect: true };
  }
  if (payload.maxUses !== undefined) data.maxUses = payload.maxUses;
  if (payload.expiresAt !== undefined) data.expiresAt = payload.expiresAt;
  if (payload.isActive !== undefined) data.isActive = payload.isActive;

  return prisma.promoCode.update({
    where: { id: existing.id },
    data,
  });
};

/**
 * Hard-deletes a promo owned by the caller.
 */
export const deletePromoCodeService = async ({
  id,
  userId,
}: IDeletePromoCodeParams): Promise<void> => {
  const existing = await findOwnedPromoOrThrow({ id, userId });
  await prisma.promoCode.delete({ where: { id: existing.id } });
};
