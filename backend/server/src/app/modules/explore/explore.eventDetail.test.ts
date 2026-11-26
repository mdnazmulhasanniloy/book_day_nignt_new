import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildEventMapUrl } from '@/app/modules/explore/explore.mapUrl';

// T-045: the map link is built only from lat, lng and the event name, always URL-encoded.
describe('buildEventMapUrl (T-045)', () => {
  it('encodes name and coordinates into one query parameter', () => {
    assert.equal(
      buildEventMapUrl({ name: 'Club Night', lat: 23.78, lng: 90.4 }),
      'https://www.google.com/maps/search/?api=1&query=Club%20Night%2023.78%2C90.4'
    );
  });

  it('encodes ampersand, quotes, markup, percent and non-ASCII', () => {
    const url = buildEventMapUrl({ name: `A&B "x" <script>alert(1)</script> 100% Café 中`, lat: 1, lng: -2 });
    assert.match(url, /^https:\/\/www\.google\.com\/maps\/search\/\?api=1&query=[A-Za-z0-9%._~-]+$/);
    assert.equal(new URL(url).searchParams.get('query'), `A&B "x" <script>alert(1)</script> 100% Café 中 1,-2`);
  });

  it('a name that tries to add parameters stays inside the query value', () => {
    const url = buildEventMapUrl({ name: 'x&api=2&query=evil', lat: 0, lng: 0 });
    assert.equal(new URL(url).searchParams.getAll('query').length, 1);
    assert.equal(new URL(url).searchParams.get('api'), '1');
  });
});
