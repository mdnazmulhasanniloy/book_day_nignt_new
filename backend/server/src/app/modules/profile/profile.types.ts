import {
  TUpdateProfilePayload,
  TChangePasswordPayload,
} from '@/app/modules/profile/profile.schema';

export interface IGetUserProfileService {
  userId: string;
}

export interface IUpdateUserProfileService {
  userId: string;
  payload: TUpdateProfilePayload;
}

export interface IChangePasswordService {
  userId: string;
  payload: TChangePasswordPayload;
}

export interface IDeleteAccountService {
  userId: string;
  accessToken: string | null;
  tokenExp?: number;
}

export interface IGetDeletionPreviewService {
  userId: string;
}
