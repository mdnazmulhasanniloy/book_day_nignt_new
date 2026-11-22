/**
 * Pure rules for deleting uploaded media. No I/O so they are cheap to test.
 *
 * Ownership is never inferred from the URL: the only trusted source is the
 * MediaAsset row written when the file was uploaded. The URL is only used to
 * find the storage key, and only if it points into our own bucket prefix.
 */

export const MEDIA_KEY_PREFIX = 'attachments/';

export interface IMediaActor {
  id: string;
  /** AccountRole value, e.g. 'ADMIN'. */
  role: string;
}

/**
 * Returns the storage key for a URL that belongs to our public bucket base and
 * has the exact shape `<base>/attachments/<one-segment>`, else null. Rejects
 * foreign hosts, nested paths, dot segments, encoded characters, queries and
 * fragments so a crafted URL can never address another object.
 */
export const mediaKeyFromUrl = ({
  url,
  publicBase,
}: {
  url: string;
  publicBase: string;
}): string | null => {
  const base = publicBase.replace(/\/+$/, '');
  if (!url.startsWith(`${base}/`)) return null;
  const key = url.slice(base.length + 1);
  if (!key.startsWith(MEDIA_KEY_PREFIX)) return null;
  const name = key.slice(MEDIA_KEY_PREFIX.length);
  if (!name || name === '.' || name === '..') return null;
  if (/[\/\\?#%\s\u0000-\u001f]/.test(name)) return null;
  return key;
};

export interface IMediaDeleteDecision {
  allowed: boolean;
  deniedKeys: string[];
}

/**
 * ADMIN may delete any object under attachments/ (including files uploaded
 * before ownership was recorded). Anyone else may delete a key only when a
 * MediaAsset row says they own it. Files with no row are therefore admin-only.
 */
export const authorizeMediaDelete = ({
  actor,
  keys,
  owners,
}: {
  actor: IMediaActor;
  keys: string[];
  /** key -> ownerId, from MediaAsset rows only. */
  owners: ReadonlyMap<string, string>;
}): IMediaDeleteDecision => {
  if (actor.role === 'ADMIN') return { allowed: true, deniedKeys: [] };
  const deniedKeys = keys.filter((key) => owners.get(key) !== actor.id);
  return { allowed: deniedKeys.length === 0, deniedKeys };
};
