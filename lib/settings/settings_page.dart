// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/app_db.dart';
import '../sync/cloud_sync_service.dart';
import '../sync/supabase_manager.dart';
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
  bool _suspendDirty = false;

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
    _syncFromCloud();
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
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
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
        const SnackBar(content: Text('Glossary updated from TXT')),
      );
    }
  }

  void _markDirty() {
    if (_dirty || _suspendDirty) return;
    setState(() {
      _dirty = true;
      _saved = false;
    });
  }

  Future<void> _syncFromCloud() async {
    await _cloud.ensureInit();
    if (!_cloud.isReady) return;
    await _cloud.syncSettingsOnly();
    if (!mounted || _dirty) return;
    _suspendDirty = true;
    _keyCtrl.text = _svc.openAiKey;
    _textModelCtrl.text = _svc.openAiTextModel;
    _sttModelCtrl.text = _svc.openAiSttModel;
    _mode = _svc.voiceInputMode;
    _suspendDirty = false;
    setState(() {});
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit without saving settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save'),
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
        const SnackBar(content: Text('Could not open the update link.')),
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
          title: const Text('Settings'),
          actions: [
            IconButton(
              tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: widget.onToggleTheme,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedBuilder(
              animation: SupabaseManager.instance,
              builder: (context, _) {
                final supabase = SupabaseManager.instance;
                if (!supabase.hasCloudConfig) {
                  return const SizedBox.shrink();
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          supabase.isAuthenticated
                              ? 'Signed in as ${supabase.currentUserEmail ?? 'user without email'}'
                              : 'No active session.',
                        ),
                        if (supabase.isAuthenticated) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await supabase.signOut();
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            if (SupabaseManager.instance.hasCloudConfig)
              const SizedBox(height: 16),
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
                labelText: 'Text model (punctuation / assists)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sttModelCtrl,
              decoration: const InputDecoration(
                labelText: 'STT model (audio→text)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Glossaries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_folders.isEmpty)
              const Text(
                'No folders yet. Create or select a folder to link glossaries.',
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedFolder,
                items: _folders
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.trim().isEmpty ? 'No folder' : f),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Series / Folder',
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
                  labelText: 'Terms (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickTxtForFolder(_selectedFolder),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload TXT'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Voice input',
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
              subtitle: const Text('Fast, but usually without punctuation.'),
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
              title: const Text('OpenAI (recording + transcription)'),
              subtitle: Text(
                disabledOpenAiMode
                    ? 'We will enable this on Web later.'
                    : 'Better punctuation/capitalization and more stability on PC.',
              ),
            ),
            const SizedBox(height: 16),
            const _VoiceCommandsBox(),
            const SizedBox(height: 16),
            const Text(
              'Video sync across devices (R2)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _cloud.isR2Available
                  ? 'R2 configured on this device: yes'
                  : 'R2 configured on this device: no (missing R2_* env vars)',
            ),
            const SizedBox(height: 4),
            Text(
              _cloud.hasR2PublicBase
                  ? 'Public base: ${_cloud.r2PublicBase}'
                  : 'Public base: not configured (R2_PUBLIC_BASE)',
            ),
            const SizedBox(height: 4),
            Text(
              _cloud.isR2Available
                  ? 'Bucket: ${_cloud.r2Bucket ?? '-'}'
                  : 'Bucket: -',
            ),
            const SizedBox(height: 8),
            Text(
              'R2 is only needed to sync and view videos on other devices. '
              'If the project already has a local video, it will keep playing even when R2 is not configured.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (Platform.isWindows) ...[
              const Text(
                'Updates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _launchUpdater,
                icon: const Icon(Icons.system_update),
                label: const Text('Update (Windows)'),
              ),
              const SizedBox(height: 4),
              Text(
                'Opens the latest version in GitHub Releases and downloads the MSIX.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            if (_saved) const SizedBox(height: 8),
            if (_saved)
              Text(
                'Tip: in Review, the ✨ button refines punctuation if you already have text.',
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
      'next / forward / advance → go to the next line',
      'previous / back → go to the previous line',
      'doubt / mark doubt / clear doubt → toggle doubt',
      'accept / use / use voice / confirm → use the dictated text',
      'reject / delete / clear → delete the dictated text',
      'repeat / again / listen again → listen again',
      'Any other phrase → save as dictated text',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice commands',
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
