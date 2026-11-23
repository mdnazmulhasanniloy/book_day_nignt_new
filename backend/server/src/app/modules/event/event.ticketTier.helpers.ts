import { EventTicketTier, Prisma, TierType } from '@prisma/client';

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
    tierType: tier.tierType,
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
  /** Omitted: created as TICKET (DB default), kept as stored on update. */
  tierType?: TierType;
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

const tierError = (statusCode: number, errorType: string, message: string) => ({
  statusCode,
  message,
  errorType,
});

type Entry = {
  input: TierFieldsInput;
  /** Existing row this incoming tier updates; null means create. */
  existing: EventTicketTier | null;
  children: Entry[];
};

const normalize = (value: string | null | undefined): string =>
  (value ?? '').trim().toLowerCase();

/** Deterministic order of existing tiers: (sortOrder, createdAt, id). */
const byStableOrder = (a: EventTicketTier, b: EventTicketTier): number =>
  a.sortOrder - b.sortOrder ||
  a.createdAt.getTime() - b.createdAt.getTime() ||
  (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);

/**
 * ADR-004 key matching for clients that send no ids. Pairs incoming entries
 * with candidate existing tiers that share a key:
 * 1. exact pairs (same price and capacity), incoming in array order;
 * 2. the rest by position (existing by stable order, incoming by array order);
 * 3. surplus incoming stays unmatched (created).
 * A positional pair inside a duplicate-key group whose price differs or that
 * already has sales is reported as TIER_MATCH_AMBIGUOUS (warning, not error).
 */
const pairByKey = ({
  eventId,
  candidates,
  entries,
  keyOf,
  entryKeyOf,
  warnings,
}: {
  eventId: string;
  candidates: EventTicketTier[];
  entries: Entry[];
  keyOf: (tier: EventTicketTier) => string;
  entryKeyOf: (entry: Entry) => string;
  warnings: TierReconcileWarning[];
}): void => {
  const existingByKey = new Map<string, EventTicketTier[]>();
  for (const tier of [...candidates].sort(byStableOrder)) {
    const key = keyOf(tier);
    existingByKey.set(key, [...(existingByKey.get(key) ?? []), tier]);
  }
  const entriesByKey = new Map<string, Entry[]>();
  for (const entry of entries) {
    const key = entryKeyOf(entry);
    entriesByKey.set(key, [...(entriesByKey.get(key) ?? []), entry]);
  }

  for (const [key, group] of entriesByKey) {
    const pool = [...(existingByKey.get(key) ?? [])];
    if (pool.length === 0) continue;
    const isDuplicateKey = pool.length > 1 || group.length > 1;
    const unpaired: Entry[] = [];

    for (const entry of group) {
      const idx = pool.findIndex(
        (tier) =>
          Number(tier.price) === entry.input.price &&
          tier.capacity === entry.input.capacity
      );
      if (idx >= 0) {
        entry.existing = pool.splice(idx, 1)[0];
      } else {
        unpaired.push(entry);
      }
    }
    for (const entry of unpaired) {
      const tier = pool.shift();
      if (!tier) break;
      entry.existing = tier;
      if (isDuplicateKey && (Number(tier.price) !== entry.input.price || tier.soldCount > 0)) {
        warnings.push({
          code: 'TIER_MATCH_AMBIGUOUS',
          eventId,
          tierIds: [tier.id],
        });
      }
    }
  }
};

/**
 * Section vs tier rule (T-016): a section is a parent tier (no sales of its
 * own), a tier is a child or a top-level priced tier. Checked on write only;
 * existing events are not re-validated on read.
 * - a tier that has children cannot already have sales (422 TIER_SECTION_HAS_SALES);
 * - the parent of a child must be a top-level tier of the same event (422 TIER_INVALID_PARENT).
 */
export const assertTierSectionRules = ({
  eventId,
  sections,
}: {
  eventId: string;
  sections: Array<{
    hasChildren: boolean;
    existing: Pick<EventTicketTier, 'id' | 'eventId' | 'parentId' | 'soldCount'> | null;
  }>;
}): void => {
  for (const { hasChildren, existing } of sections) {
    if (!hasChildren || !existing) continue;
    if (existing.eventId !== eventId || existing.parentId !== null) {
      throw tierError(422, 'TIER_INVALID_PARENT', `Ticket tier ${existing.id} cannot be a section: a parent must be a top-level tier of the same event`);
    }
    if (existing.soldCount > 0) {
      throw tierError(422, 'TIER_SECTION_HAS_SALES', `Ticket tier ${existing.id} already has ${existing.soldCount} tickets sold and cannot become a section with child tiers`);
    }
  }
};

