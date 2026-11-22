import { Gender } from '@prisma/client';
import { z } from 'zod';
import { assertSignupDob } from '@/app/utils/dob.utils';

const signupDateOfBirthSchema = z.string().superRefine((value, ctx) => {
  try {
    assertSignupDob(value);
  } catch (error) {
    ctx.addIssue({
      code: 'custom',
      message:
        error instanceof Error ? error.message : 'Invalid date of birth',
    });
  }
});

/**
 * Schema for user signup.
 */
export const signupSchema = z
  .object({
    role: z.enum(['CLUB_OWNER', 'USER']),
    name: z.string().min(1, 'Name is required'),
    email: z.email('Invalid email'),
    phoneNumber: z.string().min(5, 'Phone number is required'),
    location: z.string().min(1, 'Location is required'),
    password: z.string().min(6, 'Password must be at least 6 characters long'),
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    fcmToken: z.string().optional(),
    lat: z.number(),
    lng: z.number(),
    platform: z.enum(['ANDROID', 'IOS']),
    gender: z.nativeEnum(Gender).optional(),
    dateOfBirth: signupDateOfBirthSchema,
  })
  .strict();

/**
 * Type for user signup.
 */
export type TSignupPayload = z.infer<typeof signupSchema>;

/**
 * Schema for verifying signup user.
 */
export const verifySignupUserSchema = z
  .object({
    otp: z
      .string()
      .trim()
      .min(1, 'OTP cannot be empty')
      .length(6, 'OTP must be exactly 6 characters long')
      .regex(/^\d+$/, 'OTP must contain numbers only'),
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    fcmToken: z.string().optional(),
    platform: z.enum(['ANDROID', 'IOS']),
  })
  .strict();

/**
 * Type for verifying signup user.
 */
export type TVerifySignupUserPayload = z.infer<typeof verifySignupUserSchema>;

/**
 * Schema for check access token.
 */
export const checkAccessTokenSchema = z
  .object({
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    lat: z.number(),
    lng: z.number(),
    platform: z.enum(['ANDROID', 'IOS']),
    fcmToken: z.string().optional(),
  })
  .strict();

/**
 * Type for check access token.
 */
export type TCheckAccessTokenPayload = z.infer<typeof checkAccessTokenSchema>;

/**
 * Schema for user login.
 */
export const loginSchema = z
  .object({
    email: z.email('Invalid email'),
    password: z.string().min(6, 'Password must be at least 6 characters long'),
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    platform: z.enum(['ANDROID', 'IOS']),
    fcmToken: z.string().optional(),
    lat: z.number(),
    lng: z.number(),
    rememberMe: z.boolean().optional().default(false),
  })
  .strict();

export const refreshTokenSchema = z
  .object({
    refreshToken: z.string().min(1, 'Refresh token is required'),
  })
  .strict();

export type TRefreshTokenPayload = z.infer<typeof refreshTokenSchema>;

/**
 * Type for user login.
 */
export type TLoginPayload = z.infer<typeof loginSchema>;

/**
 * Schema for user logout.
 */
export const logoutSchema = z
  .object({
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    refreshToken: z.string().min(1).optional(),
  })
  .strict();

/**
 * Type for user logout.
 */
export type TLogoutPayload = z.infer<typeof logoutSchema>;

/**
 * Schema for oAuth login.
 */
export const oAuthLoginSchema = z
  .object({
    idToken: z.string().min(20, 'Identity token is required'),
    nonce: z.string().min(1).optional(),
    name: z.string().min(1).optional(),
    phoneNumber: z.string().min(5).optional(),
    email: z.email('Invalid email').optional(),
    deviceIdentifier: z.string().min(1, 'Device Identifier is required'),
    platform: z.enum(['ANDROID', 'IOS']),
    provider: z.enum(['GOOGLE', 'APPLE']),
    fcmToken: z.string().optional(),
    lat: z.number(),
    lng: z.number(),
    dateOfBirth: signupDateOfBirthSchema.optional(),
  })
  .strict();

/** 
 * Type for oAuth login.
 */
export type TOAuthLoginPayload = z.infer<typeof oAuthLoginSchema>;
