import { randomUUID } from 'node:crypto';
import type { Prisma } from '@prisma/client';

// Minimal fixtures: only required columns, unique values per call.
// Extend when a task needs more; do not grow this into a general factory.
type Tx = Prisma.TransactionClient;

export const createUser = (tx: Tx, data: Partial<Prisma.UserUncheckedCreateInput> = {}) =>
  tx.user.create({
    data: {
      name: 'Test User',
      email: `user-${randomUUID()}@example.test`,
      phoneNumber: `+1555${Math.floor(Math.random() * 1e7)}`,
      ...data,
    },
  });

export const createClub = (
  tx: Tx,
  userId: string,
  data: Partial<Prisma.ClubUncheckedCreateInput> = {}
) =>
  tx.club.create({
    data: {
      userId,
      name: 'Test Club',
      thumbnail: 'https://example.test/t.png',
      dressCode: 'casual',
      lat: 23.78,
      lng: 90.4,
      ...data,
    },
  });

export const createEvent = (
  tx: Tx,
  userId: string,
  data: Partial<Prisma.EventUncheckedCreateInput> = {}
) =>
  tx.event.create({
    data: {
      userId,
      eventName: 'Test Event',
      thumbnail: 'https://example.test/t.png',
      lat: 23.78,
      lng: 90.4,
      startAt: new Date(Date.now() + 86_400_000),
      endAt: new Date(Date.now() + 2 * 86_400_000),
      dressCode: 'casual',
      eventPrice: 10,
      currency: 'USD',
      ...data,
    },
  });

export const createTier = (
  tx: Tx,
  eventId: string,
  data: Partial<Prisma.EventTicketTierUncheckedCreateInput> = {}
) =>
  tx.eventTicketTier.create({
    data: { eventId, tierName: 'General', price: 10, capacity: 100, ...data },
  });

export const createOrder = (
  tx: Tx,
  buyerUserId: string,
  sellerUserId: string,
  data: Partial<Prisma.OrderUncheckedCreateInput> = {}
) =>
  tx.order.create({
    data: {
      buyerUserId,
      sellerUserId,
      serviceType: 'EVENT',
      buyerName: 'Buyer',
      buyerPhoneNumber: '+15550000000',
      grossAmount: 10,
      serviceChargeAmount: 1,
      buyerTotal: 11,
      commissionRate: 10,
      commissionAmount: 1,
      sellerEarnings: 9,
      currency: 'USD',
      idempotencyKey: randomUUID(),
      ...data,
    },
  });
