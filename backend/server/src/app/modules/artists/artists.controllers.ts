import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { JwtPayload } from 'jsonwebtoken';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  adminListArtistsService,
  adminUpdateArtistService,
  followArtistService,
  getArtistProfileService,
  getMyArtistsService,
  listArtistsService,
  ownerUpdateArtistService,
  unfollowArtistService,
} from '@/app/modules/artists/artists.services';
import {
  TAdminListArtistsQuery,
  TAdminUpdateArtistBody,
  TArtistIdParams,
  TListArtistsQuery,
  TMyArtistsQuery,
  TOwnerUpdateArtistBody,
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

// T-044 (CR-12). KNOWN TRAP: after optionalUserAccessTokenMiddleware req.user is the JWT payload
// (id in `sub`); after checkUserExistenceMiddleware it is the database User row (id in `id`).
export const listArtistsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = req.validatedQuery as TListArtistsQuery;
    const userId = (req.user as JwtPayload | undefined)?.sub;
    const { data, meta } = await listArtistsService({ query, userId });
    res.status(200).json({
      success: true,
      message: 'Artists retrieved successfully',
      data,
      meta,
      traceId: getTraceId(),
    });
  }
);

export const getArtistProfileController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as TArtistIdParams;
    const userId = (req.user as JwtPayload | undefined)?.sub;
    const data = await getArtistProfileService({ artistId: id, userId });
    res.status(200).json({
      success: true,
      message: 'Artist retrieved successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const ownerUpdateArtistController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as User;
    const { id } = req.params as TArtistIdParams;
    const data = await ownerUpdateArtistService({
      userId: user.id,
      artistId: id,
      body: req.body as TOwnerUpdateArtistBody,
    });
    res.status(200).json({
      success: true,
      message: 'Artist updated successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const adminListArtistsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = req.validatedQuery as TAdminListArtistsQuery;
    const { data, meta } = await adminListArtistsService({ query });
    res.status(200).json({
      success: true,
      message: 'Artists retrieved successfully',
      data,
      meta,
      traceId: getTraceId(),
    });
  }
);

export const adminUpdateArtistController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as TArtistIdParams;
    const data = await adminUpdateArtistService({
      artistId: id,
      body: req.body as TAdminUpdateArtistBody,
    });
    res.status(200).json({
      success: true,
      message: 'Artist updated successfully',
      data,
      traceId: getTraceId(),
    });
  }
);
