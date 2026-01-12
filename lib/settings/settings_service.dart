import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum VoiceInputMode { local, openai }

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  SharedPreferences? _prefs;
  String? _deviceId;
  Map<String, String> _glossaryByFolder = {};
  List<String> _manualFolders = [];
  int _manualFoldersUpdatedAtMs = 0;
  int _updatedAtMs = 0;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _deviceId = _prefs?.getString('device_id') ?? const Uuid().v4();
    await _prefs?.setString('device_id', _deviceId!);
    _updatedAtMs = _prefs?.getInt('settings_updated_at_ms') ?? 0;
    final rawMap = _prefs?.getString('stt_glossary_by_folder');
    if (rawMap != null && rawMap.isNotEmpty) {
      try {
        final map = (jsonDecode(rawMap) as Map<String, dynamic>);
        _glossaryByFolder = map.map(
          (k, v) => MapEntry(k, (v as String?) ?? ''),
        );
      } catch (_) {
        _glossaryByFolder = {};
      }
    } else {
      final legacy = _prefs?.getString('stt_glossary') ?? '';
      if (legacy.isNotEmpty) {
        _glossaryByFolder = {'': legacy};
      }
    }

    _manualFolders = _prefs?.getStringList('manual_folders') ?? [];
    _manualFoldersUpdatedAtMs =
        _prefs?.getInt('manual_folders_updated_at_ms') ?? 0;
    if (_manualFoldersUpdatedAtMs == 0 && _manualFolders.isNotEmpty) {
      _manualFoldersUpdatedAtMs = _updatedAtMs;
      if (_manualFoldersUpdatedAtMs == 0) {
        _manualFoldersUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
      }
      await _prefs?.setInt(
        'manual_folders_updated_at_ms',
        _manualFoldersUpdatedAtMs,
      );
    }

    // Deja updated_at_ms en 0 hasta que haya un cambio real de ajustes.
  }

  String get openAiKey => _prefs?.getString('openai_key') ?? '';
  Future<void> setOpenAiKey(String v) async {
    await init();
    await _prefs!.setString('openai_key', v.trim());
    await _touchUpdatedAt();
  }

  String get openAiTextModel =>
      _prefs?.getString('openai_text_model') ?? 'gpt-4o-mini';
  Future<void> setOpenAiTextModel(String v) async {
    await init();
    await _prefs!.setString('openai_text_model', v.trim());
    await _touchUpdatedAt();
  }

  String get openAiSttModel =>
      _prefs?.getString('openai_stt_model') ?? 'gpt-4o-mini-transcribe';
  Future<void> setOpenAiSttModel(String v) async {
    await init();
    await _prefs!.setString('openai_stt_model', v.trim());
    await _touchUpdatedAt();
  }

  VoiceInputMode get voiceInputMode {
    final raw = _prefs?.getString('voice_input_mode') ?? 'local';
    return raw == 'openai' ? VoiceInputMode.openai : VoiceInputMode.local;
  }

  Future<void> setVoiceInputMode(VoiceInputMode mode) async {
    await init();
    await _prefs!.setString(
      'voice_input_mode',
      mode == VoiceInputMode.openai ? 'openai' : 'local',
    );
    await _touchUpdatedAt();
  }

  bool get hasOpenAiKey => openAiKey.isNotEmpty;

  String get deviceId {
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      _prefs?.setString('device_id', _deviceId!);
    }
    return _deviceId!;
  }

  String get sttGlossary => getGlossaryForFolder('');
  Future<void> setSttGlossary(String v) => setGlossaryForFolder('', v);

  String getGlossaryForFolder(String folder) {
    return _glossaryByFolder[folder] ?? '';
  }

  Future<void> setGlossaryForFolder(String folder, String v) async {
    await init();
    final trimmed = v.trim();
    _glossaryByFolder[folder] = trimmed;
    await _prefs!.setString(
      'stt_glossary_by_folder',
      jsonEncode(_glossaryByFolder),
    );
    await _touchUpdatedAt();
  }

  List<String> get manualFolders => List.unmodifiable(_manualFolders);
  int get manualFoldersUpdatedAtMs => _manualFoldersUpdatedAtMs;

  Future<void> setManualFolders(Iterable<String> folders) async {
    await init();
    final deduped = {for (final f in folders) f.trim()}
      ..removeWhere((e) => e.isEmpty);
    _manualFolders = deduped.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await _prefs?.setStringList('manual_folders', _manualFolders);
    _manualFoldersUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(
      'manual_folders_updated_at_ms',
      _manualFoldersUpdatedAtMs,
    );
  }

  int get settingsUpdatedAtMs => _updatedAtMs;

  Future<void> _touchUpdatedAt() async {
    _updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt('settings_updated_at_ms', _updatedAtMs);
  }

  Map<String, dynamic> exportSyncPayload() {
    return {
      'updated_at_ms': _updatedAtMs,
      'device_id': deviceId,
      'openai_key': openAiKey,
      'openai_text_model': openAiTextModel,
      'openai_stt_model': openAiSttModel,
      'voice_input_mode': voiceInputMode == VoiceInputMode.openai
          ? 'openai'
          : 'local',
      'glossary_by_folder': _glossaryByFolder,
      'manual_folders': _manualFolders,
      'manual_folders_updated_at_ms': _manualFoldersUpdatedAtMs,
    };
  }

  Future<bool> importSyncPayload(
    Map<String, dynamic> payload, {
    bool includeManualFolders = true,
  }) async {
    await init();
    final remoteUpdated = payload['updated_at_ms'] as int? ?? 0;
    if (remoteUpdated <= _updatedAtMs) return false;

    final prefs = _prefs!;
    await prefs.setString(
      'openai_key',
      (payload['openai_key'] as String? ?? '').trim(),
    );
    await prefs.setString(
      'openai_text_model',
      (payload['openai_text_model'] as String? ?? '').trim(),
    );
    await prefs.setString(
      'openai_stt_model',
      (payload['openai_stt_model'] as String? ?? '').trim(),
    );

    final modeRaw = (payload['voice_input_mode'] as String? ?? 'local')
        .toLowerCase();
    await prefs.setString(
      'voice_input_mode',
      modeRaw == 'openai' ? 'openai' : 'local',
    );

    final gloss =
        (payload['glossary_by_folder'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    _glossaryByFolder = gloss.map((k, v) => MapEntry(k, (v as String?) ?? ''));
    await prefs.setString(
      'stt_glossary_by_folder',
      jsonEncode(_glossaryByFolder),
    );

    if (includeManualFolders) {
      final manual =
          (payload['manual_folders'] as List?)?.cast<String>() ??
          const <String>[];
      _manualFolders = ({for (final f in manual) f.trim()}
        ..removeWhere((e) => e.isEmpty)).toList();
      _manualFolders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await prefs.setStringList('manual_folders', _manualFolders);
      _manualFoldersUpdatedAtMs =
          payload['manual_folders_updated_at_ms'] as int? ?? remoteUpdated;
      await prefs.setInt(
        'manual_folders_updated_at_ms',
        _manualFoldersUpdatedAtMs,
      );
    }

    _updatedAtMs = remoteUpdated;
    await prefs.setInt('settings_updated_at_ms', _updatedAtMs);
    return true;
  }

  Future<void> setManualFoldersFromSync(
    Iterable<String> folders,
    int updatedAtMs,
  ) async {
    await init();
    final deduped = {for (final f in folders) f.trim()}
      ..removeWhere((e) => e.isEmpty);
    _manualFolders = deduped.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _manualFoldersUpdatedAtMs = updatedAtMs;
    await _prefs?.setStringList('manual_folders', _manualFolders);
    await _prefs?.setInt(
      'manual_folders_updated_at_ms',
      _manualFoldersUpdatedAtMs,
    );
  }
}
