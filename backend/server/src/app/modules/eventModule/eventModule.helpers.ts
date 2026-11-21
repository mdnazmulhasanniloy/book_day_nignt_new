import { EventModule, EventModuleStatus, Prisma } from '@prisma/client';

const money = (value: Prisma.Decimal | number | string) =>
  new Prisma.Decimal(value).toFixed(2);

export const resolveModuleStatus = (
  module: Pick<EventModule, 'status' | 'remaining' | 'quantity'>
): EventModuleStatus => {
  if (module.status === 'UNAVAILABLE') return 'UNAVAILABLE';
  if (module.remaining <= 0 || module.status === 'SOLD_OUT') return 'SOLD_OUT';
  if (module.status === 'LIMITED') return 'LIMITED';
  if (module.remaining < module.quantity) return 'LIMITED';
  return 'AVAILABLE';
};

export const mapEventModule = (module: EventModule) => ({
  id: module.id,
  eventId: module.eventId,
  name: module.name,
  image: module.image,
  description: module.description,
  maxGuests: module.maxGuests,
  startingPrice: money(module.startingPrice),
  minSpend: money(module.minSpend),
  deposit: money(module.deposit),
  currency: module.currency,
  quantity: module.quantity,
  remaining: module.remaining,
  venueArea: module.venueArea,
  includedExtras: module.includedExtras,
  optionalExtras: module.optionalExtras,
  status: resolveModuleStatus(module),
  sortOrder: module.sortOrder,
  isActive: module.isActive,
});
