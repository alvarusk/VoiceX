import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

import '../commands/command_router.dart';
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
  final _speech = SpeechService.instance;
  String? _localeId;
  double _videoHeight = 200;
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

  void _startSession(String projectId) {
    if (_sessionStarted) return;
    _sessionStarted = true;
    final platform = _platformName();
    _svc.startSession(projectId, platform);
  }

  void _endSession() {
    if (!_sessionStarted) return;
    _svc.endSession(widget.projectId);
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
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Hay cambios locales sin subir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('exit'),
            child: const Text('Salir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Guardar'),
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

  PageController? _pageController;
  VideoPlayerController? _videoController;
  Future<void>? _videoInit;
  String? _videoPath;
  bool _videoError = false;
  SubtitleLine? _currentLine;

  // Toggles de visibilidad (MVP: en memoria)
  bool showGpt = true;
  bool showClaude = true;
  bool showGemini = true;
  bool showDeepseek = true;

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
              'STT: no hay paquetes de voz instalados en Windows. Añade un idioma de voz en Configuración.',
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
    if (_videoInit != null || _videoError) return;

    final path = await _svc.getVideoPath(project.projectId);
    if (path == null || path.isEmpty) {
      setState(() {
        _videoPath = path;
      });
      return;
    }
    debugPrint('Intentando cargar video: $path');

    final isRemote = path.startsWith('http://') || path.startsWith('https://');
    try {
      VideoPlayerController ctrl;
      if (isRemote) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('Video no encontrado en ruta: $path');
          setState(() {
            _videoPath = '';
            _videoError = true;
          });
          return;
        }
        ctrl = VideoPlayerController.file(file as dynamic);
      }
      _videoController = ctrl;
      _videoPath = path;
      _videoInit = ctrl
          .initialize()
          .then((_) async {
            await ctrl.setVolume(1.0);
            setState(() {});
          })
          .catchError((err) {
            debugPrint('Error al inicializar video: $err');
            _videoError = true;
            setState(() {});
          });

      await _videoInit;
    } catch (e) {
      debugPrint('Error al preparar video: $e');
      setState(() {
        _videoError = true;
        _videoPath = path;
      });
    }
  }

  Future<void> _seekVideoForIndex(String projectId, int idx) async {
    if (_videoController == null || _videoInit == null) return;
    try {
      await _videoInit;
      final line = await _svc.watchLine(projectId, idx).first;
      await _seekVideoTo(line.startMs);
    } catch (_) {}
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

  Future<void> _jumpToIndex(Project project, int idx) async {
    if (_pageController == null) return;
    await _pageController!.animateToPage(
      idx,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    await _svc.setCurrentIndex(project.projectId, idx);
    await _seekVideoForIndex(project.projectId, idx);
  }

  Future<void> _gotoNextUnreviewed(Project project) async {
    final next = await _svc.findNextUnreviewed(
      project.projectId,
      project.currentIndex,
    );
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay más líneas sin revisar.')),
      );
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
      ).showSnackBar(const SnackBar(content: Text('No hay más dudas.')));
      return;
    }
    await _jumpToIndex(project, next);
  }

  Future<void> _gotoNext(Project project, int total) async {
    final target = (project.currentIndex + 1).clamp(0, total - 1);
    if (target == project.currentIndex) {
      _showSnack('Es la ultima linea.');
      return;
    }
    await _jumpToIndex(project, target);
  }

  Future<void> _gotoPrevious(Project project) async {
    final target = (project.currentIndex - 1).clamp(0, project.currentIndex);
    if (target == project.currentIndex) {
      _showSnack('Ya estas en la primera linea.');
      return;
    }
    await _jumpToIndex(project, target);
  }

  Future<void> _openTools(Project project) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              SwitchListTile(
                title: const Text('Saltar revisadas al avanzar'),
                value: skipReviewedOnAdvance,
                onChanged: (v) => setState(() => skipReviewedOnAdvance = v),
              ),
              ListTile(
                leading: const Icon(Icons.skip_next),
                title: const Text('Ir a siguiente sin revisar'),
                onTap: () {
                  Navigator.pop(context);
                  _gotoNextUnreviewed(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Ir a siguiente duda'),
                onTap: () {
                  Navigator.pop(context);
                  _gotoNextDoubt(project);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Mostrar GPT'),
                value: showGpt,
                onChanged: (v) => setState(() => showGpt = v),
              ),
              SwitchListTile(
                title: const Text('Mostrar Claude'),
                value: showClaude,
                onChanged: (v) => setState(() => showClaude = v),
              ),
              SwitchListTile(
                title: const Text('Mostrar Gemini'),
                value: showGemini,
                onChanged: (v) => setState(() => showGemini = v),
              ),
              SwitchListTile(
                title: const Text('Mostrar DeepSeek'),
                value: showDeepseek,
                onChanged: (v) => setState(() => showDeepseek = v),
              ),
            ],
          ),
        );
      },
    );
  }

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
      ).showSnackBar(const SnackBar(content: Text('Fin del proyecto.')));
    }
  }

  Future<void> _toggleDoubt(SubtitleLine line) async {
    await _svc.toggleDoubt(line.lineId, !line.doubt);
  }

  Future<void> _setVoiceText(SubtitleLine line, String? text) async {
    await _svc.setVoiceText(line.lineId, text);
  }

  Future<void> _playSegment(SubtitleLine line) async {
    if (_videoController == null || _videoInit == null) return;
    final start = Duration(milliseconds: line.startMs);
    final end = Duration(milliseconds: line.endMs);
    final dur = end - start;
    if (dur <= Duration.zero) return;

    try {
      await _videoInit;
      await _videoController!.seekTo(start);
      await _videoController!.play();
      Future.delayed(dur, () async {
        if (!_videoController!.value.isInitialized) return;
        await _videoController!.pause();
        setState(() {});
      });
      setState(() {});
    } catch (_) {}
  }

  Future<String?> _promptEdit(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Shortcuts(
            shortcuts: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  const _SubmitEditIntent(),
              const SingleActivator(
                LogicalKeyboardKey.numpadEnter,
                control: true,
              ): const _SubmitEditIntent(),
            },
            child: Actions(
              actions: {
                _SubmitEditIntent: CallbackAction<_SubmitEditIntent>(
                  onInvoke: (_) {
                    Navigator.of(ctx).pop(controller.text);
                    return null;
                  },
                ),
              },
              child: Focus(
                autofocus: true,
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCandidateText(
    SubtitleLine line,
    String source,
    String current,
  ) async {
    final edited = await _promptEdit('Editar $source', current);
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
          _showSnack('No hay texto de voz para usar.');
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
        _showSnack('Escuchando de nuevo.');
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
            content: Text('OpenAI STT en Web: lo activamos más adelante.'),
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
          content: Text('speech_to_text no disponible en este dispositivo.'),
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
        const SnackBar(content: Text('Falta API key en Ajustes.')),
      );
      return;
    }

    setState(() => _recBusy = true);
    try {
      final hasPerm = await _rec.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin permiso de micrófono.')),
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
Transcribe al español respetando estos nombres y términos exactamente como están escritos (aunque la pronunciación suene distinta):
$glossary
Si dudas, prioriza estas grafías tal cual.
''';
      }
      final text = await client.transcribeAudioFile(
        filePath: path,
        model: settings.openAiSttModel,
        language: 'es',
        prompt: prompt,
      );
      await _setVoiceText(line, text);
    } finally {
      if (mounted) setState(() => _recBusy = false);
    }
  }

  Future<void> _refineVoiceWithOpenAi(SubtitleLine line) async {
    final settings = SettingsService.instance;
    if (!settings.hasOpenAiKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura la API key en Ajustes.')),
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

    await _setVoiceText(line, refined);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Puntuación refinada ✨')));
  }

  // --------

  @override
  void dispose() {
    _endSession();
    _pageController?.dispose();
    _videoController?.dispose();
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
        if (!_initialSeekDone) {
          _initialSeekDone = true;
          _seekVideoForIndex(project.projectId, project.currentIndex);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldPop = await _confirmExitIfDirty(project);
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  project.folder.trim().isNotEmpty
                      ? '${project.folder.trim()} > ${project.title}'
                      : project.title,
                  maxLines: 1,
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
                        ? 'Guardar (hay cambios locales sin subir)'
                        : 'Guardado en cloud';
                    return IconButton(
                      icon: Icon(icon, color: color),
                      tooltip: tooltip,
                      onPressed: _savingCloud
                          ? null
                          : () => _saveToCloud(project),
                    );
                  },
                ),
                StreamBuilder<int>(
                  stream: _svc.watchReviewedLines(widget.projectId),
                  builder: (context, reviewedSnap) {
                    return StreamBuilder<int>(
                      stream: _svc.watchTotalLines(widget.projectId),
                      builder: (context, totalSnap) {
                        final reviewed = reviewedSnap.data ?? 0;
                        final total = totalSnap.data ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(child: Text('$reviewed/$total')),
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Metricas',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MetricsPage(
                          db: widget.db,
                          projectId: project.projectId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () => _openTools(project),
                  tooltip: 'Herramientas',
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _svc.exportAndShareProject(
                    context,
                    projectId: project.projectId,
                  ),
                  tooltip: 'Exportar ASS final',
                ),
              ],
            ),
            body: StreamBuilder<int>(
              stream: _svc.watchTotalLines(widget.projectId),
              builder: (context, snapTotal) {
                final total = snapTotal.data ?? 0;
                if (total == 0) {
                  return const Center(child: Text('Sin líneas.'));
                }

                return StreamBuilder<List<SubtitleLine>>(
                  stream: _svc.watchAllLines(project.projectId),
                  builder: (context, linesSnap) {
                    final subtitleLines =
                        linesSnap.data ?? const <SubtitleLine>[];
                    return Column(
                      children: [
                        _VideoPanel(
                          controller: _videoController,
                          initFuture: _videoInit,
                          error: _videoError,
                          videoPath: _videoPath,
                          subtitle: _currentSubtitleText(_currentLine),
                          subtitleLines: subtitleLines,
                          getLineText: _currentSubtitleText,
                          subtitleStartMs: _currentLine?.startMs,
                          subtitleEndMs: _currentLine?.endMs,
                          height: _videoHeight,
                          onDragResize: (delta) {
                            final next = (_videoHeight + delta * 0.8).clamp(
                              120,
                              400,
                            );
                            setState(() => _videoHeight = next.toDouble());
                          },
                          onBack: () =>
                              _nudgeVideo(const Duration(seconds: -5)),
                          onPlayPause: _togglePlayPause,
                          onPlaySegment: () {
                            final line = _currentLine;
                            if (line != null) {
                              _playSegment(line);
                            }
                          },
                          onForward: () =>
                              _nudgeVideo(const Duration(seconds: 5)),
                          onPrevLine: () => _gotoPrevious(project),
                          onNextLine: () => _gotoNext(project, total),
                          onHeightChanged: (h) =>
                              setState(() => _videoHeight = h),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (idx) {
                              _svc.setCurrentIndex(project.projectId, idx);
                              _seekVideoForIndex(project.projectId, idx);
                            },
                            itemCount: total,
                            itemBuilder: (context, idx) {
                              return StreamBuilder<SubtitleLine>(
                                stream: _svc.watchLine(project.projectId, idx),
                                builder: (context, snapLine) {
                                  final line = snapLine.data;
                                  if (line == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  _currentLine = line;

                                  final voiceMode =
                                      SettingsService.instance.voiceInputMode;
                                  final sttAvailable = _speech.available.value;
                                  final statusText =
                                      voiceMode == VoiceInputMode.openai
                                      ? (_recBusy
                                            ? 'Procesando grabacion...'
                                            : (_isRecording
                                                  ? 'Grabando para OpenAI...'
                                                  : 'Listo para grabar.'))
                                      : (!sttAvailable
                                            ? 'STT local no disponible (Windows beta).'
                                            : (_speech.isListening
                                                  ? 'Escuchando...'
                                                  : 'Listo para dictar.'));

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
                                    onEditCandidate: (src, current) =>
                                        _editCandidateText(line, src, current),
                                    onPlaySegment: () => _playSegment(line),
                                    onTapCandidate: (src, txt, method) =>
                                        _pickCandidate(
                                          project: project,
                                          line: line,
                                          source: src,
                                          text: txt,
                                          method: method,
                                        ),
                                    onToggleDoubt: () => _toggleDoubt(line),
                                    onMic: () =>
                                        _toggleVoiceInput(project, line, total),
                                    onRefine: () =>
                                        _refineVoiceWithOpenAi(line),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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

  Future<void> _saveToCloud(Project project) async {
    await _cloud.ensureInit();
    if (!_cloud.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supabase no configurado (URL/key).')),
        );
      }
      return;
    }
    if (_savingCloud) return;
    setState(() => _savingCloud = true);

    if (!mounted) return;

    final notifier = ValueNotifier<String>('Guardando...');
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
      await _cloud.pushProject(
        project.projectId,
        onProgress: (v, stage) {
          final pct = (v * 100).toInt();
          notifier.value = '$stage ($pct %)';
        },
      );
      ok = true;
    } catch (e) {
      debugPrint('save cloud error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar en cloud.')),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto guardado en cloud.')),
      );
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
    required this.subtitleLines,
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
  final List<SubtitleLine> subtitleLines;
  final String Function(SubtitleLine) getLineText;
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
            'Video no disponible (ruta inválida o Web): ${videoPath ?? '-'}',
          ),
        );
      } else if (controller == null || initFuture == null) {
        player = const Center(child: Text('Sin video importado.'));
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
              return const Center(child: Text('No se pudo cargar el video.'));
            }
            return ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller!,
              builder: (context, value, _) {
                final aspect = value.aspectRatio == 0
                    ? 16 / 9
                    : value.aspectRatio;
                final posMs = value.position.inMilliseconds;
                SubtitleLine? activeLine;
                String activeSubtitle = subtitle;
                int? startMs = subtitleStartMs;
                int? endMs = subtitleEndMs;
                if (subtitleLines.isNotEmpty) {
                  activeLine = _findLineForMs(subtitleLines, posMs);
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
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: height,
                child: Center(child: player),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onPanUpdate: (details) => onDragResize(details.delta.dy),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [Icon(Icons.drag_handle, size: 18)],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$positionText / $durationText',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Rebobinar 5s',
                    icon: const Icon(Icons.replay_5),
                    onPressed: controller == null ? null : onBack,
                  ),
                  IconButton(
                    tooltip: controller?.value.isPlaying == true
                        ? 'Pausar'
                        : 'Reproducir',
                    icon: Icon(
                      controller?.value.isPlaying == true
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    onPressed: controller == null ? null : onPlayPause,
                    iconSize: 32,
                  ),
                  IconButton(
                    tooltip: 'Reproducir solo la línea actual',
                    icon: const Icon(Icons.playlist_play),
                    onPressed: controller == null ? null : onPlaySegment,
                    iconSize: 28,
                  ),
                  IconButton(
                    tooltip: 'Avanzar 5s',
                    icon: const Icon(Icons.forward_5),
                    onPressed: controller == null ? null : onForward,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Línea anterior',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: controller == null ? null : onPrevLine,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Línea siguiente',
                    icon: const Icon(Icons.skip_next),
                    onPressed: controller == null ? null : onNextLine,
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

  SubtitleLine? _findLineForMs(List<SubtitleLine> lines, int posMs) {
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

  final CandidateTap onTapCandidate;
  final void Function(String source, String current) onEditCandidate;
  final VoidCallback onToggleDoubt;
  final VoidCallback onPlaySegment;
  final VoidCallback onMic;
  final VoidCallback onRefine;

  @override
  Widget build(BuildContext context) {
    final title =
        'Línea ${line.dialogueIndex + 1} • ${_fmtTime(line.startMs)} → ${_fmtTime(line.endMs)}';
    final hasOtherCand =
        (line.candClaude ?? '').isNotEmpty ||
        (line.candGemini ?? '').isNotEmpty ||
        (line.candDeepseek ?? '').isNotEmpty;
    final gptLabel = hasOtherCand ? 'GPT' : 'Guion ES';
    final romajiTag =
        _firstTag(line.sourceText ?? '') ?? _firstTag(line.originalText);
    final displayRomanization = (line.romanization ?? '').trim().isNotEmpty
        ? line.romanization!.trim()
        : (romajiTag ?? '');
    final sourceFirst = (line.sourceText ?? '')
        .split('\n')
        .first
        .split('{')
        .first
        .trim();
    final romanFirst = displayRomanization.split('\n').first.trim();
    final originCombined = [
      if (sourceFirst.isNotEmpty) sourceFirst,
      if (romanFirst.isNotEmpty) romanFirst,
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
                    tooltip: 'Marcar duda',
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
              if ((line.name ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Actor: ${line.name}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (originCombined.isNotEmpty)
                _SourceBlock(label: '', text: originCombined, highlight: true),
              if ((line.gloss ?? '').isNotEmpty)
                _SourceBlock(label: 'Glosa', text: line.gloss ?? ''),
              const SizedBox(height: 12),

              // Candidatos con CPS
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
    final clean = text.trim();
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
        subtitle: Text(text),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Editar',
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class _SubmitEditIntent extends Intent {
  const _SubmitEditIntent();
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
      tooltip = 'Detener (OpenAI)';
    } else if (isListening) {
      icon = Icons.stop_circle;
      tooltip = 'Detener';
    } else {
      icon = Icons.mic;
      tooltip = 'Hablar';
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
                    'Mi voz',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: tooltip,
                  icon: Icon(icon),
                  onPressed: openAiBusy ? null : onMic,
                ),
                IconButton(
                  tooltip: 'Refinar puntuación ✨',
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: hasText ? onRefine : null,
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: hasText ? onEdit : null,
                ),
                FilledButton(
                  onPressed: hasText ? () => onUse(text) : null,
                  child: const Text('Usar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hasText ? text : 'Pulsa el micrófono y dicta tu traducción.'),
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
