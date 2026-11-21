import { z } from 'zod';

export const createHostSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    role: z.string().trim().min(1).max(120),
    isVerified: z.boolean().optional().default(false),
    photo: z.string().url().optional().nullable(),
    whatsapp: z.string().trim().min(1).max(500).optional().nullable(),
    phone: z.string().trim().min(1).max(40).optional().nullable(),
    email: z.string().trim().email().optional().nullable(),
    bio: z.string().trim().max(2000).optional().nullable(),
    officialPricesNote: z.string().trim().max(1000).optional().nullable(),
    isActive: z.boolean().optional().default(true),
  })
  .strict();

export const updateHostSchema = z
  .object({
    name: z.string().trim().min(1).max(120).optional(),
    role: z.string().trim().min(1).max(120).optional(),
    isVerified: z.boolean().optional(),
    photo: z.string().url().optional().nullable(),
    whatsapp: z.string().trim().min(1).max(500).optional().nullable(),
    phone: z.string().trim().min(1).max(40).optional().nullable(),
    email: z.string().trim().email().optional().nullable(),
    bio: z.string().trim().max(2000).optional().nullable(),
    officialPricesNote: z.string().trim().max(1000).optional().nullable(),
    isActive: z.boolean().optional(),
  })
  .strict()
  .refine((data) => Object.keys(data).length > 0, {
    message: 'At least one field is required',
  });

export const hostIdParamsSchema = z.object({
  id: z.string().uuid('Invalid host id'),
});

export const attachHostSchema = z
  .object({
    hostId: z.string().uuid(),
  })
  .strict();

export const eventHostParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
});

export const eventHostUnassignParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
  hostId: z.string().uuid('Invalid host id'),
});

export const clubHostParamsSchema = z.object({
  clubId: z.string().uuid('Invalid club id'),
});

/** Accept `message` or PascalCase `Message` (Flutter clients). */
const normalizeMessageKey = <T extends Record<string, unknown>>(input: T) => {
  if (input.message == null && input.Message != null) {
    const { Message, ...rest } = input;
    return { ...rest, message: Message };
  }
  if ('Message' in input) {
    const { Message: _Message, ...rest } = input;
    return rest;
  }
  return input;
};

export const hostContactSchema = z.preprocess(
  (raw) =>
    raw && typeof raw === 'object' && !Array.isArray(raw)
      ? normalizeMessageKey(raw as Record<string, unknown>)
      : raw,
  z
    .object({
      name: z.string().trim().min(1).max(120),
      email: z.string().trim().email(),
      phone: z.string().trim().min(1).max(40),
      message: z.string().trim().min(1).max(2000),
      eventId: z.string().uuid('Invalid event id').optional(),
    })
    .strict()
);

export type TCreateHostPayload = z.infer<typeof createHostSchema>;
export type TUpdateHostPayload = z.infer<typeof updateHostSchema>;
export type THostIdParams = z.infer<typeof hostIdParamsSchema>;
export type TAttachHostPayload = z.infer<typeof attachHostSchema>;
export type TEventHostParams = z.infer<typeof eventHostParamsSchema>;
export type TEventHostUnassignParams = z.infer<
  typeof eventHostUnassignParamsSchema
>;
export type TClubHostParams = z.infer<typeof clubHostParamsSchema>;
export type THostContactPayload = z.infer<typeof hostContactSchema>;
