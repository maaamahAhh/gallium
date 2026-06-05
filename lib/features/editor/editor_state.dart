// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:gallium_editor/features/settings/settings_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

/// Central state management for the editor.
///
/// Manages the current file, its content, modification state,
/// cursor position, and language detection. This is the single
/// source of truth for all editor-related state.
class EditorState extends ChangeNotifier {
  CodeController? _controller;
  String _fileName = 'Untitled';
  String? _filePath;
  bool _isModified = false;
  int _cursorLine = 1;
  int _cursorColumn = 1;
  final String _encoding = 'UTF-8';
  String _lineEnding = 'LF';

  /// The current code controller.
  CodeController get controller => _controller ??= _createController();

  /// The current file name (displayed in the title bar).
  String get fileName => _fileName;

  /// The current file path (null if unsaved).
  String? get filePath => _filePath;

  /// Whether the file has unsaved modifications.
  bool get isModified => _isModified;

  /// The current cursor line number (1-based).
  int get cursorLine => _cursorLine;

  /// The current cursor column number (1-based).
  int get cursorColumn => _cursorColumn;

  /// The detected file encoding.
  String get encoding => _encoding;

  /// The line ending style (LF or CRLF).
  String get lineEnding => _lineEnding;

  CodeController _createController() {
    return CodeController(text: '', language: plaintext)
      ..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _updateCursorPosition();
    _isModified = true;
    notifyListeners();
  }

  void _updateCursorPosition() {
    final ctrl = _controller;
    if (ctrl == null) return;

    final text = ctrl.text;
    final selection = ctrl.selection;
    if (!selection.isValid) return;

    final offset = selection.baseOffset;
    var line = 1;
    var column = 1;

    for (var i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        line++;
        column = 1;
      } else {
        column++;
      }
    }

    if (_cursorLine != line || _cursorColumn != column) {
      _cursorLine = line;
      _cursorColumn = column;
      notifyListeners();
    }
  }

  /// Opens a file from [path] and loads its content into the editor.
  Future<void> openFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();

    // Detect line ending.
    if (content.contains('\r\n')) {
      _lineEnding = 'CRLF';
    } else {
      _lineEnding = 'LF';
    }

    _filePath = path;
    _fileName = path.split(Platform.pathSeparator).last;
    _isModified = false;

    // Detect language from file extension.
    final language = _detectLanguage(_fileName);

    final ctrl = _controller;
    if (ctrl != null) {
      ctrl
        ..removeListener(_onTextChanged)
        ..dispose();
    }

    _controller = CodeController(text: content, language: language)
      ..addListener(_onTextChanged);
    _updateCursorPosition();
    notifyListeners();
  }

  /// Saves the current content to the file at [filePath].
  ///
  /// Returns true if the save was successful.
  Future<bool> save() async {
    if (_filePath == null) return false;
    return saveAs(_filePath!);
  }

  /// Saves the current content to the file at [path].
  ///
  /// If the file extension changes, the editor's language mode is
  /// updated to match the new extension so syntax highlighting
  /// reflects the correct language.
  Future<bool> saveAs(String path) async {
    try {
      final ctrl = _controller;
      if (ctrl == null) return false;

      final file = File(path);
      await file.writeAsString(ctrl.text);

      final oldFileName = _fileName;
      _filePath = path;
      _fileName = path.split(Platform.pathSeparator).last;
      _isModified = false;

      // Update language if the file extension changed.
      if (oldFileName != _fileName) {
        final language = _detectLanguage(_fileName);
        ctrl.language = language;
      }

      notifyListeners();
      return true;
    } on Exception {
      return false;
    }
  }

  /// Creates a new untitled document.
  void newFile() {
    final ctrl = _controller;
    if (ctrl != null) {
      ctrl
        ..removeListener(_onTextChanged)
        ..dispose();
    }

    _controller = CodeController(text: '', language: plaintext)
      ..addListener(_onTextChanged);

    _fileName = 'Untitled';
    _filePath = null;
    _isModified = false;
    _cursorLine = 1;
    _cursorColumn = 1;
    notifyListeners();
  }

  /// Detects the programming language from a file extension.
  Mode _detectLanguage(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    return switch (ext) {
      'dart' => dart,
      'java' => java,
      'js' || 'mjs' || 'cjs' => javascript,
      'json' => json,
      'md' || 'markdown' => markdown,
      'py' => python,
      'xml' || 'html' || 'htm' || 'svg' => xml,
      'yaml' || 'yml' => yaml,
      'cpp' || 'c' || 'h' || 'hpp' => cpp,
      'css' || 'scss' => css,
      'go' => go,
      'rs' => rust,
      'sh' || 'bash' => bash,
      'sql' => sql,
      'txt' || '' => plaintext,
      _ => plaintext,
    };
  }

  /// Returns the monospace text style for the editor with custom settings.
  TextStyle editorTextStyleFor({
    required double fontSize,
    required EditorFontFamily fontFamily,
  }) {
    return switch (fontFamily) {
      EditorFontFamily.robotoMono => GoogleFonts.robotoMono(
        fontSize: fontSize,
        height: 1.5,
      ),
      EditorFontFamily.sourceCodePro => GoogleFonts.sourceCodePro(
        fontSize: fontSize,
        height: 1.5,
      ),
      EditorFontFamily.firaCode => GoogleFonts.firaCode(
        fontSize: fontSize,
        height: 1.5,
      ),
    };
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    super.dispose();
  }
}
