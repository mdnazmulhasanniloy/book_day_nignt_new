import {
  TAttachHostPayload,
  TCreateHostPayload,
  THostContactPayload,
  TUpdateHostPayload,
} from '@/app/modules/hosts/hosts.schema';

export interface ICreateHostService {
  ownerUserId: string;
  payload: TCreateHostPayload;
}

export interface IListHostsService {
  ownerUserId: string;
}

export interface IUpdateHostService {
  ownerUserId: string;
  hostId: string;
  payload: TUpdateHostPayload;
}

export interface IDeleteHostService {
  ownerUserId: string;
  hostId: string;
}

export interface IAttachHostToEventService {
  ownerUserId: string;
  eventId: string;
  payload: TAttachHostPayload;
}

export interface IListEventHostsService {
  ownerUserId: string;
  eventId: string;
}

export interface IUnassignHostFromEventService {
  ownerUserId: string;
  eventId: string;
  hostId: string;
}

export interface IAttachHostToClubService {
  ownerUserId: string;
  clubId: string;
  payload: TAttachHostPayload;
}

export interface IContactHostService {
  hostId: string;
  payload: THostContactPayload;
  traceId?: string;
}

export interface IListEventHostInquiriesService {
  ownerUserId: string;
  eventId: string;
}
