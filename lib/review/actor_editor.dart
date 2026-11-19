import 'package:flutter/material.dart';

/// Edits this line's actor; suggestions come from the current project.
class ActorEditor extends StatefulWidget {
  const ActorEditor({
    super.key,
    required this.initialValue,
    required this.actors,
    required this.onSave,
  });

  final String initialValue;
  final List<String> actors;
  final Future<void> Function(String actor) onSave;

  @override
  State<ActorEditor> createState() => _ActorEditorState();
}

class _ActorEditorState extends State<ActorEditor> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();
  Future<void> _saveTail = Future<void>.value();
  int _pending = 0;
  bool _saveFailed = false;

  @override
  void didUpdateWidget(covariant ActorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Older database acknowledgements must not replace newer typed text.
    if (_pending == 0 &&
        !_focusNode.hasFocus &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  void _save(String value) {
    final save = widget.onSave;
    _pending++;
    // Serialize writes, including the final edit if the user leaves the line.
    _saveTail = _saveTail.then((_) async {
      try {
        await save(value);
        if (mounted && _saveFailed) setState(() => _saveFailed = false);
      } catch (_) {
        if (mounted) setState(() => _saveFailed = true);
      } finally {
        _pending--;
      }
    });
  }

  void _select(String actor) {
    _controller.value = TextEditingValue(
      text: actor,
      selection: TextSelection.collapsed(offset: actor.length),
    );
    _save(actor);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => widget.actors.where(
        (actor) => actor.toLowerCase().contains(value.text.toLowerCase()),
      ),
      onSelected: _select,
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final actor in options)
                  ListTile(title: Text(actor), onTap: () => onSelected(actor)),
              ],
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focus, onSubmitted) => TextField(
        controller: controller,
        focusNode: focus,
        onChanged: _save,
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          labelText: 'Actor',
          hintText: 'No actor',
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: _saveFailed
              ? 'Could not save actor. Edit to retry.'
              : null,
          suffixIcon: PopupMenuButton<String>(
            tooltip: 'Choose actor',
            icon: const Icon(Icons.arrow_drop_down),
            onSelected: _select,
            itemBuilder: (_) => [
              for (final actor in widget.actors)
                PopupMenuItem(value: actor, child: Text(actor)),
            ],
          ),
        ),
      ),
    );
  }
}
