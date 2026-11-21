import { z } from 'zod';

export const followClubParamsSchema = z.object({
  clubId: z.string().uuid(),
});

export const getFollowingQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
});

export type TFollowClubParams = z.infer<typeof followClubParamsSchema>;
export type TGetFollowingQuery = z.infer<typeof getFollowingQuerySchema>;
