import { NextFunction, Request, Response } from 'express';
import { AccountRole, User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { AuthErrorType } from '@/const';

/**
 * Promo create/update/delete are for club owners and admins only (S-02).
 * Customers (USER) get 403. Runs after the user auth middlewares.
 */
export const checkPromoManagerRoleMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const user = req.user as User;

    if (
      user.accountRole !== AccountRole.CLUB_OWNER &&
      user.accountRole !== AccountRole.ADMIN
    ) {
      res.status(403).json({
        success: false,
        message: 'Access denied: Requires club owner privileges',
        errorType: AuthErrorType.ACCESS_DENIED,
        traceId: getTraceId(),
      });
      return;
    }

    next();
  }
);
