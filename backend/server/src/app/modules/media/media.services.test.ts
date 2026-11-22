import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  IMediaDb,
  IMediaDeps,
  removeMediaService,
  uploadMediaService,
} from './media.services';

const publicBase = 'https://cdn.example.test/bucket';
const urlOf = (key: string) => `${publicBase}/${key}`;

const makeDeps = (opts: { failRemove?: string[]; failCreate?: boolean } = {}) => {
  const rows = new Map<string, string>();
  const objects = new Set<string>();
  const db: IMediaDb = {
    mediaAsset: {
      async createMany({ data }) {
        if (opts.failCreate) throw new Error('db down');
        for (const d of data) rows.set(d.key, d.ownerId);
      },
      async findMany({ where }) {
        return where.key.in
          .filter((k) => rows.has(k))
          .map((k) => ({ key: k, ownerId: rows.get(k)! }));
      },
      async deleteMany({ where }) {
        for (const k of where.key.in) rows.delete(k);
      },
    },
  };
  const removed: string[] = [];
  const deps: IMediaDeps = {
    db,
    publicBase,
    storage: {
      async upload({ key }) {
        objects.add(key);
        return urlOf(key);
      },
      async remove({ key }) {
        if (opts.failRemove?.includes(key)) throw new Error('s3 down');
        removed.push(key);
        objects.delete(key);
      },
    },
  };
  return { deps, rows, objects, removed };
};

const file = (name: string) =>
  ({
    originalname: name,
    path: `/tmp/${name}`,
    mimetype: 'image/png',
    size: 10,
  }) as Express.Multer.File;

const user = (id: string) => ({ id, role: 'USER' });
const admin = { id: 'admin1', role: 'ADMIN' };

describe('uploadMediaService', () => {
  it('records the uploader as owner of every file and returns urls', async () => {
    const t = makeDeps();
    const urls = await uploadMediaService({
      files: [file('a.png'), file('b.png')],
      ownerId: 'u1',
      deps: t.deps,
    });
    assert.equal(urls.length, 2);
    assert.equal(t.rows.size, 2);
    assert.ok([...t.rows.values()].every((o) => o === 'u1'));
    assert.ok(urls.every((u) => u.startsWith(`${publicBase}/attachments/`)));
  });

  it('removes the uploaded objects when ownership cannot be recorded', async () => {
    const t = makeDeps({ failCreate: true });
    await assert.rejects(
      uploadMediaService({ files: [file('a.png')], ownerId: 'u1', deps: t.deps }),
      /db down/
    );
    assert.equal(t.objects.size, 0);
  });
});

describe('removeMediaService', () => {
  const seed = async (t: ReturnType<typeof makeDeps>, owner: string) =>
    (
      await uploadMediaService({ files: [file('a.png')], ownerId: owner, deps: t.deps })
    )[0];

  it('owner can delete their own file (object and row removed)', async () => {
    const t = makeDeps();
    const url = await seed(t, 'u1');
    await removeMediaService({ urls: [url], actor: user('u1'), deps: t.deps });
    assert.equal(t.objects.size, 0);
    assert.equal(t.rows.size, 0);
  });

  it("another user cannot delete it by supplying the url (403, nothing removed)", async () => {
    const t = makeDeps();
    const url = await seed(t, 'u1');
    await assert.rejects(
      removeMediaService({ urls: [url], actor: user('u2'), deps: t.deps }),
      { statusCode: 403, errorType: 'ACCESS_DENIED' }
    );
    assert.equal(t.removed.length, 0);
    assert.equal(t.rows.size, 1);
  });

  it('a mixed batch with one foreign file deletes nothing', async () => {
    const t = makeDeps();
    const mine = await seed(t, 'u1');
    const theirs = (
      await uploadMediaService({ files: [file('c.png')], ownerId: 'u2', deps: t.deps })
    )[0];
    await assert.rejects(
      removeMediaService({ urls: [mine, theirs], actor: user('u1'), deps: t.deps }),
      { statusCode: 403 }
    );
    assert.equal(t.removed.length, 0);
    assert.equal(t.rows.size, 2);
  });

  it('files without an ownership record are admin-only', async () => {
    const t = makeDeps();
    const legacy = urlOf('attachments/legacy-1.png');
    t.objects.add('attachments/legacy-1.png');
    await assert.rejects(
      removeMediaService({ urls: [legacy], actor: user('u1'), deps: t.deps }),
      { statusCode: 403 }
    );
    assert.equal(t.removed.length, 0);
    await removeMediaService({ urls: [legacy], actor: admin, deps: t.deps });
    assert.deepEqual(t.removed, ['attachments/legacy-1.png']);
  });

  it("admin can delete another user's file", async () => {
    const t = makeDeps();
    const url = await seed(t, 'u1');
    await removeMediaService({ urls: [url], actor: admin, deps: t.deps });
    assert.equal(t.rows.size, 0);
  });

  it('rejects foreign and crafted urls without touching storage, even for admin', async () => {
    const t = makeDeps();
    for (const bad of [
      'https://evil.test/bucket/attachments/a.png',
      `${publicBase}/attachments/../secret`,
      `${publicBase}/other/file.png`,
      'not a url',
    ]) {
      await assert.rejects(
        removeMediaService({ urls: [bad], actor: admin, deps: t.deps }),
        { statusCode: 422, errorType: 'INVALID_MEDIA_URL' }
      );
    }
    assert.equal(t.removed.length, 0);
  });

  it('keeps the ownership row when the storage delete fails', async () => {
    const t = makeDeps();
    const url = await seed(t, 'u1');
    const key = [...t.rows.keys()][0];
    const failing = makeDeps({ failRemove: [key] });
    failing.rows.set(key, 'u1');
    await assert.rejects(
      removeMediaService({ urls: [url], actor: user('u1'), deps: failing.deps }),
      /s3 down/
    );
    assert.equal(failing.rows.size, 1);
  });

  it('duplicate urls in one request delete once', async () => {
    const t = makeDeps();
    const url = await seed(t, 'u1');
    await removeMediaService({ urls: [url, url], actor: user('u1'), deps: t.deps });
    assert.equal(t.removed.length, 1);
  });
});
