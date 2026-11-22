import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  uploadMediaService,
  removeMediaService,
} from '@/app/modules/media/media.services';
import { deleteMediaSchema } from './media.schema';
import type { User } from '@prisma/client';

export const uploadMediaController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const files = req.files as Express.Multer.File[];
    const user = req.user as User;
    const data = await uploadMediaService({ files, ownerId: user.id });
    res.status(200).json({
      success: true,
      message: 'Media uploads successful',
      data,
      traceId,
    });
    return;
  }
);

export const removeMediaController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    // validateReqBody skips DELETE (S-18), so validate here.
    const parsed = deleteMediaSchema.safeParse(req.body);
    if (!parsed.success) {
      throw {
        statusCode: 422,
        message: parsed.error.issues[0]?.message ?? 'Invalid request body',
        errorType: 'VALIDATION_ERROR',
      };
    }
    const { urls } = parsed.data;
    const user = req.user as User;
    await removeMediaService({
      urls,
      actor: { id: user.id, role: user.accountRole },
    });

    res.status(200).json({
      success: true,
      message: 'Media items delatation successful!',
      traceId,
    });
    return;
  }
);
