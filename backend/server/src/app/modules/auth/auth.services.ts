import { getRedisClient } from '@/app/configs/redis.configs';
import { getTraceId } from '@/app/configs/requestContext.configs';
import {
  assertResendAllowed,
  hashOtp,
  saveHashedOtp,
} from '@/app/utils/otp.utils';
import { generateNumericOtp } from '@/app/utils/otpPolicy';
import { assertSignupDob } from '@/app/utils/dob.utils';
import { hashPassword } from '@/app/utils/password.utils';
import {
  calculateMilliseconds,
  createRedisKey,
} from '@/app/utils/system.utils';
import { getEmailQueue } from '@/app/queues/email/email.queue';
import prisma from '@/app/configs/db.configs';
import {
  AccountRole,
  AccountStatus,
  AuthProvider,
  Prisma,
} from '@prisma/client';
import {
  generateOtpPageToken,
  verifyOtpPageToken,
} from '@/app/utils/jwt.utils';
import {
  issueUserSession,
  revokeUserSession,
  rotateUserSession,
} from '@/app/utils/session.utils';
import { verifyOAuthIdToken } from '@/app/utils/oauthToken.utils';
import logger from '@/app/configs/logger.configs';
import {
  locationExpireAt,
  otpExpireAt,
  QUEUE_JOBS,
  REDIS_PREFIXES,
} from '@/const';
import {
  ICheckAccessTokenService,
  ILoginService,
  ILogoutService,
  IOAuthLoginService,
  IResendOtpService,
  ISignupService,
  IVerifySignupUserService,
} from '@/app/modules/auth/auth.types';
import { JwtPayload } from 'jsonwebtoken';

/**
 * Service for user signup.
 * Creates a new user with the given payload.
 * Generates an OTP and stores it in Redis.
 * Adds a job to the email queue to send the OTP to the user.
 * @returns Promise<{ token: string; }>
 */
export const signupService = async ({
  payload,
  existingUser,
}: ISignupService): Promise<Record<string, unknown>> => {
  const redisClient = getRedisClient();
  const emailQueue = getEmailQueue();
  const traceId = getTraceId();
  try {
    const {
      email,
      lat,
      lng,
      location,
      name,
      password,
      phoneNumber,
      role,
      gender,
      dateOfBirth,
    } = payload;
    const hashPass = await hashPassword(password);
    const dateOfBirthDate = assertSignupDob(dateOfBirth);
    const otp = generateNumericOtp(6);
    const hashedOtp = hashOtp({ otp });
    const phoneOwner = await prisma.user.findFirst({
      where: {
        phoneNumber,
        ...(existingUser ? { NOT: { id: existingUser.id } } : {}),
      },
      select: { id: true },
    });
    if (phoneOwner) {
      throw {
        statusCode: 409,
        message: 'Phone number is already in use',
        errorType: 'DUPLICATE_DATA',
      };
    }
    const newUser = existingUser
      ? await prisma.$transaction(async (tx) => {
          const user = await tx.user.update({
            where: { id: existingUser.id },
            data: {
              name,
              password: hashPass,
              phoneNumber,
              accountRole: role,
            },
          });
          await tx.profile.upsert({
            where: { userId: user.id },
            create: {
              location,
              gender,
              dateOfBirth: dateOfBirthDate,
              userId: user.id,
            },
            update: {
              location,
              gender,
              dateOfBirth: dateOfBirthDate,
            },
          });
          return user;
        })
      : await prisma.$transaction(async (tx) => {
          const user = await tx.user.create({
            data: {
              email,
              name,
              password: hashPass,
              phoneNumber,
              accountRole: role,
            },
          });
          await tx.profile.create({
            data: {
              location,
              gender,
              dateOfBirth: dateOfBirthDate,
              userId: user.id,
            },
          });
          return user;
        });
    const token = generateOtpPageToken({
      accountStatus: newUser.accountStatus,
      role: newUser.accountRole,
      isVerified: newUser.isVerified,
      sub: newUser.id,
      deviceId: 'pending',
    });
    const emailQueueData = {
      name: newUser.name,
      email: newUser.email,
      otp,
      otpExpireAt,
      traceId,
    };
    await Promise.all([
      saveHashedOtp(newUser.id, hashedOtp),
      redisClient.set(
        createRedisKey(REDIS_PREFIXES.location, newUser.id),
        JSON.stringify({ lat, lng }),
        'EX',
        calculateMilliseconds(locationExpireAt, 'days')
      ),
      redisClient.geoadd(
        createRedisKey(REDIS_PREFIXES.locations),
        lng,
        lat,
        newUser.id
      ),
      emailQueue.add(QUEUE_JOBS.SEND_SIGNUP_SUCCESS_EMAIL, emailQueueData),
    ]);
    return { token };
  } catch (error) {
    throw error;
  }
};

