import { Router } from 'express';
import {
  signupController,
  verifySignupUserController,
  resendOtpController,
  checkUserAccessTokenController,
  loginController,
  logoutController,
  oAuthLoginController,
  refreshUserSessionController,
} from '@/app/modules/auth/auth.controllers';
import { validateReqBody } from '@/app/utils/system.utils';
import {
  checkAccessTokenSchema,
  signupSchema,
  verifySignupUserSchema,
  loginSchema,
  logoutSchema,
  oAuthLoginSchema,
  refreshTokenSchema,
} from '@/app/modules/auth/auth.schema';
import {
  checkOtpMiddleware,
  checkOtpPageTokenMiddleware,
  checkSignupUserExistsMiddleware,
  checkUserExistenceMiddleware,
  checkUserAccessTokenMiddleware,
  checkPassword,
  findUserByEmail,
  checkAccountStatus,
  checkDeviceContextMiddleware,
  limitOtpSendMiddleware,
} from '@/app/modules/auth/auth.middlewares';

const router = Router();

router.route('/auth/roles').get((_req, res) => {
  res.status(200).json({
    success: true,
    data: {
      roles: [
        {
          apiRole: 'USER',
          productRole: 'customer',
          can: ['browse', 'purchase own tickets', 'read own bookings'],
        },
        {
          apiRole: 'CLUB_OWNER',
          productRole: 'club_manager',
          can: [
            'manage own clubs and events',
            'read own revenue',
            'cannot read another owner id',
          ],
        },
        {
          apiRole: 'ADMIN',
          productRole: 'admin',
          can: ['users', 'commission', 'restore deleted accounts'],
        },
      ],
      missingRole:
        'ORGANIZER is not a separate role. Event organizers use CLUB_OWNER.',
    },
  });
});

router
  .route('/auth/signup')
  .post(
    limitOtpSendMiddleware,
    validateReqBody(signupSchema),
    checkSignupUserExistsMiddleware,
    signupController
  );

router
  .route('/auth/login')
  .post(
    validateReqBody(loginSchema),
    findUserByEmail,
    checkAccountStatus,
    checkPassword,
    loginController
  );

router
  .route('/auth/verify')
  .post(
    checkOtpPageTokenMiddleware,
    checkUserExistenceMiddleware,
    validateReqBody(verifySignupUserSchema),
    checkOtpMiddleware,
    verifySignupUserController
  );

router
  .route('/auth/resend')
  .post(
    limitOtpSendMiddleware,
    checkOtpPageTokenMiddleware,
    checkUserExistenceMiddleware,
    resendOtpController
  );

router
  .route('/auth/refresh')
  .post(validateReqBody(refreshTokenSchema), refreshUserSessionController);

router
  .route('/auth/check')
  .post(
    validateReqBody(checkAccessTokenSchema),
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    checkDeviceContextMiddleware,
    checkUserAccessTokenController
  );

router
  .route('/auth/logout')
  .post(
    validateReqBody(logoutSchema),
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    checkDeviceContextMiddleware,
    logoutController
  );

router
  .route('/auth/social')
  .post(validateReqBody(oAuthLoginSchema), oAuthLoginController);

export default router;
