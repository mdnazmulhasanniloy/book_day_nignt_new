import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assertSafeTestDatabaseUrl } from '@/testing/testDb';

// Template 1: pure function, no I/O.
describe('assertSafeTestDatabaseUrl', () => {
  it('accepts *_test and *_rehearsal databases', () => {
    assert.ok(assertSafeTestDatabaseUrl('postgresql://u:p@localhost:5441/app_test?schema=public'));
    assert.ok(assertSafeTestDatabaseUrl('postgresql://u:p@localhost:5441/bookdia_rehearsal'));
  });
  it('rejects other database names and a missing url', () => {
    for (const bad of ['postgresql://u:p@h/bookdianight', 'postgresql://u:p@h/prod', 'postgresql://u:p@h/test_data']) {
      assert.throws(() => assertSafeTestDatabaseUrl(bad), /must end in _test or _rehearsal/);
    }
    assert.throws(() => assertSafeTestDatabaseUrl(undefined), /not set/);
    assert.throws(() => assertSafeTestDatabaseUrl('not a url'), /not a valid URL/);
  });
});
