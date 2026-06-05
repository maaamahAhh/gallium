// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(420, 320),
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

  runApp(const GalliumInstaller());
}

class GalliumInstaller extends StatelessWidget {
  const GalliumInstaller({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallium Installer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const InstallerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});

  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage>
    with WindowListener {
  String _statusText = 'Installing Gallium...';
  double _progress = 0.0;
  bool _isComplete = false;
  bool _hasError = false;

  // Google brand colors for the marquee progress bar.
  static const _googleBlue = Color(0xFF4285F4);
  static const _googleRed = Color(0xFFEA4335);
  static const _googleYellow = Color(0xFFFBBC05);
  static const _googleGreen = Color(0xFF34A853);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Start installation after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInstallation();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // Allow closing only if installation is complete or errored.
    if (_isComplete || _hasError) {
      windowManager.destroy();
    }
  }

  Future<void> _runInstallation() async {
    try {
      // Step 1: Determine install directory.
      setState(() {
        _statusText = 'Preparing...';
        _progress = 0.05;
      });

      final appData = Platform.environment['LOCALAPPDATA']!;
      final installDir = p.join(appData, 'Programs', 'Gallium');

      // Step 2: Load and extract the embedded release archive.
      setState(() {
        _statusText = 'Extracting files...';
        _progress = 0.1;
      });

      final archiveBytes =
          await rootBundle.load('assets/data/gallium_release.zip');
      final archive =
          ZipDecoder().decodeBytes(archiveBytes.buffer.asUint8List());

      final totalFiles = archive.files.length;
      var extractedCount = 0;

      for (final file in archive.files) {
        final filePath = p.join(installDir, file.name);
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
        extractedCount++;
        if (extractedCount % 3 == 0 || extractedCount == totalFiles) {
          setState(() {
            _progress = 0.1 + 0.6 * (extractedCount / totalFiles);
          });
          // Yield to let the UI update.
          await Future.delayed(Duration.zero);
        }
      }

      // Step 3: Create desktop shortcut.
      setState(() {
        _statusText = 'Creating shortcuts...';
        _progress = 0.8;
      });

      final exePath = p.join(installDir, 'Gallium.exe');
      final desktop = Platform.environment['USERPROFILE']!;
      final shortcutPath = p.join(desktop, 'Desktop', 'Gallium.lnk');

      await _createShortcut(
        shortcutPath: shortcutPath,
        targetPath: exePath,
        iconPath: exePath,
        description: 'Gallium Editor',
      );

      // Step 4: Create Start Menu shortcut.
      final appDataRoaming = Platform.environment['APPDATA']!;
      final startMenu = p.join(
        appDataRoaming,
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
      );
      final startMenuShortcut = p.join(startMenu, 'Gallium.lnk');

      await _createShortcut(
        shortcutPath: startMenuShortcut,
        targetPath: exePath,
        iconPath: exePath,
        description: 'Gallium Editor',
      );

      // Step 5: Register uninstaller in Windows Registry.
      setState(() {
        _statusText = 'Registering application...';
        _progress = 0.9;
      });

      await _registerUninstaller(
        installDir: installDir,
        exePath: exePath,
      );

      // Step 6: Done — launch Gallium and exit.
      setState(() {
        _statusText = 'Complete!';
        _progress = 1.0;
        _isComplete = true;
      });

      // Launch Gallium.exe.
      await Process.start(exePath, []);

      // Wait briefly so the user sees "Complete!", then exit.
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } on Exception catch (e) {
      setState(() {
        _statusText = 'Installation failed: $e';
        _hasError = true;
      });
    }
  }