/**
 * Service for verifying signup user.
 * Verifies the OTP and updates the user status.
 * Removes the OTP from Redis.
 * @returns Promise<void>
 */
export const verifySignupUserService = async ({
  token,
  user,
  payload,
}: IVerifySignupUserService): Promise<Record<string, unknown>> => {
  try {
    const redisClient = getRedisClient();
    const traceId = getTraceId();
    const emailQueue = getEmailQueue();
    const { deviceIdentifier, fcmToken, platform } = payload;
    const updatedUser = await prisma.user.update({
      where: { id: user.id },
      data: { isVerified: true },
    });
    const device = await prisma.device.upsert({
      where: { deviceIdentifier },
      create: {
        deviceIdentifier,
        fcmToken: fcmToken || null,
        platform,
        authProvider: AuthProvider.MANUAL,
        userId: user.id,
        isActive: true,
      },
      update: {
        userId: user.id,
        fcmToken: fcmToken || null,
        platform,
        lastSeenAt: new Date(),
        isActive: true,
      },
    });
    const session = await issueUserSession({
      accountStatus: updatedUser.accountStatus,
      role: updatedUser.accountRole,
      isVerified: updatedUser.isVerified,
      userId: updatedUser.id,
      deviceId: device.id,
      rememberMe: true,
    });
    const accessToken = session.token;
    const decoded = verifyOtpPageToken(token) as JwtPayload;
    const tokenExpirationTime = decoded.exp as number;
    const currentTime = Math.floor(Date.now() / 1000); // current time in seconds
    const ttl = Math.floor(tokenExpirationTime - currentTime); // remaining time in seconds
    if (ttl > 0)
      await redisClient.set(
        createRedisKey(REDIS_PREFIXES.blacklist, token),
        token as string,
        'EX',
        ttl
      );
    const emailData = {
      name: updatedUser.name,
      email: updatedUser.email,
      traceId,
    };
    await Promise.all([
      redisClient.del(createRedisKey(REDIS_PREFIXES.otp, updatedUser.id)),
      emailQueue.add(QUEUE_JOBS.SIGNUP_USER_VERIFICATION_SUCCESSFUL, emailData),
    ]);

    return { token: accessToken, refreshToken: session.refreshToken };
  } catch (error) {
    throw error;
  }
};

/**
 * Service for resending OTP.
 * Generates a new OTP and stores it in Redis.
 * Adds a job to the email queue to send the OTP to the user.
 * @returns Promise<void>
 */
export const resendOtpService = async ({
  user,
}: IResendOtpService): Promise<void> => {
  try {
    const traceId = getTraceId();
    const emailQueue = getEmailQueue();
    await assertResendAllowed(user.id);
    const otp = generateNumericOtp(6);
    const hashedOtp = hashOtp({ otp });
    const emailData = {
      name: user.name,
      email: user.email,
      otp,
      otpExpireAt,
      traceId,
    };
    await Promise.all([
      saveHashedOtp(user.id, hashedOtp),
      emailQueue.add(QUEUE_JOBS.RESEND_VERIFICATION_OTP, emailData),
    ]);
    return;
  } catch (error) {
    throw error;
  }
};

/**
 * This service is used to check the user's access token.
 * It updates the device information and returns the user's profile information.
 * @returns Promise<{
 *   name: string;
 *   avatar: string | null;
 *   role: string;
 *   accountStatus: string;
 * }>
 */
