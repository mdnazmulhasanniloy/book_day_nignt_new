import { Request, Response, NextFunction } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { User } from '@prisma/client';
import { resolveBuyerBookingByIdOrOrderId } from '@/app/modules/bookings/bookings.helpers';

/**
 * Middleware to check if a single booking exists and belongs to the authenticated user.
 * Accepts ClubBooking/EventPurchase/EventModulePurchase id OR Order id.
 */
export const checkBookingExistenceAndOwnershipMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const traceId = getTraceId();
    const id = req.params.id as string;
    const type = req.query.type as string;
    const userId = (req.user as User).id;

    if (type !== 'CLUB' && type !== 'EVENT') {
      res.status(400).json({
        success: false,
        message: 'Invalid type parameter',
        traceId,
      });
      return;
    }

    const resolved = await resolveBuyerBookingByIdOrOrderId({
      id,
      userId,
      preferredType: type,
    });

    if (!resolved) {
      res.status(404).json({
        success: false,
        message: 'Booking not found',
        traceId,
      });
      return;
    }

    if (type === 'CLUB' && resolved.kind !== 'CLUB') {
      res.status(404).json({
        success: false,
        message: 'Booking not found',
        traceId,
      });
      return;
    }

    if (
      type === 'EVENT' &&
      resolved.kind !== 'EVENT_TICKET' &&
      resolved.kind !== 'EVENT_MODULE'
    ) {
      res.status(404).json({
        success: false,
        message: 'Booking not found',
        traceId,
      });
      return;
    }

    // Canonical booking id for downstream controllers/services
    req.params.id = resolved.bookingId;
    (req as Request & { resolvedBooking?: typeof resolved }).resolvedBooking =
      resolved;
    next();
  }
);

/**
 * Middleware to check if a booking ticket exists and belongs to the authenticated user.
 * Accepts booking id OR order id (club / event ticket / VIP module).
 */
export const checkTicketBookingExistenceAndOwnershipMiddleware = asyncHandler(
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const traceId = getTraceId();
    const id = req.params.id as string;
    const userId = (req.user as User).id;

    const resolved = await resolveBuyerBookingByIdOrOrderId({
      id,
      userId,
    });

    if (!resolved) {
      res.status(404).json({
        success: false,
        message: 'Booking not found',
        traceId,
      });
      return;
    }

    req.params.id = resolved.bookingId;
    (req as Request & { resolvedBooking?: typeof resolved }).resolvedBooking =
      resolved;
    next();
  }
);
