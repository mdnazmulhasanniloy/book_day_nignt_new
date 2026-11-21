import { z } from 'zod';

export const guestListEventParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
});

export const guestListEntryParamsSchema = z.object({
  eventId: z.string().uuid('Invalid event id'),
  id: z.string().uuid('Invalid entry id'),
});

export const guestListFallbackSchema = z
  .object({
    type: z.enum(['TICKET_TIER', 'MODULE', 'CLUB_PACKAGE', 'WAITING_LIST']),
    id: z.string().uuid(),
  })
  .strict();

export const upsertGuestListSchema = z
  .object({
    isEnabled: z.boolean(),
    daysBefore: z.coerce.number().int().min(0).optional().nullable(),
    cutoffAt: z.string().datetime({ offset: true }).optional().nullable(),
    arrivalTimes: z.array(z.string().trim().min(1)).default([]),
    maleCap: z.coerce.number().int().min(0).optional().nullable(),
    femaleCap: z.coerce.number().int().min(0).optional().nullable(),
    freeSpots: z.coerce.number().int().min(0).optional().nullable(),
    dressCode: z.string().trim().max(500).optional().nullable(),
    idRequired: z.boolean().optional().default(false),
    notes: z.string().trim().max(2000).optional().nullable(),
    fallbacks: z.array(guestListFallbackSchema).default([]),
  })
  .strict();

export const joinGuestListSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    email: z.string().trim().email(),
    phone: z.string().trim().min(1).max(40),
    menCount: z.coerce.number().int().min(0).default(0),
    womenCount: z.coerce.number().int().min(0).default(0),
    otherCount: z.coerce.number().int().min(0).default(0),
    // Optional when owner left arrivalTimes empty; clients may omit the field.
    arrivalTime: z.preprocess(
      (val) =>
        val === undefined || val === null || val === '' ? 'Anytime' : val,
      z.string().trim().min(1).max(80)
    ),
    acceptedTerms: z.literal(true),
  })
  .strict()
  .refine(
    (data) => data.menCount + data.womenCount + data.otherCount > 0,
    {
      message: 'At least one guest is required',
      path: ['menCount'],
    }
  );

export const guestListEntriesQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export const updateGuestListEntrySchema = z
  .object({
    status: z.enum(['CONFIRMED', 'REJECTED']),
  })
  .strict();

export type TGuestListEventParams = z.infer<typeof guestListEventParamsSchema>;
export type TGuestListEntryParams = z.infer<typeof guestListEntryParamsSchema>;
export type TUpsertGuestListPayload = z.infer<typeof upsertGuestListSchema>;
export type TJoinGuestListPayload = z.infer<typeof joinGuestListSchema>;
export type TGuestListEntriesQuery = z.infer<typeof guestListEntriesQuerySchema>;
export type TUpdateGuestListEntryPayload = z.infer<
  typeof updateGuestListEntrySchema
>;
