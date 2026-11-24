import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Prisma } from '@prisma/client';
import { mapPrismaError } from '@/app/utils/prismaError.utils';

const known = (code: string, message = 'raw prisma internals: Club.userId') =>
  new Prisma.PrismaClientKnownRequestError(message, {
    code,
    clientVersion: 'test',
    meta: { field_name: 'secret_fk' },
  });

describe('mapPrismaError (T-012, B-26)', () => {
  it('P2025 -> 404 NOT_FOUND with a fixed message', () => {
    const out = mapPrismaError(known('P2025'));
    assert.deepEqual(out, {
      statusCode: 404,
      message: 'Resource not found',
      errorType: 'NOT_FOUND',
    });
  });

  it('P2025 uses the caller message', () => {
    const out = mapPrismaError(known('P2025'), { notFoundMessage: 'Club not found' });
    assert.equal((out as { message: string }).message, 'Club not found');
  });

  it('P2003 -> 409 FOREIGN_KEY_CONFLICT by default', () => {
    const out = mapPrismaError(known('P2003'));
    assert.deepEqual(out, {
      statusCode: 409,
      message: 'The request conflicts with related records',
      errorType: 'FOREIGN_KEY_CONFLICT',
    });
  });

  it('P2003 -> 404 when the caller says the missing parent is the cause', () => {
    const out = mapPrismaError(known('P2003'), {
      foreignKey: 'notFound',
      notFoundMessage: 'Club not found',
    });
    assert.deepEqual(out, {
      statusCode: 404,
      message: 'Club not found',
      errorType: 'NOT_FOUND',
    });
  });

  it('never leaks raw Prisma message or meta', () => {
    for (const code of ['P2025', 'P2003']) {
      const text = JSON.stringify(mapPrismaError(known(code)));
      assert.doesNotMatch(text, /raw prisma|secret_fk|Club\.userId/);
    }
  });

  it('other Prisma codes and unknown errors pass through unchanged', () => {
    const p2002 = known('P2002');
    assert.equal(mapPrismaError(p2002), p2002);
    const plain = new Error('boom');
    assert.equal(mapPrismaError(plain), plain);
    const obj = { statusCode: 422, message: 'x' };
    assert.equal(mapPrismaError(obj), obj);
    assert.equal(mapPrismaError(undefined), undefined);
  });
});
