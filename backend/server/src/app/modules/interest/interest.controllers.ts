import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { addInterestService, removeInterestService } from '@/app/modules/interest/interest.services';

export const addInterestController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as User;
    const { eventId } = req.params as { eventId: string };
    const data = await addInterestService({ userId: user.id, eventId });
    res.status(200).json({ success: true, message: 'Marked as interested', data, traceId: getTraceId() });
  }
);

export const removeInterestController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const user = req.user as User;
    const { eventId } = req.params as { eventId: string };
    const data = await removeInterestService({ userId: user.id, eventId });
    res.status(200).json({ success: true, message: 'Interest removed', data, traceId: getTraceId() });
  }
);
