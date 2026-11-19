/// Apply the editorial rules only when importing a FINAL translation.
/// The order matters for mixed opening and closing question marks.
String normalizeFinalTranslation(String text) => text
    .replaceAll('¡¿', '¿')
    .replaceAll('¿¡', '¿')
    .replaceAll('?!', '?')
    .replaceAll('!?', '?')
    .replaceAll(RegExp(r'\.{3}|…'), '.')
    .replaceAll('¡', '')
    .replaceAll('!', '.');

String normalizeExportQuotes(String text) =>
    text.replaceAll('«', '"').replaceAll('»', '"');