  Future<void> _createShortcut({
    required String shortcutPath,
    required String targetPath,
    required String iconPath,
    required String description,
  }) async {
    // Use PowerShell to create a .lnk shortcut via WScript.Shell COM.
    final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$shortcutPath')
\$s.TargetPath = '$targetPath'
\$s.IconLocation = '$iconPath, 0'
\$s.Description = '$description'
\$s.WorkingDirectory = '${p.dirname(targetPath)}'
\$s.Save()
''';

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', script],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to create shortcut: ${result.stderr}');
    }
  }

  Future<void> _registerUninstaller({
    required String installDir,
    required String exePath,
  }) async {
    final uninstallKey =
        r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Gallium';

    final script = '''
if (-not (Test-Path '$uninstallKey')) {
  New-Item -Path '$uninstallKey' -Force | Out-Null
}
Set-ItemProperty -Path '$uninstallKey' -Name 'DisplayName' -Value 'Gallium Editor'
Set-ItemProperty -Path '$uninstallKey' -Name 'DisplayVersion' -Value '1.0.0'
Set-ItemProperty -Path '$uninstallKey' -Name 'Publisher' -Value 'dev.gallium'
Set-ItemProperty -Path '$uninstallKey' -Name 'InstallLocation' -Value '$installDir'
Set-ItemProperty -Path '$uninstallKey' -Name 'DisplayIcon' -Value '$exePath'
Set-ItemProperty -Path '$uninstallKey' -Name 'UninstallString' -Value 'powershell -NoProfile -Command "Remove-Item -Recurse -Force \\"$installDir\\"; Remove-Item -Path \\"$uninstallKey\\" -Force"'
Set-ItemProperty -Path '$uninstallKey' -Name 'NoModify' -Value 1 -Type DWord
Set-ItemProperty -Path '$uninstallKey' -Name 'NoRepair' -Value 1 -Type DWord
''';

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', script],
    );

    if (result.exitCode != 0) {
      // Non-critical: don't throw, just log.
      stderr.writeln('Warning: Failed to register uninstaller: ${result.stderr}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: 420,
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Close button (top-right).
            Positioned(
              top: 8,
              right: 8,
              child: _CloseButton(
                enabled: _isComplete || _hasError,
                onClose: () => windowManager.close(),
              ),
            ),

            // Main content: centered logo + status + progress.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gallium Logo.
                  Image.asset(
                    'assets/images/gallium_logo.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),

                  // Status text.
                  Text(
                    _statusText,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _hasError
                          ? colorScheme.error
                          : const Color(0xFF5F6368),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Four-color marquee progress bar.
                  SizedBox(
                    width: 280,
                    child: _MarqueeProgressBar(
                      progress: _progress,
                      colors: const [
                        _googleBlue,
                        _googleRed,
                        _googleYellow,
                        _googleGreen,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A close button that appears in the top-right corner.
class _CloseButton extends StatefulWidget {
  const _CloseButton({
    required this.enabled,
    required this.onClose,
  });

  final bool enabled;
  final VoidCallback onClose;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? (_isHovering ? Colors.black54 : const Color(0xFF9AA0A6))
        : const Color(0xFF9AA0A6).withValues(alpha: 0.3);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onClose : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _isHovering && widget.enabled
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Icon(Icons.close, size: 16, color: color),
        ),
      ),
    );
  }
}

/// A Google-style four-color marquee progress bar.
///
/// When [progress] < 1.0, displays a looping gradient animation.
/// When [progress] reaches 1.0, fills the bar completely.
class _MarqueeProgressBar extends StatefulWidget {
  const _MarqueeProgressBar({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final List<Color> colors;

  @override
  State<_MarqueeProgressBar> createState() => _MarqueeProgressBarState();
}

class _MarqueeProgressBarState extends State<_MarqueeProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(1.5),
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: Stack(
              children: [
                // Background fill based on progress.
                FractionallySizedBox(
                  widthFactor: widget.progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _buildGradient(),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                // Animated shimmer overlay when not complete.
                if (widget.progress < 1.0)
                  FractionallySizedBox(
                    widthFactor: widget.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _buildShimmerGradient(),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Gradient _buildGradient() {
    return LinearGradient(
      colors: widget.colors,
    );
  }

  Gradient _buildShimmerGradient() {
    final offset = _controller.value;
    return LinearGradient(
      begin: Alignment(offset * 2 - 1, 0),
      end: Alignment(offset * 2, 0),
      colors: [
        Colors.white.withValues(alpha: 0.0),
        Colors.white.withValues(alpha: 0.3),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}
