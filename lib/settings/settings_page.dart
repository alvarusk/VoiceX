// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/app_db.dart';
import '../sync/cloud_sync_service.dart';
import 'settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.db,
  });
  final bool isDark;
  final VoidCallback onToggleTheme;
  final AppDatabase db;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _svc = SettingsService.instance;
  late final CloudSyncService _cloud;

  late final TextEditingController _keyCtrl;
  late final TextEditingController _textModelCtrl;
  late final TextEditingController _sttModelCtrl;
  final Map<String, TextEditingController> _glossaryCtrls = {};
  List<String> _folders = const [];
  String _selectedFolder = '';

  VoiceInputMode _mode = VoiceInputMode.local;
  bool _saved = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _cloud = CloudSyncService(widget.db);
    _keyCtrl = TextEditingController(text: _svc.openAiKey);
    _keyCtrl.addListener(_markDirty);
    _textModelCtrl = TextEditingController(text: _svc.openAiTextModel);
    _textModelCtrl.addListener(_markDirty);
    _sttModelCtrl = TextEditingController(text: _svc.openAiSttModel);
    _sttModelCtrl.addListener(_markDirty);
    _mode = _svc.voiceInputMode;
    _loadFolders();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _textModelCtrl.dispose();
    _sttModelCtrl.dispose();
    for (final c in _glossaryCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFolders() async {
    await _svc.init();
    final rows = await widget.db
        .customSelect('SELECT DISTINCT folder FROM projects')
        .get();
    final set = <String>{..._svc.manualFolders};
    for (final r in rows) {
      set.add(r.data['folder'] as String? ?? '');
    }
    if (set.isEmpty || !set.contains('')) set.add('');
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _glossaryCtrls.clear();
    for (final f in list) {
      final c = TextEditingController(text: _svc.getGlossaryForFolder(f));
      c.addListener(_markDirty);
      _glossaryCtrls[f] = c;
    }
    setState(() {
      _folders = list;
      _selectedFolder = list.first;
      _dirty = false;
      _saved = false;
    });
  }

  Future<void> _save() async {
    await _svc.setOpenAiKey(_keyCtrl.text);
    await _svc.setOpenAiTextModel(_textModelCtrl.text);
    await _svc.setOpenAiSttModel(_sttModelCtrl.text);
    await _svc.setVoiceInputMode(_mode);
    await _svc.setGlossaryForFolder(
      _selectedFolder,
      _glossaryCtrls[_selectedFolder]?.text ?? '',
    );
    setState(() {
      _saved = true;
      _dirty = false;
    });
    await _cloud.ensureInit();
    if (_cloud.isReady) {
      await _cloud.syncSettingsOnly();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
  }

  Future<void> _pickTxtForFolder(String folder) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    if (res == null) return;
    final file = res.files.single;
    String content = '';
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }
    final terms = content
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final joined = terms.join(', ');
    final ctrl = _glossaryCtrls[folder];
    if (ctrl != null) {
      ctrl.text = joined;
    }
    await _svc.setGlossaryForFolder(folder, joined);
    setState(() {
      _dirty = true;
      _saved = false;
    });
    await _cloud.ensureInit();
    if (_cloud.isReady) {
      await _cloud.syncSettingsOnly();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Glosario actualizado desde TXT')),
      );
    }
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() {
      _dirty = true;
      _saved = false;
    });
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Salir sin guardar ajustes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (res == 'save') {
      await _save();
      return true;
    }
    return res != 'cancel';
  }

  Future<void> _launchUpdater() async {
    final uri = Uri.parse('https://github.com/alvarusk/VoiceX/releases/latest');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace de actualización.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabledOpenAiMode =
        kIsWeb; // MVP: grabación a archivo en web es más delicada

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Ajustes'),
          actions: [
            IconButton(
              tooltip: widget.isDark ? 'Modo claro' : 'Modo oscuro',
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: widget.onToggleTheme,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'OpenAI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'API key',
                hintText: 'sk-…',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo texto (puntuación / ayudas)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sttModelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo STT (audio→texto)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Glosarios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_folders.isEmpty)
              const Text(
                'No hay carpetas todavía. Crea o selecciona una carpeta para vincular glosarios.',
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedFolder,
                items: _folders
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.trim().isEmpty ? 'Sin carpeta' : f),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Serie / Carpeta',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedFolder = v;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _glossaryCtrls[_selectedFolder],
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Términos (separados por comas)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickTxtForFolder(_selectedFolder),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Subir TXT'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Entrada de voz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            RadioListTile<VoiceInputMode>(
              value: VoiceInputMode.local,
              groupValue: _mode,
              onChanged: (v) => setState(() {
                _mode = v!;
                _markDirty();
              }),
              title: const Text('Local (speech_to_text)'),
              subtitle: const Text('Rápido, pero suele venir sin puntuación.'),
            ),
            RadioListTile<VoiceInputMode>(
              value: VoiceInputMode.openai,
              groupValue: _mode,
              onChanged: disabledOpenAiMode
                  ? null
                  : (v) => setState(() {
                      _mode = v!;
                      _markDirty();
                    }),
              title: const Text('OpenAI (grabación + transcripción)'),
              subtitle: Text(
                disabledOpenAiMode
                    ? 'En Web lo activaremos más adelante.'
                    : 'Mejor puntuación/capitalización y más estabilidad en PC.',
              ),
            ),
            const SizedBox(height: 16),
            const _VoiceCommandsBox(),
            const SizedBox(height: 16),
            if (Platform.isWindows) ...[
              const Text(
                'Actualizaciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _launchUpdater,
                icon: const Icon(Icons.system_update),
                label: const Text('Actualizar (Windows)'),
              ),
              const SizedBox(height: 4),
              Text(
                'Abre la última versión en GitHub Releases y descarga el MSIX.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
            if (_saved) const SizedBox(height: 8),
            if (_saved)
              Text(
                'Tip: en Review, el botón ✨ refina puntuación si ya tienes texto.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCommandsBox extends StatelessWidget {
  const _VoiceCommandsBox();

  @override
  Widget build(BuildContext context) {
    final items = const [
      'siguiente / adelante / avanzar / next → ir a la siguiente línea',
      'anterior / atrás / previous → ir a la línea anterior',
      'duda / marcar duda / quitar duda → alternar duda',
      'aceptar / usar / usar voz / confirmar → usar el texto dictado',
      'rechazar / borrar / limpiar → borrar el texto dictado',
      'repetir / otra vez / escuchar de nuevo → volver a escuchar',
      'Otra frase → se guarda como texto dictado',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comandos de voz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $t'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
