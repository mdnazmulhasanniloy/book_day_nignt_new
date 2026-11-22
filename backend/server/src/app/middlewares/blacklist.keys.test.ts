import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { REDIS_PREFIXES } from '@/const';
import { createRedisKey } from '@/app/utils/system.utils';

const read = (p: string) => readFileSync(join(__dirname, p), 'utf8');

describe('blacklist key (BUG-S04)', () => {
  it('writer and readers share one key helper', () => {
    assert.equal(
      createRedisKey(REDIS_PREFIXES.blacklist, 'abc'),
      'blacklist:token:abc'
    );
  });

  for (const file of [
    './socket.middlewares.ts',
    '../modules/auth/auth.middlewares.ts',
  ]) {
    it(`${file} no longer reads the literal blacklist:jwt key`, () => {
      const src = read(file);
      assert.equal(src.includes('blacklist:jwt'), false);
      assert.equal(src.includes('createRedisKey(REDIS_PREFIXES.blacklist'), true);
    });
  }
});
