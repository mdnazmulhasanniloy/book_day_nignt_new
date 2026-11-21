import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { User } from '@prisma/client';
import {
  followClubService,
  unfollowClubService,
  isFollowingClubService,
  getUserFollowingService,
} from '@/app/modules/follow/follow.services';
import { TFollowClubParams, TGetFollowingQuery } from '@/app/modules/follow/follow.schema';

export const followClubController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TFollowClubParams;

    const result = await followClubService({
      userId: user.id,
      clubId,
    });

    res.status(200).json({
      success: true,
      message: 'Followed club successfully',
      data: result,
      traceId,
    });
  }
);

export const unfollowClubController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TFollowClubParams;

    const result = await unfollowClubService({
      userId: user.id,
      clubId,
    });

    res.status(200).json({
      success: true,
      message: 'Unfollowed club successfully',
      data: result,
      traceId,
    });
  }
);

export const isFollowingClubController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TFollowClubParams;

    const result = await isFollowingClubService({
      userId: user.id,
      clubId,
    });

    res.status(200).json({
      success: true,
      data: result,
      traceId,
    });
  }
);

export const getUserFollowingController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { page, limit } = req.query as unknown as TGetFollowingQuery;

    const result = await getUserFollowingService({
      userId: user.id,
      page: Number(page) || 1,
      limit: Number(limit) || 10,
    });

    res.status(200).json({
      success: true,
      data: result.data,
      meta: result.meta,
      traceId,
    });
  }
);
