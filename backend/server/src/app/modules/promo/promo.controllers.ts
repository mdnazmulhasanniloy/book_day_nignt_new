import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import { User } from '@prisma/client';
import {
  validatePromoCodeService,
  createPromoCodeService,
  listPromoCodesService,
  updatePromoCodeService,
  deletePromoCodeService,
} from '@/app/modules/promo/promo.services';
import {
  TValidatePromoCodePayload,
  TCreatePromoCodePayload,
  TListPromoQuery,
  TUpdatePromoCodePayload,
} from '@/app/modules/promo/promo.schema';

interface IHttpError {
  statusCode: number;
  message: string;
}

const isHttpError = (err: unknown): err is IHttpError => {
  return (
    typeof err === 'object' &&
    err !== null &&
    'statusCode' in err &&
    typeof (err as { statusCode: unknown }).statusCode === 'number' &&
    'message' in err &&
    typeof (err as { message: unknown }).message === 'string'
  );
};

export const validatePromoCodeController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const payload = req.body as TValidatePromoCodePayload;

    try {
      const result = await validatePromoCodeService({
        code: payload.code,
        originalAmount: payload.originalAmount,
        eventId: payload.eventId,
        clubId: payload.clubId,
      });

      res.status(200).json({
        success: true,
        message: 'Promo code is valid',
        data: result,
        traceId,
      });
    } catch (err: unknown) {
      if (isHttpError(err)) {
        res.status(err.statusCode).json({
          success: false,
          message: err.message,
          traceId,
        });
        return;
      }
      throw err;
    }
  }
);

export const listPromoCodesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const query = req.validatedQuery as TListPromoQuery;

    const result = await listPromoCodesService({
      userId: user.id,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Promo codes retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);

export const createPromoCodeController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const payload = req.body as TCreatePromoCodePayload;

    const user = req.user as User;

    try {
      const result = await createPromoCodeService({
        userId: user.id,
        code: payload.code,
        discountType: payload.discountType,
        discountValue: payload.discountValue,
        eventId: payload.eventId,
        clubId: payload.clubId,
        maxUses: payload.maxUses,
        expiresAt: payload.expiresAt,
      });

      res.status(201).json({
        success: true,
        message: 'Promo code created successfully',
        data: result,
        traceId,
      });
    } catch (err: unknown) {
      if (isHttpError(err)) {
        res.status(err.statusCode).json({
          success: false,
          message: err.message,
          traceId,
        });
        return;
      }
      throw err;
    }
  }
);

export const updatePromoCodeController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const id = req.params.id as string;
    const payload = req.body as TUpdatePromoCodePayload;

    try {
      const result = await updatePromoCodeService({
        id,
        userId: user.id,
        payload,
      });

      res.status(200).json({
        success: true,
        message: 'Promo code updated successfully',
        data: result,
        traceId,
      });
    } catch (err: unknown) {
      if (isHttpError(err)) {
        res.status(err.statusCode).json({
          success: false,
          message: err.message,
          traceId,
        });
        return;
      }
      throw err;
    }
  }
);

export const deletePromoCodeController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const id = req.params.id as string;

    try {
      await deletePromoCodeService({
        id,
        userId: user.id,
      });

      res.status(200).json({
        success: true,
        message: 'Promo code deleted successfully',
        data: null,
        traceId,
      });
    } catch (err: unknown) {
      if (isHttpError(err)) {
        res.status(err.statusCode).json({
          success: false,
          message: err.message,
          traceId,
        });
        return;
      }
      throw err;
    }
  }
);
