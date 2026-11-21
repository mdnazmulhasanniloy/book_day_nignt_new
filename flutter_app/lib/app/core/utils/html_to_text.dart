/// Converts CMS HTML (legal pages, descriptions) into readable plain text,
/// keeping paragraph and list line breaks.
String htmlToPlainText(String html) {
  if (!html.contains('<') && !html.contains('&')) return html.trim();

  var text = html
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(
        RegExp(
          r'</(p|div|h[1-6]|ul|ol|li|tr|table|section|article|blockquote)>',
          caseSensitive: false,
        ),
        '\n\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');

  text = _decodeEntities(text);

  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'\n\n(?=• )'), '\n')
      .trim();
}

const _namedEntities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'rsquo': '\u2019',
  'lsquo': '\u2018',
  'rdquo': '\u201D',
  'ldquo': '\u201C',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'hellip': '\u2026',
  'copy': '\u00A9',
  'reg': '\u00AE',
  'trade': '\u2122',
  'euro': '\u20AC',
  'bull': '\u2022',
};

String _decodeEntities(String input) {
  return input.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'),
    (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return _namedEntities[entity.toLowerCase()] ?? match.group(0)!;
    },
  );
}