export const checkUserAccessTokenService = async ({
  payload,
  jwtPayload,
  user,
  device,
}: ICheckAccessTokenService): Promise<{
  name: string;
  avatar: string | null;
  role: string;
  accountStatus: string;
}> => {
  try {
    const { fcmToken } = payload;
    const { sub } = jwtPayload;

    // Throttle lastSeenAt updates to at most once per hour to minimize DB writes
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const shouldUpdateLastSeenAt = device.lastSeenAt < oneHourAgo;

    if (shouldUpdateLastSeenAt || (fcmToken && device.fcmToken !== fcmToken)) {
      await prisma.device.update({
        where: { id: device.id },
        data: {
          lastSeenAt: shouldUpdateLastSeenAt ? new Date() : undefined,
          fcmToken: fcmToken ? fcmToken : undefined,
        },
      });
    }

    const userProfile = await prisma.profile.findUnique({
      where: { userId: sub },
      select: { profileAvatar: true },
    });

    return {
      name: user.name,
      avatar: userProfile?.profileAvatar || null,
      role: user.accountRole,
      accountStatus: user.accountStatus,
    };
  } catch (error) {
    throw error;
  }
};
/**
 * Service for user login.
 * Validates credentials, checks account status, manages Device creation/updates/reassignment,
 * and returns the appropriate JWT (access token or OTP token).
 * @returns Promise<{ token: string; }>
 */
export const loginService = async ({
  user,
  payload,
}: ILoginService): Promise<Record<string, unknown>> => {
  try {
    const { deviceIdentifier, platform, fcmToken, rememberMe, lat, lng } =
      payload;

    const redisClient = getRedisClient();

    // 4. Handle Unverified Users
    if (!user.isVerified) {
      // Reuse existing OTP mechanism if not verified
      const traceId = getTraceId();
      const emailQueue = getEmailQueue();

      const otp = generateNumericOtp(6);
      const hashedOtp = hashOtp({ otp });

      const token = generateOtpPageToken({
        accountStatus: user.accountStatus,
        role: user.accountRole,
        isVerified: user.isVerified,
        sub: user.id,
        deviceId: 'pending',
      });

      const emailQueueData = {
        name: user.name,
        email: user.email,
        otp,
        otpExpireAt,
        traceId,
      };

      await Promise.all([
        saveHashedOtp(user.id, hashedOtp),
        redisClient.set(
          createRedisKey(REDIS_PREFIXES.location, user.id),
          JSON.stringify({ lat, lng }),
          'EX',
          calculateMilliseconds(locationExpireAt, 'days')
        ),
        redisClient.geoadd(
          createRedisKey(REDIS_PREFIXES.locations),
          lng,
          lat,
          user.id
        ),
        emailQueue.add(QUEUE_JOBS.RESEND_VERIFICATION_OTP, emailQueueData),
      ]);

      return { token, role: user.accountRole, isUserVerified: user.isVerified };
    }

    // Update location for verified users too
    await Promise.all([
      redisClient.set(
        createRedisKey(REDIS_PREFIXES.location, user.id),
        JSON.stringify({ lat, lng }),
        'EX',
        calculateMilliseconds(locationExpireAt, 'days')
      ),
      redisClient.geoadd(
        createRedisKey(REDIS_PREFIXES.locations),
        lng,
        lat,
        user.id
      ),
    ]);

    // 5 & 6. Resolve and manage Device
    // We upsert: if it doesn't exist, create it (CASE A).
    // If it exists (CASE B or CASE C), update it and reassign userId.
    const device = await prisma.device.upsert({
      where: { deviceIdentifier },
      create: {
        deviceIdentifier,
        fcmToken: fcmToken || null,
        platform,
        authProvider: AuthProvider.MANUAL,
        userId: user.id,
        isActive: true,
      },
      update: {
        userId: user.id, // Handles CASE C (reassignment) silently, and is a no-op for CASE B
        platform,
        lastSeenAt: new Date(),
        isActive: true,
        ...(fcmToken ? { fcmToken } : {}), // Update fcmToken only if provided
      },
    });

    // 7. Generate access JWT with Device.id
    const session = await issueUserSession({
      accountStatus: user.accountStatus,
      role: user.accountRole,
      isVerified: user.isVerified,
      userId: user.id,
      deviceId: device.id,
      rememberMe: rememberMe ?? false,
    });

    return {
      token: session.token,
      refreshToken: session.refreshToken,
      role: user.accountRole,
      isUserVerified: user.isVerified,
    };
  } catch (error) {
    throw error;
  }
};

