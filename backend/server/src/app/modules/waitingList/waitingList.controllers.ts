import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { User } from '@prisma/client';
import {
  joinWaitingListService,
  leaveWaitingListService,
  getMyWaitingListService,
  getClubWaitingListStatusService,
  getClubWaitingListMembersService,
  notifyWaitingListEntryService,
  deleteWaitingListEntryService,
} from '@/app/modules/waitingList/waitingList.services';
import {
  TJoinWaitingListPayload,
  TLeaveWaitingListPayload,
  TMyWaitingListQuery,
  TClubWaitingListStatusParams,
  TClubWaitingListMembersParams,
  TClubWaitingListMembersQuery,
  TWaitingListEntryParams,
} from '@/app/modules/waitingList/waitingList.schema';

export const joinWaitingListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const payload = req.body as TJoinWaitingListPayload;

    const result = await joinWaitingListService({
      userId: user.id,
      payload,
    });

    res.status(201).json({
      success: true,
      message: 'Successfully joined waiting list',
      data: result,
      traceId,
    });
  }
);

export const leaveWaitingListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const payload = req.body as TLeaveWaitingListPayload;

    const result = await leaveWaitingListService({
      userId: user.id,
      payload,
    });

    res.status(200).json({
      success: true,
      message: result.message,
      data: null,
      traceId,
    });
  }
);

export const getMyWaitingListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const query = req.validatedQuery as TMyWaitingListQuery;

    const result = await getMyWaitingListService({
      userId: user.id,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Waiting list retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);

export const getClubWaitingListStatusController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TClubWaitingListStatusParams;

    const result = await getClubWaitingListStatusService({
      userId: user.id,
      clubId,
    });

    res.status(200).json({
      success: true,
      message: 'Club waiting list status retrieved successfully',
      data: result,
      traceId,
    });
  }
);

export const getClubWaitingListMembersController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TClubWaitingListMembersParams;
    const query = req.validatedQuery as TClubWaitingListMembersQuery;

    const result = await getClubWaitingListMembersService({
      ownerUserId: user.id,
      clubId,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Waiting list retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);

export const notifyWaitingListEntryController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as TWaitingListEntryParams;

    const result = await notifyWaitingListEntryService({
      ownerUserId: user.id,
      entryId: id,
    });

    res.status(200).json({
      success: true,
      message: 'Waiting list entry notified successfully',
      data: result,
      traceId,
    });
  }
);

export const deleteWaitingListEntryController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as TWaitingListEntryParams;

    const result = await deleteWaitingListEntryService({
      ownerUserId: user.id,
      entryId: id,
    });

    res.status(200).json({
      success: true,
      message: result.message,
      data: null,
      traceId,
    });
  }
);
