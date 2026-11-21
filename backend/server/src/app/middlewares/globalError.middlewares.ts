import { NextFunction, Request, Response } from 'express';

import logger from '@/app/configs/logger.configs';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { ExtendedError } from '@/app/@types/error.types';

const isClientHttpError = (
  value: unknown
): value is { statusCode: number; message: string; errorType?: string } => {
  if (typeof value !== 'object' || value === null) return false;

  const statusCode = (value as { statusCode?: unknown }).statusCode;
  const message = (value as { message?: unknown }).message;

  return (
    typeof statusCode === 'number' &&
    Number.isInteger(statusCode) &&
    statusCode >= 400 &&
    (statusCode <= 499 || statusCode === 502 || statusCode === 503) &&
    typeof message === 'string' &&
    message.trim().length > 0
  );
};

export const globalErrorMiddleware = (
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
) => {
  const traceId = getTraceId();

  if (isClientHttpError(err)) {
    logger.error({
      traceId,
      message: err.message,
    });

    res.status(err.statusCode).json({
      success: false,
      message: err.message,
      ...(err.errorType ? { errorType: err.errorType } : {}),
      traceId,
    });
    return;
  }

  if (err instanceof Error) {
    const e = err as ExtendedError;
    const causeObj = e.cause;
    const causeStr = causeObj ? ` | Cause: [${causeObj.name}] ${causeObj.message} (Code: ${causeObj.code})` : '';
    const metaStr = e.$metadata ? ` | $metadata: ${JSON.stringify(e.$metadata)}` : '';

    logger.error({
      traceId: traceId,
      message: `${err.name}: ${err.message}${causeStr}${metaStr}`,
      stack: err.stack,
    });

    if (err instanceof SyntaxError && 'status' in err && err.status === 400 && 'body' in err) {
      res.status(400).json({
        success: false,
        message: 'Invalid JSON Payload',
        traceId: traceId,
      });
      return;
    }

    res.status(500).json({
      success: false,
      message: 'Internal Server Error',
      traceId: traceId,
    });
    return;
  }

  logger.error({
    traceId,
    message: 'Unexpected Error Occurred In Somewhere',
  });

  res.status(500).json({
    success: false,
    message: 'Internal Server Error',
    traceId,
  });

  return;
};