/**
 * Service for user logout.
 * Operates on a trusted device context established by checkDeviceContextMiddleware.
 * Marks the device as inactive, clears FCM token,
 * and blacklists the current JWT access token.
 * @returns Promise<void>
 */
export const logoutService = async ({
  jwtPayload,
  token,
  device,
  payload,
}: ILogoutService): Promise<void> => {
  try {
    const { exp } = jwtPayload;

    const redisClient = getRedisClient();
    const currentTime = Math.floor(Date.now() / 1000);
    const ttl = Math.floor(exp! - currentTime);

    const updateDevicePromise = prisma.device.update({
      where: { id: device.id },
      data: {
        isActive: false,
        fcmToken: null,
      },
    });

    if (payload.refreshToken) {
      await revokeUserSession(payload.refreshToken);
    }

    if (ttl > 0) {
      await Promise.all([
        updateDevicePromise,
        redisClient.set(
          createRedisKey(REDIS_PREFIXES.blacklist, token),
          token,
          'EX',
          ttl
        ),
      ]);
    } else {
      await updateDevicePromise;
    }

    return;
  } catch (error) {
    throw error;
  }
};

export const refreshUserSessionService = async ({
  refreshToken,
}: {
  refreshToken: string;
}) => rotateUserSession(refreshToken);

const socialFallbackEmail = (provider: string, sub: string) => {
  const safeSub = sub.toLowerCase().replace(/[^a-z0-9]/g, '');
  return `social.${provider.toLowerCase()}.${safeSub}@users.bookdianight.invalid`;
};

const isUniqueViolation = (error: unknown) =>
  error instanceof Prisma.PrismaClientKnownRequestError &&
  error.code === 'P2002';

const socialPhoneNumber = async ({
  phoneNumber,
  provider,
  sub,
}: {
  phoneNumber?: string;
  provider: string;
  sub: string;
}) => {
  const fallback = `social:${provider}:${sub}`;
  if (!phoneNumber) return fallback;
  const phoneOwner = await prisma.user.findFirst({
    where: { phoneNumber },
    select: { id: true },
  });
  if (!phoneOwner) return phoneNumber;
  logger.warn('OAuth phone already in use; storing a placeholder', {
    provider,
  });
  return fallback;
};

