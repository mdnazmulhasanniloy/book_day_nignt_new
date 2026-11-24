import type { PricingMode } from '@prisma/client';

/**
 * Event pricing mode rules (T-017, CR-03, data-model.md 8.3).
 * Only active tiers count. A section (a tier with child rows) counts through its
 * children; a top-level tier without children counts as itself.
 */

export type PricingTierInput = {
  price: number;
  isActive?: boolean;
  children?: Array<{ price: number; isActive?: boolean }>;
};

const pricingError = (message: string) => ({
  statusCode: 422,
  message,
  errorType: 'PRICING_MODE_INVALID',
});

/** Prices of the tiers a buyer can actually pick (active leaf tiers). */
const sellablePrices = (tiers: PricingTierInput[]): number[] => {
  const prices: number[] = [];
  for (const tier of tiers) {
    if (tier.children && tier.children.length > 0) {
      for (const child of tier.children) {
        if (child.isActive !== false) prices.push(Number(child.price));
      }
    } else if (tier.isActive !== false) {
      prices.push(Number(tier.price));
    }
  }
  return prices;
};

/** Same rule migration 4 used for existing events (MIXED is never derived). */
export const deriveEventPricingMode = ({
  eventPrice,
  tiers,
}: {
  eventPrice: number;
  tiers: PricingTierInput[];
}): PricingMode => {
  if (sellablePrices(tiers).length > 0) return 'TIERED';
  return Number(eventPrice) === 0 ? 'FREE' : 'SINGLE';
};

/** Throws a 422 PRICING_MODE_INVALID when `pricingMode` does not fit the price and tiers. */
export const assertPricingModeConsistent = ({
  pricingMode,
  eventPrice,
  tiers,
}: {
  pricingMode: PricingMode;
  eventPrice: number;
  tiers: PricingTierInput[];
}): void => {
  const prices = sellablePrices(tiers);
  const paid = prices.filter((p) => p > 0).length;
  const free = prices.length - paid;

  switch (pricingMode) {
    case 'TIERED':
      if (prices.length < 1) throw pricingError('pricingMode TIERED needs at least one ticket tier');
      return;
    case 'SINGLE':
      if (prices.length > 0) throw pricingError('pricingMode SINGLE cannot have ticket tiers');
      return;
    case 'FREE':
      if (Number(eventPrice) !== 0) throw pricingError('pricingMode FREE needs eventPrice 0');
      if (paid > 0) throw pricingError('pricingMode FREE cannot have a paid ticket tier');
      return;
    case 'MIXED':
      if (free < 1 || paid < 1) {
        throw pricingError('pricingMode MIXED needs at least one free and one paid ticket tier');
      }
      return;
  }
};

/**
 * Picks the pricingMode to store.
 * - sent: validated (422 on mismatch) and used;
 * - not sent, a stored value that still fits: kept (an old client must not reset it);
 * - otherwise derived with the migration 4 rule. Never a 422 for a client that sent no pricingMode.
 */
export const resolvePricingMode = ({
  requested,
  stored,
  eventPrice,
  tiers,
}: {
  requested: PricingMode | undefined;
  stored: PricingMode | null;
  eventPrice: number;
  tiers: PricingTierInput[];
}): PricingMode => {
  if (requested !== undefined) {
    assertPricingModeConsistent({ pricingMode: requested, eventPrice, tiers });
    return requested;
  }
  if (stored !== null) {
    try {
      assertPricingModeConsistent({ pricingMode: stored, eventPrice, tiers });
      return stored;
    } catch {
      // stored value no longer fits: fall through to derive
    }
  }
  return deriveEventPricingMode({ eventPrice, tiers });
};
