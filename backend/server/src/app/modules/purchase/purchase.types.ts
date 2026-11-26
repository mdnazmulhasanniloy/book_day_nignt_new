import {
  TClubAvailabilityQuery,
  TCreateClubPurchasePayload,
  TCreateEventPurchasePayload,
  TCreateModulePurchasePayload,
} from '@/app/modules/purchase/purchase.schema';
import {
  ClubBooking,
  EventModulePurchase,
  EventPurchase,
  EventPurchaseAttendee,
  Order,
} from '@prisma/client';
export interface IClubAvailabilityService {
  query: TClubAvailabilityQuery;
}
export interface ICreateClubPurchaseService {
  userId: string;
  payload: TCreateClubPurchasePayload;
  idempotencyKey: string;
}
export interface ICreateEventPurchaseService {
  userId: string;
  payload: TCreateEventPurchasePayload;
  idempotencyKey: string;
  buyerAge: number;
}
export interface ICreateModulePurchaseService {
  userId: string;
  payload: TCreateModulePurchasePayload;
  idempotencyKey: string;
}
export interface IClubPurchaseResult {
  order: Order;
  booking: ClubBooking;
  replayed: boolean;
}
export interface IEventPurchaseResult {
  order: Order;
  eventPurchase: EventPurchase;
  attendees: EventPurchaseAttendee[];
  replayed: boolean;
}
export interface IModulePurchaseResult {
  order: Order;
  booking: EventModulePurchase;
  replayed: boolean;
}
