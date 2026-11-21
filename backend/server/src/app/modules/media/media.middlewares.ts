import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { AuthErrorType, COOKIE_NAMES } from '@/const';
import {
  checkAccountStatus,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  checkAdminAccessTokenMiddleware,
  checkAdminExistenceMiddleware,
  checkCsrfTokenMiddleware,
} from '@/app/modules/admin/admin.middlewares';
import { createMediaGuard } from '@/app/modules/media/media.guard';

/**
 * Requires a signed-in account for /media: a mobile Bearer token (any
 * active role) or the admin dashboard cookie session (with CSRF check).
 */
export const requireMediaAuthMiddleware = createMediaGuard({
  bearer: [
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
  ],
  cookie: [
    checkCsrfTokenMiddleware,
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
  ],
  cookieName: COOKIE_NAMES.ACCESS_TOKEN,
  onMissing: (_req: Request, res: Response) => {
    res.status(401).json({
      success: false,
      message: 'Authentication required',
      errorType: AuthErrorType.TOKEN_INVALID,
      traceId: getTraceId(),
    });
  },
});
