import { z } from 'zod';

const kindSchema = z.enum(['GENRE', 'MOOD']);
const labelSchema = z.string().trim().min(1, 'label is required').max(120);
const sortOrderSchema = z.number().int().min(0).max(1_000_000);

export const exploreFiltersQuerySchema = z.object({
  type: z.enum(['CLUB', 'EVENT']),
});
export type TExploreFiltersQuery = z.infer<typeof exploreFiltersQuerySchema>;

export const adminListFilterOptionsQuerySchema = z.object({
  kind: kindSchema.optional(),
});
export type TAdminListFilterOptionsQuery = z.infer<
  typeof adminListFilterOptionsQuerySchema
>;

export const createFilterOptionSchema = z
  .object({
    kind: kindSchema,
    label: labelSchema,
    sortOrder: sortOrderSchema.optional(),
  })
  .strict();
export type TCreateFilterOptionBody = z.infer<typeof createFilterOptionSchema>;

export const updateFilterOptionSchema = z
  .object({
    label: labelSchema.optional(),
    sortOrder: sortOrderSchema.optional(),
    isActive: z.boolean().optional(),
  })
  .strict()
  .refine((v) => Object.keys(v).length > 0, 'at least one field is required');
export type TUpdateFilterOptionBody = z.infer<typeof updateFilterOptionSchema>;

export const filterOptionIdParamsSchema = z.object({
  id: z.string().uuid('Invalid filter option ID format'),
});
export type TFilterOptionIdParams = z.infer<typeof filterOptionIdParamsSchema>;
