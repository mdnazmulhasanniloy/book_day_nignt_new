import { z } from 'zod';
import { Gender } from '@prisma/client';
import { assertSignupDob } from '@/app/utils/dob.utils';

/**
 * Schema for updating user profile.
 */
export const updateProfileSchema = z.object({
  name: z.string().min(1, 'Name is required').optional(),
  phoneNumber: z.string().min(1, 'Phone number is required').optional(),
  location: z.string().optional(),
  gender: z.nativeEnum(Gender).optional(),
  dateOfBirth: z
    .string()
    .optional()
    .superRefine((value, ctx) => {
      if (!value) return;
      try {
        assertSignupDob(value);
      } catch (error) {
        ctx.addIssue({
          code: 'custom',
          message:
            error instanceof Error ? error.message : 'Invalid date of birth',
        });
      }
    }),
  profileAvatar: z.url('Invalid avatar URL').optional(),
  profileCover: z.url('Invalid cover URL').optional(),
});

/**
 * Type for updating user profile.
 */
export type TUpdateProfilePayload = z.infer<typeof updateProfileSchema>;

/**
 * Schema for changing user password.
 */
export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(6, 'Password must be at least 6 characters long'),
    newPassword: z.string().min(6, 'Password must be at least 6 characters long'),
    confirmPassword: z.string().min(6, 'Password must be at least 6 characters long'),
  })
  .strict()
  .refine((data) => data.newPassword === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });

/**
 * Type for changing user password.
 */
export type TChangePasswordPayload = z.infer<typeof changePasswordSchema>;

