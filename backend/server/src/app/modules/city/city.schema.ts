import { z } from 'zod';

/**
 * page/limit stay strings like the other modules; limit is capped at 50 to
 * match the api-spec (T-033).
 */
const positiveIntString = (field: string) =>
  z
    .string()
    .regex(/^[1-9]\d*$/, `${field} must be a positive integer`)
    .refine((v) => Number.isSafeInteger(Number(v)), `${field} is too large`);

const pageSchema = positiveIntString('page').optional().default('1');
const limitSchema = positiveIntString('limit')
  .refine((v) => Number(v) <= 50, 'limit must be at most 50')
  .optional()
  .default('10');

const boolString = z
  .enum(['true', 'false'])
  .optional()
  .transform((v) => v === 'true');

type IntlWithZones = typeof Intl & {
  supportedValuesOf?: (key: 'timeZone') => string[];
};
const listZones = (): string[] =>
  (Intl as IntlWithZones).supportedValuesOf?.('timeZone') ?? [];

const IANA_ZONES: ReadonlySet<string> = new Set(['UTC', ...listZones()]);

/** True when the value is an IANA zone name known to this runtime. */
export const isValidIanaTimezone = (value: string): boolean => {
  if (IANA_ZONES.has(value)) return true;
  try {
    // Canonical aliases such as Asia/Calcutta are accepted by Intl but not
    // listed by supportedValuesOf. Offsets and abbreviations are rejected.
    if (!/^[A-Za-z_]+(\/[A-Za-z_+\-0-9]+)+$/.test(value)) return false;
    new Intl.DateTimeFormat('en', { timeZone: value });
    return true;
  } catch {
    return false;
  }
};

const nameSchema = z.string().trim().min(1, 'name is required').max(120);
const countryCodeSchema = z
  .string()
  .regex(/^[A-Za-z]{2}$/, 'countryCode must be an ISO 3166-1 alpha-2 code')
  .transform((v) => v.toUpperCase());
const latSchema = z.number().min(-90).max(90);
const lngSchema = z.number().min(-180).max(180);
const timezoneSchema = z
  .string()
  .refine(isValidIanaTimezone, 'timezone must be a valid IANA zone');

export const listCitiesQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  launchedOnly: boolString,
  page: pageSchema,
  limit: limitSchema,
});
export type TListCitiesQuery = z.infer<typeof listCitiesQuerySchema>;

export const adminListCitiesQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  page: pageSchema,
  limit: limitSchema,
});
export type TAdminListCitiesQuery = z.infer<typeof adminListCitiesQuerySchema>;

export const createCitySchema = z
  .object({
    name: nameSchema,
    countryCode: countryCodeSchema.optional(),
    lat: latSchema,
    lng: lngSchema,
    timezone: timezoneSchema.optional(),
    isLaunched: z.boolean().optional(),
  })
  .strict();
export type TCreateCityBody = z.infer<typeof createCitySchema>;

export const updateCitySchema = z
  .object({
    name: nameSchema.optional(),
    countryCode: countryCodeSchema.optional(),
    lat: latSchema.optional(),
    lng: lngSchema.optional(),
    timezone: timezoneSchema.optional(),
    isLaunched: z.boolean().optional(),
  })
  .strict()
  .refine((v) => Object.keys(v).length > 0, 'at least one field is required');
export type TUpdateCityBody = z.infer<typeof updateCitySchema>;

export const cityIdParamsSchema = z.object({
  id: z.string().uuid('Invalid city ID format'),
});
export type TCityIdParams = z.infer<typeof cityIdParamsSchema>;
