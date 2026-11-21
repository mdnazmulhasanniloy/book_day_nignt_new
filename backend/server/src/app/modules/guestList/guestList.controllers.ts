import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  getGuestListService,
  joinGuestListService,
  listGuestListEntriesService,
  updateGuestListEntryService,
  upsertGuestListService,
} from '@/app/modules/guestList/guestList.services';
import {
  TGuestListEntriesQuery,
  TGuestListEntryParams,
  TGuestListEventParams,
  TJoinGuestListPayload,
  TUpdateGuestListEntryPayload,
  TUpsertGuestListPayload,
} from '@/app/modules/guestList/guestList.schema';

export const getGuestListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TGuestListEventParams;

    const data = await getGuestListService({
      ownerUserId: user.id,
      eventId,
    });

    res.status(200).json({
      success: true,
      message: 'Guest list retrieved successfully',
      data,
      traceId,
    });
  }
);

export const upsertGuestListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TGuestListEventParams;
    const payload = req.body as TUpsertGuestListPayload;

    const data = await upsertGuestListService({
      ownerUserId: user.id,
      eventId,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Guest list updated successfully',
      data,
      traceId,
    });
  }
);

export const joinGuestListController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User | undefined;
    const { eventId } = req.params as TGuestListEventParams;
    const payload = req.body as TJoinGuestListPayload;

    const data = await joinGuestListService({
      eventId,
      payload,
      userId: user?.id,
    });

    res.status(201).json({
      success: true,
      message: 'Joined guest list successfully',
      data,
      traceId,
    });
  }
);

export const listGuestListEntriesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TGuestListEventParams;
    const query = req.validatedQuery as TGuestListEntriesQuery;

    const result = await listGuestListEntriesService({
      ownerUserId: user.id,
      eventId,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Guest list entries retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);

export const updateGuestListEntryController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId, id } = req.params as TGuestListEntryParams;
    const payload = req.body as TUpdateGuestListEntryPayload;

    const data = await updateGuestListEntryService({
      ownerUserId: user.id,
      eventId,
      entryId: id,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Guest list entry updated successfully',
      data,
      traceId,
    });
  }
);
