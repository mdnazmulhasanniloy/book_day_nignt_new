import { Router } from 'express';
import {
  findRecoverUserController,
  verifyRecoverUserController,
  recoverUserPasswordResetController,
  recoverUserVerificationOtpResendController,
} from '@/app/modules/recover/recover.controllers';
import {
  checkAccountStatus,
  checkOtpMiddleware,
  checkUserExistenceMiddleware,
  findUserByEmail,
  limitOtpSendMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import { checkResetPasswordPageTokenMiddleware } from '@/app/modules/recover/recover.middlewares';
import { validateReqBody } from '@/app/utils/system.utils';
import {
  findRecoverUserByEmailSchema,
  resetRecoverUserPasswordSchema,
  verifyRecoverUserOtpSchema,
} from '@/app/modules/recover/recover.schema';

const router = Router();

router
  .route('/recover/find')
  .post(
    limitOtpSendMiddleware,
    validateReqBody(findRecoverUserByEmailSchema),
    findUserByEmail,
    checkAccountStatus,
    findRecoverUserController
  );

router
  .route('/recover/verify')
  .post(
    validateReqBody(verifyRecoverUserOtpSchema),
    checkResetPasswordPageTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    checkOtpMiddleware,
    verifyRecoverUserController
  );

router
  .route('/recover/reset')
  .post(
    validateReqBody(resetRecoverUserPasswordSchema),
    checkResetPasswordPageTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    recoverUserPasswordResetController
  );

router
  .route('/recover/resend')
  .post(
    limitOtpSendMiddleware,
    checkResetPasswordPageTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    recoverUserVerificationOtpResendController
  );

export default router;
