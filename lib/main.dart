// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallium_editor/features/editor/editor_page.dart';
import 'package:gallium_editor/features/settings/settings_service.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

/// The entry point for the Gallium document editor.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = await SettingsService.load();

  // Check if a file path was passed as a command-line argument
  // (e.g., when the user double-clicks a file to "Open with Gallium").
  String? initialFilePath;
  if (args.isNotEmpty) {
    final candidate = args.first;
    final file = File(candidate);
    if (await file.exists()) {
      initialFilePath = candidate;
    }
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    GalliumApp(
      settingsService: settingsService,
      initialFilePath: initialFilePath,
    ),
  );
}

/// The root widget for the Gallium application.
///
/// Configures Material Design 3 theming with Roboto typography and sets up
/// the application's navigation structure.
class GalliumApp extends StatelessWidget {
  /// Creates the root application widget.
  const GalliumApp({
    required this.settingsService,
    this.initialFilePath,
    super.key,
  });

  final SettingsService settingsService;
  final String? initialFilePath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Gallium',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settingsService.themeMode.toThemeMode(),
          home: EditorPage(
            settingsService: settingsService,
            initialFilePath: initialFilePath,
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
