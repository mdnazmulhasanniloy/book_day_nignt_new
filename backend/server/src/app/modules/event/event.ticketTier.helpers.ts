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

export type TierFieldsInput = {
  id?: string;
  tierName: string;
  groupName?: string | null;
  description?: string | null;
  price: number;
  capacity: number;
  sortOrder: number;
  startAt?: Date | null;
  endAt?: Date | null;
  isActive: boolean;
};

export type TierInput = TierFieldsInput & { children?: TierFieldsInput[] };

export type TierReconcileWarning = {
  code: 'TIER_MATCH_AMBIGUOUS';
  eventId: string;
  tierIds: string[];
};

export type TierReconcileResult = {
  warnings: TierReconcileWarning[];
};

/**
 * BASELINE (pre-T-004 behaviour, kept only for the failing-test run):
 * delete every tier of the event and recreate it. Replaced in the next commit.
 */
export const reconcileEventTicketTiers = async ({
  tx,
  eventId,
  tiers,
}: {
  tx: Prisma.TransactionClient;
  eventId: string;
  tiers: TierInput[];
}): Promise<TierReconcileResult> => {
  await tx.eventTicketTier.deleteMany({ where: { eventId } });
  for (const tier of tiers) {
    const { children = [], id: _id, ...tierData } = tier;
    const parent = await tx.eventTicketTier.create({
      data: { ...tierData, eventId },
    });
    for (const child of children) {
      const { id: _childId, ...childData } = child;
      await tx.eventTicketTier.create({
        data: { ...childData, eventId, parentId: parent.id },
      });
    }
  }
  return { warnings: [] };
};
