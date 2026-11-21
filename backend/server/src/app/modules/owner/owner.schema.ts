import { z } from 'zod';

export const ownerEarningsQuerySchema = z.object({
  year: z.coerce.number().int().min(2000).max(2100).optional(),
});

export const ownerPaymentsQuerySchema = z
  .object({
    type: z.enum(['CLUB', 'EVENT']).optional(),
    clubId: z.string().uuid().optional(),
    eventId: z.string().uuid().optional(),
    page: z.coerce.number().int().min(1).optional(),
    limit: z.coerce.number().int().min(1).max(50).optional(),
  })
  .refine(
    (data) => {
      if (data.clubId && data.type !== 'CLUB') return false;
      if (data.eventId && data.type !== 'EVENT') return false;
      if (data.clubId && data.eventId) return false;
      return true;
    },
    {
      message: 'Invalid filter combination: clubId requires type=CLUB, eventId requires type=EVENT, and they cannot be combined',
      path: ['type'],
    }
  );

/** YYYY-MM-DD → UTC day start/end; otherwise parse as ISO datetime. */
export const parseOwnerExportBound = (
  value: string,
  edge: 'start' | 'end'
): Date => {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return edge === 'start'
      ? new Date(`${value}T00:00:00.000Z`)
      : new Date(`${value}T23:59:59.999Z`);
  }
  return new Date(value);
};

/** Accept YYYY-MM-DD or ISO-8601 datetime with offset. */
const ownerExportDateSchema = z.union([
  z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD'),
  z.string().datetime({ offset: true }),
]);

export const ownerBookingsExportQuerySchema = z
  .object({
    from: ownerExportDateSchema,
    to: ownerExportDateSchema,
    type: z.enum(['CLUB', 'EVENT']),
    clubId: z.string().uuid().optional(),
    eventId: z.string().uuid().optional(),
  })
  .strict()
  .refine(
    (data) => {
      if (data.clubId && data.type !== 'CLUB') return false;
      if (data.eventId && data.type !== 'EVENT') return false;
      if (data.clubId && data.eventId) return false;
      return true;
    },
    {
      message:
        'Invalid filter combination: clubId requires type=CLUB, eventId requires type=EVENT, and they cannot be combined',
      path: ['type'],
    }
  )
  .refine(
    (data) => {
      const from = parseOwnerExportBound(data.from, 'start');
      const to = parseOwnerExportBound(data.to, 'end');
      return from.getTime() <= to.getTime();
    },
    {
      message: 'from must be before or equal to to',
      path: ['from'],
    }
  );

export type TOwnerBookingsExportQuery = z.infer<
  typeof ownerBookingsExportQuerySchema
>;

export const verifyTicketSchema = z.object({
  orderId: z.string().uuid(),
});