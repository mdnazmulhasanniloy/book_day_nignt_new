import { Request, Response } from 'express';
import { User } from '@prisma/client';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  createQuoteService,
  listQuotesService,
  updateQuoteService,
} from '@/app/modules/quotes/quotes.services';
import {
  TCreateQuotePayload,
  TListQuotesQuery,
  TQuoteIdParams,
  TUpdateQuotePayload,
} from '@/app/modules/quotes/quotes.schema';

export const createQuoteController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const payload = req.body as TCreateQuotePayload;

    const data = await createQuoteService({ payload });

    res.status(201).json({
      success: true,
      message: 'Quote submitted successfully',
      data,
      traceId,
    });
  }
);

export const listQuotesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const query = req.validatedQuery as TListQuotesQuery;

    const result = await listQuotesService({
      ownerUserId: user.id,
      query,
    });

    res.status(200).json({
      success: true,
      message: 'Quotes retrieved successfully',
      meta: result.meta,
      data: result.data,
      traceId,
    });
  }
);

export const updateQuoteController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const traceId = getTraceId();
    const user = req.user as User;
    const { id } = req.params as TQuoteIdParams;
    const payload = req.body as TUpdateQuotePayload;

    const data = await updateQuoteService({
      ownerUserId: user.id,
      quoteId: id,
      payload,
    });

    res.status(200).json({
      success: true,
      message: 'Quote updated successfully',
      data,
      traceId,
    });
  }
);
