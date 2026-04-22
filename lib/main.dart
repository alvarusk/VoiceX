import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'db/app_db.dart';
import 'projects/projects_page.dart';
import 'settings/settings_page.dart';
import 'settings/settings_service.dart';
import 'sync/cloud_sync_service.dart';
import 'sync/supabase_manager.dart';
import 'utils/app_version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Si no existe .env en assets, seguimos con dart-define/Platform.
  }
  await SettingsService.instance.init();
  unawaited(SupabaseManager.instance.init());
  runApp(const VoiceXApp());
}

class VoiceXApp extends StatefulWidget {
  const VoiceXApp({
    super.key,
    this.autoSyncOnStart = true,
    this.showSplash = true,
  });

  final bool autoSyncOnStart;
  final bool showSplash;

  @override
  State<VoiceXApp> createState() => _VoiceXAppState();
}

class _VoiceXAppState extends State<VoiceXApp> {
  late final AppDatabase _db = AppDatabase();
  late final CloudSyncService _cloud = CloudSyncService(_db);
  final SupabaseManager _supabase = SupabaseManager.instance;
  int _tab = 0;
  late bool _showSplash = widget.showSplash;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _settingsSyncStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSyncOnStart) {
      _syncSettingsOnStart();
    }
    if (widget.showSplash) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  void _syncSettingsOnStart() {
    if (_settingsSyncStarted) return;
    _settingsSyncStarted = true;
    Future(() async {
      await _cloud.ensureInit();
      if (!_cloud.isReady) return;
      await _cloud.syncSettingsOnly();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceX for TakoWorks',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: _showSplash
          ? _SplashScreen()
          : AnimatedBuilder(
              animation: _supabase,
              builder: (context, _) {
                if (_supabase.hasCloudConfig &&
                    !_supabase.isAuthenticated &&
                    _supabase.isInitializing) {
                  return const _CloudLoadingScreen();
                }
                if (_supabase.hasCloudConfig && !_supabase.isAuthenticated) {
                  return _CloudLoginScreen(
                    isDark: _themeMode == ThemeMode.dark,
                    onToggleTheme: _toggleTheme,
                  );
                }
                return Scaffold(
                  body: SafeArea(
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        ProjectsPage(
                          db: _db,
                          isDark: _themeMode == ThemeMode.dark,
                          onToggleTheme: _toggleTheme,
                          autoSyncOnStart: widget.autoSyncOnStart,
                        ),
                        SettingsPage(
                          db: _db,
                          isDark: _themeMode == ThemeMode.dark,
                          onToggleTheme: _toggleTheme,
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _tab,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.folder),
                        label: 'Proyectos',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings),
                        label: 'Ajustes',
                      ),
                    ],
                    onDestinationSelected: (i) => setState(() => _tab = i),
                  ),
                );
              },
            ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }
}

class _SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final asset = defaultTargetPlatform == TargetPlatform.windows
        ? 'assets/voicex_splash_pc.png'
        : 'assets/voicex_splash_phone.png';
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          Positioned(
            right: 12,
            bottom: 8,
            child: FutureBuilder<String>(
              future: AppVersion.load(),
              builder: (context, snap) {
                final version = snap.data;
                if (version == null || version.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Text(
                  'v$version',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudLoadingScreen extends StatelessWidget {
  const _CloudLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Inicializando cloud...'),
          ],
        ),
      ),
    );
  }
}

class _CloudLoginScreen extends StatefulWidget {
  const _CloudLoginScreen({
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<_CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<_CloudLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final ok = await SupabaseManager.instance.signInWithPassword(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            SupabaseManager.instance.authError ??
                'No se pudo iniciar sesion en cloud.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = SupabaseManager.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso cloud'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Inicia sesion para cargar tus proyectos cloud.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitting ? null : _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_submitting ? 'Entrando...' : 'Iniciar sesion'),
                ),
                if (manager.authError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    manager.authError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
