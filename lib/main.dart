import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'db/app_db.dart';
import 'projects/projects_page.dart';
import 'settings/settings_page.dart';
import 'settings/settings_service.dart';
import 'sync/supabase_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await SupabaseManager.instance.init();
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
  int _tab = 0;
  late bool _showSplash = widget.showSplash;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
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
          : Scaffold(
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
                  NavigationDestination(icon: Icon(Icons.folder), label: 'Proyectos'),
                  NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
                ],
                onDestinationSelected: (i) => setState(() => _tab = i),
              ),
            ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }
}

class _SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const version = '1.0.0+1';
    final asset = defaultTargetPlatform == TargetPlatform.windows
        ? 'assets/voicex_splash_pc.png'
        : 'assets/voicex_splash_phone.png';
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
          ),
          const Positioned(
            right: 12,
            bottom: 8,
            child: Text(
              'v$version',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
