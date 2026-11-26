import { Prisma } from '@prisma/client';

/**
 * T-030 (CR-09, BUG-B02, BUG-B25): sets "geog" of one Event or Club from the lat/lng columns
 * ALREADY STORED on that row, inside the caller's transaction. Reading the stored pair (not the
 * request) means an update that sends only lat or only lng still ends with a matching geog.
 * A row whose stored coordinates are not finite or are out of range (lat -90..90, lng -180..180)
 * is left untouched, so no bad geography is ever written. Returns true when geog was written.
 */
export const syncGeogFromLatLng = async ({
  tx,
  table,
  id,
}: {
  tx: Prisma.TransactionClient;
  table: 'Event' | 'Club';
  id: string;
}): Promise<boolean> => {
  // Postgres orders NaN above every number, so BETWEEN also rejects NaN and Infinity.
  const written =
    table === 'Event'
      ? await tx.$executeRaw`
          UPDATE "Event"
          SET geog = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
          WHERE id = ${id} AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180`
      : await tx.$executeRaw`
          UPDATE "Club"
          SET geog = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
          WHERE id = ${id} AND lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180`;
  return written > 0;
};
