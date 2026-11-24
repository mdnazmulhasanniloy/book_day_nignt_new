import { z } from 'zod';

const booleanQuery = z.preprocess((val) => {
  if (val === 'true' || val === true) return true;
  if (val === 'false' || val === false) return false;
  return val;
}, z.boolean().optional());

/** Allowed search radii in km. The server default when radiusKm is omitted is 20 (old clients). */
export const EXPLORE_RADIUS_KM_OPTIONS: readonly number[] = [10, 20, 30, 40, 50];
export const EXPLORE_DEFAULT_RADIUS_KM = 20;

/** radiusKm validation shared by GET /explore and GET /explore/feed. */
const radiusKmQuery = z.coerce
  .number()
  .refine((v) => EXPLORE_RADIUS_KM_OPTIONS.includes(v), {
    message: 'radiusKm must be one of 10, 20, 30, 40, 50',
  })
  .optional();

/** ISO calendar date YYYY-MM-DD (a real date), interpreted in the explore time zone rule (T-035). */
const isoDateQuery = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'must be an ISO date YYYY-MM-DD')
  .refine((v) => {
    const d = new Date(`${v}T00:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
  }, 'must be a real calendar date');

const exploreQueryBase = z.object({
  type: z.enum(['CLUB', 'EVENT']).optional(),
  date: z.string().datetime().optional(),
  dateFilter: z.enum(['today', 'tomorrow', 'this_weekend', 'next_weekend', 'this_week']).optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  city: z.string().optional(),
  radiusKm: radiusKmQuery,
  cityId: z.string().uuid().optional(),
  minPrice: z.coerce.number().nonnegative().optional(),
  maxPrice: z.coerce.number().nonnegative().optional(),
  isFree: booleanQuery,
  genres: z.string().optional(), // Comma-separated (e.g. "Techno,House")
  mood: z.string().optional(), // Comma-separated mood chips; does NOT overload categoryType
  categoryType: z.enum(['CLUB', 'CONCERT', 'FESTIVAL', 'OPEN_AIR', 'WAREHOUSE']).optional(),
  isPopular: booleanQuery,
  ratings: z.coerce.number().min(0).max(5).optional(),
  isVip: booleanQuery,
  search: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
  sort: z.enum(['newest', 'oldest', 'trending']).optional(),
  group: z.enum(['none', 'day']).optional(),
  from: isoDateQuery.optional(),
  to: isoDateQuery.optional(),
});

/** Cross-field rules shared by GET /explore and GET /explore/map (T-038). */
const refineExploreQuery = (data: z.infer<typeof exploreQueryBase>, ctx: z.RefinementCtx) => {
  if (data.from !== undefined && data.to !== undefined && data.from > data.to) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'from must not be after to',
      path: ['from'],
    });
  }
  if (data.group === 'day' && data.type === 'CLUB') {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'group=day applies to events only and cannot be used with type=CLUB',
      path: ['group'],
    });
  }
  if (data.type === 'EVENT') {
    if (data.isPopular !== undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'isPopular is a Club-only filter and cannot be used with type=EVENT',
        path: ['isPopular']
      });
    }
    if (data.ratings !== undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'ratings is a Club-only filter and cannot be used with type=EVENT',
        path: ['ratings']
      });
    }
    if (data.isVip !== undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'isVip is a Club-only filter and cannot be used with type=EVENT',
        path: ['isVip']
      });
    }
  }
};

export const exploreQuerySchema = exploreQueryBase.superRefine(refineExploreQuery);

/** Fixed pin cap for GET /explore/map (api-spec: capped at 300 pins). */
export const EXPLORE_MAP_MAX_PINS = 300;

/**
 * GET /explore/map: the /explore filters, no paging fields (page, limit, sort, group are dropped).
 * type is required by the api-spec.
 */
export const exploreMapQuerySchema = exploreQueryBase
  .omit({ page: true, limit: true, sort: true, group: true })
  .extend({ type: z.enum(['CLUB', 'EVENT']) })
  .superRefine((data, ctx) => refineExploreQuery({ ...data, page: 1, limit: 10 }, ctx));

export const exploreDetailQuerySchema = z.object({
  type: z.enum(['CLUB', 'EVENT'])
});

export const exploreFeedQuerySchema = z.object({
  city: z.string().optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: radiusKmQuery,
  cityId: z.string().uuid().optional(),
});

/** GET /explore/most-viewed (T-042): city or point plus radius, at most 20 items. */
export const exploreMostViewedQuerySchema = z.object({
  cityId: z.string().uuid().optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: radiusKmQuery,
  limit: z.coerce.number().int().min(1).max(20).default(10),
});

export const explorePaginationQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(10),
});

export type TExploreQuery = z.infer<typeof exploreQuerySchema>;
export type TExploreMapQuery = z.infer<typeof exploreMapQuerySchema>;
export type TExploreDetailQuery = z.infer<typeof exploreDetailQuerySchema>;
export type TExploreFeedQuery = z.infer<typeof exploreFeedQuerySchema>;
export type TExploreMostViewedQuery = z.infer<typeof exploreMostViewedQuerySchema>;
export type TExplorePaginationQuery = z.infer<typeof explorePaginationQuerySchema>;

export const exploreIdParamsSchema = z.object({
  id: z.string().uuid()
});
