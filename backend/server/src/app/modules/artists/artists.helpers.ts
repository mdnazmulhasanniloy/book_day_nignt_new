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

  if (existing) {
    return tx.artist.update({
      where: { id: existing.id },
      data: {
        name: input.artistName.trim(),
        ...(input.artistAvatar !== undefined
          ? { avatar: input.artistAvatar }
          : {}),
        ...(input.audioPreviewUrl !== undefined
          ? { audioPreviewUrl: input.audioPreviewUrl }
          : {}),
        ...(input.spotifyUrl !== undefined
          ? { spotifyUrl: input.spotifyUrl }
          : {}),
        ...(input.soundcloudUrl !== undefined
          ? { soundcloudUrl: input.soundcloudUrl }
          : {}),
        ...(input.isVerified !== undefined
          ? { isVerified: input.isVerified }
          : {}),
      },
    });
  }

  return tx.artist.create({
    data: {
      name: input.artistName.trim(),
      nameKey,
      avatar: input.artistAvatar ?? null,
      audioPreviewUrl: input.audioPreviewUrl ?? null,
      spotifyUrl: input.spotifyUrl ?? null,
      soundcloudUrl: input.soundcloudUrl ?? null,
      isVerified: input.isVerified ?? false,
    },
  });
};
