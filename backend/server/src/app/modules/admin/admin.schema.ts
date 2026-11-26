import { z } from 'zod';

/**
 * Schema for admin login.
 */
export const adminLoginSchema = z.object({
  email: z.email({ error: 'Invalid email address' }),
  password: z.string().min(6, { error: 'Password must be at least 6 characters long' }),
});

/**
 * Type for admin login.
 */
export type TAdminLoginPayload = z.infer<typeof adminLoginSchema>;

/**
 * Schema for updating admin profile.
 */
export const updateAdminProfileSchema = z.object({
  name: z.string().min(1, 'Name is required').optional(),
  phoneNumber: z.string().min(1, 'Phone number is required').optional(),
  profileAvatar: z.url('Invalid avatar URL').optional(),
});

/**
 * Type for updating admin profile.
 */
export type TUpdateAdminProfilePayload = z.infer<typeof updateAdminProfileSchema>;

/**
 * Schema for changing admin password.
 */
export const changeAdminPasswordSchema = z
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
 * Type for changing admin password.
 */
export type TChangeAdminPasswordPayload = z.infer<typeof changeAdminPasswordSchema>;

/**
 * Schema for updating commission configuration.
 */
export const updateCommissionSchema = z
  .object({
    serviceType: z.enum(['EVENT', 'CLUB']),
    chargePercentage: z
      .number()
      .finite('Charge percentage must be a finite number')
      .multipleOf(0.01, 'Charge percentage must have at most 2 decimal places'),
  })
  .strict();

/**
 * Type for updating commission configuration.
 */
export type TUpdateCommissionPayload = z.infer<typeof updateCommissionSchema>;

/**
 * Schema for dashboard query.
 */
export const getDashboardQuerySchema = z.object({
  year: z.string().regex(/^\d{4}$/, 'Invalid year format').optional(),
  role: z.enum(['USER', 'CLUB_OWNER']).optional(),
});

/**
 * Type for dashboard query.
 */
export type TGetDashboardQuery = z.infer<typeof getDashboardQuerySchema>;

/**
 * page/limit stay strings (services parse them) so the parsed output type is
 * unchanged. Values must be positive integers; limit is capped at 100 (T-010).
 */
const positiveIntString = (field: string) =>
  z
    .string()
    .regex(/^[1-9]\d*$/, `${field} must be a positive integer`)
    .refine((v) => Number.isSafeInteger(Number(v)), `${field} is too large`);

const pageQuerySchema = positiveIntString('page').optional().default('1');
const limitQuerySchema = positiveIntString('limit')
  .refine((v) => Number(v) <= 100, 'limit must be at most 100')
  .optional()
  .default('10');

export const getAdminUsersQuerySchema = z.object({
  page: pageQuerySchema,
  limit: limitQuerySchema,
  role: z.enum(['USER', 'CLUB_OWNER']).optional(),
  search: z.string().optional(),
  /** Default excludes DELETED. Pass DELETED to list soft-deleted accounts for restore. */
  status: z.enum(['ACTIVE', 'BLOCKED', 'INACTIVE', 'DELETED']).optional(),
});

export type TGetAdminUsersQuery = z.infer<typeof getAdminUsersQuerySchema>;

export const adminUserIdParamsSchema = z.object({
  id: z.string().uuid('Invalid user ID format'),
});

export type TAdminUserIdParams = z.infer<typeof adminUserIdParamsSchema>;

export const earningsQuerySchema = z.object({
  page: pageQuerySchema,
  limit: limitQuerySchema,
  serviceType: z.enum(['EVENT', 'CLUB']).optional(),
});

export type TEarningsQuery = z.infer<typeof earningsQuerySchema>;