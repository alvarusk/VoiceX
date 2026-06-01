import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_db.dart';
import '../review/review_page.dart';
import '../review/review_service.dart';
import '../sync/cloud_sync_service.dart';
import '../costs/costs_repository.dart';
import '../costs/costs_sheet.dart';
import '../sync/supabase_manager.dart';
import '../settings/settings_service.dart';
import '../utils/app_update_checker.dart';
import 'project_import_sheet.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({
    super.key,
    required this.db,
    required this.isDark,
    required this.onToggleTheme,
    this.autoSyncOnStart = true,
  });
  final AppDatabase db;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final bool autoSyncOnStart;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late final CloudSyncService _cloud = CloudSyncService(widget.db);
  final SettingsService _settings = SettingsService.instance;
  bool _autoSyncStarted = false;
  bool _syncingAll = false;
  final Map<String, bool> _collapsed = {}; // folder -> collapsed
  final Set<String> _manualFolders = {}; // created manually even if vacías
  final Set<String> _archivedFolders = {}; // hidden from the main screen
  final Map<String, bool> _folderHover = {}; // folder -> drag hover
  List<String> _folderNamesCache = [];
  bool _updateChecked = false;
  String? _folderScopeOwnerId;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
      ),
    );
  }

  Future<bool> _canOpenProject(ProjectSummary p) async {
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadFolderState();
    if (widget.autoSyncOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeCheckAndroidUpdate(),
    );
  }

  Future<void> _loadFolderState() async {
    await _settings.init();
    final ownerId = SupabaseManager.instance.userId;
    if (_folderScopeOwnerId != ownerId) {
      _folderScopeOwnerId = ownerId;
      _manualFolders.clear();
      _archivedFolders.clear();
      _collapsed.clear();
      _folderHover.clear();
      _folderNamesCache = [];
    }
    final manual = _settings.manualFolders.toSet();
    final archived = _settings.archivedFolders.toSet();
    setState(() {
      _manualFolders
        ..clear()
        ..addAll(manual.difference(archived));
      _archivedFolders
        ..clear()
        ..addAll(archived);
      for (final f in _manualFolders) {
        _collapsed.putIfAbsent(f, () => false);
      }
      _folderNamesCache = _manualFolders.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  Future<void> _autoSync() async {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    await _cloud.ensureInit();
    if (!_cloud.isReady || !mounted) return;
    setState(() => _syncingAll = true);
    try {
      await _runWithProgress(
        context,
        initial: 'Loading projects...',
        action: (update) async {
          update('Loading projects...');
          await _cloud.syncAllProjects(
            includeArchived: false,
            onProgress: (v, stage) {
              final pct = (v * 100).toStringAsFixed(0);
              final pctInt = double.tryParse(pct)?.toInt() ?? 0;
              update('$stage ($pctInt %)');
            },
          );
        },
      );
      if (mounted) {
        setState(() {});
        await _loadFolderState();
        _showSnack('Initial sync complete.');
      }
    } on CloudSyncException catch (e) {
      debugPrint(
        'autoSync cloud error [${e.code}]: ${e.userMessage} | '
        'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
      );
      if (mounted) _showSnack(e.userMessage);
    } on TimeoutException {
      // El mensaje ya se muestra en _runWithProgress.
    } catch (e) {
      debugPrint('autoSync error: $e');
      if (mounted) {
        _showSnack('Error while syncing on startup.');
      }
    }
    if (mounted) setState(() => _syncingAll = false);
  }

  Future<void> _maybeCheckAndroidUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;

    const checker = AppUpdateChecker(
      packageName: 'com.kingdomm.voicex',
      storeUrl:
          'https://play.google.com/store/apps/details?id=com.kingdomm.voicex',
    );
    final result = await checker.checkForUpdate();
    if (!mounted || result == null) return;

    if (result.immediateAllowed) {
      final started = await checker.startImmediateUpdate();
      if (started) return;
    }

    if (!mounted) return;
    final versionSuffix = result.currentVersion.isEmpty
        ? ''
        : ' (you have v${result.currentVersion})';
    final playCode = result.availableVersionCode != null
        ? ' (Play code ${result.availableVersionCode})'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New version available$versionSuffix$playCode'),
        action: SnackBarAction(
          label: 'Google Play',
          onPressed: checker.openPlayStore,
        ),
      ),
    );
  }

  Future<void> _runWithProgress(
    BuildContext context, {
    required String initial,
    required Future<void> Function(void Function(String) update) action,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ValueNotifier<String>(initial);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
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

    try {
      await action((m) => notifier.value = m).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('operation timeout'),
      );
    } on TimeoutException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Operation canceled because it took too long.'),
        ),
      );
      rethrow;
    } finally {
      navigator.pop();
    }
  }

  Future<String?> _promptFolderName({String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Folder'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'MF Ghost, The Daily Life..., etc.',
            ),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ensureFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _manualFolders.add(trimmed);
      _archivedFolders.remove(trimmed);
      _collapsed.putIfAbsent(trimmed, () => false);
      if (!_folderNamesCache.contains(trimmed)) {
        _folderNamesCache.add(trimmed);
        _folderNamesCache.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
    });
    await _settings.ensureFolderActive(trimmed);
  }

  Future<void> _selectFolderForProject(
    ProjectSummary p,
    ReviewService svc,
  ) async {
    final archivedFolders = _settings.archivedFolders.toSet();
    final folders = <String>{
      'No folder',
      ..._settings.manualFolders.where((f) => !archivedFolders.contains(f)),
      if (p.folder.trim().isNotEmpty) p.folder.trim(),
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String newName = '';
        final sorted = folders.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Move to folder',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...sorted.map(
                      (f) => ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(f),
                        onTap: () =>
                            Navigator.pop(ctx, f == 'No folder' ? '' : f),
                      ),
                    ),
                    const Divider(),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Create new folder',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => newName = v,
                      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, newName.trim()),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Create and move'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    final trimmed = selected.trim();
    if (trimmed == p.folder.trim()) return; // sin cambios
    await svc.setProjectFolder(p.projectId, trimmed);
    await _ensureFolder(trimmed);
  }

  Future<void> _renameProject(ProjectSummary p, ReviewService svc) async {
    final ctrl = TextEditingController(text: p.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename project'),
        content: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
                const ActivateIntent(),
          },
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  Navigator.pop(context, ctrl.text.trim());
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  hintText: 'Episode only, e.g. E05',
                ),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    await svc.renameProject(p.projectId, newName.trim());
    setState(() {});
  }

  Future<void> _openCostsSheet() async {
    if (!SupabaseManager.instance.isReady) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supabase not available (config/auth).'),
          ),
        );
      }
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: CostsSheet(repo: CostsRepository()),
      ),
    );
  }

  Future<void> _syncAllProjects() async {
    if (_syncingAll) {
      _showSnack('A sync is already in progress.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (mounted) {
      setState(() => _syncingAll = true);
    }
    await _cloud.ensureInit();
    if (!mounted) return;
    if (!_cloud.isReady) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Supabase not available (config/auth).')),
      );
      if (mounted) {
        setState(() => _syncingAll = false);
      }
      return;
    }
    try {
      await _runWithProgress(
        context,
        initial: 'Syncing projects...',
        action: (update) async {
          update('Syncing projects...');
          await _cloud.syncAllProjects(
            includeArchived: true,
            onProgress: (v, stage) {
              final pct = (v * 100).toStringAsFixed(0);
              final pctInt = double.tryParse(pct)?.toInt() ?? 0;
              update('$stage ($pctInt %)');
            },
          );
        },
      );
      if (!mounted) return;
      await _loadFolderState();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Cloud sync complete.')),
      );
    } on TimeoutException {
      // El mensaje se muestra en _runWithProgress.
    } on CloudSyncException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
      debugPrint(
        'sync button cloud error [${e.code}]: ${e.userMessage} | '
        'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Error syncing with cloud.')),
      );
      debugPrint('sync button error: $e');
    } finally {
      if (mounted) {
        setState(() => _syncingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = ReviewService(widget.db);
    final compactAppBar = MediaQuery.sizeOf(context).width < 700;
    final toolbarHeight = compactAppBar ? 68.0 : 150.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: SizedBox(
          height: 128, // 200% más grande
          child: Image.asset('assets/voicex_logo.png', fit: BoxFit.contain),
        ),
        toolbarHeight: toolbarHeight,
        actions: [
          IconButton(
            tooltip: 'API costs',
            icon: const Icon(Icons.receipt_long),
            onPressed: _openCostsSheet,
          ),
          IconButton(
            tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Sync with cloud',
            icon: const Icon(Icons.sync),
            onPressed: _syncAllProjects,
          ),
          IconButton(
            tooltip: 'Create folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final name = await _promptFolderName(initial: '');
              if (name == null) return;
              await _ensureFolder(name);
              if (context.mounted && name.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Folder "$name" ready. Use it when creating or moving projects.',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'New project',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final projectId = await showModalBottomSheet<String?>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProjectImportSheet(
                  db: widget.db,
                  initialFolder: null,
                  folderOptions: _folderNamesCache
                      .where((f) => f != 'No folder')
                      .toList(),
                  onFolderCreated: (f) => unawaited(_ensureFolder(f)),
                ),
              );
              if (projectId == null || !context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ReviewPage(db: widget.db, projectId: projectId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ProjectSummary>>(
        stream: svc.watchProjectSummaries(),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          final archivedFolders = _settings.archivedFolders.toSet();
          final manualFolders = _settings.manualFolders.toSet();
          final visibleFolders = items
              .map(
                (p) => p.folder.trim().isEmpty ? 'No folder' : p.folder.trim(),
              )
              .where((f) => !archivedFolders.contains(f))
              .toSet();
          final activeManualFolders = manualFolders
              .where((f) => !archivedFolders.contains(f))
              .toSet();
          final grouped = <String, List<ProjectSummary>>{};
          for (final p in items) {
            final folder = p.folder.trim().isEmpty
                ? 'No folder'
                : p.folder.trim();
            if (!archivedFolders.contains(folder)) {
              (grouped[folder] ??= []).add(p);
            }
          }
          for (final f in activeManualFolders) {
            grouped.putIfAbsent(f, () => []);
          }
          for (final f in visibleFolders) {
            grouped.putIfAbsent(f, () => []);
          }
          final folderNames = grouped.keys.toList()
            ..sort((a, b) {
              if (a == 'No folder') return -1;
              if (b == 'No folder') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });
          _folderNamesCache = folderNames;

          if (folderNames.isEmpty) {
            final emptyText = items.isEmpty && archivedFolders.isEmpty
                ? 'No projects yet.\nPress + to import an ASS.'
                : 'No active folders yet.\nCreate one or unarchive it from Settings.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  emptyText,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final folder in folderNames) ...[
                DragTarget<ProjectSummary>(
                  builder: (context, candidates, rejects) {
                    final collapsed = _collapsed[folder] ?? false;
                    final hovering = _folderHover[folder] ?? false;
                    return Container(
                      decoration: BoxDecoration(
                        color: hovering
                            ? Colors.blue.withValues(alpha: 0.08)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  collapsed
                                      ? Icons.chevron_right
                                      : Icons.expand_more,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    _collapsed[folder] = !collapsed;
                                  });
                                },
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.folder_open, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  folder,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (folder != 'No folder')
                                PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'rename') {
                                      final name = await _promptFolderName(
                                        initial: folder,
                                      );
                                      if (name != null &&
                                          name.trim().isNotEmpty &&
                                          name.trim() != folder) {
                                        await svc.renameFolder(
                                          folder,
                                          name.trim(),
                                        );
                                        setState(() {
                                          _manualFolders.remove(folder);
                                          _manualFolders.add(name.trim());
                                          _folderNamesCache = _folderNamesCache
                                              .map(
                                                (e) => e == folder
                                                    ? name.trim()
                                                    : e,
                                              )
                                              .toList();
                                        });
                                        await _settings.setManualFolders(
                                          _manualFolders,
                                        );
                                        await _settings.ensureFolderActive(
                                          name.trim(),
                                        );
                                        await _cloud.ensureInit();
                                        if (_cloud.isReady) {
                                          await _cloud.syncSettingsOnly();
                                        }
                                      }
                                    } else if (v == 'archive') {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Archive folder'),
                                          content: Text(
                                            'This will hide "$folder" from the main screen without deleting its projects. Continue?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Archive'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await _settings.archiveFolder(folder);
                                        setState(() {
                                          _manualFolders.remove(folder);
                                          _archivedFolders.add(folder);
                                          _folderHover.remove(folder);
                                          _collapsed.remove(folder);
                                          _folderNamesCache.remove(folder);
                                        });
                                        await _cloud.ensureInit();
                                        if (_cloud.isReady) {
                                          await _cloud.syncSettingsOnly();
                                        }
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Folder "$folder" archived.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } else if (v == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Delete folder'),
                                          content: Text(
                                            'Projects will be moved to "No folder". Are you sure you want to delete "$folder"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await svc.renameFolder(folder, '');
                                        setState(() {
                                          _manualFolders.remove(folder);
                                          _folderHover.remove(folder);
                                          _collapsed.remove(folder);
                                          _folderNamesCache.remove(folder);
                                        });
                                        await _settings.setManualFolders(
                                          _manualFolders,
                                        );
                                        await _cloud.ensureInit();
                                        if (_cloud.isReady) {
                                          await _cloud.syncSettingsOnly();
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Rename folder'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text('Archive folder'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete folder'),
                                    ),
                                  ],
                                  tooltip: 'Folder options',
                                  icon: const Icon(Icons.more_vert),
                                ),
                            ],
                          ),
                          if (!collapsed)
                            ...grouped[folder]!.map(
                              (p) => _buildProjectTile(p, svc, folder),
                            ),
                          if (!collapsed && grouped[folder]!.isNotEmpty)
                            const SizedBox(height: 12),
                          if (!collapsed && grouped[folder]!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 38,
                                bottom: 8,
                              ),
                              child: Text(
                                'Drag projects here',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  onWillAcceptWithDetails: (_) {
                    setState(() => _folderHover[folder] = true);
                    return true;
                  },
                  onLeave: (_) => setState(() => _folderHover[folder] = false),
                  onAcceptWithDetails: (details) async {
                    setState(() => _folderHover[folder] = false);
                    final proj = details.data;
                    final target = (folder == 'No folder' ? '' : folder).trim();
                    final current = proj.folder.trim();
                    if (current == target) return; // no-op drop, evita ensuciar
                    await svc.setProjectFolder(proj.projectId, target);
                    await _ensureFolder(target);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectTile(ProjectSummary p, ReviewService svc, String folder) {
    final child = Card(
      child: ListTile(
        leading: FutureBuilder<bool>(
          key: ValueKey(
            '${p.projectId}_${p.updatedAtMs}_${p.reviewed}_${p.total}',
          ),
          future: _cloud.isProjectDirty(p.projectId),
          builder: (_, snapDirty) {
            final dirty = snapDirty.data ?? false;
            return Icon(
              dirty ? Icons.cloud_upload : Icons.cloud_done,
              color: dirty ? Colors.orange : Colors.green,
            );
          },
        ),
        title: Text(p.title),
        subtitle: Text(
          '${p.reviewed}/${p.total} (${p.total == 0 ? 0 : (p.reviewed * 100 ~/ p.total)} %) · line ${p.currentIndex + 1}/${p.total}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            if (v == 'open') {
              if (await _canOpenProject(p)) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewPage(db: widget.db, projectId: p.projectId),
                  ),
                );
              }
            } else if (v == 'export') {
              await svc.exportAndShareProject(context, projectId: p.projectId);
            } else if (v == 'move_folder') {
              await _selectFolderForProject(p, svc);
            } else if (v == 'rename') {
              await _renameProject(p, svc);
            } else if (v == 'sync_up') {
              await _cloud.ensureInit();
              if (!_cloud.isReady) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Supabase not available (config/auth).'),
                  ),
                );
                return;
              }
              if (!mounted) return;
              try {
                await _runWithProgress(
                  context,
                  initial: 'Uploading project...',
                  action: (update) async {
                    update('Uploading project...');
                    await _cloud.pushProject(
                      p.projectId,
                      onProgress: (v, stage) {
                        final pct = (v * 100).toInt();
                        update('$stage ($pct %)');
                      },
                    );
                  },
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('Project uploaded.')),
                );
              } on TimeoutException {
                // El mensaje ya se muestra en _runWithProgress.
              } on CloudSyncException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
                debugPrint(
                  'sync_up cloud error [${e.code}]: ${e.userMessage} | '
                  'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
                );
              } catch (e) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Error uploading project.')),
                );
                debugPrint('sync_up error: $e');
              }
            } else if (v == 'sync_down') {
              await _cloud.ensureInit();
              if (!_cloud.isReady) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Supabase not available (config/auth).'),
                  ),
                );
                return;
              }
              if (!mounted) return;
              try {
                await _runWithProgress(
                  context,
                  initial: 'Downloading project...',
                  action: (update) async {
                    update('Downloading project...');
                    await _cloud.pullProject(
                      p.projectId,
                      onProgress: (v, stage) {
                        final pct = (v * 100).toInt();
                        update('$stage ($pct %)');
                      },
                    );
                  },
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text('Project downloaded.')),
                );
              } on TimeoutException {
                // El mensaje ya se muestra en _runWithProgress.
              } on CloudSyncException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
                debugPrint(
                  'sync_down cloud error [${e.code}]: ${e.userMessage} | '
                  'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
                );
              } catch (e) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Error downloading project.')),
                );
                debugPrint('sync_down error: $e');
              }
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete project'),
                  content: const Text(
                    'Lines and metrics will be deleted. Are you sure?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await svc.deleteProject(p.projectId);
                await _cloud.ensureInit();
                if (_cloud.isReady) {
                  await _cloud.deleteRemoteProject(p.projectId);
                }
              }
            } else if (v == 'archive') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Archive project'),
                  content: const Text(
                    'Local files (ASS/video) will be deleted, but metrics and lines will be kept. Archive it?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Archive'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await svc.archiveProject(p.projectId);
                await _cloud.ensureInit();
                if (_cloud.isReady && mounted) {
                  try {
                    await _cloud.pushProject(p.projectId);
                  } on CloudSyncException catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.userMessage)),
                    );
                    debugPrint(
                      'archive cloud error [${e.code}]: ${e.userMessage} | '
                      'debug=${e.debugMessage ?? '-'} | cause=${e.cause ?? '-'}',
                    );
                  } catch (e) {
                    debugPrint('archive sync error: $e');
                  }
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Project archived.')),
                );
              }
            }
          },
          itemBuilder: (_) {
            final showDownload =
                DateTime.now().millisecondsSinceEpoch ==
                -1; // oculto por ahora, lo mantenemos en código
            return [
              const PopupMenuItem(value: 'open', child: Text('Open')),
              const PopupMenuItem(value: 'export', child: Text('Export ASS')),
              const PopupMenuItem(
                value: 'move_folder',
                child: Text('Move to folder'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(
                value: 'sync_up',
                child: Text('Upload to cloud'),
              ),
              if (showDownload)
                const PopupMenuItem(
                  value: 'sync_down',
                  child: Text('Download from cloud'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ];
          },
        ),
        onTap: () async {
          final navigator = Navigator.of(context);
          if (await _canOpenProject(p)) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) =>
                    ReviewPage(db: widget.db, projectId: p.projectId),
              ),
            );
          }
        },
      ),
    );

    return LongPressDraggable<ProjectSummary>(
      data: p,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Opacity(opacity: 0.9, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}
