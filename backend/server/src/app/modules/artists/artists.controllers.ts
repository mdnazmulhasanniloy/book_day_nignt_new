import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  followArtistService,
  getMyArtistsService,
  unfollowArtistService,
} from '@/app/modules/artists/artists.services';
import {
  TArtistIdParams,
  TMyArtistsQuery,
} from '@/app/modules/artists/artists.schema';

export const followArtistController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as TArtistIdParams;

    const data = await followArtistService({
      userId: user.id,
      artistId: id,
    });

    res.status(200).json({
      success: true,
      message: 'Artist followed successfully',
      data,
      traceId,
    });
  }
);

export const unfollowArtistController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as TArtistIdParams;

    const data = await unfollowArtistService({
      userId: user.id,
      artistId: id,
    });

    res.status(200).json({
      success: true,
      message: 'Artist unfollowed successfully',
      data,
      traceId,
    });
  }
);

export const getMyArtistsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const query = req.validatedQuery as TMyArtistsQuery;

    const result = await getMyArtistsService({
      userId: user.id,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Followed artists retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);
