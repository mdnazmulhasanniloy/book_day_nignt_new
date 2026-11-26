import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  adminListArtistsQuerySchema,
  adminUpdateArtistSchema,
  artistSocialLinksSchema,
  listArtistsQuerySchema,
  ownerUpdateArtistSchema,
} from '@/app/modules/artists/artists.schema';

// T-044: pure validation rules. The socialLinks shape is OUR proposal (not defined by the client).

describe('artist socialLinks schema (T-044 proposal)', () => {
  const ok = (v: unknown) => artistSocialLinksSchema.safeParse(v).success;

  it('accepts known platform keys with https URLs, including an empty object', () => {
    assert.ok(ok({}));
    assert.ok(
      ok({
        instagram: 'https://instagram.com/a',
        facebook: 'https://facebook.com/a',
        x: 'https://x.com/a',
        tiktok: 'https://tiktok.com/@a',
        youtube: 'https://youtube.com/@a',
        soundcloud: 'https://soundcloud.com/a',
        website: 'https://a.example.test',
      })
    );
  });

  it('rejects unknown keys, non-https and malformed URLs, non-strings, long values, arrays', () => {
    assert.ok(!ok({ myspace: 'https://x.test' }));
    assert.ok(!ok({ spotify: 'https://open.spotify.com/artist/a' }), 'spotify has its own column');
    assert.ok(!ok({ instagram: 'http://instagram.com/a' }));
    assert.ok(!ok({ instagram: 'javascript:alert(1)' }));
    assert.ok(!ok({ instagram: 'instagram.com/a' }));
    assert.ok(!ok({ instagram: 5 }));
    assert.ok(!ok({ instagram: null }));
    assert.ok(!ok({ instagram: `https://x.test/${'a'.repeat(2050)}` }));
    assert.ok(!ok([]));
    assert.ok(!ok('https://x.test'));
  });
});

describe('artist update schemas', () => {
  it('owner schema: photo, bio, spotifyUrl, socialLinks only; at least one field; null clears', () => {
    assert.ok(ownerUpdateArtistSchema.safeParse({ bio: null, photo: null, socialLinks: null, spotifyUrl: null }).success);
    assert.ok(!ownerUpdateArtistSchema.safeParse({}).success);
    assert.ok(!ownerUpdateArtistSchema.safeParse({ name: 'x' }).success);
    assert.ok(!ownerUpdateArtistSchema.safeParse({ isVerified: true }).success);
  });

  it('bio is trimmed, an empty bio becomes null, 2000 chars max', () => {
    const r = ownerUpdateArtistSchema.parse({ bio: '  hi  ' });
    assert.equal(r.bio, 'hi');
    assert.equal(ownerUpdateArtistSchema.parse({ bio: '   ' }).bio, null);
    assert.ok(ownerUpdateArtistSchema.safeParse({ bio: 'x'.repeat(2000) }).success);
    assert.ok(!ownerUpdateArtistSchema.safeParse({ bio: 'x'.repeat(2001) }).success);
  });

  it('admin schema adds name (trimmed, 1..120) and isVerified', () => {
    assert.ok(adminUpdateArtistSchema.safeParse({ isVerified: false }).success);
    assert.equal(adminUpdateArtistSchema.parse({ name: '  DJ X ' }).name, 'DJ X');
    assert.ok(!adminUpdateArtistSchema.safeParse({ name: '   ' }).success);
    assert.ok(!adminUpdateArtistSchema.safeParse({ name: 'x'.repeat(121) }).success);
    assert.ok(!adminUpdateArtistSchema.safeParse({ other: 1 }).success);
  });
});

describe('artist list query schemas', () => {
  it('defaults page 1 and limit 10, caps limit at 50', () => {
    const q = listArtistsQuerySchema.parse({});
    assert.equal(q.page, '1');
    assert.equal(q.limit, '10');
    assert.ok(!listArtistsQuerySchema.safeParse({ limit: '51' }).success);
    assert.ok(!listArtistsQuerySchema.safeParse({ cityId: 'nope' }).success);
  });

  it('admin list parses isVerified as a tri-state boolean', () => {
    assert.equal(adminListArtistsQuerySchema.parse({}).isVerified, undefined);
    assert.equal(adminListArtistsQuerySchema.parse({ isVerified: 'true' }).isVerified, true);
    assert.equal(adminListArtistsQuerySchema.parse({ isVerified: 'false' }).isVerified, false);
    assert.ok(!adminListArtistsQuerySchema.safeParse({ isVerified: 'maybe' }).success);
  });
});
