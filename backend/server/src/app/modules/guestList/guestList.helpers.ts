import {
  Event,
  EventGuestList,
  EventGuestListEntry,
  EventGuestListFallback,
  GuestListFallbackType,
} from '@prisma/client';
import prisma from '@/app/configs/db.configs';

type GuestListWithFallbacks = EventGuestList & {
  fallbacks: EventGuestListFallback[];
};

export const countActiveGuests = async (guestListId: string) => {
  const rows = await prisma.eventGuestListEntry.findMany({
    where: {
      guestListId,
      status: { in: ['PENDING', 'CONFIRMED'] },
    },
    select: { menCount: true, womenCount: true, otherCount: true },
  });

  return rows.reduce(
    (acc, row) => {
      acc.men += row.menCount;
      acc.women += row.womenCount;
      acc.other += row.otherCount;
      acc.total += row.menCount + row.womenCount + row.otherCount;
      return acc;
    },
    { men: 0, women: 0, other: 0, total: 0 }
  );
};

export const getRemainingCapacity = ({
  guestList,
  used,
}: {
  guestList: EventGuestList;
  used: { men: number; women: number; other: number; total: number };
}) => {
  const remainingMale =
    guestList.maleCap == null ? null : Math.max(0, guestList.maleCap - used.men);
  const remainingFemale =
    guestList.femaleCap == null
      ? null
      : Math.max(0, guestList.femaleCap - used.women);
  const remainingTotal =
    guestList.freeSpots == null
      ? null
      : Math.max(0, guestList.freeSpots - used.total);

  return { remainingMale, remainingFemale, remainingTotal };
};

export const computeIsOpen = ({
  guestList,
  event,
  used,
  now = new Date(),
}: {
  guestList: EventGuestList;
  event: Pick<Event, 'startAt'>;
  used: { men: number; women: number; other: number; total: number };
  now?: Date;
}) => {
  if (!guestList.isEnabled) return false;
  if (guestList.cutoffAt && now > guestList.cutoffAt) return false;

  if (guestList.daysBefore != null) {
    const opensAt = new Date(
      event.startAt.getTime() - guestList.daysBefore * 24 * 60 * 60 * 1000
    );
    if (now < opensAt) return false;
  }

  const { remainingTotal } = getRemainingCapacity({ guestList, used });

  // Close only when total freeSpots are exhausted. Gender caps are enforced
  // per join request so otherCount can still consume remaining total capacity.
  if (remainingTotal === 0) return false;

  return true;
};

export const resolveFallbackLabels = async (
  fallbacks: EventGuestListFallback[]
): Promise<
  Array<{ type: GuestListFallbackType; id: string; label: string }>
> => {
  const sorted = [...fallbacks].sort((a, b) => a.sortOrder - b.sortOrder);
  const results: Array<{
    type: GuestListFallbackType;
    id: string;
    label: string;
  }> = [];

  for (const item of sorted) {
    let label = item.targetId;

    if (item.type === 'TICKET_TIER') {
      const tier = await prisma.eventTicketTier.findUnique({
        where: { id: item.targetId },
        select: { tierName: true, groupName: true },
      });
      if (tier) label = tier.groupName || tier.tierName;
    } else if (item.type === 'MODULE') {
      const module = await prisma.eventModule.findUnique({
        where: { id: item.targetId },
        select: { name: true, venueArea: true },
      });
      if (module) {
        label = module.venueArea
          ? `${module.name} (${module.venueArea})`
          : module.name;
      }
    } else if (item.type === 'CLUB_PACKAGE') {
      const pkg = await prisma.clubPackage.findUnique({
        where: { id: item.targetId },
        select: { name: true },
      });
      if (pkg) label = pkg.name;
    } else if (item.type === 'WAITING_LIST') {
      const club = await prisma.club.findUnique({
        where: { id: item.targetId },
        select: { name: true },
      });
      label = club ? `${club.name} waiting list` : 'Club waiting list';
    }

    results.push({ type: item.type, id: item.targetId, label });
  }

  return results;
};

export const buildPublicGuestListPayload = async ({
  guestList,
  event,
}: {
  guestList: GuestListWithFallbacks | null;
  event: Pick<Event, 'startAt'>;
}) => {
  if (!guestList || !guestList.isEnabled) {
    return null;
  }

  const used = await countActiveGuests(guestList.id);
  const isOpen = computeIsOpen({ guestList, event, used });
  const remaining = getRemainingCapacity({ guestList, used });
  const fallbacks = await resolveFallbackLabels(guestList.fallbacks);

  const remainingMale = remaining.remainingMale ?? remaining.remainingTotal ?? 0;
  const remainingFemale =
    remaining.remainingFemale ?? remaining.remainingTotal ?? 0;
  const remainingTotal =
    remaining.remainingTotal ?? remainingMale + remainingFemale;

  return {
    isOpen,
    remainingMale,
    remainingFemale,
    remainingTotal,
    arrivalTimes: guestList.arrivalTimes,
    cutoffAt: guestList.cutoffAt,
    dressCode: guestList.dressCode,
    notes: guestList.notes,
    idRequired: guestList.idRequired,
    fallbacks,
  };
};

export const mapOwnerGuestList = async (guestList: GuestListWithFallbacks) => {
  const used = await countActiveGuests(guestList.id);
  const fallbacks = await resolveFallbackLabels(guestList.fallbacks);

  return {
    id: guestList.id,
    eventId: guestList.eventId,
    isEnabled: guestList.isEnabled,
    daysBefore: guestList.daysBefore,
    cutoffAt: guestList.cutoffAt,
    arrivalTimes: guestList.arrivalTimes,
    maleCap: guestList.maleCap,
    femaleCap: guestList.femaleCap,
    freeSpots: guestList.freeSpots,
    dressCode: guestList.dressCode,
    idRequired: guestList.idRequired,
    notes: guestList.notes,
    used,
    fallbacks: fallbacks.map((f) => ({
      type: f.type,
      id: f.id,
      label: f.label,
    })),
  };
};

export const mapGuestListEntry = (entry: EventGuestListEntry) => ({
  id: entry.id,
  guestListId: entry.guestListId,
  userId: entry.userId,
  name: entry.name,
  email: entry.email,
  phone: entry.phone,
  menCount: entry.menCount,
  womenCount: entry.womenCount,
  otherCount: entry.otherCount,
  arrivalTime: entry.arrivalTime?.trim() ? entry.arrivalTime : 'Anytime',
  status: entry.status,
  acceptedTerms: entry.acceptedTerms,
  createdAt: entry.createdAt,
});