export const oAuthLoginService = async ({
  payload,
  verifyIdentity = verifyOAuthIdToken,
}: IOAuthLoginService): Promise<Record<string, unknown>> => {
  const {
    deviceIdentifier,
    platform,
    fcmToken,
    provider,
    lat,
    lng,
    phoneNumber,
    name,
  } = payload;

  // Validate before any provider call or write: an invalid DOB must create nothing.
  let dateOfBirth: Date | undefined;
  if (payload.dateOfBirth !== undefined) {
    try {
      dateOfBirth = assertSignupDob(payload.dateOfBirth);
    } catch (error) {
      throw {
        statusCode: 422,
        message:
          error instanceof Error ? error.message : 'Invalid date of birth',
        errorType: 'VALIDATION_ERROR',
      };
    }
  }

  const identity = await verifyIdentity({
    provider,
    idToken: payload.idToken,
    nonce: payload.nonce,
  });

  const providerEnum =
    provider === 'GOOGLE' ? AuthProvider.GOOGLE : AuthProvider.APPLE;

  let user =
    (
      await prisma.oAuthIdentity.findUnique({
        where: {
          provider_providerUserId: {
            provider: providerEnum,
            providerUserId: identity.sub,
          },
        },
        include: { user: true },
      })
    )?.user ?? null;

  if (!user && identity.email) {
    user = await prisma.user.findUnique({
      where: { email: identity.email },
    });
  }

  if (!user) {
    const email = identity.email ?? socialFallbackEmail(provider, identity.sub);
    const resolvedPhone = await socialPhoneNumber({
      phoneNumber,
      provider,
      sub: identity.sub,
    });
    const fallbackPhone = await socialPhoneNumber({
      provider,
      sub: identity.sub,
    });
    // User, profile and identity are created in ONE statement (one
    // transaction), so a failure never leaves a half-created account.
    const createAccount = (phone: string) =>
      prisma.user.create({
        data: {
          email,
          name: identity.name || name || 'Guest',
          phoneNumber: phone,
          accountRole: AccountRole.USER,
          isVerified: true,
          profile: { create: { dateOfBirth } },
          oauthIdentities: {
            create: { provider: providerEnum, providerUserId: identity.sub },
          },
        },
      });
    const findExisting = async () =>
      (
        await prisma.oAuthIdentity.findUnique({
          where: {
            provider_providerUserId: {
              provider: providerEnum,
              providerUserId: identity.sub,
            },
          },
          include: { user: true },
        })
      )?.user ?? (await prisma.user.findUnique({ where: { email } }));
    try {
      user = await createAccount(resolvedPhone);
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // A parallel or repeated request won the race: return its account.
      user = await findExisting();
      if (!user && resolvedPhone !== fallbackPhone) {
        // The phone was taken meanwhile by another account: use the placeholder.
        try {
          user = await createAccount(fallbackPhone);
        } catch (retryError) {
          if (!isUniqueViolation(retryError)) throw retryError;
          user = await findExisting();
        }
      }
      if (!user) throw error;
    }
  }

  if (!user.isVerified) {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { isVerified: true },
    });
  }

  if (user.accountStatus === AccountStatus.DELETED) {
    throw {
      statusCode: 401,
      message: 'Your account has been deleted',
      errorType: 'ACCOUNT_DELETED',
    };
  }
  if (user.accountStatus === AccountStatus.BLOCKED) {
    throw {
      statusCode: 401,
      message: 'Your account has been blocked',
      errorType: 'USER_BLOCKED',
    };
  }
  if (user.accountStatus === AccountStatus.INACTIVE) {
    throw {
      statusCode: 401,
      message: 'Your account has been deactivated',
      errorType: 'ACCOUNT_INACTIVE',
    };
  }

  try {
    await prisma.oAuthIdentity.upsert({
      where: {
        provider_providerUserId: {
          provider: providerEnum,
          providerUserId: identity.sub,
        },
      },
      create: {
        provider: providerEnum,
        providerUserId: identity.sub,
        userId: user.id,
      },
      update: {},
    });
  } catch (error) {
    // A concurrent upsert won the race; the identity row exists, which is fine.
    if (!isUniqueViolation(error)) throw error;
  }

  // Set the DOB only while it is missing; an existing DOB is never overwritten.
  const existingProfile = await prisma.profile.findUnique({
    where: { userId: user.id },
    select: { dateOfBirth: true },
  });
  let hasDateOfBirth = existingProfile?.dateOfBirth != null;
  if (!hasDateOfBirth && dateOfBirth) {
    if (!existingProfile) {
      try {
        await prisma.profile.create({ data: { userId: user.id, dateOfBirth } });
      } catch (error) {
        if (!isUniqueViolation(error)) throw error;
      }
    }
    // No-op when the DOB is already set (conditional on NULL), so never overwrites.
    await prisma.profile.updateMany({
      where: { userId: user.id, dateOfBirth: null },
      data: { dateOfBirth },
    });
    hasDateOfBirth = true;
  }

  const redisClient = getRedisClient();
  await Promise.all([
    redisClient.set(
      createRedisKey(REDIS_PREFIXES.location, user.id),
      JSON.stringify({ lat, lng }),
      'EX',
      calculateMilliseconds(locationExpireAt, 'days')
    ),
    redisClient.geoadd(
      createRedisKey(REDIS_PREFIXES.locations),
      lng,
      lat,
      user.id
    ),
  ]);

  const device = await prisma.device.upsert({
    where: { deviceIdentifier },
    create: {
      deviceIdentifier,
      fcmToken: fcmToken || null,
      platform,
      authProvider: providerEnum,
      userId: user.id,
      isActive: true,
    },
    update: {
      userId: user.id,
      authProvider: providerEnum,
      platform,
      lastSeenAt: new Date(),
      isActive: true,
      ...(fcmToken ? { fcmToken } : {}),
    },
  });

  const session = await issueUserSession({
    userId: user.id,
    role: user.accountRole,
    accountStatus: user.accountStatus,
    isVerified: true,
    deviceId: device.id,
    rememberMe: true,
  });

  return {
    token: session.token,
    refreshToken: session.refreshToken,
    role: user.accountRole,
    isUserVerified: true,
    profileComplete: hasDateOfBirth,
  };
};
