import type { TierType } from '@prisma/client';

/**
 * Static preset tier names (T-016, CR-03). Names come from the client tracker
 * items A2.5 to A2.7 ("new update.md"). The list is a suggestion: custom tier
 * names stay allowed everywhere.
 */
export const TICKET_TIER_PRESET_NAMES = [
  'Super Early',
  'Early',
  'Advance',
  'Regular',
  'Late',
  'Super Late',
] as const;

export const PASS_TIER_PRESET_NAMES = [
  'Blind Pass',
  'Early Pass',
  'Standard Pass',
  'Late Pass',
] as const;

export const SECTION_HELP_TEXT =
  'A section groups products for a day or access type, for example Friday, Saturday or 2-Day Pass.';
export const TIER_HELP_TEXT =
  'A tier is a priced quantity within a section, for example Early or Regular. Pick a preset or type a custom name.';

export type TicketTierPreset = {
  name: string;
  tierType: TierType;
  sortOrder: number;
};

const toPresets = (names: readonly string[], tierType: TierType): TicketTierPreset[] =>
  names.map((name, sortOrder) => ({ name, tierType, sortOrder }));

export const getTicketTierPresets = () => ({
  ticketPresets: [...TICKET_TIER_PRESET_NAMES],
  passPresets: [...PASS_TIER_PRESET_NAMES],
  presets: [
    ...toPresets(TICKET_TIER_PRESET_NAMES, 'TICKET'),
    ...toPresets(PASS_TIER_PRESET_NAMES, 'PASS'),
  ],
  sectionHelp: SECTION_HELP_TEXT,
  tierHelp: TIER_HELP_TEXT,
});
