import { NextFunction, Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler, createRedisKey } from '@/app/utils/system.utils';
import {
  extractToken,
  verifyResetPasswordPageToken,
} from '@/app/utils/jwt.utils';
import { AuthErrorType, REDIS_PREFIXES, COOKIE_NAMES } from '@/const';
import { JwtPayload } from 'jsonwebtoken';
import { getRedisClient } from '@/app/configs/redis.configs';
import { User } from '@prisma/client';
import { isRecoverVerified } from '@/app/modules/recover/recover.verified.helpers';

/**
 * This middleware is used to verify the reset password page token.
 * It checks if the token is blacklisted and if the token is expired.
 * If the token is valid, it sets the user in the request.
 * @param req - The request object.
 * @param res - The response object.
 * @param next - The next function.
 * @returns {Promise<void>}
 */
export const checkResetPasswordPageTokenMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const traceId = getTraceId();
    const token = req.cookies[COOKIE_NAMES.RECOVER_PAGE_TOKEN] || extractToken(req);
    req.headers['x-recover-token'] = token as string;
    if (!token) {
      res.status(401).json({
        success: false,
        message: 'Authentication token not found',
        errorType: AuthErrorType.TOKEN_INVALID,
        traceId,
      });
      return;
    }
    const redisClient = getRedisClient();
    const isBlackListed = await redisClient.get(
      createRedisKey(REDIS_PREFIXES.blacklist, token)
    );
    if (isBlackListed) {
      res.status(401).json({
        success: false,
        message: 'Token has been revoked',
        errorType: AuthErrorType.TOKEN_BLACKLISTED,
        traceId,
      });
      return;
    }
    const decoded = verifyResetPasswordPageToken(token);
    if (decoded.error) {
      if (decoded.error === AuthErrorType.TOKEN_EXPIRED) {
        res.status(401).json({
          success: false,
          message: 'Token has been expired',
          errorType: AuthErrorType.TOKEN_EXPIRED,
          traceId,
        });
        return;
      }
      res.status(401).json({
        success: false,
        message: 'Token is invalid',
        errorType: AuthErrorType.TOKEN_INVALID,
        traceId,
      });
      return;
    }
    req.user = decoded.data as JwtPayload;
    return next();
  }
);

/**
 * Refuses password reset unless the OTP step (POST /recover/verify) succeeded for this user (BUG-S19).
 * Returns 403, not 401, so clients do not treat it as an expired session.
 */
export const requireRecoverVerifiedMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction) => {
    const user = req.user as User;
    const verified = await isRecoverVerified({
      redis: getRedisClient(),
      userId: user.id,
    });
    if (!verified) {
      res.status(403).json({
        success: false,
        message: 'OTP verification is required before resetting the password',
        errorType: 'RECOVER_OTP_NOT_VERIFIED',
        traceId: getTraceId(),
      });
      return;
    }
    next();
  }
);
