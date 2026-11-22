import prisma from '@/app/configs/db.configs';
import { env } from '@/env';
import { AuthErrorType } from '@/const';
import { singleDeleteToS3, singleUploadToS3 } from '@/app/utils/s3.utils';
import { v4 as uuidv4 } from 'uuid';
import {
  authorizeMediaDelete,
  IMediaActor,
  mediaKeyFromUrl,
} from '@/app/modules/media/media.policy';

/** Narrow views of the collaborators so tests can pass fakes. */
export interface IMediaDb {
  mediaAsset: {
    createMany(args: {
      data: {
        key: string;
        url: string;
        ownerId: string;
        mimeType: string;
        sizeBytes: number;
      }[];
    }): Promise<unknown>;
    findMany(args: {
      where: { key: { in: string[] } };
      select: { key: true; ownerId: true };
    }): Promise<{ key: string; ownerId: string }[]>;
    deleteMany(args: { where: { key: { in: string[] } } }): Promise<unknown>;
  };
}

export interface IMediaStorage {
  upload(args: {
    filePath: string;
    key: string;
    mimeType: string;
  }): Promise<string>;
  remove(args: { key: string }): Promise<void>;
}

export interface IMediaDeps {
  db: IMediaDb;
  storage: IMediaStorage;
  publicBase: string;
}

const defaultDeps = (): IMediaDeps => ({
  db: prisma as unknown as IMediaDb,
  storage: {
    upload: ({ filePath, key, mimeType }) =>
      singleUploadToS3({ filePath, key, mimeType }),
    remove: ({ key }) => singleDeleteToS3({ key }),
  },
  publicBase: env.S3_PUBLIC_URL,
});

/**
 * Uploads files and records the uploader as owner of each one. If recording
 * fails the just-uploaded objects are removed so no ownerless file is left.
 */
export const uploadMediaService = async ({
  files,
  ownerId,
  deps = defaultDeps(),
}: {
  files: Express.Multer.File[];
  ownerId: string;
  deps?: IMediaDeps;
}): Promise<string[]> => {
  const uploaded = await Promise.all(
    files.map(async (file) => {
      const extension = file.originalname.split('.').pop();
      const key = `attachments/${uuidv4()}-${Date.now()}.${extension}`;
      const url = await deps.storage.upload({
        filePath: file.path,
        key,
        mimeType: file.mimetype,
      });
      return {
        key,
        url,
        ownerId,
        mimeType: file.mimetype,
        sizeBytes: file.size,
      };
    })
  );

  try {
    await deps.db.mediaAsset.createMany({ data: uploaded });
  } catch (error) {
    await Promise.allSettled(
      uploaded.map(({ key }) => deps.storage.remove({ key }))
    );
    throw error;
  }
  return uploaded.map(({ url }) => url);
};

/**
 * Deletes media the actor is allowed to delete. All-or-nothing: if any URL is
 * invalid or not permitted, nothing is deleted.
 */
export const removeMediaService = async ({
  urls,
  actor,
  deps = defaultDeps(),
}: {
  urls: string[];
  actor: IMediaActor;
  deps?: IMediaDeps;
}): Promise<void> => {
  const keys: string[] = [];
  for (const url of urls) {
    const key = mediaKeyFromUrl({ url, publicBase: deps.publicBase });
    if (!key) {
      throw {
        statusCode: 422,
        message: 'Not a media url of this service',
        errorType: 'INVALID_MEDIA_URL',
      };
    }
    if (!keys.includes(key)) keys.push(key);
  }
  if (keys.length === 0) return;

  const rows = await deps.db.mediaAsset.findMany({
    where: { key: { in: keys } },
    select: { key: true, ownerId: true },
  });
  const owners = new Map(rows.map((row) => [row.key, row.ownerId]));

  const decision = authorizeMediaDelete({ actor, keys, owners });
  if (!decision.allowed) {
    throw {
      statusCode: 403,
      message: 'You can only delete media you uploaded',
      errorType: AuthErrorType.ACCESS_DENIED,
    };
  }

  const results = await Promise.allSettled(
    keys.map((key) => deps.storage.remove({ key }))
  );
  const removed = keys.filter((_, i) => results[i].status === 'fulfilled');
  if (removed.length > 0) {
    await deps.db.mediaAsset.deleteMany({ where: { key: { in: removed } } });
  }
  const failed = results.find((r) => r.status === 'rejected');
  if (failed) throw (failed as PromiseRejectedResult).reason;
};
