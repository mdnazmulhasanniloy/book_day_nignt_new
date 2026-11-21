export interface IFollowClubParams {
  userId: string;
  clubId: string;
}

export interface IUnfollowClubParams {
  userId: string;
  clubId: string;
}

export interface IIsFollowingParams {
  userId: string;
  clubId: string;
}

export interface IGetUserFollowingParams {
  userId: string;
  page: number;
  limit: number;
}
