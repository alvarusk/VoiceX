import 'dart:collection';

/// Normalizes spoken phrases and maps them to known actions.
///
/// If the text matches a command (for example "next", "previous",
/// "accept"), we return the action; otherwise, the text is treated as free
/// text.
class CommandRouter {
  CommandRouter._();
  static final CommandRouter instance = CommandRouter._();

  final Map<String, CommandAction> _map = UnmodifiableMapView({
    // Navigation
    'siguiente': CommandAction.next,
    'adelante': CommandAction.next,
    'next': CommandAction.next,
    'avanzar': CommandAction.next,
    'forward': CommandAction.next,
    'advance': CommandAction.next,
    'anterior': CommandAction.previous,
    'atras': CommandAction.previous,
    'previo': CommandAction.previous,
    'previous': CommandAction.previous,
    'back': CommandAction.previous,

    // Doubt state
    'duda': CommandAction.toggleDoubt,
    'marcar duda': CommandAction.toggleDoubt,
    'quitar duda': CommandAction.toggleDoubt,
    'doubt': CommandAction.toggleDoubt,
    'mark doubt': CommandAction.toggleDoubt,
    'clear doubt': CommandAction.toggleDoubt,
    'flag': CommandAction.toggleDoubt,

    // Voice
    'aceptar': CommandAction.acceptVoice,
    'usar': CommandAction.acceptVoice,
    'usar voz': CommandAction.acceptVoice,
    'confirmar': CommandAction.acceptVoice,
    'accept': CommandAction.acceptVoice,
    'use': CommandAction.acceptVoice,
    'use voice': CommandAction.acceptVoice,
    'confirm': CommandAction.acceptVoice,
    'rechazar': CommandAction.clearVoice,
    'borrar': CommandAction.clearVoice,
    'limpiar': CommandAction.clearVoice,
    'reject': CommandAction.clearVoice,
    'delete': CommandAction.clearVoice,
    'clear': CommandAction.clearVoice,

    // Control
    'repetir': CommandAction.repeat,
    'otra vez': CommandAction.repeat,
    'escuchar de nuevo': CommandAction.repeat,
    'repeat': CommandAction.repeat,
    'again': CommandAction.repeat,
    'listen again': CommandAction.repeat,
  });

  CommandRouteResult route(String raw) {
    final norm = _normalize(raw);
    if (norm.isEmpty) return CommandRouteResult.raw(raw: raw);

    for (final entry in _map.entries) {
      final k = entry.key;
      if (norm == k || norm.startsWith('$k ')) {
        final leftover = norm == k ? null : norm.substring(k.length).trim();
        return CommandRouteResult(
          raw: raw,
          normalized: norm,
          matched: k,
          action: entry.value,
          payload: leftover,
        );
      }
    }

    return CommandRouteResult.raw(raw: raw, normalized: norm);
  }

  String _normalize(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return '';
    final withoutPunctuation = lower.replaceAll(
      RegExp(r'[.,;:\u00a1!\u00bf?"]'),
      '',
    );
    final squashedSpaces = withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ');
    // Basic accent folding for simpler matching.
    return squashedSpaces
        .replaceAll(RegExp('[\\u00e1\\u00e0\\u00e4\\u00e2]'), 'a')
        .replaceAll(RegExp('[\\u00e9\\u00e8\\u00eb\\u00ea]'), 'e')
        .replaceAll(RegExp('[\\u00ed\\u00ec\\u00ef\\u00ee]'), 'i')
        .replaceAll(RegExp('[\\u00f3\\u00f2\\u00f6\\u00f4]'), 'o')
        .replaceAll(RegExp('[\\u00fa\\u00f9\\u00fc\\u00fb]'), 'u');
  }
}

enum CommandAction {
  next,
  previous,
  toggleDoubt,
  acceptVoice,
  clearVoice,
  repeat,
}

class CommandRouteResult {
  const CommandRouteResult({
    required this.raw,
    this.normalized,
    this.matched,
    this.action,
    this.payload,
  });

  CommandRouteResult.raw({required this.raw, this.normalized})
    : matched = null,
      action = null,
      payload = null;

  final String raw;
  final String? normalized;
  final String? matched;
  final CommandAction? action;
  final String? payload;

  bool get isCommand => action != null;
}
