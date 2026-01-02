import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../import/import_service.dart';

class ProjectImportSheet extends StatefulWidget {
  const ProjectImportSheet({
    super.key,
    required this.db,
    this.initialFolder,
    this.folderOptions = const [],
    this.onFolderCreated,
  });
  final AppDatabase db;
  final String? initialFolder;
  final List<String> folderOptions;
  final void Function(String folder)? onFolderCreated;

  @override
  State<ProjectImportSheet> createState() => _ProjectImportSheetState();
}

class _ProjectImportSheetState extends State<ProjectImportSheet> {
  String _log = '';
  bool _busy = false;
  late final TextEditingController _folderCtrl =
      TextEditingController(text: widget.initialFolder ?? '');
  final TextEditingController _episodeCtrl = TextEditingController();

  PlatformFile? _baseFile;
  List<PlatformFile> _engineFiles = [];
  PlatformFile? _videoFile;
  PlatformFile? _scriptFile;

  Future<void> _promptEpisodeNumber() async {
    if (_episodeCtrl.text.trim().isNotEmpty) return; // ya indicado
    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Número de episodio'),
          content: TextField(
            controller: _episodeCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Ej: 5',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Engine? _inferEngineFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('gpt')) return Engine.gpt;
    if (n.contains('claude')) return Engine.claude;
    if (n.contains('gemini')) return Engine.gemini;
    if (n.contains('deepseek') || n.contains('ds')) return Engine.deepseek;
    return null;
  }

  Future<void> _pickBase() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ass'],
      withData: kIsWeb,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _baseFile = res.files.single);
    if (!mounted) return;
    await _promptEpisodeNumber();
  }

  Future<void> _pickEngines() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ass'],
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (res == null) return;
    setState(() => _engineFiles = res.files);
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'mov'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _videoFile = res.files.single);
  }

  Future<void> _pickScriptEs() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ass'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _scriptFile = res.files.single);
  }

  Future<void> _runImport() async {
    if (_busy) return;
    if (_baseFile == null) {
      setState(() => _log = 'Falta seleccionar BASE (.ass).');
      return;
    }
    final ep = _episodeCtrl.text.trim();
    if (ep.isEmpty) {
      setState(() => _log = 'Indica el n\u00famero de episodio.');
      return;
    }

    setState(() {
      _busy = true;
      _log = 'Importando…';
    });

    try {
      final engines = <Engine, PlatformFile>{};
      for (final f in _engineFiles) {
        final e = _inferEngineFromName(f.name);
        if (e == null) continue;
        engines[e] = f;
      }

      if (_scriptFile != null && !engines.containsKey(Engine.gpt)) {
        engines[Engine.gpt] = _scriptFile!;
      }

      final importer = ImportService(widget.db);
      final projectId = await importer.importProject(
        title: 'Episodio $ep',
        folder: _folderCtrl.text.trim(),
        baseAss: _baseFile!,
        engineAssFiles: engines,
        videoFile: _videoFile,
      );

      if (!mounted) return;
      Navigator.of(context).pop(projectId);
    } catch (e) {
      setState(() => _log = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nuevo proyecto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (widget.folderOptions.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: (widget.initialFolder ?? '').isNotEmpty &&
                        widget.folderOptions.contains(widget.initialFolder)
                    ? widget.initialFolder
                    : null,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Sin carpeta'),
                  ),
                  ...widget.folderOptions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f))),
                ],
                decoration: const InputDecoration(
                  labelText: 'Seleccionar carpeta',
                  border: OutlineInputBorder(),
                ),
                onChanged: _busy
                    ? null
                    : (v) {
                        _folderCtrl.text = v ?? '';
                      },
              ),
            if (widget.folderOptions.isNotEmpty) const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final name = await showDialog<String>(
                        context: context,
                        builder: (_) {
                          final ctrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('Nueva carpeta'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                hintText: 'Nombre de carpeta',
                              ),
                              autofocus: true,
                              onSubmitted: (v) => Navigator.pop(context, v.trim()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                                child: const Text('Crear'),
                              ),
                            ],
                          );
                        },
                      );
                      if (name != null && name.trim().isNotEmpty) {
                        final trimmed = name.trim();
                        _folderCtrl.text = trimmed;
                        widget.onFolderCreated?.call(trimmed);
                      }
                    },
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Nueva carpeta'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _pickBase,
              icon: const Icon(Icons.upload_file),
              label: const Text('Seleccionar BASE (.ass)'),
            ),
            if (_baseFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Base: ${_baseFile!.name}'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickEngines,
              icon: const Icon(Icons.layers),
              label: const Text('Seleccionar motores (multi)'),
            ),
            if (_engineFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Motores: ${_engineFiles.map((f) => f.name).join(', ')}'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickVideo,
              icon: const Icon(Icons.video_file),
              label: const Text('Seleccionar video (opcional)'),
            ),
            if (_videoFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Video: ${_videoFile!.name}'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickScriptEs,
              icon: const Icon(Icons.menu_book),
              label: const Text('Guion en español (ASS)'),
            ),
            if (_scriptFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Guion ES: ${_scriptFile!.name}'),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _runImport,
              icon: const Icon(Icons.import_export),
              label: const Text('Importar'),
            ),
            const SizedBox(height: 8),
            Text(
              _log,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _folderCtrl.dispose();
    _episodeCtrl.dispose();
    super.dispose();
  }
}
