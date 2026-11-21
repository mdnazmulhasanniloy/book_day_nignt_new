import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  attachHostToClubService,
  attachHostToEventService,
  contactHostService,
  createHostService,
  deleteHostService,
  listEventHostInquiriesService,
  listEventHostsService,
  listHostsService,
  unassignHostFromEventService,
  updateHostService,
} from '@/app/modules/hosts/hosts.services';
import {
  TAttachHostPayload,
  TClubHostParams,
  TCreateHostPayload,
  TEventHostParams,
  TEventHostUnassignParams,
  THostContactPayload,
  THostIdParams,
  TUpdateHostPayload,
} from '@/app/modules/hosts/hosts.schema';

export const createHostController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const payload = req.body as TCreateHostPayload;

    const data = await createHostService({
      ownerUserId: user.id,
      payload,
    });

    res.status(201).json({
      success: true,
      message: 'Host created successfully',
      data,
      traceId,
    });
  }
);

export const listHostsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;

    const data = await listHostsService({ ownerUserId: user.id });

    res.status(200).json({
      success: true,
      message: 'Hosts retrieved successfully',
      data,
      traceId,
    });
  }
);

export const updateHostController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as THostIdParams;
    const payload = req.body as TUpdateHostPayload;

    const data = await updateHostService({
      ownerUserId: user.id,
      hostId: id,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Host updated successfully',
      data,
      traceId,
    });
  }
);

export const deleteHostController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as THostIdParams;

    const result = await deleteHostService({
      ownerUserId: user.id,
      hostId: id,
    });

    res.status(200).json({
      success: true,
      message: result.message,
      data: null,
      traceId,
    });
  }
);

export const attachHostToEventController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventHostParams;
    const payload = req.body as TAttachHostPayload;

    const data = await attachHostToEventService({
      ownerUserId: user.id,
      eventId,
      payload,
    });

    res.status(201).json({
      success: true,
      message: 'Host attached to event successfully',
      data,
      traceId,
    });
  }
);

export const listEventHostsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventHostParams;

    const data = await listEventHostsService({
      ownerUserId: user.id,
      eventId,
    });

    res.status(200).json({
      success: true,
      message: 'Event hosts retrieved successfully',
      data,
      traceId,
    });
  }
);

export const unassignHostFromEventController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId, hostId } = req.params as TEventHostUnassignParams;

    const result = await unassignHostFromEventService({
      ownerUserId: user.id,
      eventId,
      hostId,
    });

    res.status(200).json({
      success: true,
      message: result.message,
      data: null,
      traceId,
    });
  }
);

export const attachHostToClubController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { clubId } = req.params as TClubHostParams;
    const payload = req.body as TAttachHostPayload;

    const data = await attachHostToClubService({
      ownerUserId: user.id,
      clubId,
      payload,
    });

    res.status(201).json({
      success: true,
      message: 'Host attached to club successfully',
      data,
      traceId,
    });
  }
);

export const contactHostController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const { id } = req.params as THostIdParams;
    const payload = req.body as THostContactPayload;

    const data = await contactHostService({
      hostId: id,
      payload,
      traceId,
    });

    res.status(201).json({
      success: true,
      message: 'Host contact submitted successfully',
      data,
      traceId,
    });
  }
);

export const listEventHostInquiriesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventHostParams;

    const data = await listEventHostInquiriesService({
      ownerUserId: user.id,
      eventId,
    });

    res.status(200).json({
      success: true,
      message: 'Host inquiries retrieved successfully',
      data,
      traceId,
    });
  }
);
