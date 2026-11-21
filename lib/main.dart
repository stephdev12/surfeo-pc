import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'api/core_controller.dart';
import 'api/surfeo_api_client.dart';
import 'storage/persistent_storage.dart';
import 'theme/surfeo_theme.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop Window Configuration
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(480, 800),
      minimumSize: Size(440, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Surfeo Secure Tunnel - PC Edition',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final storage = PersistentStorage();
  await storage.init();

  final apiClient = SurfeoApiClient();
  final coreController = CoreController();

  runApp(SurfeoPcApp(
    storage: storage,
    apiClient: apiClient,
    coreController: coreController,
  ));
}

class SurfeoPcApp extends StatelessWidget {
  final PersistentStorage storage;
  final SurfeoApiClient apiClient;
  final CoreController coreController;

  const SurfeoPcApp({
    super.key,
    required this.storage,
    required this.apiClient,
    required this.coreController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surfeo Secure Tunnel',
      debugShowCheckedModeBanner: false,
      theme: SurfeoTheme.darkTheme,
      home: HomeScreen(
        storage: storage,
        apiClient: apiClient,
        coreController: coreController,
      ),
    );
  }
}
