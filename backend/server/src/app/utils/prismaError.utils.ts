import { Prisma } from '@prisma/client';

export interface IMappedPrismaError {
  statusCode: number;
  message: string;
  errorType: string;
}

export interface IMapPrismaErrorOptions {
  /** Client message for P2025 (record not found). Never a raw Prisma message. */
  notFoundMessage?: string;
  /**
   * What a P2003 (foreign key violation) means for this operation.
   * 'conflict' (default): a child row still points at the record (e.g. delete) -> 409.
   * 'notFound': a referenced parent row does not exist (e.g. create/update with a bad id) -> 404.
   */
  foreignKey?: 'conflict' | 'notFound';
}

const isKnownRequestError = (
  error: unknown
): error is { code: string; name: string } =>
  error instanceof Prisma.PrismaClientKnownRequestError ||
  (typeof error === 'object' &&
    error !== null &&
    (error as { name?: unknown }).name === 'PrismaClientKnownRequestError' &&
    typeof (error as { code?: unknown }).code === 'string');

/**
 * Converts known Prisma errors into a client error the global error handler
 * renders (statusCode, message, errorType). Anything else is returned
 * unchanged. Messages are fixed strings: raw Prisma text and meta never reach
 * the client. Usage: `throw mapPrismaError(error, { notFoundMessage })`.
 */
export const mapPrismaError = <E>(
  error: E,
  options: IMapPrismaErrorOptions = {}
): E | IMappedPrismaError => {
  if (!isKnownRequestError(error)) return error;

  if (error.code === 'P2025') {
    return {
      statusCode: 404,
      message: options.notFoundMessage ?? 'Resource not found',
      errorType: 'NOT_FOUND',
    };
  }

  if (error.code === 'P2003') {
    if (options.foreignKey === 'notFound') {
      return {
        statusCode: 404,
        message: options.notFoundMessage ?? 'Referenced resource not found',
        errorType: 'NOT_FOUND',
      };
    }
    return {
      statusCode: 409,
      message: 'The request conflicts with related records',
      errorType: 'FOREIGN_KEY_CONFLICT',
    };
  }

  return error;
};
