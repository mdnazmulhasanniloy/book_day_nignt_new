import { Router } from 'express';
import {
  getUserProfileController,
  updateUserProfileController,
  changePasswordController,
  getDeletionPreviewController,
  deleteAccountController,
} from '@/app/modules/profile/profile.controllers';
import {
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
} from '@/app/modules/auth/auth.middlewares';
import { validateReqBody } from '@/app/utils/system.utils';
import { updateProfileSchema, changePasswordSchema } from '@/app/modules/profile/profile.schema';

const router = Router();

router.route('/profile')
  .get(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    getUserProfileController
  )
  .patch(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    validateReqBody(updateProfileSchema),
    updateUserProfileController
  )
  .delete(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    deleteAccountController
  );

router.route('/profile/deletion-preview')
  .get(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    getDeletionPreviewController
  );

router.route('/change-password')
  .patch(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    validateReqBody(changePasswordSchema),
    changePasswordController
  );

export default router;
