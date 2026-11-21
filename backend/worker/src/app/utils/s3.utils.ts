import { createReadStream, statSync } from 'fs';
import { Readable } from 'stream';

import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { lookup } from 'mime-types';

import s3Client from '@/app/configs/s3Client.configs';
import { env } from '@/env';
import { unlinkFile } from '@/app/utils/system.utils';

const bucketName = env.S3_BUCKET_NAME;

/**
 * Uploads a file to S3 and returns the public URL.
 * WHY: Abstracting this ensures consistent object metadata (ContentType, ACL).
 */
export async function singleUploadToS3({
  filePath,
  key,
  mimeType,
  acl = 'public-read',
}: {
  filePath: string;
  mimeType: string;
  key: string;
  acl?: 'public-read' | 'private';
}): Promise<string> {
  try {
    const fileStats = statSync(filePath);
    const contentType = lookup(filePath);
    const stream = createReadStream(filePath);
    const command = new PutObjectCommand({
      Key: key,
      Bucket: bucketName,
      ContentType: contentType || `application/${mimeType.replace(/^\./, '')}`,
      Body: stream,
      ContentLength: fileStats.size,
      ACL: acl,
    });
    await s3Client.send(command);
    stream.destroy();

    // Always cleanup the local temporary file
    await unlinkFile({ filePath });

    // Return the public URL following the repository's convention
    return `${env.S3_PUBLIC_URL}/${key}`;
  } catch (error) {
    await unlinkFile({ filePath });
    if (error instanceof Error) throw error;
    throw new Error('Unknown Error Occurred In S3 Single File Upload Utility');
  }
}

/**
 * Deletes an object from S3.
 */
export async function singleDeleteToS3({
  key,
}: {
  key: string;
}): Promise<void> {
  try {
    const command = new DeleteObjectCommand({
      Bucket: bucketName,
      Key: key,
    });

    await s3Client.send(command);
  } catch (error) {
    if (error instanceof Error) throw error;
    throw new Error('Unknown Error Occurred In S3 Single File Delete Utility');
  }
}

/** Downloads a private S3 object into a Buffer (for email attachments). */
export async function getObjectBufferFromS3({
  key,
}: {
  key: string;
}): Promise<Buffer> {
  try {
    const command = new GetObjectCommand({
      Bucket: bucketName,
      Key: key,
    });
    const response = await s3Client.send(command);
    const body = response.Body;
    if (!body) {
      throw new Error(`S3 object body missing for key ${key}`);
    }

    if (typeof (body as { transformToByteArray?: unknown }).transformToByteArray === 'function') {
      const bytes = await (
        body as { transformToByteArray: () => Promise<Uint8Array> }
      ).transformToByteArray();
      return Buffer.from(bytes);
    }

    const stream = body as Readable;
    const chunks: Buffer[] = [];
    for await (const chunk of stream) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  } catch (error) {
    if (error instanceof Error) throw error;
    throw new Error('Unknown Error Occurred In S3 Object Download Utility');
  }
}

/** Time-limited download URL for private ticket PDFs (default 7 days). */
export async function getPresignedUrlFromS3({
  key,
  expiresIn = 604800,
}: {
  key: string;
  expiresIn?: number;
}): Promise<string> {
  try {
    const command = new GetObjectCommand({
      Bucket: bucketName,
      Key: key,
    });
    return await getSignedUrl(s3Client as any, command as any, { expiresIn });
  } catch (error) {
    if (error instanceof Error) throw error;
    throw new Error('Unknown Error Occurred While Presigning S3 URL');
  }
}
