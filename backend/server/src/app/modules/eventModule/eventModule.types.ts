import {
  TCreateEventModulePayload,
  TReorderEventModulesPayload,
  TUpdateEventModulePayload,
} from '@/app/modules/eventModule/eventModule.schema';

export interface IAssertOwnedEvent {
  eventId: string;
  ownerUserId: string;
}

export interface ICreateEventModuleService {
  ownerUserId: string;
  eventId: string;
  payload: TCreateEventModulePayload;
}

export interface IListEventModulesService {
  ownerUserId: string;
  eventId: string;
}

export interface IUpdateEventModuleService {
  ownerUserId: string;
  eventId: string;
  moduleId: string;
  payload: TUpdateEventModulePayload;
}

export interface IDeleteEventModuleService {
  ownerUserId: string;
  eventId: string;
  moduleId: string;
}

export interface IDuplicateEventModuleService {
  ownerUserId: string;
  eventId: string;
  moduleId: string;
}

export interface IReorderEventModulesService {
  ownerUserId: string;
  eventId: string;
  payload: TReorderEventModulesPayload;
}
