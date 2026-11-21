import { QuoteStatus } from '@prisma/client';
import { z } from 'zod';

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

export const createQuoteSchema = z.preprocess(
  (raw) =>
    raw && typeof raw === 'object' && !Array.isArray(raw)
      ? normalizeMessageKey(raw as Record<string, unknown>)
      : raw,
  z
    .object({
      eventId: z.string().uuid(),
      moduleId: z.string().uuid(),
      name: z.string().trim().min(1).max(120),
      email: z.string().trim().email(),
      phone: z.string().trim().min(1).max(40),
      guestCount: z.coerce.number().int().positive(),
      message: z.string().trim().min(1).max(2000),
      date: z.string().datetime({ offset: true }).optional().nullable(),
    })
    .strict()
);

export const listQuotesQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export const quoteIdParamsSchema = z.object({
  id: z.string().uuid('Invalid quote id'),
});

export const updateQuoteSchema = z
  .object({
    status: z.nativeEnum(QuoteStatus),
  })
  .strict();

export type TCreateQuotePayload = z.infer<typeof createQuoteSchema>;
export type TListQuotesQuery = z.infer<typeof listQuotesQuerySchema>;
export type TQuoteIdParams = z.infer<typeof quoteIdParamsSchema>;
export type TUpdateQuotePayload = z.infer<typeof updateQuoteSchema>;
