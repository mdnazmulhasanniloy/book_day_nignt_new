import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { escapeHtml, jsStringLiteral, safeHttpUrl } from '@/app/utils/htmlEscape';

// S-23: shared escape helper for server-built HTML.

const PAYLOADS = [
  '"><script>alert(1)</script>',
  '<img src=x onerror=alert(1)>',
  "' onmouseover='alert(1)",
  '</title><script>alert(1)</script>',
  '</script><script>alert(1)</script>',
];

describe('escapeHtml', () => {
  it('escapes & < > " \' exactly', () => {
    assert.equal(escapeHtml(`& < > " '`), '&amp; &lt; &gt; &quot; &#39;');
  });

  it('leaves normal text unchanged (letters, digits, spaces, accents, punctuation, CJK, middle dot)', () => {
    const s = 'Café Zürich 42, Rock-n-Roll! 100% (open) / late: 中文 · ok.';
    assert.equal(escapeHtml(s), s);
  });

  it('escapes already-escaped text once more so it displays literally', () => {
    assert.equal(escapeHtml('&lt;b&gt;'), '&amp;lt;b&amp;gt;');
  });

  it('leaves no angle bracket or quote in the output for any payload', () => {
    for (const p of PAYLOADS) {
      const out = escapeHtml(p);
      assert.doesNotMatch(out, /[<>"']/, p);
    }
  });

  it('handles null and undefined as empty string', () => {
    assert.equal(escapeHtml(null), '');
    assert.equal(escapeHtml(undefined), '');
  });
});

describe('safeHttpUrl', () => {
  it('keeps http and https URLs unchanged', () => {
    assert.equal(safeHttpUrl('https://cdn.example.test/a b.png?x=1&y=2'), 'https://cdn.example.test/a b.png?x=1&y=2');
    assert.equal(safeHttpUrl('http://example.test/t.png'), 'http://example.test/t.png');
  });

  it('returns empty string for other schemes, relative and junk values', () => {
    for (const v of [
      'javascript:alert(1)',
      ' JaVaScRiPt:alert(1)',
      'java\tscript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'vbscript:x',
      'bookdianight://club/1',
      '//evil.test/x.png',
      '/relative.png',
      '',
      'not a url',
    ]) {
      assert.equal(safeHttpUrl(v), '', v);
    }
    assert.equal(safeHttpUrl(null), '');
    assert.equal(safeHttpUrl(undefined), '');
  });
});

describe('jsStringLiteral', () => {
  it('produces a literal that cannot close a script element or break out of the string', () => {
    for (const p of PAYLOADS.concat(['a\u2028b\u2029c', '<!-- x'])) {
      const out = jsStringLiteral(p);
      assert.doesNotMatch(out, /[<>&\u2028\u2029]/, p);
      assert.equal(eval(out), p); // round-trips to the original string
    }
  });

  it('keeps a normal value as a plain JSON string', () => {
    assert.equal(jsStringLiteral('bookdianight://club/abc-123'), '"bookdianight://club/abc-123"');
  });
});
