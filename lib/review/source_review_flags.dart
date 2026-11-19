import 'package:flutter/material.dart';

/// Touch controls for the standard source-review annotations.
class SourceReviewFlags extends StatefulWidget {
  const SourceReviewFlags({
    super.key,
    required this.note,
    required this.onChanged,
  });

  final String note;
  final Future<void> Function(String) onChanged;

  @override
  State<SourceReviewFlags> createState() => _SourceReviewFlagsState();
}

class _SourceReviewFlagsState extends State<SourceReviewFlags> {
  static final _annotation = RegExp(
    r'(^|\n)Revisar (actor y texto|actor|texto)(?=\n|$)',
  );
  late String _note = widget.note;
  Future<void> _saveTail = Future<void>.value();
  int _pending = 0;
  bool _saveFailed = false;

  String get _flag => _annotation.firstMatch(_note)?.group(2) ?? '';
  bool get _actor => _flag == 'actor' || _flag == 'actor y texto';
  bool get _text => _flag == 'texto' || _flag == 'actor y texto';

  @override
  void didUpdateWidget(covariant SourceReviewFlags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending == 0 && widget.note != oldWidget.note) _note = widget.note;
  }

  void _toggle({required bool actor}) {
    final reviewActor = actor ? !_actor : _actor;
    final reviewText = actor ? _text : !_text;
    final flag = reviewActor && reviewText
        ? 'Revisar actor y texto'
        : reviewActor
        ? 'Revisar actor'
        : reviewText
        ? 'Revisar texto'
        : '';
    // Keep notes written in earlier app versions or on desktop.
    final legacy = _note.replaceAll(_annotation, '').trim();
    final note = [legacy, flag].where((part) => part.isNotEmpty).join('\n');
    setState(() => _note = note);
    final save = widget.onChanged;
    _pending++;
    // A rapid second tap must be persisted after the first one.
    _saveTail = _saveTail.then((_) async {
      try {
        await save(note);
        if (mounted) setState(() => _saveFailed = false);
      } catch (_) {
        if (mounted) setState(() => _saveFailed = true);
      } finally {
        _pending--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget button(String label, bool selected, bool actor) => Expanded(
      child: Semantics(
        toggled: selected,
        child: FilledButton.tonalIcon(
          onPressed: () => _toggle(actor: actor),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 64),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
          label: Text(label),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            button('Actor', _actor, true),
            const SizedBox(width: 12),
            button('Text', _text, false),
          ],
        ),
        if (_note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('($_note)'),
          ),
        if (_saveFailed)
          const Text('Could not save review. Tap a button to retry.'),
      ],
    );
  }
}