/**
 * Reconciles the incoming ticket tiers of `PUT /event/{id}` with the stored
 * ones, in place, inside the caller's transaction (T-004, ADR-004, B-24).
 *
 * - Any incoming tier with an `id`: id mode. Tiers with an id must belong to
 *   this event (else 404 TIER_NOT_FOUND) and are updated in place; tiers
 *   without an id are created.
 * - No incoming id (live app): key mode. Sections match on trimmed,
 *   case-insensitive (groupName, tierName); children on (matched parent id,
 *   tierName). Duplicate keys: see `pairByKey`.
 * - Existing tiers not matched: hard-deleted only when soldCount = 0, no
 *   surviving child and no EventPurchase row references the tier (T-006; the
 *   snapshot trigger would reject the FK SET NULL of such a delete), otherwise
 *   kept with isActive = false.
 * - capacity < soldCount: 409 TIER_CAPACITY_BELOW_SOLD. soldCount is never
 *   written. All validation runs before the first write.
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
  const warnings: TierReconcileWarning[] = [];

  // Lock the event's tiers so a concurrent purchase cannot change soldCount
  // between the checks below and the writes.
  await tx.$queryRaw`SELECT id FROM "EventTicketTier" WHERE "eventId" = ${eventId} FOR UPDATE`;
  const existing = (
    await tx.eventTicketTier.findMany({ where: { eventId } })
  ).sort(byStableOrder);
  const existingById = new Map(existing.map((tier) => [tier.id, tier]));

  const sections: Entry[] = tiers.map((tier) => {
    const { children = [], ...input } = tier;
    return {
      input,
      existing: null,
      children: children.map((child) => ({
        input: child,
        existing: null,
        children: [],
      })),
    };
  });
  const allEntries = sections.flatMap((s) => [s, ...s.children]);
  const childEntries = sections.flatMap((s) => s.children);
  const idMode = allEntries.some((entry) => entry.input.id !== undefined);

  if (idMode) {
    const seen = new Set<string>();
    for (const entry of allEntries) {
      const id = entry.input.id;
      if (id === undefined) continue;
      if (seen.has(id)) {
        throw tierError(422, 'TIER_DUPLICATE_ID', `Ticket tier id ${id} appears more than once in the request`);
      }
      seen.add(id);
      const found = existingById.get(id);
      if (!found) {
        throw tierError(404, 'TIER_NOT_FOUND', `Ticket tier ${id} does not belong to this event`);
      }
      entry.existing = found;
    }
    // Only two levels exist: a tier that still owns children cannot become a child.
    for (const child of childEntries) {
      if (child.existing && existing.some((t) => t.parentId === child.existing?.id)) {
        throw tierError(422, 'TIER_INVALID_HIERARCHY', `Ticket tier ${child.existing.id} has children and cannot be nested under another tier`);
      }
    }
  } else {
    const roots = existing.filter((tier) => !tier.parentId);
    pairByKey({
      eventId,
      candidates: roots,
      entries: sections,
      keyOf: (t) => `${normalize(t.groupName)}\u0000${normalize(t.tierName)}`,
      entryKeyOf: (e) => `${normalize(e.input.groupName)}\u0000${normalize(e.input.tierName)}`,
      warnings,
    });
    for (const section of sections) {
      if (!section.existing) continue; // new parent: its children are new too
      const parentId = section.existing.id;
      pairByKey({
        eventId,
        candidates: existing.filter((t) => t.parentId === parentId),
        entries: section.children,
        keyOf: (t) => normalize(t.tierName),
        entryKeyOf: (e) => normalize(e.input.tierName),
        warnings,
      });
    }
  }

  for (const entry of allEntries) {
    if (entry.existing && entry.input.capacity < entry.existing.soldCount) {
      throw tierError(
        409,
        'TIER_CAPACITY_BELOW_SOLD',
        `Capacity ${entry.input.capacity} for ticket tier "${entry.existing.tierName}" is below the ${entry.existing.soldCount} tickets already sold`
      );
    }
  }

  assertTierSectionRules({
    eventId,
    sections: sections.map((section) => ({
      hasChildren: section.children.length > 0,
      existing: section.existing,
    })),
  });

  // ---- writes (all validation done) ----
  const fields = (input: TierFieldsInput) => ({
    tierName: input.tierName,
    groupName: input.groupName ?? null,
    description: input.description ?? null,
    price: input.price,
    capacity: input.capacity,
    sortOrder: input.sortOrder,
    startAt: input.startAt ?? null,
    endAt: input.endAt ?? null,
    isActive: input.isActive,
    ...(input.tierType ? { tierType: input.tierType } : {}),
  });

  const write = async (entry: Entry, parentId: string | null): Promise<string> => {
    if (entry.existing) {
      await tx.eventTicketTier.update({
        where: { id: entry.existing.id },
        data: { ...fields(entry.input), parentId },
      });
      return entry.existing.id;
    }
    const created = await tx.eventTicketTier.create({
      data: { ...fields(entry.input), eventId, parentId },
    });
    return created.id;
  };

  const keptIds = new Set<string>();
  for (const section of sections) {
    const sectionId = await write(section, null);
    keptIds.add(sectionId);
    for (const child of section.children) {
      keptIds.add(await write(child, sectionId));
    }
  }

  // Unmatched existing tiers: children first, then sections (deleting a
  // section cascades to its children, so it is only deleted when none remain).
  const unmatched = existing.filter((tier) => !keptIds.has(tier.id));
  const referenced = new Set(
    (
      await tx.eventPurchase.findMany({
        where: { ticketTierId: { in: unmatched.map((tier) => tier.id) } },
        select: { ticketTierId: true },
        distinct: ['ticketTierId'],
      })
    ).map((purchase) => purchase.ticketTierId)
  );
  const retire = async (tier: EventTicketTier, canDelete: boolean) => {
    if (tier.soldCount === 0 && canDelete && !referenced.has(tier.id)) {
      await tx.eventTicketTier.delete({ where: { id: tier.id } });
    } else if (tier.isActive) {
      await tx.eventTicketTier.update({
        where: { id: tier.id },
        data: { isActive: false },
      });
    }
  };
  for (const tier of unmatched.filter((t) => t.parentId)) {
    await retire(tier, true);
  }
  for (const tier of unmatched.filter((t) => !t.parentId)) {
    const remainingChildren = await tx.eventTicketTier.count({
      where: { parentId: tier.id },
    });
    await retire(tier, remainingChildren === 0);
  }

  return { warnings };
};

