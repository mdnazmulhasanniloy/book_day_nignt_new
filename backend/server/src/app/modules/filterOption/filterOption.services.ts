import { EventCategoryType, Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import {
  TAdminListFilterOptionsQuery,
  TCreateFilterOptionBody,
  TExploreFiltersQuery,
  TUpdateFilterOptionBody,
} from '@/app/modules/filterOption/filterOption.schema';

const optionSelect = {
  id: true,
  kind: true,
  label: true,
  sortOrder: true,
  isActive: true,
} satisfies Prisma.FilterOptionSelect;

const conflict = () => ({
  statusCode: 409,
  message: 'Filter option already exists',
  errorType: 'FILTER_OPTION_ALREADY_EXISTS',
});

const notFound = () => ({
  statusCode: 404,
  message: 'Filter option not found',
  errorType: 'NOT_FOUND',
});

const errorCode = (error: unknown): unknown =>
  typeof error === 'object' && error !== null
    ? (error as { code?: unknown }).code
    : undefined;

/** Same normalisation as the T-031 backfill and the T-032 seed. */
export const toLabelKey = (label: string): string => label.trim().toLowerCase();

/** Stable order: sortOrder, then label, then id (ties are common: default 0). */
const displayOrder: Prisma.FilterOptionOrderByWithRelationInput[] = [
  { sortOrder: 'asc' },
  { label: 'asc' },
  { id: 'asc' },
];

/**
 * Public vocabulary. Genres and moods are the active FilterOption rows (English
 * `label`) in sortOrder. type=EVENT lists the EventCategoryType values; the
 * spec does not define club venue attributes, so type=CLUB lists none.
 */
export const exploreFiltersService = async ({
  query,
}: {
  query: TExploreFiltersQuery;
}) => {
  const rows = await prisma.filterOption.findMany({
    where: { isActive: true },
    select: { kind: true, label: true },
    orderBy: displayOrder,
  });
  return {
    categories:
      query.type === 'EVENT' ? (Object.values(EventCategoryType) as string[]) : [],
    genres: rows.filter((r) => r.kind === 'GENRE').map((r) => r.label),
    moods: rows.filter((r) => r.kind === 'MOOD').map((r) => r.label),
  };
};

export const listFilterOptionsService = ({
  query,
}: {
  query: TAdminListFilterOptionsQuery;
}) =>
  prisma.filterOption.findMany({
    where: query.kind ? { kind: query.kind } : {},
    select: optionSelect,
    orderBy: [{ kind: 'asc' }, ...displayOrder],
  });

export const createFilterOptionService = async ({
  body,
}: {
  body: TCreateFilterOptionBody;
}) => {
  const labelKey = toLabelKey(body.label);
  const dup = await prisma.filterOption.findUnique({
    where: { kind_labelKey: { kind: body.kind, labelKey } },
    select: { id: true },
  });
  if (dup) throw conflict();
  try {
    return await prisma.filterOption.create({
      data: {
        kind: body.kind,
        label: body.label,
        labelKey,
        ...(body.sortOrder !== undefined ? { sortOrder: body.sortOrder } : {}),
      },
      select: optionSelect,
    });
  } catch (error) {
    if (errorCode(error) === 'P2002') throw conflict();
    throw error;
  }
};

/**
 * Only touches the FilterOption row. Events keep their own free-text
 * musicGenres / moodTags (no FK), so deactivating or renaming a value never
 * edits an event.
 */
export const updateFilterOptionService = async ({
  id,
  body,
}: {
  id: string;
  body: TUpdateFilterOptionBody;
}) => {
  const existing = await prisma.filterOption.findUnique({ where: { id } });
  if (!existing) throw notFound();
  const data: Prisma.FilterOptionUpdateInput = {};
  if (body.sortOrder !== undefined) data.sortOrder = body.sortOrder;
  if (body.isActive !== undefined) data.isActive = body.isActive;
  if (body.label !== undefined) {
    const labelKey = toLabelKey(body.label);
    if (labelKey !== existing.labelKey) {
      const dup = await prisma.filterOption.findUnique({
        where: { kind_labelKey: { kind: existing.kind, labelKey } },
        select: { id: true },
      });
      if (dup) throw conflict();
    }
    data.label = body.label;
    data.labelKey = labelKey;
  }
  try {
    return await prisma.filterOption.update({
      where: { id },
      data,
      select: optionSelect,
    });
  } catch (error) {
    if (errorCode(error) === 'P2002') throw conflict();
    if (errorCode(error) === 'P2025') throw notFound();
    throw error;
  }
};
