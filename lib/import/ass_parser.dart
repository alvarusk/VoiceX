class ParsedDialogue {
  ParsedDialogue({
    required this.eventsRowIndex,
    required this.dialoguePrefix,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.style,
    required this.name,
    required this.effect,
    required this.leadingTags,
    required this.hasVectorDrawing,
    required this.sourceText,
    required this.romanization,
    required this.gloss,
    required this.translationCandidate,
  });

  final int eventsRowIndex;
  final String dialoguePrefix; // incluye coma final antes del Text
  final String text;

  final int startMs;
  final int endMs;
  final String? style;
  final String? name;
  final String? effect;

  final String leadingTags;
  final bool hasVectorDrawing;

  final String? sourceText;
  final String? romanization;
  final String? gloss;

  // Para motores: bloque de traduccion con saltos reales.
  final String? translationCandidate;
}

class ParsedAss {
  ParsedAss({required this.formatFields, required this.dialogues});

  final List<String> formatFields;
  final List<ParsedDialogue> dialogues;
}

class AssParser {
  static ParsedAss parseAssLines(List<String> lines) {
    bool inEvents = false;
    List<String> formatFields = const [];
    final dialogues = <ParsedDialogue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line == '[Events]') {
        inEvents = true;
        continue;
      }
      if (!inEvents) continue;

      if (line.startsWith('Format:')) {
        final raw = line.substring('Format:'.length).trim();
        formatFields = raw.split(',').map((s) => s.trim()).toList();
        continue;
      }

      if (!line.startsWith('Dialogue:')) continue;
      if (formatFields.isEmpty) {
        throw FormatException('ASS invalido: falta "Format:" en [Events].');
      }

      final parsed = _parseDialogueLine(
        originalLine: lines[i],
        eventsRowIndex: i,
        formatFields: formatFields,
      );
      dialogues.add(parsed);
    }

    return ParsedAss(formatFields: formatFields, dialogues: dialogues);
  }

  static ParsedDialogue _parseDialogueLine({
    required String originalLine,
    required int eventsRowIndex,
    required List<String> formatFields,
  }) {
    // ASS: el campo Text es el ultimo. Encontramos la (n-1)-esima coma.
    final neededCommas = formatFields.length - 1;
    int commaCount = 0;
    int splitCommaIndex = -1;

    for (int idx = 0; idx < originalLine.length; idx++) {
      if (originalLine.codeUnitAt(idx) == 44) {
        // ','
        commaCount++;
        if (commaCount == neededCommas) {
          splitCommaIndex = idx;
          break;
        }
      }
    }
    if (splitCommaIndex < 0) {
      throw FormatException(
        'Dialogue malformado (no encuentro coma de split): $originalLine',
      );
    }

    final dialoguePrefix = originalLine.substring(0, splitCommaIndex + 1);
    final text = originalLine.substring(splitCommaIndex + 1);

    // Campos previos (n-1)
    final afterPrefix = originalLine.substring(
      'Dialogue:'.length,
      splitCommaIndex,
    );
    final values = afterPrefix.split(',').map((s) => s.trim()).toList();

    String? getField(String name) {
      final idx = formatFields.indexWhere(
        (f) => f.toLowerCase() == name.toLowerCase(),
      );
      if (idx < 0) return null;
      if (idx >= values.length) return null;
      return values[idx];
    }

    final start = getField('Start');
    final end = getField('End');
    if (start == null || end == null) {
      throw FormatException('Dialogue sin Start/End: $originalLine');
    }

    final startMs = _parseAssTimeToMs(start);
    final endMs = _parseAssTimeToMs(end);

    final style = getField('Style');
    final name = getField('Name');
    final effect = getField('Effect');

    final leadingTags = _extractLeadingTags(text);
    final hasVector = RegExp(r'\\p\d+').hasMatch(leadingTags);

    // Normalizamos \n -> \N y luego convertimos a saltos reales.
    final payload = text.substring(leadingTags.length).replaceAll(r'\n', r'\N');
    // Quita tags de Aegisub {\\...} pero deja otros (ej: {pinyin})
    final cleanedPayload = payload.replaceAll(RegExp(r'\{\\[^}]*\}'), '');
    final displayText = cleanedPayload.replaceAll(r'\N', '\n');

    // En guiones EN/ES, \N es solo salto de linea: tratamos todo como bloque unico.
    final sourceText = displayText.isEmpty ? null : displayText;
    final String? romanization = null;
    final String? gloss = null;

    // Para traducciones, guardamos todas las lineas (no solo la ultima).
    final candidate = displayText.isEmpty ? null : displayText;

    return ParsedDialogue(
      eventsRowIndex: eventsRowIndex,
      dialoguePrefix: dialoguePrefix,
      text: text,
      startMs: startMs,
      endMs: endMs,
      style: style,
      name: name,
      effect: effect,
      leadingTags: leadingTags,
      hasVectorDrawing: hasVector,
      sourceText: sourceText,
      romanization: romanization,
      gloss: gloss,
      translationCandidate: candidate,
    );
  }

  static String _extractLeadingTags(String text) {
    final m = RegExp(r'^(\{[^}]*\})+').firstMatch(text);
    return m?.group(0) ?? '';
  }

  static int _parseAssTimeToMs(String t) {
    // Formato tipico: H:MM:SS.cc (centisegundos)
    final m = RegExp(r'^(\d+):(\d{2}):(\d{2})\.(\d{2})$').firstMatch(t.trim());
    if (m == null) {
      throw FormatException('Tiempo ASS invalido: "$t"');
    }
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    final s = int.parse(m.group(3)!);
    final cs = int.parse(m.group(4)!);
    return (((h * 60 + mm) * 60 + s) * 1000) + (cs * 10);
  }
}
