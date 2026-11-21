import { z } from 'zod';

export const validatePromoCodeSchema = z.object({
  code: z.string().trim().min(1, 'Promo code cannot be empty'),
  originalAmount: z.coerce.number().positive('Original amount must be greater than zero'),
  eventId: z.string().uuid().optional(),
  clubId: z.string().uuid().optional(),
});

export const createPromoCodeSchema = z.object({
  code: z.string().trim().min(2).toUpperCase(),
  discountType: z.enum(['PERCENTAGE', 'FIXED_AMOUNT']),
  discountValue: z.coerce.number().positive(),
  eventId: z.string().uuid().optional(),
  clubId: z.string().uuid().optional(),
  maxUses: z.coerce.number().int().positive().optional(),
  expiresAt: z.coerce.date().optional(),
}).refine(
  (data) => {
    if (data.discountType === 'PERCENTAGE' && data.discountValue > 100) {
      return false;
    }
    return true;
  },
  {
    message: 'Percentage discount cannot exceed 100%',
    path: ['discountValue'],
  }
);

export const listPromoQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export const promoIdParamsSchema = z.object({
  id: z.string().uuid('Invalid promo id'),
});

export const updatePromoCodeSchema = z
  .object({
    code: z.string().trim().min(2).toUpperCase().optional(),
    discountType: z.enum(['PERCENTAGE', 'FIXED_AMOUNT']).optional(),
    discountValue: z.coerce.number().positive().optional(),
    eventId: z.union([z.null(), z.string().uuid()]).optional(),
    clubId: z.union([z.null(), z.string().uuid()]).optional(),
    maxUses: z.union([z.null(), z.coerce.number().int().positive()]).optional(),
    expiresAt: z.union([z.null(), z.coerce.date()]).optional(),
    isActive: z.boolean().optional(),
  })
  .refine(
    (data) =>
      data.code !== undefined ||
      data.discountType !== undefined ||
      data.discountValue !== undefined ||
      data.eventId !== undefined ||
      data.clubId !== undefined ||
      data.maxUses !== undefined ||
      data.expiresAt !== undefined ||
      data.isActive !== undefined,
    {
      message: 'At least one field is required',
    }
  )
  .refine(
    (data) => {
      if (
        data.discountType === 'PERCENTAGE' &&
        data.discountValue !== undefined &&
        data.discountValue > 100
      ) {
        return false;
      }
      return true;
    },
    {
      message: 'Percentage discount cannot exceed 100%',
      path: ['discountValue'],
    }
  );

export type TValidatePromoCodePayload = z.infer<typeof validatePromoCodeSchema>;
export type TCreatePromoCodePayload = z.infer<typeof createPromoCodeSchema>;
export type TListPromoQuery = z.infer<typeof listPromoQuerySchema>;
export type TPromoIdParams = z.infer<typeof promoIdParamsSchema>;
export type TUpdatePromoCodePayload = z.infer<typeof updatePromoCodeSchema>;
