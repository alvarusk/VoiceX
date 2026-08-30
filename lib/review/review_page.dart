import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

import '../commands/command_router.dart';
import '../costs/api_cost_logger.dart';
import '../db/app_db.dart';
import '../openai/openai_service.dart';
import '../settings/settings_service.dart';
import '../stt/speech_service.dart';
import '../metrics/metrics_page.dart';
import 'review_service.dart';
import '../sync/cloud_sync_service.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.db, required this.projectId});
  final AppDatabase db;
  final String projectId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final ReviewService _svc = ReviewService(widget.db);
  late final CloudSyncService _cloud = CloudSyncService(widget.db);
  final ApiCostLogger _costLogger = ApiCostLogger();
  final _speech = SpeechService.instance;
  String? _localeId;
  double _videoHeight = 260;
  double _topPaneRatio = 0.6;
  bool _showVideoPanel = true;
  bool _showPromptPanel = true;
  bool _handlingPop = false;
  bool _sessionStarted = false;
  String _currentSubtitleText(SubtitleLine? line) {
    if (line == null) return '';
    final sel = _stripSubtitleTags(line.selectedText ?? '');
    if (sel.isNotEmpty) return sel;
    final src = _stripSubtitleTags(line.sourceText ?? '');
    if (src.isNotEmpty) return src;
    return _stripSubtitleTags(line.originalText);
  }

  String _stripSubtitleTags(String text) {
    // Remove ASS-style tags like {italic} or romaji annotations from overlay.
    final noTags = text.replaceAll(RegExp(r'\{[^}]*\}'), '');
    return noTags.trim();
  }

  String _currentPromptText(SubtitleLine? line) {
    if (line == null || line.dialogueIndex >= _asrPrompts.length) return '';
    return _asrPrompts[line.dialogueIndex];
  }

  void _cacheLineText(SubtitleLine line) {
    _lineTextCache[line.lineId] = _currentSubtitleText(line);
  }

  String _textFromTiming(LineTiming timing) {
    if (_currentLine?.lineId == timing.lineId) {
      return _currentSubtitleText(_currentLine);
    }
    final cached = _lineTextCache[timing.lineId];
    if (cached != null) return cached;
    final selected = _stripSubtitleTags(timing.selectedText ?? '');
    if (selected.isNotEmpty) return selected;
    final source = _stripSubtitleTags(timing.sourceText ?? '');
    if (source.isNotEmpty) return source;
    return _stripSubtitleTags(timing.originalText);
  }

  void _startSession(String projectId) {
    if (_sessionStarted) return;
    _sessionStarted = true;
    final platform = _platformName();
    unawaited(
      _svc.startSession(projectId, platform).catchError((error) {
        debugPrint('Could not start review session: $error');
      }),
    );
  }

  void _endSession() {
    if (!_sessionStarted) return;
    unawaited(
      _svc.endSession(widget.projectId).catchError((error) {
        debugPrint('Could not end review session: $error');
      }),
    );
    _sessionStarted = false;
  }

  Future<bool> _confirmExitIfDirty(Project project) async {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return true; // aviso solo en m¢vil

    final dirty = await _cloud.isProjectDirty(project.projectId);
    if (!dirty) return true;
    if (!mounted) return false;

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit without saving?'),
        content: const Text(
          'There are local changes that have not been uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('exit'),
            child: const Text('Exit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res == 'exit') return true;
    if (res == 'save') {
      await _saveToCloud(project);
      return true;
    }
    return false;
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Duration get _reviewTimerValue {
    if (!_reviewTimerRunning || _reviewTimerStartedAt == null) {
      return _reviewTimerElapsed;
    }
    return _reviewTimerElapsed +
        DateTime.now().difference(_reviewTimerStartedAt!);
  }

  void _toggleReviewTimer() {
    setState(() {
      if (_reviewTimerRunning) {
        if (_reviewTimerStartedAt != null) {
          _reviewTimerElapsed += DateTime.now().difference(
            _reviewTimerStartedAt!,
          );
        }
        _reviewTimerStartedAt = null;
        _reviewTimerRunning = false;
        _reviewTimerTicker?.cancel();
        _reviewTimerTicker = null;
      } else {
        _reviewTimerStartedAt = DateTime.now();
        _reviewTimerRunning = true;
        _reviewTimerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && _reviewTimerRunning) {
            setState(() {});
          }
        });
      }
    });
  }

  void _resetReviewTimer() {
    setState(() {
      _reviewTimerElapsed = Duration.zero;
      _reviewTimerStartedAt = _reviewTimerRunning ? DateTime.now() : null;
      if (!_reviewTimerRunning) {
        _reviewTimerTicker?.cancel();
        _reviewTimerTicker = null;
      }
    });
  }

  PageController? _pageController;
  VideoPlayerController? _videoController;
  Future<void>? _videoInit;
  String? _videoPath;
  bool _videoError = false;
  bool _videoDisposed = false;
  SubtitleLine? _currentLine;
  Future<List<LineTiming>>? _timingsFuture;
  List<LineTiming> _lineTimings = const [];
  final Map<String, String> _lineTextCache = {};
  List<String> _asrPrompts = const [];
  String? _asrPromptsProjectId;

  // Toggles de visibilidad (MVP: en memoria)
  bool showGpt = true;
  bool showClaude = true;
  bool showGemini = true;
  bool showDeepseek = true;

  Timer? _reviewTimerTicker;
  Duration _reviewTimerElapsed = Duration.zero;
  DateTime? _reviewTimerStartedAt;
  bool _reviewTimerRunning = false;
  Timer? _segmentStopTimer;
  int _lineChangeToken = 0;

  // Navegación
  bool skipReviewedOnAdvance = false;
  bool _initialSeekDone = false;

  // OpenAI STT (record)
  final _rec = AudioRecorder();
  bool _recBusy = false;
  bool _isRecording = false;
  bool _savingCloud = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      _videoHeight = 220;
      _showPromptPanel = false;
    }
    _initSpeechLocale();
    _speech.listening.addListener(() {
      if (mounted) setState(() {});
    });
    _speech.available.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initSpeechLocale() async {
    final ok = await _speech.ensureInitialized();
    if (!ok) return;
    final locales = await _speech.locales();
    if (locales.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'STT: no voice packages are installed on Windows. Add a voice language in Settings.',
            ),
          ),
        );
      }
      return;
    }
    // Preferimos es-ES si existe
    _localeId = locales
        .firstWhere(
          (l) => l.localeId.toLowerCase().startsWith('es'),
          orElse: () => locales.first,
        )
        .localeId;
    setState(() {});
  }

  Future<void> _ensureVideo(Project project) async {
    if (!mounted || _videoDisposed || _videoInit != null || _videoError) return;

    final path = await _svc.getVideoPath(project.projectId);
    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _videoPath = path;
        });
      }
      return;
    }
    final resolved = await _cloud.resolveVideoUrl(path);
    debugPrint('Intentando cargar video: $path');

    final isRemote =
        resolved.startsWith('http://') || resolved.startsWith('https://');
    try {
      File? localFile;
      if (!isRemote) {
        localFile = File(resolved);
        if (!await localFile.exists()) {
          debugPrint('Video not found at path: $path');
          if (mounted) {
            setState(() {
              _videoPath = '';
              _videoError = true;
            });
          }
          return;
        }
      }

      final initCompleter = Completer<void>();
      _videoInit = initCompleter.future;

      Object? lastError;
      for (final viewType in _videoViewTypesForCurrentPlatform()) {
        final ctrl = isRemote
            ? VideoPlayerController.networkUrl(
                Uri.parse(resolved),
                viewType: viewType,
              )
            : VideoPlayerController.file(localFile!, viewType: viewType);
        try {
          await ctrl.initialize();
          await ctrl.setVolume(1.0);
          if (!mounted || _videoDisposed) {
            if (!initCompleter.isCompleted) initCompleter.complete();
            await ctrl.dispose();
            return;
          }
          _videoController = ctrl;
          _videoPath = resolved;
          if (!initCompleter.isCompleted) {
            initCompleter.complete();
          }
          if (mounted) {
            setState(() {});
          }
          return;
        } catch (err) {
          lastError = err;
          debugPrint(
            'Error al inicializar video (${viewType.name}) para $resolved: $err',
          );
          await ctrl.dispose();
        }
      }

      if (isRemote && !kIsWeb) {
        final cachedPath = await _cloud.materializeRemoteVideo(
          project.projectId,
          resolved,
        );
        if (cachedPath != null && cachedPath.isNotEmpty) {
          final cachedFile = File(cachedPath);
          if (await cachedFile.exists()) {
            for (final viewType in _videoViewTypesForCurrentPlatform()) {
              final ctrl = VideoPlayerController.file(
                cachedFile,
                viewType: viewType,
              );
              try {
                await ctrl.initialize();
                await ctrl.setVolume(1.0);
                if (!mounted || _videoDisposed) {
                  if (!initCompleter.isCompleted) initCompleter.complete();
                  await ctrl.dispose();
                  return;
                }
                _videoController = ctrl;
                _videoPath = cachedPath;
                if (!initCompleter.isCompleted) {
                  initCompleter.complete();
                }
                if (mounted) {
                  setState(() {});
                }
                return;
              } catch (err) {
                lastError = err;
                debugPrint(
                  'Error al inicializar video cacheado (${viewType.name}) para $cachedPath: $err',
                );
                await ctrl.dispose();
              }
            }
          }
        }
      }

      throw lastError ?? StateError('Could not initialize the video.');
    } catch (e, st) {
      debugPrint('Error al preparar video: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          _videoController = null;
          _videoInit = null;
          _videoError = true;
          _videoPath = path;
        });
      }
    }
  }

  List<VideoViewType> _videoViewTypesForCurrentPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const [VideoViewType.textureView, VideoViewType.platformView];
    }
    return const [VideoViewType.textureView];
  }

  Future<void> _ensureAsrPrompts(Project project) async {
    if (_asrPromptsProjectId == project.projectId) return;
    _asrPromptsProjectId = project.projectId;
    final prompts = await _svc.loadAsrPrompts(project.projectId);
    if (mounted) setState(() => _asrPrompts = prompts);
  }

  Future<void> _seekVideoForIndex(String projectId, int idx) async {
    if (_videoController == null || _videoInit == null) return;
    try {
      await _videoInit;
      final line = await _svc.watchLine(projectId, idx).first;
      await _seekVideoTo(line.startMs);
    } catch (_) {}
  }

  Future<SubtitleLine?> _lineForIndex(String projectId, int idx) async {
    try {
      return await _svc.watchLine(projectId, idx).first;
    } catch (_) {}
    return null;
  }

  Future<void> _seekVideoTo(int ms) async {
    if (_videoController == null || _videoInit == null) return;
    try {
      await _videoInit;
      await _videoController!.seekTo(Duration(milliseconds: ms));
    } catch (_) {}
  }

  Future<void> _nudgeVideo(Duration delta) async {
    if (_videoController == null || _videoInit == null) return;
    try {
      await _videoInit;
      final pos = await _videoController!.position ?? Duration.zero;
      final target = pos + delta;
      await _videoController!.seekTo(
        target.isNegative ? Duration.zero : target,
      );
    } catch (_) {}
  }

  Future<void> _togglePlayPause() async {
    if (_videoController == null || _videoInit == null) return;
    await _videoInit;
    if (_videoController!.value.isPlaying) {
      await _videoController!.pause();
    } else {
      await _videoController!.play();
    }
    setState(() {});
  }

  Future<void> _ensurePageController(Project project) async {
    _pageController ??= PageController(initialPage: project.currentIndex);
  }

  Future<void> _ensureTimingsFuture(String projectId) async {
    _timingsFuture ??= _svc.fetchLineTimings(projectId);
    final list = await _timingsFuture!;
    if (mounted) {
      setState(() {
        _lineTimings = list;
      });
    }
  }

  Future<void> _handleLineChange(
    Project project,
    int idx, {
    required bool autoplay,
  }) async {
    final token = ++_lineChangeToken;
    await _svc.setCurrentIndex(project.projectId, idx);
    if (token != _lineChangeToken) return;

    final line = await _lineForIndex(project.projectId, idx);
    if (line == null || token != _lineChangeToken) return;

    _segmentStopTimer?.cancel();
    await _seekVideoTo(line.startMs);
    if (token != _lineChangeToken) return;

    if (autoplay) {
      await _playSegment(line, seekFirst: false);
    }
  }

  Future<void> _jumpToIndex(Project project, int idx) async {
    if (_pageController?.hasClients == true) {
      await _pageController!.animateToPage(
        idx,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }
    if (idx == project.currentIndex) return;
    await _handleLineChange(project, idx, autoplay: project.autoPlayLine);
  }

  Future<void> _gotoNextUnreviewed(Project project) async {
    final next = await _svc.findNextUnreviewed(
      project.projectId,
      project.currentIndex,
    );
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No more lines to review.')));
      return;
    }
    await _jumpToIndex(project, next);
  }

  Future<void> _gotoNextDoubt(Project project) async {
    final next = await _svc.findNextDoubt(
      project.projectId,
      project.currentIndex,
    );
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No more doubts.')));
      return;
    }
    await _jumpToIndex(project, next);
  }

  Future<void> _gotoNext(Project project, int total) async {
    final target = (project.currentIndex + 1).clamp(0, total - 1);
    if (target == project.currentIndex) {
      _showSnack('This is the last line.');
      return;
    }
    await _jumpToIndex(project, target);
  }

  Future<void> _gotoPrevious(Project project) async {
    final target = (project.currentIndex - 1).clamp(0, project.currentIndex);
    if (target == project.currentIndex) {
      _showSnack('You are already on the first line.');
      return;
    }
    await _jumpToIndex(project, target);
  }

  Future<void> _openTools(Project project) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        var autoPlayLineEnabled = project.autoPlayLine;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              SwitchListTile(
                title: const Text('Skip reviewed lines when advancing'),
                value: skipReviewedOnAdvance,
                onChanged: (v) => setState(() => skipReviewedOnAdvance = v),
              ),
              ListTile(
                leading: const Icon(Icons.skip_next),
                title: const Text('Go to next unreviewed line'),
                onTap: () {
                  Navigator.pop(context);
                  _gotoNextUnreviewed(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Go to next doubt'),
                onTap: () {
                  Navigator.pop(context);
                  _gotoNextDoubt(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_file),
                title: const Text('Assign or change video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAttachVideo(project);
                },
              ),
              StatefulBuilder(
                builder: (context, setModalState) {
                  return SwitchListTile(
                    title: const Text('Autoplay current line'),
                    subtitle: const Text(
                      'Seek and play the line every time you change it.',
                    ),
                    value: autoPlayLineEnabled,
                    onChanged: (v) {
                      setModalState(() => autoPlayLineEnabled = v);
                      unawaited(_svc.setAutoPlayLine(project.projectId, v));
                    },
                  );
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Show GPT'),
                value: showGpt,
                onChanged: (v) => setState(() => showGpt = v),
              ),
              SwitchListTile(
                title: const Text('Show Claude'),
                value: showClaude,
                onChanged: (v) => setState(() => showClaude = v),
              ),
              SwitchListTile(
                title: const Text('Show Gemini'),
                value: showGemini,
                onChanged: (v) => setState(() => showGemini = v),
              ),
              SwitchListTile(
                title: const Text('Show DeepSeek'),
                value: showDeepseek,
                onChanged: (v) => setState(() => showDeepseek = v),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndAttachVideo(Project project) async {
    if (kIsWeb) {
      _showSnack('Assigning video is not available on Web.');
      return;
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _allowedVideoExtensions,
    );
    if (file == null) return;
    final path = file.path;
    if (path == null || path.isEmpty) {
      _showSnack('Could not read the video file.');
      return;
    }
    try {
      await _svc.attachVideo(projectId: project.projectId, sourcePath: path);
      if (!mounted) return;
      _videoController?.dispose();
      _videoController = null;
      _videoInit = null;
      _videoError = false;
      _videoPath = null;
      _initialSeekDone = false;
      await _ensureVideo(project);
      _showSnack('Video updated.');
    } catch (e) {
      debugPrint('attach video error: $e');
      _showSnack('Could not update the video.');
    }
  }

  List<String> get _allowedVideoExtensions =>
      defaultTargetPlatform == TargetPlatform.android
      ? const ['mp4']
      : const ['mp4', 'mkv', 'mov'];

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCandidate({
    required Project project,
    required SubtitleLine line,
    required String source,
    required String text,
    required String method,
  }) async {
    await _svc.chooseCandidate(
      projectId: project.projectId,
      lineId: line.lineId,
      source: source,
      text: text,
      method: method,
    );

    // Avanza
    final total = await _svc.watchTotalLines(project.projectId).first;
    final current = line.dialogueIndex;

    int? next;
    if (skipReviewedOnAdvance) {
      next = await _svc.findNextUnreviewed(project.projectId, current);
    }
    next ??= (current + 1 < total) ? current + 1 : null;

    if (next != null) {
      await _jumpToIndex(project, next);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('End of project.')));
    }
  }

  Future<void> _toggleDoubt(SubtitleLine line) async {
    await _svc.toggleDoubt(line.lineId, !line.doubt);
  }

  Future<void> _setVoiceText(SubtitleLine line, String? text) async {
    await _svc.setVoiceText(line.lineId, text);
  }

  Future<void> _playSegment(SubtitleLine line, {bool seekFirst = true}) async {
    if (_videoController == null || _videoInit == null) return;
    final start = Duration(milliseconds: line.startMs);
    final end = Duration(milliseconds: line.endMs);
    final dur = end - start;
    if (dur <= Duration.zero) return;

    try {
      await _videoInit;
      _segmentStopTimer?.cancel();
      if (seekFirst) {
        await _videoController!.seekTo(start);
      }
      await _videoController!.play();
      _segmentStopTimer = Timer(dur, () async {
        final controller = _videoController;
        if (!mounted || controller == null || !controller.value.isInitialized) {
          return;
        }
        await controller.pause();
        if (mounted) setState(() {});
      });
      setState(() {});
    } catch (_) {}
  }

  Future<String?> _promptEdit(
    SubtitleLine line,
    String title,
    String initial,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _EditDialog(title: title, initial: initial, line: line),
    );
  }

  Future<void> _editCandidateText(
    SubtitleLine line,
    String source,
    String current,
  ) async {
    final edited = await _promptEdit(line, 'Edit $source', current);
    if (edited == null) return;
    await _svc.setCandidateText(
      lineId: line.lineId,
      source: source,
      text: edited,
    );
    await _svc.chooseCandidate(
      projectId: line.projectId,
      lineId: line.lineId,
      source: source,
      text: edited,
      method: 'edit',
    );
  }

  // -------- Voice input

  Future<void> _handleVoiceInputResult(
    String txt,
    Project project,
    SubtitleLine line,
    int total,
  ) async {
    final route = CommandRouter.instance.route(txt);
    debugPrint(
      'Voice input: "${route.normalized ?? txt}" -> ${route.action ?? 'text'}',
    );

    if (!route.isCommand) {
      await _setVoiceText(line, txt);
      return;
    }

    await _handleCommandAction(route.action!, project, line, total);
  }

  Future<void> _handleCommandAction(
    CommandAction action,
    Project project,
    SubtitleLine line,
    int total,
  ) async {
    switch (action) {
      case CommandAction.next:
        await _gotoNext(project, total);
        break;
      case CommandAction.previous:
        await _gotoPrevious(project);
        break;
      case CommandAction.toggleDoubt:
        await _toggleDoubt(line);
        _showSnack('Duda actualizada.');
        break;
      case CommandAction.acceptVoice:
        final voice = line.candVoice?.trim() ?? '';
        if (voice.isEmpty) {
          _showSnack('There is no voice text to use.');
          return;
        }
        await _pickCandidate(
          project: project,
          line: line,
          source: 'voice',
          text: voice,
          method: 'voice-command',
        );
        break;
      case CommandAction.clearVoice:
        await _setVoiceText(line, '');
        _showSnack('Texto de voz borrado.');
        break;
      case CommandAction.repeat:
        await _speech.stop();
        await _startLocalListening(project, line, total);
        _showSnack('Listening again.');
        break;
    }
  }

  Future<void> _startLocalListening(
    Project project,
    SubtitleLine line,
    int total,
  ) async {
    await _speech.listen(
      localeId: _localeId,
      onResult: (txt) async {
        await _handleVoiceInputResult(txt, project, line, total);
      },
    );
    setState(() {});
  }

  Future<void> _toggleVoiceInput(
    Project project,
    SubtitleLine line,
    int total,
  ) async {
    final settings = SettingsService.instance;

    if (settings.voiceInputMode == VoiceInputMode.openai) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OpenAI STT on Web: we will enable it later.'),
          ),
        );
        return;
      }
      await _toggleOpenAiRecording(project, line);
      return;
    }

    // Local STT
    final ok = await _speech.ensureInitialized();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('speech_to_text is not available on this device.'),
        ),
      );
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() {});
      return;
    }

    await _startLocalListening(project, line, total);
  }

  Future<void> _toggleOpenAiRecording(
    Project project,
    SubtitleLine line,
  ) async {
    if (_recBusy) return;
    final settings = SettingsService.instance;
    if (!settings.hasOpenAiKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing API key in Settings.')),
      );
      return;
    }

    setState(() => _recBusy = true);
    try {
      final hasPerm = await _rec.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No microphone permission.')),
        );
        return;
      }

      if (!_isRecording) {
        // Grabar a WAV (fácil para OpenAI). Usamos cache/temporal para Android/iOS.
        final tmpDir = await getTemporaryDirectory();
        final recPath = p.join(tmpDir.path, 'voicex_record.wav');
        await _rec.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: recPath,
        );
        setState(() => _isRecording = true);
        return;
      }

      final path = await _rec.stop();
      setState(() => _isRecording = false);
      if (path == null) return;

      final client = OpenAiService(apiKey: settings.openAiKey);
      final glossary = settings.getGlossaryForFolder(project.folder).trim();
      String? prompt;
      if (glossary.isNotEmpty) {
        prompt =
            '''
Transcribe into Spanish, preserving these names and terms exactly as written (even if the pronunciation sounds different):
$glossary
If in doubt, prefer these spellings as-is.
''';
      }
      final result = await client.transcribeAudioFile(
        filePath: path,
        model: settings.openAiSttModel,
        language: 'es',
        prompt: prompt,
      );
      await _costLogger.logOpenAiUsage(
        project: project,
        model: result.model,
        usage: result.usage,
      );
      final text = result.text;
      await _setVoiceText(line, text);
    } finally {
      if (mounted) setState(() => _recBusy = false);
    }
  }

  Future<void> _refineVoiceWithOpenAi(
    Project project,
    SubtitleLine line,
  ) async {
    final settings = SettingsService.instance;
    if (!settings.hasOpenAiKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set the API key in Settings.')),
      );
      return;
    }
    final raw = line.candVoice?.trim() ?? '';
    if (raw.isEmpty) return;

    final client = OpenAiService(apiKey: settings.openAiKey);
    final refined = await client.refineSpanishPunctuation(
      text: raw,
      model: settings.openAiTextModel,
    );
    await _costLogger.logOpenAiUsage(
      project: project,
      model: refined.model,
      usage: refined.usage,
    );

    await _setVoiceText(line, refined.text);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Punctuation refined ✨')));
  }

  // --------

  @override
  void dispose() {
    _videoDisposed = true;
    _endSession();
    _reviewTimerTicker?.cancel();
    _segmentStopTimer?.cancel();
    _pageController?.dispose();
    final controller = _videoController;
    _videoController = null;
    controller?.dispose();
    _speech.stop();
    _speech.cancel();
    _rec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project>(
      stream: _svc.watchProject(widget.projectId),
      builder: (context, snapProject) {
        final project = snapProject.data;
        if (project == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        _startSession(project.projectId);

        _ensurePageController(project);
        _ensureVideo(project);
        _ensureAsrPrompts(project);
        _ensureTimingsFuture(project.projectId);
        if (!_initialSeekDone) {
          _initialSeekDone = true;
          _seekVideoForIndex(project.projectId, project.currentIndex);
        }

        final isMobile =
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS;
        return PopScope(
          canPop: !isMobile,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !isMobile) return;
            if (_handlingPop) return;
            _handlingPop = true;
            try {
              final shouldPop = await _confirmExitIfDirty(project);
              if (shouldPop && context.mounted) Navigator.of(context).pop();
            } catch (e) {
              debugPrint('Error while leaving project: $e');
            } finally {
              _handlingPop = false;
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Tooltip(
                message: project.folder.trim().isNotEmpty
                    ? '${project.folder.trim()} > ${project.title}'
                    : project.title,
                waitDuration: const Duration(milliseconds: 400),
                child: Text(
                  project.folder.trim().isNotEmpty
                      ? '${project.folder.trim()} > ${project.title}'
                      : project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              actions: [
                FutureBuilder<bool>(
                  future: _cloud.isProjectDirty(project.projectId),
                  builder: (context, snapDirty) {
                    final dirty = snapDirty.data ?? true;
                    final icon = dirty ? Icons.cloud_upload : Icons.cloud_done;
                    final color = dirty ? Colors.orange : null;
                    final tooltip = dirty
                        ? 'Save (local changes not uploaded yet)'
                        : 'Saved to cloud';
                    return IconButton(
                      icon: Icon(icon, color: color),
                      tooltip: tooltip,
                      onPressed: _savingCloud
                          ? null
                          : () => _saveToCloud(project),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.playlist_play,
                    color: project.autoPlayLine ? Colors.green : Colors.grey,
                  ),
                  tooltip: project.autoPlayLine
                      ? 'Autoplay line segment: on'
                      : 'Autoplay line segment: off',
                  onPressed: () => unawaited(
                    _svc.setAutoPlayLine(
                      project.projectId,
                      !project.autoPlayLine,
                    ),
                  ),
                ),
                StreamBuilder<int>(
                  stream: _svc.watchTotalLines(widget.projectId),
                  builder: (context, totalSnap) {
                    final total = totalSnap.data ?? 0;
                    final currentLine = project.currentIndex + 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _LineJumpCounter(
                        currentLine: currentLine,
                        total: total,
                        onJump: (lineNumber) =>
                            _jumpToIndex(project, lineNumber - 1),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Metrics',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MetricsPage(
                          db: widget.db,
                          projectId: project.projectId,
                          projectTitle: project.title,
                          projectFolder: project.folder,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openTools(project),
                  tooltip: 'Tools',
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _svc.exportAndShareProject(
                    context,
                    projectId: project.projectId,
                  ),
                  tooltip: 'Export final ASS',
                ),
              ],
            ),
            body: StreamBuilder<int>(
              stream: _svc.watchTotalLines(widget.projectId),
              builder: (context, snapTotal) {
                final total = snapTotal.data ?? 0;
                if (total == 0) {
                  return const Center(child: Text('No lines.'));
                }

                final timingsFuture =
                    _timingsFuture ?? _svc.fetchLineTimings(project.projectId);
                _timingsFuture = timingsFuture;

                return FutureBuilder<List<LineTiming>>(
                  future: timingsFuture,
                  builder: (context, linesSnap) {
                    final timings = linesSnap.data ?? _lineTimings;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobilePlatform =
                            defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS;
                        final useStackedLayout =
                            isMobilePlatform || constraints.maxWidth < 720;

                        if (useStackedLayout) {
                          final screenHeight = MediaQuery.sizeOf(
                            context,
                          ).height;
                          final pageHeight = math
                              .max(520.0, screenHeight * 0.72)
                              .toDouble();
                          final mobilePromptHeight = screenHeight * 0.24 < 120
                              ? 120.0
                              : math.min(220.0, screenHeight * 0.24).toDouble();

                          return Stack(
                            children: [
                              SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  0,
                                  0,
                                  104,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        8,
                                        12,
                                        0,
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FilterChip(
                                              selected: _showVideoPanel,
                                              label: const Text('Video'),
                                              avatar: const Icon(
                                                Icons.video_file,
                                                size: 18,
                                              ),
                                              showCheckmark: false,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              onSelected: (selected) {
                                                setState(() {
                                                  _showVideoPanel = selected;
                                                });
                                              },
                                            ),
                                            FilterChip(
                                              selected: _showPromptPanel,
                                              label: const Text('Prompt'),
                                              avatar: const Icon(
                                                Icons.notes,
                                                size: 18,
                                              ),
                                              showCheckmark: false,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              onSelected: (selected) {
                                                setState(() {
                                                  _showPromptPanel = selected;
                                                });
                                              },
                                            ),
                                            _ReviewTimerControl(
                                              elapsed: _reviewTimerValue,
                                              running: _reviewTimerRunning,
                                              onToggle: _toggleReviewTimer,
                                              onReset: _resetReviewTimer,
                                              dense: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_showVideoPanel)
                                      _VideoPanel(
                                        controller: _videoController,
                                        initFuture: _videoInit,
                                        error: _videoError,
                                        videoPath: _videoPath,
                                        subtitle: _currentSubtitleText(
                                          _currentLine,
                                        ),
                                        lineTimings: timings,
                                        getLineText: _textFromTiming,
                                        subtitleStartMs: _currentLine?.startMs,
                                        subtitleEndMs: _currentLine?.endMs,
                                        height: _videoHeight,
                                        onDragResize: (delta) {
                                          final next =
                                              (_videoHeight + delta * 0.8)
                                                  .clamp(180, 520);
                                          setState(
                                            () =>
                                                _videoHeight = next.toDouble(),
                                          );
                                        },
                                        onBack: () => _nudgeVideo(
                                          const Duration(seconds: -5),
                                        ),
                                        onPlayPause: _togglePlayPause,
                                        onPlaySegment: () {
                                          final line = _currentLine;
                                          if (line != null) {
                                            _playSegment(line);
                                          }
                                        },
                                        onForward: () => _nudgeVideo(
                                          const Duration(seconds: 5),
                                        ),
                                        onPrevLine: () =>
                                            _gotoPrevious(project),
                                        onNextLine: () =>
                                            _gotoNext(project, total),
                                        onHeightChanged: (h) =>
                                            setState(() => _videoHeight = h),
                                      ),
                                    if (_showPromptPanel)
                                      _TranscriberPromptPanel(
                                        promptText: _currentPromptText(
                                          _currentLine,
                                        ),
                                        maxHeight: mobilePromptHeight,
                                        margin: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          8,
                                        ),
                                      ),
                                    SizedBox(
                                      height: pageHeight,
                                      child: _buildLinePager(
                                        project: project,
                                        total: total,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 16,
                                bottom: 16,
                                child: SafeArea(
                                  minimum: const EdgeInsets.only(bottom: 8),
                                  child: Opacity(
                                    opacity: 0.65,
                                    child: FloatingActionButton(
                                      heroTag: 'review-mic',
                                      onPressed:
                                          _currentLine == null || _recBusy
                                          ? null
                                          : () => _toggleVoiceInput(
                                              project,
                                              _currentLine!,
                                              total,
                                            ),
                                      child: const Icon(Icons.mic),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        const splitterWidth = 14.0;
                        final availableWidth = math.max(
                          0.0,
                          constraints.maxWidth - splitterWidth,
                        );
                        final minPaneWidth = availableWidth < 520
                            ? math.max(120.0, availableWidth * 0.28)
                            : 220.0;
                        final leftWidth = (availableWidth * _topPaneRatio)
                            .clamp(
                              minPaneWidth,
                              math.max(
                                minPaneWidth,
                                availableWidth - minPaneWidth,
                              ),
                            )
                            .toDouble();
                        final rightWidth = math.max(
                          minPaneWidth,
                          availableWidth - leftWidth,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: leftWidth,
                                    child: _VideoPanel(
                                      controller: _videoController,
                                      initFuture: _videoInit,
                                      error: _videoError,
                                      videoPath: _videoPath,
                                      subtitle: _currentSubtitleText(
                                        _currentLine,
                                      ),
                                      lineTimings: timings,
                                      getLineText: _textFromTiming,
                                      subtitleStartMs: _currentLine?.startMs,
                                      subtitleEndMs: _currentLine?.endMs,
                                      height: _videoHeight,
                                      onDragResize: (delta) {
                                        final next =
                                            (_videoHeight + delta * 0.8).clamp(
                                              140,
                                              520,
                                            );
                                        setState(
                                          () => _videoHeight = next.toDouble(),
                                        );
                                      },
                                      onBack: () => _nudgeVideo(
                                        const Duration(seconds: -5),
                                      ),
                                      onPlayPause: _togglePlayPause,
                                      onPlaySegment: () {
                                        final line = _currentLine;
                                        if (line != null) {
                                          _playSegment(line);
                                        }
                                      },
                                      onForward: () => _nudgeVideo(
                                        const Duration(seconds: 5),
                                      ),
                                      onPrevLine: () => _gotoPrevious(project),
                                      onNextLine: () =>
                                          _gotoNext(project, total),
                                      onHeightChanged: (h) =>
                                          setState(() => _videoHeight = h),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.resizeLeftRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragUpdate: (details) {
                                        if (availableWidth <= 0) return;
                                        final next =
                                            ((leftWidth + details.delta.dx) /
                                                    availableWidth)
                                                .clamp(
                                                  minPaneWidth / availableWidth,
                                                  (availableWidth -
                                                          minPaneWidth) /
                                                      availableWidth,
                                                );
                                        setState(() {
                                          _topPaneRatio = next.toDouble();
                                        });
                                      },
                                      child: SizedBox(
                                        width: splitterWidth,
                                        child: Center(
                                          child: Container(
                                            width: 6,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Center(
                                              child: RotatedBox(
                                                quarterTurns: 1,
                                                child: Icon(
                                                  Icons.drag_handle,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: rightWidth,
                                    child: _TranscriberPromptPanel(
                                      promptText: _currentPromptText(
                                        _currentLine,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildLinePager(
                                project: project,
                                total: total,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinePager({required Project project, required int total}) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (idx) {
        unawaited(
          _handleLineChange(project, idx, autoplay: project.autoPlayLine),
        );
      },
      itemCount: total,
      itemBuilder: (context, idx) {
        return StreamBuilder<SubtitleLine>(
          stream: _svc.watchLine(project.projectId, idx),
          builder: (context, snapLine) {
            final line = snapLine.data;
            if (line == null) {
              return const Center(child: CircularProgressIndicator());
            }
            _currentLine = line;
            _cacheLineText(line);

            final voiceMode = SettingsService.instance.voiceInputMode;
            final sttAvailable = _speech.available.value;
            final statusText = voiceMode == VoiceInputMode.openai
                ? (_recBusy
                      ? 'Processing recording...'
                      : (_isRecording
                            ? 'Recording for OpenAI...'
                            : 'Ready to record.'))
                : (!sttAvailable
                      ? 'Local STT not available (Windows beta).'
                      : (_speech.isListening
                            ? 'Listening...'
                            : 'Ready to dictate.'));

            return _LineCard(
              project: project,
              line: line,
              showGpt: showGpt,
              showClaude: showClaude,
              showGemini: showGemini,
              showDeepseek: showDeepseek,
              isLocalListening: _speech.isListening,
              isOpenAiRecording: _isRecording,
              openAiBusy: _recBusy,
              statusText: statusText,
              onSaveActor: (actor) => _svc.setActorName(line.lineId, actor),
              onEditCandidate: (src, current) =>
                  _editCandidateText(line, src, current),
              onPlaySegment: () => _playSegment(line),
              onTapCandidate: (src, txt, method) => _pickCandidate(
                project: project,
                line: line,
                source: src,
                text: txt,
                method: method,
              ),
              onToggleDoubt: () => _toggleDoubt(line),
              onMic: () => _toggleVoiceInput(project, line, total),
              onRefine: () => _refineVoiceWithOpenAi(project, line),
            );
          },
        );
      },
    );
  }

  Future<void> _saveToCloud(Project project) async {
    await _cloud.ensureInit();
    if (!_cloud.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supabase not available (config/auth).'),
          ),
        );
      }
      return;
    }
    if (_savingCloud) return;
    setState(() => _savingCloud = true);

    if (!mounted) return;

    final notifier = ValueNotifier<String>('Saving...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: notifier,
            builder: (context, msg, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(msg)),
              ],
            ),
          ),
        ),
      ),
    );

    bool ok = false;
    try {
      await _cloud
          .pushProject(
            project.projectId,
            onProgress: (v, stage) {
              final pct = (v * 100).toInt();
              notifier.value = '$stage ($pct %)';
            },
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw TimeoutException('cloud save timeout'),
          );
      ok = true;
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload canceled because it took too long.'),
          ),
        );
      }
    } on CloudSyncException catch (e) {
      debugPrint(
        'save cloud error [${e.code}]: ${e.userMessage} | '
        'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } catch (e) {
      debugPrint('save cloud error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error saving to cloud.')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (mounted && ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project saved to cloud.')));
      setState(() {}); // refresca indicadores de suciedad
    }
    if (mounted) setState(() => _savingCloud = false);
  }
}

typedef CandidateTap = void Function(String src, String txt, String method);

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({
    required this.controller,
    required this.initFuture,
    required this.error,
    required this.videoPath,
    required this.subtitle,
    required this.lineTimings,
    required this.getLineText,
    required this.subtitleStartMs,
    required this.subtitleEndMs,
    required this.height,
    required this.onDragResize,
    required this.onBack,
    required this.onPlayPause,
    required this.onPlaySegment,
    required this.onForward,
    required this.onPrevLine,
    required this.onNextLine,
    required this.onHeightChanged,
  });

  final VideoPlayerController? controller;
  final Future<void>? initFuture;
  final bool error;
  final String? videoPath;
  final String subtitle;
  final List<LineTiming> lineTimings;
  final String Function(LineTiming) getLineText;
  final int? subtitleStartMs;
  final int? subtitleEndMs;
  final double height;
  final void Function(double delta) onDragResize;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaySegment;
  final VoidCallback onForward;
  final VoidCallback onPrevLine;
  final VoidCallback onNextLine;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    Widget buildContent(String positionText, String durationText) {
      Widget player;
      if (error) {
        player = Center(
          child: Text(
            'Video unavailable (invalid path or Web): ${videoPath ?? '-'}',
          ),
        );
      } else if (controller == null || initFuture == null) {
        player = const Center(child: Text('No video imported.'));
      } else {
        player = FutureBuilder<void>(
          future: initFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (controller!.value.hasError) {
              return const Center(child: Text('Could not load the video.'));
            }
            return ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller!,
              builder: (context, value, _) {
                final aspect = value.aspectRatio == 0
                    ? 16 / 9
                    : value.aspectRatio;
                final posMs = value.position.inMilliseconds;
                LineTiming? activeLine;
                String activeSubtitle = subtitle;
                int? startMs = subtitleStartMs;
                int? endMs = subtitleEndMs;
                if (lineTimings.isNotEmpty) {
                  activeLine = _findLineForMs(lineTimings, posMs);
                  if (activeLine != null) {
                    activeSubtitle = getLineText(activeLine);
                    startMs = activeLine.startMs;
                    endMs = activeLine.endMs;
                  }
                }
                bool showSubtitle = activeSubtitle.trim().isNotEmpty;
                if (startMs != null && endMs != null) {
                  showSubtitle =
                      showSubtitle && posMs >= startMs && posMs <= endMs;
                }
                return AspectRatio(
                  aspectRatio: aspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayer(controller!),
                      if (showSubtitle)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(
                                (0.35 * 255).round(),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _wrapSubtitle(activeSubtitle, 40),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.25,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black87,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }

      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: height,
                child: Center(child: player),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onPanUpdate: (details) => onDragResize(details.delta.dy),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [Icon(Icons.drag_handle, size: 16)],
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$positionText / $durationText',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Rewind 5s',
                    icon: const Icon(Icons.replay_5),
                    onPressed: controller == null ? null : onBack,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    tooltip: controller?.value.isPlaying == true
                        ? 'Pause'
                        : 'Play',
                    icon: Icon(
                      controller?.value.isPlaying == true
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    onPressed: controller == null ? null : onPlayPause,
                    iconSize: 28,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    tooltip: 'Play only the current line',
                    icon: const Icon(Icons.playlist_play),
                    onPressed: controller == null ? null : onPlaySegment,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    tooltip: 'Forward 5s',
                    icon: const Icon(Icons.forward_5),
                    onPressed: controller == null ? null : onForward,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous line',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: onPrevLine,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Next line',
                    icon: const Icon(Icons.skip_next),
                    onPressed: onNextLine,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null) {
      return buildContent('--:--', '--:--');
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller!,
      builder: (context, value, _) {
        final positionText = value.isInitialized
            ? _fmt(value.position)
            : '--:--';
        final durationText = value.isInitialized
            ? _fmt(value.duration)
            : '--:--';
        return buildContent(positionText, durationText);
      },
    );
  }

  LineTiming? _findLineForMs(List<LineTiming> lines, int posMs) {
    if (lines.isEmpty) return null;
    int lo = 0;
    int hi = lines.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final line = lines[mid];
      if (posMs < line.startMs) {
        hi = mid - 1;
      } else if (posMs > line.endMs) {
        lo = mid + 1;
      } else {
        return line;
      }
    }
    return null;
  }

  String _fmt(Duration d) {
    final totalMs = d.inMilliseconds;
    final totalSeconds = totalMs ~/ 1000;
    final s = totalSeconds % 60;
    final m = (totalSeconds ~/ 60) % 60;
    final h = totalSeconds ~/ 3600;
    final cs = (totalMs % 1000) ~/ 10;
    String two(int x) => x.toString().padLeft(2, '0');
    return '$h:${two(m)}:${two(s)}.${two(cs)}';
  }

  String _wrapSubtitle(String text, int maxChars) {
    final words = text.split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    int lineLen = 0;
    for (final word in words) {
      if (lineLen + word.length + (lineLen == 0 ? 0 : 1) > maxChars) {
        buffer.write('\n');
        buffer.write(word);
        lineLen = word.length;
      } else {
        if (lineLen > 0) {
          buffer.write(' ');
          lineLen += 1;
        }
        buffer.write(word);
        lineLen += word.length;
      }
    }
    return buffer.toString();
  }
}

class _TranscriberPromptPanel extends StatelessWidget {
  const _TranscriberPromptPanel({
    required this.promptText,
    this.maxHeight,
    this.margin = const EdgeInsets.fromLTRB(0, 8, 12, 8),
  });

  final String promptText;
  final double? maxHeight;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final promptBody = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(
          (0.45 * 255).round(),
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha((0.7 * 255).round()),
        ),
      ),
      child: SingleChildScrollView(
        child: Builder(
          builder: (context) {
            final baseStyle = DefaultTextStyle.of(
              context,
            ).style.copyWith(height: 1.4);
            final text = promptText;
            return Text.rich(
              TextSpan(
                style: baseStyle,
                children: _buildPromptTextSpans(
                  text,
                  baseStyle: baseStyle,
                  furiganaColor: colorScheme.onSurfaceVariant.withAlpha(
                    (0.9 * 255).round(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: maxHeight == null ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Prompt Transcriber',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (maxHeight == null)
              Expanded(child: promptBody)
            else
              SizedBox(height: maxHeight, child: promptBody),
          ],
        ),
      ),
    );
  }
}

final RegExp _furiganaPromptPattern = RegExp(
  r'([一-龯々〆ヵヶ][一-龯々〆ヵヶぁ-ゖァ-ヺー]*)[\(（]([ぁ-ゖァ-ヺー・]+)[\)）]',
);

List<InlineSpan> _buildPromptTextSpans(
  String text, {
  required TextStyle baseStyle,
  required Color furiganaColor,
}) {
  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in _furiganaPromptPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }

    final surface = match.group(1);
    final reading = match.group(2);
    if (surface == null || reading == null) {
      spans.add(TextSpan(text: match.group(0) ?? ''));
      cursor = match.end;
      continue;
    }

    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _RubyText(
            surface: surface,
            reading: reading,
            baseStyle: baseStyle,
            furiganaStyle: baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 14) * 0.62,
              height: 1,
              color: furiganaColor,
            ),
          ),
        ),
      ),
    );

    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: text));
  }

  return spans;
}

class _RubyText extends StatelessWidget {
  const _RubyText({
    required this.surface,
    required this.reading,
    required this.baseStyle,
    required this.furiganaStyle,
  });

  final String surface;
  final String reading;
  final TextStyle baseStyle;
  final TextStyle furiganaStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$surface ($reading)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reading, style: furiganaStyle, textAlign: TextAlign.center),
          Text(
            surface,
            style: baseStyle.copyWith(height: 1.1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.project,
    required this.line,
    required this.showGpt,
    required this.showClaude,
    required this.showGemini,
    required this.showDeepseek,
    required this.isLocalListening,
    required this.isOpenAiRecording,
    required this.openAiBusy,
    required this.statusText,
    required this.onSaveActor,
    required this.onTapCandidate,
    required this.onEditCandidate,
    required this.onToggleDoubt,
    required this.onPlaySegment,
    required this.onMic,
    required this.onRefine,
  });

  final Project project;
  final SubtitleLine line;

  final bool showGpt;
  final bool showClaude;
  final bool showGemini;
  final bool showDeepseek;

  final bool isLocalListening;
  final bool isOpenAiRecording;
  final bool openAiBusy;
  final String statusText;

  final Future<void> Function(String actor) onSaveActor;
  final CandidateTap onTapCandidate;
  final void Function(String source, String current) onEditCandidate;
  final VoidCallback onToggleDoubt;
  final VoidCallback onPlaySegment;
  final VoidCallback onMic;
  final VoidCallback onRefine;

  @override
  Widget build(BuildContext context) {
    final title =
        'Line ${line.dialogueIndex + 1} • ${_fmtTime(line.startMs)} → ${_fmtTime(line.endMs)}';
    final hasOtherCand =
        (line.candClaude ?? '').isNotEmpty ||
        (line.candGemini ?? '').isNotEmpty ||
        (line.candDeepseek ?? '').isNotEmpty;
    final gptLabel = hasOtherCand ? 'GPT' : 'Base script';
    final romajiTag =
        _firstTag(line.sourceText ?? '') ?? _firstTag(line.originalText);
    final displayRomanization = (line.romanization ?? '').trim().isNotEmpty
        ? line.romanization!.trim()
        : (romajiTag ?? '');
    final sourceDialogue = _textBeforeFirstBraceGroup(
      line.sourceText ?? line.originalText,
    );
    final romanDialogue = displayRomanization.trim();
    final originCombined = [
      if (sourceDialogue.isNotEmpty) sourceDialogue,
      if (romanDialogue.isNotEmpty) romanDialogue,
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mark doubt',
                    icon: Icon(line.doubt ? Icons.flag : Icons.outlined_flag),
                    onPressed: onToggleDoubt,
                  ),
                  if (line.reviewed)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check_circle, size: 18),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ActorEditor(
                  initialValue: line.name ?? '',
                  onSave: onSaveActor,
                ),
              ),
              const SizedBox(height: 8),
              if (originCombined.isNotEmpty)
                _SourceBlock(label: '', text: originCombined, highlight: true),
              if ((line.gloss ?? '').isNotEmpty)
                _SourceBlock(label: 'Gloss', text: line.gloss ?? ''),
              const SizedBox(height: 12),

              // Candidates with CPS
              if (showGpt && (line.candGpt ?? '').isNotEmpty)
                _CandidateTile(
                  label: gptLabel,
                  text: line.candGpt!,
                  cps: _calcCps(line, line.candGpt!),
                  cpsColor: _cpsColor(_calcCps(line, line.candGpt!)),
                  isSelected:
                      (line.selectedSource ?? '').toLowerCase() == 'gpt',
                  onTap: () => onTapCandidate('gpt', line.candGpt!, 'tap'),
                  onEdit: () => onEditCandidate('gpt', line.candGpt!),
                ),
              if (showClaude && (line.candClaude ?? '').isNotEmpty)
                _CandidateTile(
                  label: 'Claude',
                  text: line.candClaude!,
                  cps: _calcCps(line, line.candClaude!),
                  cpsColor: _cpsColor(_calcCps(line, line.candClaude!)),
                  isSelected:
                      (line.selectedSource ?? '').toLowerCase() == 'claude',
                  onTap: () =>
                      onTapCandidate('claude', line.candClaude!, 'tap'),
                  onEdit: () => onEditCandidate('claude', line.candClaude!),
                ),
              if (showGemini && (line.candGemini ?? '').isNotEmpty)
                _CandidateTile(
                  label: 'Gemini',
                  text: line.candGemini!,
                  cps: _calcCps(line, line.candGemini!),
                  cpsColor: _cpsColor(_calcCps(line, line.candGemini!)),
                  isSelected:
                      (line.selectedSource ?? '').toLowerCase() == 'gemini',
                  onTap: () =>
                      onTapCandidate('gemini', line.candGemini!, 'tap'),
                  onEdit: () => onEditCandidate('gemini', line.candGemini!),
                ),
              if (showDeepseek && (line.candDeepseek ?? '').isNotEmpty)
                _CandidateTile(
                  label: 'DeepSeek',
                  text: line.candDeepseek!,
                  cps: _calcCps(line, line.candDeepseek!),
                  cpsColor: _cpsColor(_calcCps(line, line.candDeepseek!)),
                  isSelected:
                      (line.selectedSource ?? '').toLowerCase() == 'deepseek',
                  onTap: () =>
                      onTapCandidate('deepseek', line.candDeepseek!, 'tap'),
                  onEdit: () => onEditCandidate('deepseek', line.candDeepseek!),
                ),

              const SizedBox(height: 12),
              _VoiceTile(
                text: line.candVoice ?? '',
                isSelected:
                    (line.selectedSource ?? '').toLowerCase() == 'voice',
                isListening: isLocalListening,
                isRecordingOpenAi: isOpenAiRecording,
                openAiBusy: openAiBusy,
                statusText: statusText,
                cps: _calcCps(line, line.candVoice ?? ''),
                cpsColor: _cpsColor(_calcCps(line, line.candVoice ?? '')),
                onMic: onMic,
                onRefine: onRefine,
                onUse: (t) => onTapCandidate('voice', t, 'voice'),
                onEdit: () => onEditCandidate('voice', line.candVoice ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _calcCps(SubtitleLine l, String text) {
    final clean = text.trim().replaceAll('\r', '').replaceAll('\n', '');
    if (clean.isEmpty) return 0;
    final durationSec = math.max(0.01, (l.endMs - l.startMs) / 1000);
    return clean.length / durationSec;
  }

  static String? _firstTag(String? text) {
    if (text == null || text.isEmpty) return null;
    final start = text.indexOf('{');
    if (start < 0) return null;
    final end = text.indexOf('}', start + 1);
    if (end <= start) return null;
    final content = text.substring(start + 1, end).trim();
    return content.isEmpty ? null : content;
  }

  static String _textBeforeFirstBraceGroup(String? text) {
    if (text == null || text.isEmpty) return '';
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final firstBrace = normalized.indexOf('{');
    final visible = firstBrace >= 0
        ? normalized.substring(0, firstBrace)
        : normalized;
    return visible.trim();
  }

  static Color? _cpsColor(double cps) {
    if (cps <= 0) return null;
    if (cps < 20) return Colors.green;
    if (cps <= 22) return Colors.orange;
    return Colors.red;
  }

  static String _fmtTime(int ms) {
    final total = ms ~/ 1000;
    final s = total % 60;
    final m = (total ~/ 60) % 60;
    final h = total ~/ 3600;
    final cs = (ms % 1000) ~/ 10; // centésimas
    String two(int x) => x.toString().padLeft(2, '0');
    String twoCs(int x) => x.toString().padLeft(2, '0');
    return '$h:${two(m)}:${two(s)}.${twoCs(cs)}';
  }
}

class _SourceBlock extends StatelessWidget {
  const _SourceBlock({
    required this.label,
    required this.text,
    this.highlight = false,
  });
  final String label;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final showLabel = label.trim().isNotEmpty;
    final display = text.trim();
    return Card(
      color: highlight ? const Color(0xFF1E3A8A) : null, // cobalt-ish tone
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) ...[
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlight ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              display,
              style: TextStyle(color: highlight ? Colors.white : null),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineJumpCounter extends StatefulWidget {
  const _LineJumpCounter({
    required this.currentLine,
    required this.total,
    required this.onJump,
  });

  final int currentLine;
  final int total;
  final ValueChanged<int> onJump;

  @override
  State<_LineJumpCounter> createState() => _LineJumpCounterState();
}

class _LineJumpCounterState extends State<_LineJumpCounter> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _lineText(widget.currentLine));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LineJumpCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    if (oldWidget.currentLine != widget.currentLine ||
        oldWidget.total != widget.total) {
      _controller.text = _lineText(widget.currentLine);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _lineText(int value) {
    if (value < 1) return '0';
    return value.toString();
  }

  void _submit() {
    final total = widget.total;
    if (total <= 0) return;
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = _lineText(widget.currentLine);
      return;
    }
    final clamped = parsed.clamp(1, total).toInt();
    _controller.text = clamped.toString();
    widget.onJump(clamped);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.total > 0 ? widget.total.toString() : '--';
    return Tooltip(
      message: 'Type a number and confirm to jump to that line.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(
            (0.45 * 255).round(),
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(
              (0.7 * 255).round(),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _submit(),
                  onTapOutside: (_) => _focusNode.unfocus(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Jump to line',
                iconSize: 18,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: widget.total <= 0 ? null : _submit,
                icon: const Icon(Icons.check),
              ),
              const SizedBox(width: 2),
              Text(
                '/$total',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.label,
    required this.text,
    required this.onTap,
    required this.cps,
    required this.cpsColor,
    required this.onEdit,
    this.isSelected = false,
  });
  final String label;
  final String text;
  final VoidCallback onTap;
  final double cps;
  final Color? cpsColor;
  final VoidCallback onEdit;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.green.withAlpha((0.12 * 255).round()) : null,
      child: ListTile(
        title: Row(
          children: [
            Text(label),
            const SizedBox(width: 8),
            if (cps > 0 && cpsColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cpsColor!.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('CPS ${cps.toStringAsFixed(1)}'),
              ),
          ],
        ),
        subtitle: _LineLimitPreviewText(text: text),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class _ActorEditor extends StatefulWidget {
  const _ActorEditor({required this.initialValue, required this.onSave});

  final String initialValue;
  final Future<void> Function(String actor) onSave;

  @override
  State<_ActorEditor> createState() => _ActorEditorState();
}

class _ActorEditorState extends State<_ActorEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _saving = false;

  bool get _isDirty =>
      _normalize(_controller.text) != _normalize(widget.initialValue);

  @override
  void didUpdateWidget(covariant _ActorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue == oldWidget.initialValue) return;
    if (_normalize(widget.initialValue) == _normalize(_controller.text)) return;

    _controller.value = TextEditingValue(
      text: widget.initialValue,
      selection: TextSelection.collapsed(offset: widget.initialValue.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving || !_isDirty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            'Actor',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _handleSave(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'No actor',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Save actor',
          onPressed: (!_isDirty || _saving) ? null : _handleSave,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
        ),
      ],
    );
  }
}

class _SubmitEditIntent extends Intent {
  const _SubmitEditIntent();
}

class _InsertNewlineIntent extends Intent {
  const _InsertNewlineIntent();
}

class _LineLimitHighlightController extends TextEditingController {
  _LineLimitHighlightController({
    required super.text,
    required this.maxCharsPerLine,
  });

  final int maxCharsPerLine;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    return TextSpan(
      style: baseStyle,
      children: _buildLineLimitSpans(
        text,
        baseStyle: baseStyle,
        maxCharsPerLine: maxCharsPerLine,
      ),
    );
  }
}

List<InlineSpan> _buildLineLimitSpans(
  String text, {
  required TextStyle baseStyle,
  required int maxCharsPerLine,
}) {
  final overflowStyle = baseStyle.copyWith(color: Colors.red);
  final spans = <InlineSpan>[];
  final lines = text.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.length <= maxCharsPerLine) {
      spans.add(TextSpan(text: line, style: baseStyle));
    } else {
      spans.add(
        TextSpan(text: line.substring(0, maxCharsPerLine), style: baseStyle),
      );
      spans.add(
        TextSpan(text: line.substring(maxCharsPerLine), style: overflowStyle),
      );
    }
    if (i < lines.length - 1) {
      spans.add(TextSpan(text: '\n', style: baseStyle));
    }
  }

  return spans;
}

class _LineLimitPreviewText extends StatelessWidget {
  const _LineLimitPreviewText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _buildLineLimitSpans(
          text,
          baseStyle: baseStyle,
          maxCharsPerLine: 40,
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.initial,
    required this.line,
  });
  final String title;
  final String initial;
  final SubtitleLine line;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  static const int _lineLimit = 40;
  static const TextStyle _editorTextStyle = TextStyle(height: 1.35);

  late final _LineLimitHighlightController _controller =
      _LineLimitHighlightController(
        text: widget.initial,
        maxCharsPerLine: _lineLimit,
      )..addListener(_onTextChanged);

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  int _visibleCharCount(String value) {
    return value.replaceAll('\r', '').replaceAll('\n', '').length;
  }

  List<int> get _lineCharacterCounts =>
      _controller.text.split('\n').map(_visibleCharCount).toList();

  double get _cps => _LineCard._calcCps(widget.line, _controller.text);

  Color? get _cpsColor => _LineCard._cpsColor(_cps);

  Map<ShortcutActivator, Intent> get _editorShortcuts {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        const SingleActivator(LogicalKeyboardKey.enter):
            const _InsertNewlineIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const _InsertNewlineIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            const _InsertNewlineIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
            const _InsertNewlineIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            const _InsertNewlineIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            const _InsertNewlineIntent(),
      };
    }

    return {
      const SingleActivator(LogicalKeyboardKey.enter):
          const _SubmitEditIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const _SubmitEditIntent(),
      const SingleActivator(LogicalKeyboardKey.enter, shift: true):
          const _InsertNewlineIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
          const _InsertNewlineIntent(),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          const _InsertNewlineIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
          const _InsertNewlineIntent(),
    };
  }

  void _insertNewline() {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final updated = text.replaceRange(start, end, '\n');
    _controller.value = value.copyWith(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 620),
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Shortcuts(
            shortcuts: _editorShortcuts,
            child: Actions(
              actions: {
                _SubmitEditIntent: CallbackAction<_SubmitEditIntent>(
                  onInvoke: (_) {
                    Navigator.of(context).pop(_controller.text);
                    return null;
                  },
                ),
                _InsertNewlineIntent: CallbackAction<_InsertNewlineIntent>(
                  onInvoke: (_) {
                    _insertNewline();
                    return null;
                  },
                ),
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_cps > 0 && _cpsColor != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _cpsColor!.withAlpha(
                                  (0.15 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('CPS ${_cps.toStringAsFixed(1)}'),
                            ),
                          Text(
                            'Line limit: $_lineLimit',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: SizedBox(
                          width: 36,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final count in _lineCharacterCounts)
                                Text(
                                  '$count',
                                  style: _editorTextStyle.copyWith(
                                    color: count <= _lineLimit
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          minLines: 2,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: _editorTextStyle,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.text,
    required this.isSelected,
    required this.isListening,
    required this.isRecordingOpenAi,
    required this.openAiBusy,
    required this.statusText,
    required this.cps,
    required this.cpsColor,
    required this.onMic,
    required this.onRefine,
    required this.onUse,
    required this.onEdit,
  });

  final String text;
  final bool isSelected;
  final bool isListening;
  final bool isRecordingOpenAi;
  final bool openAiBusy;
  final String statusText;
  final double cps;
  final Color? cpsColor;

  final VoidCallback onMic;
  final VoidCallback onRefine;
  final void Function(String text) onUse;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;

    IconData icon;
    String tooltip;
    if (isRecordingOpenAi) {
      icon = Icons.stop_circle;
      tooltip = 'Stop (OpenAI)';
    } else if (isListening) {
      icon = Icons.stop_circle;
      tooltip = 'Stop';
    } else {
      icon = Icons.mic;
      tooltip = 'Speak';
    }

    return Card(
      color: isSelected ? Colors.green.withAlpha((0.12 * 255).round()) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My voice',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: tooltip,
                  icon: Icon(icon),
                  onPressed: openAiBusy ? null : onMic,
                ),
                IconButton(
                  tooltip: 'Refine punctuation ✨',
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: hasText ? onRefine : null,
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: hasText ? onEdit : null,
                ),
                FilledButton(
                  onPressed: hasText ? () => onUse(text) : null,
                  child: const Text('Use'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            hasText
                ? _LineLimitPreviewText(text: text)
                : const Text(
                    'Press the microphone and dictate your translation.',
                  ),
            const SizedBox(height: 6),
            if (cps > 0 && cpsColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cpsColor!.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('CPS ${cps.toStringAsFixed(1)}'),
              ),
            const SizedBox(height: 6),
            Text(
              statusText,
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

class _ReviewTimerControl extends StatelessWidget {
  const _ReviewTimerControl({
    required this.elapsed,
    required this.running,
    required this.onToggle,
    required this.onReset,
    this.dense = false,
  });

  final Duration elapsed;
  final bool running;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final bool dense;

  String _format(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds ~/ 60) % 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = dense ? 8.0 : 12.0;
    final verticalPadding = dense ? 6.0 : 8.0;
    final iconButtonSize = dense ? 32.0 : 40.0;
    final iconSize = dense ? 18.0 : 20.0;
    final gapWidth = dense ? 6.0 : 8.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(
          (0.45 * 255).round(),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha((0.7 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: iconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: gapWidth),
          Text(
            _format(elapsed),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: dense ? 12 : null,
            ),
          ),
          IconButton(
            tooltip: running ? 'Pause timer' : 'Start timer',
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: iconButtonSize,
              height: iconButtonSize,
            ),
            padding: EdgeInsets.zero,
            iconSize: iconSize,
          ),
          IconButton(
            tooltip: 'Reset timer',
            icon: const Icon(Icons.replay),
            onPressed: elapsed == Duration.zero ? null : onReset,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: iconButtonSize,
              height: iconButtonSize,
            ),
            padding: EdgeInsets.zero,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }
}
