import { z } from 'zod';

export const artistIdParamsSchema = z.object({
  id: z.string().uuid('Invalid artist id'),
});

export const myArtistsQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(50).default(20),
});

// T-044 (CR-12). page/limit stay strings like the cities module; limit is capped at 50.
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
const searchSchema = z.string().trim().max(120).optional();

export const listArtistsQuerySchema = z.object({
  search: searchSchema,
  cityId: z.string().uuid('Invalid city id').optional(),
  page: pageSchema,
  limit: limitSchema,
});

export const adminListArtistsQuerySchema = z.object({
  search: searchSchema,
  isVerified: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => (v === undefined ? undefined : v === 'true')),
  page: pageSchema,
  limit: limitSchema,
});

const httpsUrl = (field: string) =>
  z
    .string()
    .max(2048, `${field} is too long`)
    .refine((v) => {
      try {
        return new URL(v).protocol === 'https:';
      } catch {
        return false;
      }
    }, `${field} must be an https URL`);

/**
 * OUR PROPOSAL (not defined by the client, to be confirmed): a small object of known platform keys
 * mapping to https URLs. Unknown keys are rejected. Spotify and the photo use their own columns.
 */
export const ARTIST_SOCIAL_LINK_KEYS = [
  'instagram',
  'facebook',
  'x',
  'tiktok',
  'youtube',
  'soundcloud',
  'website',
] as const;

export const artistSocialLinksSchema = z
  .object(
    Object.fromEntries(
      ARTIST_SOCIAL_LINK_KEYS.map((k) => [k, httpsUrl(k).optional()])
    ) as Record<(typeof ARTIST_SOCIAL_LINK_KEYS)[number], z.ZodOptional<z.ZodString>>
  )
  .strict();

const bioSchema = z
  .string()
  .trim()
  .max(2000, 'bio must be at most 2000 characters')
  .transform((v) => (v === '' ? null : v));

const ownerUpdateShape = {
  photo: httpsUrl('photo').nullable().optional(),
  bio: bioSchema.nullable().optional(),
  spotifyUrl: httpsUrl('spotifyUrl').nullable().optional(),
  socialLinks: artistSocialLinksSchema.nullable().optional(),
};
const atLeastOne = (v: object) => Object.keys(v).length > 0;
const atLeastOneMessage = 'at least one field is required';

/** Club owner edit: profile fields only (no rename, no verification). */
export const ownerUpdateArtistSchema = z
  .object(ownerUpdateShape)
  .strict()
  .refine(atLeastOne, atLeastOneMessage);

/** Admin edit: the owner fields plus rename and verification. */
export const adminUpdateArtistSchema = z
  .object({
    ...ownerUpdateShape,
    name: z.string().trim().min(1, 'name is required').max(120).optional(),
    isVerified: z.boolean().optional(),
  })
  .strict()
  .refine(atLeastOne, atLeastOneMessage);

export type TListArtistsQuery = z.infer<typeof listArtistsQuerySchema>;
export type TAdminListArtistsQuery = z.infer<typeof adminListArtistsQuerySchema>;
export type TOwnerUpdateArtistBody = z.infer<typeof ownerUpdateArtistSchema>;
export type TAdminUpdateArtistBody = z.infer<typeof adminUpdateArtistSchema>;
export type TArtistIdParams = z.infer<typeof artistIdParamsSchema>;
export type TMyArtistsQuery = z.infer<typeof myArtistsQuerySchema>;
