import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { authorizeMediaDelete, mediaKeyFromUrl } from './media.policy';

const base = 'https://cdn.example.test/bucket';
const key = (url: string) => mediaKeyFromUrl({ url, publicBase: base });

describe('mediaKeyFromUrl', () => {
  it('accepts our own attachments url', () => {
    assert.equal(
      key(`${base}/attachments/abc-123.png`),
      'attachments/abc-123.png'
    );
  });
  it('ignores a trailing slash on the public base', () => {
    assert.equal(
      mediaKeyFromUrl({
        url: `${base}/attachments/a.png`,
        publicBase: `${base}/`,
      }),
      'attachments/a.png'
    );
  });
  it('rejects foreign hosts and look-alike prefixes', () => {
    assert.equal(key('https://evil.test/bucket/attachments/a.png'), null);
    assert.equal(key(`${base}.evil.test/attachments/a.png`), null);
    assert.equal(key('attachments/a.png'), null);
  });
  it('rejects keys outside attachments/', () => {
    assert.equal(key(`${base}/private/db-backup.sql`), null);
    assert.equal(key(`${base}/attachmentsX/a.png`), null);
  });
  it('rejects traversal, nesting, encoding, query and fragment tricks', () => {
    for (const bad of [
      `${base}/attachments/../secret`,
      `${base}/attachments/..`,
      `${base}/attachments/.`,
      `${base}/attachments/a/b.png`,
      `${base}/attachments/%2e%2e/x`,
      `${base}/attachments/a.png?x=1`,
      `${base}/attachments/a.png#frag`,
      `${base}/attachments/a\\b.png`,
      `${base}/attachments/a b.png`,
      `${base}/attachments/`,
    ]) {
      assert.equal(key(bad), null, bad);
    }
  });
});

describe('authorizeMediaDelete', () => {
  const owners = new Map([
    ['attachments/mine.png', 'u1'],
    ['attachments/theirs.png', 'u2'],
  ]);
  const user = { id: 'u1', role: 'USER' };

  it('lets a user delete only their own files', () => {
    assert.equal(
      authorizeMediaDelete({ actor: user, keys: ['attachments/mine.png'], owners })
        .allowed,
      true
    );
    const d = authorizeMediaDelete({
      actor: user,
      keys: ['attachments/theirs.png'],
      owners,
    });
    assert.equal(d.allowed, false);
    assert.deepEqual(d.deniedKeys, ['attachments/theirs.png']);
  });
  it('denies files with no ownership record (legacy uploads) to non-admins', () => {
    assert.equal(
      authorizeMediaDelete({ actor: user, keys: ['attachments/old.png'], owners })
        .allowed,
      false
    );
  });
  it('denies the whole batch when any key is not owned', () => {
    const d = authorizeMediaDelete({
      actor: user,
      keys: ['attachments/mine.png', 'attachments/theirs.png'],
      owners,
    });
    assert.equal(d.allowed, false);
    assert.deepEqual(d.deniedKeys, ['attachments/theirs.png']);
  });
  it('lets ADMIN delete anything, including legacy files', () => {
    const admin = { id: 'a1', role: 'ADMIN' };
    assert.equal(
      authorizeMediaDelete({
        actor: admin,
        keys: ['attachments/theirs.png', 'attachments/old.png'],
        owners,
      }).allowed,
      true
    );
  });
  it('treats CLUB_OWNER like a normal user', () => {
    assert.equal(
      authorizeMediaDelete({
        actor: { id: 'u2', role: 'CLUB_OWNER' },
        keys: ['attachments/mine.png'],
        owners,
      }).allowed,
      false
    );
  });
});
