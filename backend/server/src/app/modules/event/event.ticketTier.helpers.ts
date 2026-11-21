import { EventTicketTier, Prisma } from '@prisma/client';

export const mapTicketTierTree = (
  tiers: EventTicketTier[]
): Array<
  Record<string, unknown> & {
    soldOut: boolean;
    children: Array<Record<string, unknown> & { soldOut: boolean }>;
  }
> => {
  const mapTier = (tier: EventTicketTier) => ({
    id: tier.id,
    eventId: tier.eventId,
    parentId: tier.parentId,
    tierName: tier.tierName,
    groupName: tier.groupName,
    description: tier.description,
    price:
      tier.price instanceof Prisma.Decimal
        ? tier.price.toFixed(2)
        : String(tier.price),
    capacity: tier.capacity,
    soldCount: tier.soldCount,
    soldOut: tier.soldCount >= tier.capacity,
    sortOrder: tier.sortOrder,
    startAt: tier.startAt,
    endAt: tier.endAt,
    isActive: tier.isActive,
  });

  const roots = tiers
    .filter((tier) => !tier.parentId)
    .sort((a, b) => a.sortOrder - b.sortOrder);

  return roots.map((root) => {
    const children = tiers
      .filter((tier) => tier.parentId === root.id)
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((child) => ({
        ...mapTier(child),
        children: [] as Array<Record<string, unknown>>,
      }));

    return {
      ...mapTier(root),
      children,
    };
  });
};
