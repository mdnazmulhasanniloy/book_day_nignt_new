import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { omitPassword } from '@/app/modules/admin/admin.helpers';

describe('omitPassword (BUG-S17)', () => {
  const user = {
    id: 'u1',
    email: 'a@example.com',
    password: '$2b$10$abcdefghijklmnopqrstuvC8Yq0hT1mJ3n5p7r9t1v3x5z7B9D1F3',
    profile: { name: 'A' },
  };

  it('removes the password field', () => {
    const result = omitPassword(user);
    assert.equal('password' in result, false);
  });

  it('keeps every other field unchanged', () => {
    assert.deepEqual(omitPassword(user), {
      id: 'u1',
      email: 'a@example.com',
      profile: { name: 'A' },
    });
  });

  it('leaves no bcrypt hash in the serialized result', () => {
    const json = JSON.stringify(omitPassword(user));
    assert.equal(json.includes('$2b$'), false);
    assert.equal(json.includes('password'), false);
  });

  it('does not mutate the input and accepts records without a password', () => {
    omitPassword(user);
    assert.equal(typeof user.password, 'string');
    assert.deepEqual(omitPassword({ id: 'u2' }), { id: 'u2' });
  });
});
