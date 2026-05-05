import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'db/app_db.dart';
import 'projects/projects_page.dart';
import 'settings/settings_page.dart';
import 'settings/settings_service.dart';
import 'sync/cloud_sync_service.dart';
import 'sync/sync_prefs.dart';
import 'sync/supabase_manager.dart';
import 'utils/app_version.dart';

const bool _forceMacCloudLogin = bool.fromEnvironment(
  'VOICEX_FORCE_MACOS_CLOUD_LOGIN',
  defaultValue: kReleaseMode,
);
const String _macCloudLoginEmail = String.fromEnvironment(
  'VOICEX_MACOS_CLOUD_LOGIN_EMAIL',
  defaultValue: 'tests@localquestlanguages.com',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // Si no existe .env, seguimos con dart-define/Platform.
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
  final SupabaseManager _supabase = SupabaseManager.instance;
  bool _settingsSyncCompleted = false;
  Future<void>? _settingsSyncInFlight;
  Future<void>? _cloudScopeSyncInFlight;
  bool _cloudSessionBootstrapping = false;
  int _tab = 0;
  late bool _showSplash = widget.showSplash;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _supabase.addListener(_handleSupabaseChange);
    if (widget.showSplash) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showSplash = false);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncCloudSettingsIfReady());
    });
  }

  @override
  void dispose() {
    _supabase.removeListener(_handleSupabaseChange);
    _db.close();
    super.dispose();
  }

  void _handleSupabaseChange() {
    if (_supabase.isReady) {
      unawaited(_syncCloudAccountAndSettings());
    }
  }

  Future<void> _syncCloudAccountAndSettings() async {
    if (_cloudScopeSyncInFlight != null) {
      await _cloudScopeSyncInFlight;
      return;
    }

    if (mounted) {
      setState(() => _cloudSessionBootstrapping = true);
    } else {
      _cloudSessionBootstrapping = true;
    }
    _cloudScopeSyncInFlight = () async {
      await _ensureCloudAccountScope();
      await _syncCloudSettingsIfReady();
    }();

    try {
      await _cloudScopeSyncInFlight;
    } finally {
      _cloudScopeSyncInFlight = null;
      if (mounted) {
        setState(() => _cloudSessionBootstrapping = false);
      } else {
        _cloudSessionBootstrapping = false;
      }
    }
  }

  Future<void> _ensureCloudAccountScope() async {
    if (!_supabase.isAuthenticated) return;
    final userId = _supabase.userId?.trim() ?? '';
    if (userId.isEmpty) return;

    final settings = SettingsService.instance;
    await settings.init();
    final storedUserId = settings.activeCloudUserId.trim();
    if (storedUserId == userId) return;

    debugPrint(
      '[cloud] account changed $storedUserId -> $userId, clearing local cloud data',
    );
    await _db.clearProjectData();
    await SyncPrefs().clearAll();
    await settings.clearCloudScopedState();
    await settings.setActiveCloudUserId(userId);
    _settingsSyncCompleted = false;
    if (mounted) {
      setState(() {
        _tab = 0;
      });
    }
  }

  Future<void> _syncCloudSettingsIfReady() async {
    if (_settingsSyncCompleted ||
        !_supabase.hasCloudConfig ||
        !_supabase.isReady) {
      return;
    }
    if (_settingsSyncInFlight != null) {
      await _settingsSyncInFlight;
      return;
    }

    _settingsSyncInFlight = () async {
      try {
        final cloud = CloudSyncService(_db);
        await cloud.ensureInit();
        if (!mounted || !_supabase.isReady) return;
        await cloud.syncSettingsOnly();
        _settingsSyncCompleted = true;
      } catch (e) {
        debugPrint('[settings-sync] error: $e');
      }
    }();

    try {
      await _settingsSyncInFlight;
    } finally {
      _settingsSyncInFlight = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final requireCloudLogin = isMacOS && _forceMacCloudLogin;
    return MaterialApp(
      title: 'VoiceX',
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
                if ((requireCloudLogin || _supabase.hasCloudConfig) &&
                    !_supabase.isAuthenticated &&
                    _supabase.isInitializing) {
                  return const _CloudLoadingScreen();
                }
                if ((requireCloudLogin || _supabase.hasCloudConfig) &&
                    _supabase.isAuthenticated &&
                    _cloudSessionBootstrapping) {
                  return const _CloudLoadingScreen();
                }
                if ((requireCloudLogin || _supabase.hasCloudConfig) &&
                    !_supabase.isAuthenticated) {
                  return _CloudLoginScreen(
                    isDark: _themeMode == ThemeMode.dark,
                    onToggleTheme: _toggleTheme,
                    requiredEmail: requireCloudLogin ? _macCloudLoginEmail : '',
                    lockEmail: requireCloudLogin,
                    configReady: _supabase.hasCloudConfig,
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
                        label: 'Projects',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings),
                        label: 'Settings',
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
            Text('Initializing cloud...'),
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
    required this.requiredEmail,
    required this.lockEmail,
    required this.configReady,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final String requiredEmail;
  final bool lockEmail;
  final bool configReady;

  @override
  State<_CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<_CloudLoginScreen> {
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.requiredEmail);
  }

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
            SupabaseManager.instance.authError ?? 'Could not sign in to cloud.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = SupabaseManager.instance;
    final cloudReadyHint = widget.configReady
        ? 'Cloud access required for this build.'
        : 'Cloud access is not configured yet. This build cannot continue without it.';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Sign-In'),
        actions: [
          IconButton(
            tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
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
                  cloudReadyHint,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.requiredEmail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Use: ${widget.requiredEmail}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  readOnly: widget.lockEmail,
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
                  label: Text(_submitting ? 'Signing in...' : 'Sign in'),
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
