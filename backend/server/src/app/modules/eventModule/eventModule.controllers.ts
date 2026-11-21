import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  createEventModuleService,
  deleteEventModuleService,
  duplicateEventModuleService,
  listEventModulesService,
  reorderEventModulesService,
  updateEventModuleService,
} from '@/app/modules/eventModule/eventModule.services';
import {
  TCreateEventModulePayload,
  TEventModuleIdParams,
  TEventModuleParams,
  TReorderEventModulesPayload,
  TUpdateEventModulePayload,
} from '@/app/modules/eventModule/eventModule.schema';

export const createEventModuleController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventModuleParams;
    const payload = req.body as TCreateEventModulePayload;

    const data = await createEventModuleService({
      ownerUserId: user.id,
      eventId,
      payload,
    });

    res.status(201).json({
      success: true,
      message: 'Module created successfully',
      data,
      traceId,
    });
  }
);

export const listEventModulesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventModuleParams;

    const data = await listEventModulesService({
      ownerUserId: user.id,
      eventId,
    });

    res.status(200).json({
      success: true,
      message: 'Modules retrieved successfully',
      data,
      traceId,
    });
  }
);

export const updateEventModuleController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId, id } = req.params as TEventModuleIdParams;
    const payload = req.body as TUpdateEventModulePayload;

    const data = await updateEventModuleService({
      ownerUserId: user.id,
      eventId,
      moduleId: id,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Module updated successfully',
      data,
      traceId,
    });
  }
);

export const deleteEventModuleController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId, id } = req.params as TEventModuleIdParams;

    const result = await deleteEventModuleService({
      ownerUserId: user.id,
      eventId,
      moduleId: id,
    });

    res.status(200).json({
      success: true,
      message: result.message,
      data: null,
      traceId,
    });
  }
);

export const duplicateEventModuleController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId, id } = req.params as TEventModuleIdParams;

    const data = await duplicateEventModuleService({
      ownerUserId: user.id,
      eventId,
      moduleId: id,
    });

    res.status(201).json({
      success: true,
      message: 'Module duplicated successfully',
      data,
      traceId,
    });
  }
);

export const reorderEventModulesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { eventId } = req.params as TEventModuleParams;
    const payload = req.body as TReorderEventModulesPayload;

    const data = await reorderEventModulesService({
      ownerUserId: user.id,
      eventId,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Modules reordered successfully',
      data,
      traceId,
    });
  }
);
