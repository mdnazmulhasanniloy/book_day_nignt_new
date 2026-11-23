import { Artist, Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';

export const artistNameKey = (name: string) =>
  name.trim().toLowerCase().replace(/\s+/g, ' ');

export const mapArtist = (artist: Artist) => ({
  id: artist.id,
  name: artist.name,
  avatar: artist.avatar,
  audioPreviewUrl: artist.audioPreviewUrl,
  spotifyUrl: artist.spotifyUrl,
  soundcloudUrl: artist.soundcloudUrl,
  isVerified: artist.isVerified,
  followerCount: artist.followerCount,
});

/** Column Artist.socialLinks (Json?) as the API object; anything that is not a plain object is null. */
const toSocialLinks = (value: Prisma.JsonValue | null): Record<string, string> | null => {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(value)) {
    if (typeof v === 'string') out[k] = v;
  }
  return out;
};

export type TUpcomingEventItem = {
  id: string;
  name: string;
  lat: number;
  lng: number;
  location: string;
  type: 'EVENT';
  thumbnail: string;
  currency: string;
  price: number;
  startAt: Date;
};

/**
 * T-044 profile shape (new endpoints only). `photo` is Artist.avatar. `isFollowing`,
 * `upcomingEvents` and `upcomingEventCount` are only present when the caller supplies them.
 */
export const mapArtistProfile = (
  artist: Artist,
  extra: {
    isFollowing?: boolean;
    upcomingEvents?: TUpcomingEventItem[];
    upcomingEventCount?: number;
  } = {}
) => ({
  id: artist.id,
  name: artist.name,
  photo: artist.avatar,
  bio: artist.bio,
  socialLinks: toSocialLinks(artist.socialLinks),
  spotifyUrl: artist.spotifyUrl,
  soundcloudUrl: artist.soundcloudUrl,
  audioPreviewUrl: artist.audioPreviewUrl,
  isVerified: artist.isVerified,
  followerCount: artist.followerCount,
  ...extra,
});

/**
 * Lineup item with an optional `artistId` (T-044): links that existing Artist as is (the shared row
 * is never overwritten from a lineup item) and answers 404 when it does not exist. Without
 * `artistId`: see ensureArtistForLineup (W-04, never modifies an existing artist).
 */
export const resolveLineupArtistId = async (
  tx: Prisma.TransactionClient | typeof prisma,
  input: { artistId?: string } & Parameters<typeof ensureArtistForLineup>[1]
): Promise<string> => (await resolveLineupLink(tx, input)).artistId;

/**
 * Same as `resolveLineupArtistId`, and also returns the stored `isVerified` of the Artist.
 * A lineup row's verified mark always comes from the Artist record, never from the client payload.
 */
export const resolveLineupLink = async (
  tx: Prisma.TransactionClient | typeof prisma,
  input: { artistId?: string } & Parameters<typeof ensureArtistForLineup>[1]
): Promise<{ artistId: string; isVerified: boolean }> => {
  const { artistId, ...rest } = input;
  if (artistId !== undefined) {
    const found = await tx.artist.findUnique({
      where: { id: artistId },
      select: { id: true, isVerified: true },
    });
    if (!found) {
      throw { statusCode: 404, message: 'Artist not found' };
    }
    return { artistId: found.id, isVerified: found.isVerified };
  }
  const ensured = await ensureArtistForLineup(tx, rest);
  return { artistId: ensured.id, isVerified: ensured.isVerified };
};

/**
 * Lineup item WITHOUT `artistId` (W-04). Artist names are unique by `nameKey`, so:
 * - an Artist with that nameKey already exists: it is returned as is, NOTHING on it is modified
 *   (no name, avatar, links, isVerified, updatedAt);
 * - otherwise a new Artist is created from the item, always with `isVerified = false` (only
 *   admins verify, via /admin/artists). `isVerified` in the item is ignored.
 * The insert is `ON CONFLICT DO NOTHING` (createMany skipDuplicates), so a concurrent creation of
 * the same name is not a unique violation (which would abort the surrounding transaction): the
 * row is re-read afterwards and treated as "already exists".
 */
export const ensureArtistForLineup = async (
  tx: Prisma.TransactionClient | typeof prisma,
  input: {
    artistName: string;
    artistAvatar?: string | null;
    audioPreviewUrl?: string | null;
    spotifyUrl?: string | null;
    soundcloudUrl?: string | null;
    isVerified?: boolean;
  }
) => {
  const nameKey = artistNameKey(input.artistName);
  const existing = await tx.artist.findUnique({ where: { nameKey } });
  if (existing) return existing;

  await tx.artist.createMany({
    data: [
      {
        name: input.artistName.trim(),
        nameKey,
        avatar: input.artistAvatar ?? null,
        audioPreviewUrl: input.audioPreviewUrl ?? null,
        spotifyUrl: input.spotifyUrl ?? null,
        soundcloudUrl: input.soundcloudUrl ?? null,
        isVerified: false,
      },
    ],
    skipDuplicates: true,
  });
  return tx.artist.findUniqueOrThrow({ where: { nameKey } });
};
