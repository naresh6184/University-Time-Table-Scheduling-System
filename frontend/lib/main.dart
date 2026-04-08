import 'package:flutter/material.dart';
import 'package:university_timetable_frontend/src/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';
import 'package:university_timetable_frontend/src/routing/app_router.dart';
import 'package:university_timetable_frontend/src/theme/app_theme.dart' as app_theme;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:university_timetable_frontend/src/services/server_manager.dart';

class WindowListenerImpl extends WindowListener {
  @override
  void onWindowClose() async {
    // Kill the server and exit immediately — no waiting
    if (Platform.isWindows) {
      Process.runSync('taskkill', ['/F', '/IM', 'UniScheduler_Server.exe']);
    }
    exit(0);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    windowManager.setPreventClose(true);
    windowManager.addListener(WindowListenerImpl());
    
    // Start the backend server
    await serverManager.startServer();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 850),
      minimumSize: Size(1000, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "UniScheduler",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final container = ProviderContainer();
  await container.read(activeSessionProvider.notifier).loadSavedSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'University Timetable Scheduler',
      theme: app_theme.AppTheme.light,
      darkTheme: app_theme.AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

