import { z } from 'zod';

export const eventStatusEnum = z.enum([
  'UPCOMING',
  'ONGOING',
  'COMPLETED',
  'CANCELED',
]);

export const eventCategoryTypeEnum = z.enum([
  'CLUB',
  'CONCERT',
  'FESTIVAL',
  'OPEN_AIR',
  'WAREHOUSE',
]);

const eventTicketTierBaseSchema = z.object({
  id: z.string().uuid().optional(),
  tierName: z.string().min(1),
  groupName: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
  price: z.coerce.number().nonnegative(),
  capacity: z.coerce.number().int().positive(),
  sortOrder: z.coerce.number().int().default(0),
  startAt: z.coerce.date().nullable().optional(),
  endAt: z.coerce.date().nullable().optional(),
  isActive: z.boolean().default(true),
});

export const eventTicketTierSchema = eventTicketTierBaseSchema.extend({
  children: z.array(eventTicketTierBaseSchema).optional().default([]),
});

export const eventLineupSchema = z.object({
  id: z.string().uuid().optional(),
  artistName: z.string().min(1),
  artistAvatar: z.string().url().nullable().optional(),
  audioPreviewUrl: z.string().url().nullable().optional(),
  spotifyUrl: z.string().url().nullable().optional(),
  soundcloudUrl: z.string().url().nullable().optional(),
  isVerified: z.boolean().default(false),
  sortOrder: z.coerce.number().int().default(0),
});

export const createEventSchema = z
  .object({
    eventName: z.string().min(1),
    eventDescription: z.string().nullable().optional(),
    thumbnail: z.url(),
    images: z.array(z.url()),
    eventStatus: eventStatusEnum.default('UPCOMING'),
    categoryType: eventCategoryTypeEnum.default('CLUB'),
    musicGenres: z.array(z.string()).default([]),
    moodTags: z.array(z.string()).default([]),
    isResaleEnabled: z.boolean().default(false),
    ticketTiers: z.array(eventTicketTierSchema).optional(),
    lineup: z.array(eventLineupSchema).optional(),
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    location: z.string().min(1),
    startAt: z.coerce.date(),
    endAt: z.coerce.date(),
    dressCode: z.string(),
    eventPrice: z.number().nonnegative(),
    currency: z.string().min(1),
    clubId: z.string().optional(),
  })
  .refine((data) => new Date(data.endAt) > new Date(data.startAt), {
    message: 'endAt must be later than startAt',
    path: ['endAt'],
  });

export const updateEventSchema = z
  .object({
    eventName: z.string().min(1).optional(),
    eventDescription: z.string().nullable().optional(),
    thumbnail: z.url().optional(),
    images: z.array(z.url()).optional(),
    eventStatus: eventStatusEnum.optional(),
    categoryType: eventCategoryTypeEnum.optional(),
    musicGenres: z.array(z.string()).optional(),
    moodTags: z.array(z.string()).optional(),
    isResaleEnabled: z.boolean().optional(),
    ticketTiers: z.array(eventTicketTierSchema).optional(),
    lineup: z.array(eventLineupSchema).optional(),
    lat: z.number().min(-90).max(90).optional(),
    lng: z.number().min(-180).max(180).optional(),
    location: z.string().min(1).optional(),
    startAt: z.coerce.date().optional(),
    endAt: z.coerce.date().optional(),
    dressCode: z.string().optional(),
    eventPrice: z.number().nonnegative().optional(),
    currency: z.string().min(1).optional(),
    isActive: z.boolean().optional(),
    clubId: z.string().optional(),
  })
  .refine(
    (data) => {
      if (data.startAt && data.endAt) {
        return new Date(data.endAt) > new Date(data.startAt);
      }
      return true;
    },
    {
      message: 'endAt must be later than startAt',
      path: ['endAt'],
    }
  );

export type TCreateEventPayload = z.infer<typeof createEventSchema>;
export type TUpdateEventPayload = z.infer<typeof updateEventSchema>;

export const closeBookingsSchema = z
  .object({
    closed: z.boolean(),
  })
  .strict();

export type TCloseBookingsPayload = z.infer<typeof closeBookingsSchema>;

export const eventIdParamsSchema = z.object({
  id: z.uuid(),
});

const booleanQuery = z.preprocess((val) => {
  if (val === 'true' || val === true) return true;
  if (val === 'false' || val === false) return false;
  return val;
}, z.boolean().optional());

export const eventListQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
  eventStatus: eventStatusEnum.optional(),
  isActive: booleanQuery,
});

export type TEventListQuery = z.infer<typeof eventListQuerySchema>;

export const eventListQuerySchemaForAdmin = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
  eventStatus: eventStatusEnum.optional(),
});
export type TEventListQueryForAdmin = z.infer<
  typeof eventListQuerySchemaForAdmin
>;
