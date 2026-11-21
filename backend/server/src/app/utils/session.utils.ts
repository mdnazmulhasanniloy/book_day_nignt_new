import { verify, type JwtPayload } from 'jsonwebtoken';
import { AccountRole } from '@prisma/client';
import { getRedisClient } from '@/app/configs/redis.configs';
import { hashToken } from '@/app/utils/crypto.utils';
import {
  generateAccessTokenForUser,
  generateRefreshToken,
} from '@/app/utils/jwt.utils';
import { createRedisKey } from '@/app/utils/system.utils';
import { AuthErrorType, REDIS_PREFIXES } from '@/const';
import { env } from '@/env';
import prisma from '@/app/configs/db.configs';

type SessionUser = {
  userId: string;
  role: AccountRole;
  accountStatus: string;
  isVerified: boolean;
  deviceId: string;
  rememberMe: boolean;
};

export async function issueUserSession(input: SessionUser) {
  const payload = {
    sub: input.userId,
    role: input.role,
    accountStatus: input.accountStatus,
    isVerified: input.isVerified,
    deviceId: input.deviceId,
    rememberMe: input.rememberMe,
  };
  const token = generateAccessTokenForUser(payload);
  const refreshToken = generateRefreshToken(payload);
  const decoded = verify(
    refreshToken,
    env.JWT_REFRESH_TOKEN_SECRET_KEY
  ) as JwtPayload;
  const ttl = Math.max(
    1,
    Math.floor((decoded.exp || 0) - Date.now() / 1000)
  );
  await getRedisClient().set(
    createRedisKey(REDIS_PREFIXES.userSession, hashToken(refreshToken)),
    input.userId,
    'EX',
    ttl
  );
  return { token, refreshToken };
}

export async function revokeUserSession(refreshToken: string): Promise<void> {
  await getRedisClient().del(
    createRedisKey(REDIS_PREFIXES.userSession, hashToken(refreshToken))
  );
}

/**
 * Consumes a refresh token and issues a new access + refresh pair.
 */
export async function rotateUserSession(refreshToken: string) {
  let decoded: JwtPayload;
  try {
    decoded = verify(
      refreshToken,
      env.JWT_REFRESH_TOKEN_SECRET_KEY
    ) as JwtPayload;
  } catch (error) {
    const name = error instanceof Error ? error.name : '';
    throw {
      statusCode: 401,
      message:
        name === 'TokenExpiredError'
          ? 'Refresh token has expired'
          : 'Refresh token is invalid',
      errorType:
        name === 'TokenExpiredError'
          ? AuthErrorType.TOKEN_EXPIRED
          : AuthErrorType.TOKEN_INVALID,
    };
  }

  const redisClient = getRedisClient();
  const key = createRedisKey(
    REDIS_PREFIXES.userSession,
    hashToken(refreshToken)
  );
  const storedUserId = await redisClient.get(key);
  if (!storedUserId || storedUserId !== decoded.sub) {
    throw {
      statusCode: 401,
      message: 'Session has ended. Please log in again.',
      errorType: AuthErrorType.TOKEN_BLACKLISTED,
    };
  }

  const user = await prisma.user.findUnique({ where: { id: storedUserId } });
  if (!user || !user.isVerified || user.accountStatus !== 'ACTIVE') {
    await redisClient.del(key);
    throw {
      statusCode: 401,
      message: 'Session is no longer valid',
      errorType: AuthErrorType.TOKEN_INVALID,
    };
  }

  await redisClient.del(key);
  const deviceId = typeof decoded.deviceId === 'string' ? decoded.deviceId : '';
  if (!deviceId) {
    throw {
      statusCode: 401,
      message: 'Session is missing a device',
      errorType: AuthErrorType.INVALID_DEVICE_CONTEXT,
    };
  }

  return issueUserSession({
    userId: user.id,
    role: user.accountRole,
    accountStatus: user.accountStatus,
    isVerified: user.isVerified,
    deviceId,
    rememberMe: decoded.rememberMe === true,
  });
}
