import {
  TCreateEventPayload,
  TUpdateEventPayload,
  TEventListQuery,
} from '@/app/modules/event/event.schema';

import { Event } from '@prisma/client';

export interface ITrustedCancellationContext {
  isCancellation: boolean;
  cancellationTimestamp?: Date;
  existingEvent: Event;
}

export interface ICreateEventService {
  userId: string;
  payload: TCreateEventPayload;
}

export interface IUpdateEventService {
  eventId: string;
  userId: string;
  payload: TUpdateEventPayload;
  trustedCancellationContext?: ITrustedCancellationContext;
}

export interface IGetEventListService {
  userId: string;
  query: TEventListQuery;
}

export interface IGetEventDetailService {
  eventId: string;
  userId: string;
}
