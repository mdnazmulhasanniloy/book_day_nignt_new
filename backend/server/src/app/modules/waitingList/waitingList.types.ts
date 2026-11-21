import {
  TJoinWaitingListPayload,
  TLeaveWaitingListPayload,
  TMyWaitingListQuery,
  TClubWaitingListMembersQuery,
} from '@/app/modules/waitingList/waitingList.schema';

export interface IJoinWaitingListService {
  userId: string;
  payload: TJoinWaitingListPayload;
}

export interface ILeaveWaitingListService {
  userId: string;
  payload: TLeaveWaitingListPayload;
}

export interface IGetMyWaitingListService {
  userId: string;
  query: TMyWaitingListQuery;
}

export interface IGetClubWaitingListStatusService {
  userId: string;
  clubId: string;
}

export interface IGetClubWaitingListMembersService {
  ownerUserId: string;
  clubId: string;
  query: TClubWaitingListMembersQuery;
}

export interface INotifyWaitingListEntryService {
  ownerUserId: string;
  entryId: string;
}

export interface IDeleteWaitingListEntryService {
  ownerUserId: string;
  entryId: string;
}
