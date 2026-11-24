// S-23: one shared helper for every server-built HTML page that embeds stored values.

const HTML_ESCAPES: Record<string, string> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};

/** Escapes text for HTML text nodes and for single- or double-quoted attribute values. */
export const escapeHtml = (value: unknown): string =>
  value === null || value === undefined ? '' : String(value).replace(/[&<>"']/g, (c) => HTML_ESCAPES[c]);

/**
 * Returns the URL unchanged when it is an absolute http(s) URL, otherwise an empty string.
 * The result is NOT escaped: pass it through escapeHtml when placing it in HTML.
 */
export const safeHttpUrl = (value: unknown): string => {
  if (typeof value !== 'string') return '';
  try {
    const { protocol } = new URL(value.trim());
    return protocol === 'http:' || protocol === 'https:' ? value : '';
  } catch {
    return '';
  }
};

/**
 * Serializes a string as a JavaScript string literal that is safe inside an inline <script>:
 * `<`, `>`, `&` and the JS line separators are written as unicode escapes, so `</script>`
 * or `<!--` can never appear in the output.
 */
export const jsStringLiteral = (value: string): string =>
  JSON.stringify(value).replace(/[<>&\u2028\u2029]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, '0')}`);
