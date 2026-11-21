import { z } from 'zod';

export const joinWaitingListSchema = z.object({
  clubId: z.string().min(1, 'clubId is required'),
  startAt: z.coerce.date().optional(),
  guestCount: z.coerce.number().int().positive().max(100).optional(),
});

export type TJoinWaitingListPayload = z.infer<typeof joinWaitingListSchema>;

export const leaveWaitingListSchema = z.object({
  clubId: z.string().min(1, 'clubId is required'),
});

export type TLeaveWaitingListPayload = z.infer<typeof leaveWaitingListSchema>;

export const clubWaitingListStatusParamsSchema = z.object({
  clubId: z.string().min(1, 'clubId is required'),
});

export type TClubWaitingListStatusParams = z.infer<
  typeof clubWaitingListStatusParamsSchema
>;

export const clubWaitingListMembersParamsSchema = z.object({
  clubId: z.string().uuid('Invalid club id'),
});

export type TClubWaitingListMembersParams = z.infer<
  typeof clubWaitingListMembersParamsSchema
>;

export const myWaitingListQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export type TMyWaitingListQuery = z.infer<typeof myWaitingListQuerySchema>;

export const clubWaitingListMembersQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

export type TClubWaitingListMembersQuery = z.infer<
  typeof clubWaitingListMembersQuerySchema
>;

export const waitingListEntryParamsSchema = z.object({
  id: z.string().uuid('Invalid waiting list entry id'),
});

export type TWaitingListEntryParams = z.infer<
  typeof waitingListEntryParamsSchema
>;
