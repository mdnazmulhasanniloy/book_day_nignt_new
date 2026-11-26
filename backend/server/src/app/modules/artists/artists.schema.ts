import { z } from 'zod';

export const artistIdParamsSchema = z.object({
  id: z.string().uuid('Invalid artist id'),
});

export const myArtistsQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export type TArtistIdParams = z.infer<typeof artistIdParamsSchema>;
export type TMyArtistsQuery = z.infer<typeof myArtistsQuerySchema>;
