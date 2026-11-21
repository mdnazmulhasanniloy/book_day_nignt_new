import { Router } from 'express';
import {
  uploadMediaController,
  removeMediaController,
} from '@/app/modules/media/media.controllers';
import {
  handleAttachmentMulterError,
  uploadAttachmentArray,
} from '@/app/middlewares/multer.middlewares';
import { validateReqBody } from '@/app/utils/system.utils';
import { deleteMediaSchema } from '@/app/modules/media/media.schema';
import { requireMediaAuthMiddleware } from '@/app/modules/media/media.middlewares';

const router = Router();

router
  .route('/media')
  .post(
    requireMediaAuthMiddleware,
    uploadAttachmentArray('files', 10, true),
    handleAttachmentMulterError,
    uploadMediaController
  );

router
  .route('/media')
  .delete(
    requireMediaAuthMiddleware,
    validateReqBody(deleteMediaSchema),
    removeMediaController
  );

export default router;
