import { Request, Response, NextFunction } from 'express';
import { User } from '@prisma/client';
import prisma from '@/app/configs/db.configs';
import { asyncHandler } from '@/app/utils/system.utils';

export const checkEventCancellationValidityMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const eventId = req.params.id as string;
    const userId = (req.user as User).id;
    const { eventStatus, isActive } = req.body;

    // Fetch current state
    const existingEvent = await prisma.event.findUnique({
      where: { id: eventId },
    });

    // Missing and not-owned are the same 404 (no ownership leak, T-012). The
    // live Flutter app treats 403 like 401, so a business failure must not be 403.
    if (!existingEvent || existingEvent.userId !== userId) {
      throw {
        statusCode: 404,
        message: 'Event not found',
        errorType: 'NOT_FOUND',
      };
    }

    // 1. CANCELED events: only allow restore → UPCOMING + isActive:true
    if (existingEvent.eventStatus === 'CANCELED') {
      const isRestore = eventStatus === 'UPCOMING' && isActive === true;
      if (!isRestore) {
        res.status(400).json({
          success: false,
          message:
            'Event is already canceled. To turn it back on, send eventStatus=UPCOMING and isActive=true',
        });
        return;
      }

      req.trustedCancellationContext = {
        isCancellation: false,
        existingEvent,
      };
      next();
      return;
    }

    // 2. Hide without cancel: isActive:false keeps current status (e.g. UPCOMING).
    // Formal cancel still requires eventStatus: CANCELED (refunds + push).

    // 3. Process formal cancellation rules
    if (eventStatus === 'CANCELED') {
      const T_MINUS_6H = new Date(
        existingEvent.startAt.getTime() - 6 * 60 * 60 * 1000
      );

      if (new Date() >= T_MINUS_6H) {
        res.status(400).json({
          success: false,
          message: 'Cannot cancel event within 6 hours of its start time',
        });
        return;
      }

      // Establish trusted context for the service
      req.trustedCancellationContext = {
        isCancellation: true,
        cancellationTimestamp: new Date(),
        existingEvent,
      };
    } else {
      req.trustedCancellationContext = {
        isCancellation: false,
        existingEvent,
      };
    }

    next();
  }
);
