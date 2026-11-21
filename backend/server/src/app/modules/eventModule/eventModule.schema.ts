import { EventModuleStatus } from '@prisma/client';
import { z } from 'zod';

export const eventModuleParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
});

export const eventModuleIdParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
  id: z.string().uuid('Invalid module id'),
});

const moneyString = z
  .union([z.string(), z.number()])
  .transform((v) => String(v))
  .refine((v) => /^\d+(\.\d{1,2})?$/.test(v), {
    message: 'Money must be a decimal string with up to 2 places',
  });

export const createEventModuleSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    image: z.string().url().optional().nullable(),
    description: z.string().trim().max(2000).optional().nullable(),
    maxGuests: z.coerce.number().int().positive(),
    startingPrice: moneyString,
    minSpend: moneyString.optional().default('0.00'),
    deposit: moneyString.optional().default('0.00'),
    currency: z.string().trim().min(3).max(3).default('EUR'),
    quantity: z.coerce.number().int().positive(),
    venueArea: z.string().trim().max(120).optional().nullable(),
    includedExtras: z.array(z.string().trim().min(1)).default([]),
    optionalExtras: z.array(z.string().trim().min(1)).default([]),
    status: z.nativeEnum(EventModuleStatus).optional().default('AVAILABLE'),
    sortOrder: z.coerce.number().int().min(0).optional(),
    isActive: z.boolean().optional().default(true),
  })
  .strict();

export const updateEventModuleSchema = z
  .object({
    name: z.string().trim().min(1).max(120).optional(),
    image: z.string().url().optional().nullable(),
    description: z.string().trim().max(2000).optional().nullable(),
    maxGuests: z.coerce.number().int().positive().optional(),
    startingPrice: moneyString.optional(),
    minSpend: moneyString.optional(),
    deposit: moneyString.optional(),
    currency: z.string().trim().min(3).max(3).optional(),
    quantity: z.coerce.number().int().positive().optional(),
    remaining: z.coerce.number().int().min(0).optional(),
    venueArea: z.string().trim().max(120).optional().nullable(),
    includedExtras: z.array(z.string().trim().min(1)).optional(),
    optionalExtras: z.array(z.string().trim().min(1)).optional(),
    status: z.nativeEnum(EventModuleStatus).optional(),
    sortOrder: z.coerce.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
  })
  .strict()
  .refine((data) => Object.keys(data).length > 0, {
    message: 'At least one field is required',
  });

export const reorderEventModulesSchema = z
  .object({
    ids: z.array(z.string().uuid()).min(1),
  })
  .strict();

export type TEventModuleParams = z.infer<typeof eventModuleParamsSchema>;
export type TEventModuleIdParams = z.infer<typeof eventModuleIdParamsSchema>;
export type TCreateEventModulePayload = z.infer<typeof createEventModuleSchema>;
export type TUpdateEventModulePayload = z.infer<typeof updateEventModuleSchema>;
export type TReorderEventModulesPayload = z.infer<
  typeof reorderEventModulesSchema
>;
