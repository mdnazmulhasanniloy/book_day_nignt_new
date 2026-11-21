import {
  TGuestListEntriesQuery,
  TJoinGuestListPayload,
  TUpdateGuestListEntryPayload,
  TUpsertGuestListPayload,
} from '@/app/modules/guestList/guestList.schema';

export interface IUpsertGuestListService {
  ownerUserId: string;
  eventId: string;
  payload: TUpsertGuestListPayload;
}

export interface IGetGuestListService {
  ownerUserId: string;
  eventId: string;
}

export interface IJoinGuestListService {
  eventId: string;
  payload: TJoinGuestListPayload;
  userId?: string;
}

export interface IListGuestListEntriesService {
  ownerUserId: string;
  eventId: string;
  query: TGuestListEntriesQuery;
}

export interface IUpdateGuestListEntryService {
  ownerUserId: string;
  eventId: string;
  entryId: string;
  payload: TUpdateGuestListEntryPayload;
}
