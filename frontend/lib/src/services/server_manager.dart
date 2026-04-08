import 'dart:io';
import 'package:flutter/foundation.dart';

class ServerManager {
  Process? _serverProcess;
  final String _sep = Platform.pathSeparator;

  String _joinPath(Iterable<String> parts) => parts.join(_sep);

  String _dirname(String filePath) {
    final normalized = filePath.replaceAll('/', _sep).replaceAll('\\', _sep);
    final last = normalized.lastIndexOf(_sep);
    return last > 0 ? normalized.substring(0, last) : normalized;
  }

  Future<void> startServer() async {
    if (_serverProcess != null) return;

    try {
      String serverPath;
      
      // Try multiple locations for the server executable
      final appDir = _dirname(Platform.resolvedExecutable);
      final possiblePaths = [
        _joinPath([appDir, 'server', 'UniScheduler_Server.exe']), // onedir subfolder
        _joinPath([appDir, 'UniScheduler_Server.exe']), // root location
        _joinPath([Directory.current.path, 'dist', 'UniScheduler_Server', 'UniScheduler_Server.exe']), // dev onedir dist
        _joinPath([Directory.current.path, 'dist', 'UniScheduler_Server.exe']), // dev dist root
        _joinPath([Directory.current.path, 'UniScheduler_Server.exe']), // dev project root
      ];

      serverPath = possiblePaths.firstWhere(
        (path) => File(path).existsSync(),
        orElse: () => possiblePaths.first,
      );

      final file = File(serverPath);
      if (!await file.exists()) {
        debugPrint('Server executable not found at: $serverPath');
        return;
      }

      // Cleanup any zombie processes first — AWAIT to prevent race condition
      await _ghostCleanup();
      // Small delay to let the OS release the port
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('Starting server: $serverPath');
      
      _serverProcess = await Process.start(
        serverPath,
        [],
        mode: ProcessStartMode.detachedWithStdio,
      );

      _serverProcess!.exitCode.then((code) {
        debugPrint('Server exited with code $code');
        _serverProcess = null;
      });

      // --- NEW: Wait for server to become responsive ---
      debugPrint('Waiting for server to be ready...');
      bool isReady = false;
      int attempts = 0;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 1);

      while (!isReady && attempts < 20) {
        try {
          final request = await client.getUrl(Uri.parse('http://127.0.0.1:8000/'));
          final response = await request.close();
          if (response.statusCode == 200) {
            isReady = true;
            debugPrint('Server is ready after ${attempts * 500}ms');
          }
        } catch (_) {
          attempts++;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      client.close();

      if (!isReady) {
        debugPrint('Warning: Server did not respond within 10 seconds.');
      }

    } catch (e) {
      debugPrint('Error starting server: $e');
    }
  }

  Future<void> _ghostCleanup() async {
    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'UniScheduler_Server.exe']);
        debugPrint('Ghost cleanup finished.');
      } catch (_) {}
    }
  }

  Future<void> stopServer() async {
    debugPrint('Stopping server...');
    
    // 1. Kill our managed process handle immediately
    _serverProcess?.kill();
    _serverProcess = null;

    // 2. Fire and forget a global taskkill to be sure
    _ghostCleanup();
  }
}

final serverManager = ServerManager();
