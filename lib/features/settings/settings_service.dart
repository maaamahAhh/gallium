// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode options.
enum ThemeModeOption {
  system,
  light,
  dark;

  ThemeMode toThemeMode() => switch (this) {
    ThemeModeOption.system => ThemeMode.system,
    ThemeModeOption.light => ThemeMode.light,
    ThemeModeOption.dark => ThemeMode.dark,
  };

  static ThemeModeOption fromThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => ThemeModeOption.light,
    ThemeMode.dark => ThemeModeOption.dark,
    _ => ThemeModeOption.system,
  };
}

/// Monospace font family options for the editor.
enum EditorFontFamily {
  robotoMono('Roboto Mono'),
  sourceCodePro('Source Code Pro'),
  firaCode('Fira Code');

  const EditorFontFamily(this.displayName);

  final String displayName;
}

/// Manages application settings with persistence via SharedPreferences.
///
/// Provides theme mode, editor font size, and editor font family settings.
/// Changes are persisted automatically and notify listeners.
class SettingsService extends ChangeNotifier {
  SettingsService._(this._prefs);

  final SharedPreferences _prefs;

  static const _keyThemeMode = 'theme_mode';
  static const _keyEditorFontSize = 'editor_font_size';
  static const _keyEditorFontFamily = 'editor_font_family';

  /// Loads settings from persistent storage.
  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final service = SettingsService._(prefs).._initFromPrefs();
    return service;
  }

  // --- Theme Mode ---

  ThemeModeOption _themeMode = ThemeModeOption.system;

  /// The current theme mode setting.
  ThemeModeOption get themeMode => _themeMode;

  set themeMode(ThemeModeOption value) {
    if (_themeMode == value) return;
    _themeMode = value;
    _prefs.setString(_keyThemeMode, value.name);
    notifyListeners();
  }

  // --- Editor Font Size ---

  double _editorFontSize = 14.0;

  /// The current editor font size in pixels.
  double get editorFontSize => _editorFontSize;

  set editorFontSize(double value) {
    if (_editorFontSize == value) return;
    _editorFontSize = value;
    _prefs.setDouble(_keyEditorFontSize, value);
    notifyListeners();
  }

  // --- Editor Font Family ---

  EditorFontFamily _editorFontFamily = EditorFontFamily.robotoMono;

  /// The current editor font family.
  EditorFontFamily get editorFontFamily => _editorFontFamily;

  set editorFontFamily(EditorFontFamily value) {
    if (_editorFontFamily == value) return;
    _editorFontFamily = value;
    _prefs.setString(_keyEditorFontFamily, value.name);
    notifyListeners();
  }

  /// Initializes values from SharedPreferences (called after load).
  void _initFromPrefs() {
    final themeName = _prefs.getString(_keyThemeMode);
    if (themeName != null) {
      _themeMode = ThemeModeOption.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => ThemeModeOption.system,
      );
    }

    final fontSize = _prefs.getDouble(_keyEditorFontSize);
    if (fontSize != null) {
      _editorFontSize = fontSize.clamp(8.0, 32.0);
    }

    final fontFamily = _prefs.getString(_keyEditorFontFamily);
    if (fontFamily != null) {
      _editorFontFamily = EditorFontFamily.values.firstWhere(
        (e) => e.name == fontFamily,
        orElse: () => EditorFontFamily.robotoMono,
      );
    }
  }
}
