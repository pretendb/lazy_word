class HtmlCleaner {
  static final _soundTag = RegExp(r'\[sound:[^\]]+\]', caseSensitive: false);
  static final _htmlTag = RegExp(r'<[^>]*>');

  static String clean(String value) {
    return value
        .replaceAll(_soundTag, ' ')
        .replaceAll(_htmlTag, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
