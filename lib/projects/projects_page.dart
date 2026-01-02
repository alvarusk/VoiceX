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
import 'project_import_sheet.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({
    super.key,
    required this.db,
    required this.isDark,
    required this.onToggleTheme,
  });
  final AppDatabase db;
  final bool isDark;
  final VoidCallback onToggleTheme;

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
  final Map<String, bool> _folderHover = {}; // folder -> drag hover
  List<String> _folderNamesCache = [];

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
    if (_syncingAll) {
      _showSnack('Proyecto aún no sincronizado.');
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadManualFolders();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  Future<void> _loadManualFolders() async {
    await _settings.init();
    setState(() {
      _manualFolders
        ..clear()
        ..addAll(_settings.manualFolders);
      for (final f in _manualFolders) {
        _collapsed.putIfAbsent(f, () => false);
        if (!_folderNamesCache.contains(f)) {
          _folderNamesCache.add(f);
        }
      }
    });
  }

  Future<void> _autoSync() async {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    await _cloud.ensureInit();
    if (!_cloud.isReady || !mounted) return;
    _syncingAll = true;
    try {
      await _runWithProgress(
        context,
        initial: 'Sincronizando proyectos...',
        action: (update) async {
          await _cloud.syncAllProjects(
            onProgress: (v, stage) {
              final pct = (v * 100).toInt();
              update('$stage ($pct %)');
            },
          );
        },
      );
      if (mounted) {
        setState(() {});
        await _loadManualFolders();
        _showSnack('Sincronizacion inicial completa.');
      }
    } catch (e) {
      debugPrint('autoSync error: $e');
      if (mounted) {
        _showSnack('Error al sincronizar al iniciar.');
      }
    }
    if (mounted) setState(() => _syncingAll = false);
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

    bool timedOut = false;
    try {
      await action(
        (m) => notifier.value = m,
      ).timeout(const Duration(minutes: 5));
    } on TimeoutException {
      timedOut = true;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Operación cancelada por tardar demasiado.'),
        ),
      );
    } finally {
      if (!timedOut) {
        // no-op; kept variable to silence analyzer warning about control flow
      }
      navigator.pop();
    }
  }

  Future<String?> _promptFolderName({String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Carpeta'),
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
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _ensureFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _manualFolders.add(trimmed);
      _collapsed.putIfAbsent(trimmed, () => false);
      if (!_folderNamesCache.contains(trimmed)) {
        _folderNamesCache.add(trimmed);
      }
    });
    _settings.setManualFolders(_manualFolders);
  }

  Future<void> _selectFolderForProject(
    ProjectSummary p,
    ReviewService svc,
  ) async {
    final folders = <String>{
      'Sin carpeta',
      ..._manualFolders,
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
                      'Mover a carpeta',
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
                            Navigator.pop(ctx, f == 'Sin carpeta' ? '' : f),
                      ),
                    ),
                    const Divider(),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Crear carpeta nueva',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => newName = v,
                      onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, newName.trim()),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Crear y mover'),
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
    _ensureFolder(trimmed);
  }

  Future<void> _renameProject(ProjectSummary p, ReviewService svc) async {
    final ctrl = TextEditingController(text: p.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar proyecto'),
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
                  hintText: 'Solo episodio, ej: E05',
                ),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    await svc.renameProject(p.projectId, newName.trim());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final svc = ReviewService(widget.db);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: SizedBox(
          height: 128, // 200% más grande
          child: Image.asset('assets/voicex_logo.png', fit: BoxFit.contain),
        ),
        toolbarHeight: 150,
        actions: [
          IconButton(
            tooltip: 'Costes API',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              if (!SupabaseManager.instance.isReady) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Supabase no configurado (URL/key).'),
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
            },
          ),
          IconButton(
            tooltip: widget.isDark ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Sincronizar con cloud',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _cloud.ensureInit();
              if (!_cloud.isReady) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Supabase no configurado (URL/key).'),
                    ),
                  );
                }
                return;
              }
              if (!context.mounted) return;
              await _runWithProgress(
                context,
                initial: 'Sincronizando proyectos...',
                action: (update) async {
                  update('Sincronizando proyectos...');
                  await _cloud.syncAllProjects(
                    onProgress: (v, stage) {
                      final pct = (v * 100).toStringAsFixed(0);
                      final pctInt = double.tryParse(pct)?.toInt() ?? 0;
                      update('$stage ($pctInt %)');
                    },
                  );
                },
              );
              if (context.mounted) {
                await _loadManualFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sincronizacion cloud completa.'),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Crear carpeta',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final name = await _promptFolderName(initial: '');
              if (name == null) return;
              _ensureFolder(name);
              if (context.mounted && name.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Carpeta "$name" lista. Úsala al crear o mover proyectos.',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Nuevo proyecto',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final projectId = await showModalBottomSheet<String?>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProjectImportSheet(
                  db: widget.db,
                  initialFolder: null,
                  folderOptions: _folderNamesCache
                      .where((f) => f != 'Sin carpeta')
                      .toList(),
                  onFolderCreated: (f) => _ensureFolder(f),
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
          if (items.isEmpty &&
              _manualFolders.isEmpty &&
              _folderNamesCache.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay proyectos todavía.\nPulsa + para importar un ASS.',
                ),
              ),
            );
          }

          final grouped = <String, List<ProjectSummary>>{};
          for (final p in items) {
            final folder = p.folder.trim().isEmpty
                ? 'Sin carpeta'
                : p.folder.trim();
            (grouped[folder] ??= []).add(p);
          }
          for (final f in _manualFolders) {
            grouped.putIfAbsent(f, () => []);
          }
          for (final f in _folderNamesCache) {
            grouped.putIfAbsent(f, () => []);
          }
          final folderNames = grouped.keys.toList()
            ..sort((a, b) {
              if (a == 'Sin carpeta') return -1;
              if (b == 'Sin carpeta') return 1;
              return a.toLowerCase().compareTo(b.toLowerCase());
            });
          _folderNamesCache = folderNames;

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
                              if (folder != 'Sin carpeta')
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
                                        _settings.setManualFolders(
                                          _manualFolders,
                                        );
                                      }
                                    } else if (v == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Eliminar carpeta'),
                                          content: Text(
                                            'Los proyectos se moverán a "Sin carpeta". ¿Seguro que deseas borrar "$folder"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Eliminar'),
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
                                        _settings.setManualFolders(
                                          _manualFolders,
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Renombrar carpeta'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar carpeta'),
                                    ),
                                  ],
                                  tooltip: 'Opciones de carpeta',
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
                                'Arrastra proyectos aquí',
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
                    final target = (folder == 'Sin carpeta' ? '' : folder)
                        .trim();
                    final current = proj.folder.trim();
                    if (current == target) return; // no-op drop, evita ensuciar
                    await svc.setProjectFolder(proj.projectId, target);
                    _ensureFolder(target);
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
          '${p.reviewed}/${p.total} (${p.total == 0 ? 0 : (p.reviewed * 100 ~/ p.total)} %) · línea ${p.currentIndex + 1}/${p.total}',
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
                    content: Text('Supabase no configurado (URL/key).'),
                  ),
                );
                return;
              }
              if (!mounted) return;
              await _runWithProgress(
                context,
                initial: 'Subiendo proyecto...',
                action: (update) async {
                  update('Subiendo proyecto...');
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
                const SnackBar(content: Text('Proyecto subido.')),
              );
            } else if (v == 'sync_down') {
              await _cloud.ensureInit();
              if (!_cloud.isReady) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Supabase no configurado (URL/key).'),
                  ),
                );
                return;
              }
              if (!mounted) return;
              bool timeout = false;
              await _runWithProgress(
                context,
                initial: 'Descargando proyecto...',
                action: (update) async {
                  update('Descargando proyecto...');
                  try {
                    await _cloud
                        .pullProject(
                          p.projectId,
                          onProgress: (v, stage) {
                            final pct = (v * 100).toInt();
                            update('$stage ($pct %)');
                          },
                        )
                        .timeout(
                          const Duration(minutes: 5),
                          onTimeout: () =>
                              throw TimeoutException('download timeout'),
                        );
                  } on TimeoutException {
                    timeout = true;
                    rethrow;
                  }
                },
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    timeout
                        ? 'Descarga cancelada por tardar demasiado.'
                        : 'Proyecto descargado.',
                  ),
                ),
              );
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar proyecto'),
                  content: const Text(
                    'Se borrarán líneas y métricas. ¿Seguro?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'),
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
                  title: const Text('Archivar proyecto'),
                  content: const Text(
                    'Se eliminarán los archivos locales (ASS/vídeo) pero se mantienen métricas y líneas. ¿Archivar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Archivar'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await svc.archiveProject(p.projectId);
                await _cloud.ensureInit();
                if (_cloud.isReady) {
                  await _cloud.pushProject(p.projectId);
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Proyecto archivado.')),
                );
              }
            }
          },
          itemBuilder: (_) {
            final showDownload =
                DateTime.now().millisecondsSinceEpoch ==
                -1; // oculto por ahora, lo mantenemos en código
            return [
              const PopupMenuItem(value: 'open', child: Text('Abrir')),
              const PopupMenuItem(value: 'export', child: Text('Exportar ASS')),
              const PopupMenuItem(
                value: 'move_folder',
                child: Text('Mover a carpeta'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              const PopupMenuItem(
                value: 'sync_up',
                child: Text('Subir a cloud'),
              ),
              if (showDownload)
                const PopupMenuItem(
                  value: 'sync_down',
                  child: Text('Bajar de cloud'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'archive', child: Text('Archivar')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
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
