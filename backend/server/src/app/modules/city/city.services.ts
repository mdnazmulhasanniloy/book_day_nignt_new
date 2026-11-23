import { Prisma } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import {
  TAdminListCitiesQuery,
  TCreateCityBody,
  TListCitiesQuery,
  TUpdateCityBody,
} from '@/app/modules/city/city.schema';

const citySelect = {
  id: true,
  name: true,
  countryCode: true,
  lat: true,
  lng: true,
  timezone: true,
  isLaunched: true,
} satisfies Prisma.CitySelect;

const conflict = () => ({
  statusCode: 409,
  message: 'City already exists',
  errorType: 'CITY_ALREADY_EXISTS',
});

const notFound = () => ({
  statusCode: 404,
  message: 'City not found',
  errorType: 'NOT_FOUND',
});

const errorCode = (error: unknown): unknown =>
  typeof error === 'object' && error !== null
    ? (error as { code?: unknown }).code
    : undefined;

/** Shared by the public and admin lists. Sorted by name, then id for stable paging. */
export const listCitiesService = async ({
  query,
  launchedOnly = false,
}: {
  query: Pick<TAdminListCitiesQuery, 'q' | 'page' | 'limit'>;
  launchedOnly?: boolean;
}) => {
  const page = Number(query.page);
  const limit = Number(query.limit);
  const where: Prisma.CityWhereInput = {
    ...(query.q ? { name: { startsWith: query.q, mode: 'insensitive' } } : {}),
    ...(launchedOnly ? { isLaunched: true } : {}),
  };
  const [total, data] = await Promise.all([
    prisma.city.count({ where }),
    prisma.city.findMany({
      where,
      select: citySelect,
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      skip: (page - 1) * limit,
      take: limit,
    }),
  ]);
  return {
    data,
    meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
};

export const publicListCitiesService = ({ query }: { query: TListCitiesQuery }) =>
  listCitiesService({ query, launchedOnly: query.launchedOnly });

/**
 * (name, countryCode) is unique in the database, but PostgreSQL treats NULL
 * country codes as distinct, so that case is checked here.
 */
const assertNoDuplicate = async ({
  name,
  countryCode,
  excludeId,
}: {
  name: string;
  countryCode: string | null;
  excludeId?: string;
}) => {
  if (countryCode !== null) return;
  const dup = await prisma.city.findFirst({
    where: {
      name,
      countryCode: null,
      ...(excludeId ? { id: { not: excludeId } } : {}),
    },
    select: { id: true },
  });
  if (dup) throw conflict();
};

export const createCityService = async ({ body }: { body: TCreateCityBody }) => {
  const countryCode = body.countryCode ?? null;
  await assertNoDuplicate({ name: body.name, countryCode });
  try {
    return await prisma.city.create({
      data: {
        name: body.name,
        countryCode,
        lat: body.lat,
        lng: body.lng,
        ...(body.timezone !== undefined ? { timezone: body.timezone } : {}),
        isLaunched: body.isLaunched ?? false,
      },
      select: citySelect,
    });
  } catch (error) {
    if (errorCode(error) === 'P2002') throw conflict();
    throw error;
  }
};

export const updateCityService = async ({
  id,
  body,
}: {
  id: string;
  body: TUpdateCityBody;
}) => {
  const existing = await prisma.city.findUnique({ where: { id } });
  if (!existing) throw notFound();
  const name = body.name ?? existing.name;
  const countryCode =
    body.countryCode !== undefined ? body.countryCode : existing.countryCode;
  await assertNoDuplicate({ name, countryCode, excludeId: id });
  try {
    return await prisma.city.update({
      where: { id },
      data: body,
      select: citySelect,
    });
  } catch (error) {
    if (errorCode(error) === 'P2002') throw conflict();
    if (errorCode(error) === 'P2025') throw notFound();
    throw error;
  }
};
