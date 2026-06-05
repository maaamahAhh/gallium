// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:gallium_editor/features/editor/editor_state.dart';
import 'package:gallium_editor/features/file_tree/file_node.dart';
import 'package:gallium_editor/features/file_tree/file_tree_service.dart';
import 'package:gallium_editor/features/file_tree/files_page.dart';
import 'package:gallium_editor/features/search/search_page.dart';
import 'package:gallium_editor/features/search/search_service.dart';
import 'package:gallium_editor/features/settings/settings_page.dart';
import 'package:gallium_editor/features/settings/settings_service.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:gallium_editor/ui/theme/highlight_theme.dart';
import 'package:gallium_editor/ui/widgets/app_title_bar.dart';
import 'package:window_manager/window_manager.dart';

/// The main editor page for the Gallium application.
///
/// Displays a code editor with syntax highlighting, file operations,
/// cursor tracking, and keyboard shortcuts. The layout uses MD3
/// Surface color layers instead of dividers.
class EditorPage extends StatefulWidget {
  /// Creates the editor page.
  const EditorPage({
    required this.settingsService,
    this.initialFilePath,
    super.key,
  });

  final SettingsService settingsService;
  final String? initialFilePath;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WindowListener {
  final EditorState _editorState = EditorState();
  int _selectedIndex = 0;
  final List<String> _recentFiles = [];
  FileNode? _fileTreeRoot;
  final Set<String> _expandedPaths = {};
  bool _isFileTreeLoading = false;

  // Inline find/replace bar state.
  bool _showFindBar = false;
  final TextEditingController _findBarController = TextEditingController();
  final TextEditingController _replaceBarController = TextEditingController();
  bool _findCaseSensitive = false;
  bool _findUseRegex = false;
  int _findMatchCount = 0;
  int _findCurrentIndex = 0;
  List<TextSelection> _findMatches = const [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _editorState.addListener(_onEditorStateChanged);
    widget.settingsService.addListener(_onSettingsChanged);

    // Open the file passed via command-line argument (e.g., "Open with Gallium").
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFileFromPath(widget.initialFilePath!);
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _editorState
      ..removeListener(_onEditorStateChanged)
      ..dispose();
    widget.settingsService.removeListener(_onSettingsChanged);
    _findBarController.dispose();
    _replaceBarController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  // --- Inline find/replace ---

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      if (_showFindBar) {
        // If there's selected text, pre-fill the find field.
        final ctrl = _editorState.controller;
        final selection = ctrl.selection;
        if (selection.isValid && !selection.isCollapsed) {
          final selected = ctrl.text.substring(selection.start, selection.end);
          if (!selected.contains('\n')) {
            _findBarController.text = selected;
          }
        }
        _performFind();
      } else {
        _findMatches = const [];
        _findMatchCount = 0;
        _findCurrentIndex = 0;
      }
    });
  }

  void _performFind() {
    final query = _findBarController.text;
    if (query.isEmpty) {
      setState(() {
        _findMatches = const [];
        _findMatchCount = 0;
        _findCurrentIndex = 0;
      });
      return;
    }

    final text = _editorState.controller.text;
    final matches = <TextSelection>[];

    try {
      final pattern = _findUseRegex
          ? RegExp(query, caseSensitive: _findCaseSensitive)
          : RegExp(RegExp.escape(query), caseSensitive: _findCaseSensitive);

      for (final match in pattern.allMatches(text)) {
        matches.add(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
      }
    } on FormatException {
      // Invalid regex — no matches.
    }

    // Find which match is closest to current cursor.
    final cursorOffset = _editorState.controller.selection.baseOffset;
    var currentIndex = 0;
    if (cursorOffset > 0 && matches.isNotEmpty) {
      for (var i = 0; i < matches.length; i++) {
        if (matches[i].baseOffset >= cursorOffset) {
          currentIndex = i;
          break;
        }
        currentIndex = i;
      }
    }

    setState(() {
      _findMatches = matches;
      _findMatchCount = matches.length;
      _findCurrentIndex = currentIndex;
    });

    _jumpToMatch(currentIndex);
  }

  void _jumpToMatch(int index) {
    if (_findMatches.isEmpty || index < 0 || index >= _findMatches.length) {
      return;
    }
    final match = _findMatches[index];
    _editorState.controller.selection = match;
    // Scroll to make the match visible.
    // CodeField handles this via selection.
  }

  void _findNext() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCurrentIndex = (_findCurrentIndex + 1) % _findMatches.length;
    });
    _jumpToMatch(_findCurrentIndex);
  }

  void _findPrevious() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _findCurrentIndex =
          (_findCurrentIndex - 1 + _findMatches.length) % _findMatches.length;
    });
    _jumpToMatch(_findCurrentIndex);
  }

  void _replaceCurrent() {
    if (_findMatches.isEmpty || _findCurrentIndex >= _findMatches.length) {
      return;
    }
    final match = _findMatches[_findCurrentIndex];
    final ctrl = _editorState.controller;
    final replacement = _replaceBarController.text;

    final text = ctrl.text;
    ctrl.text = text.replaceRange(
      match.baseOffset,
      match.extentOffset,
      replacement,
    );

    // Re-run find after replacement.
    _performFind();
  }

  void _replaceAll() {
    if (_findMatches.isEmpty) return;
    final ctrl = _editorState.controller;
    final query = _findBarController.text;
    final replacement = _replaceBarController.text;

    if (query.isEmpty) return;

    try {
      final pattern = _findUseRegex
          ? RegExp(query, caseSensitive: _findCaseSensitive)
          : RegExp(RegExp.escape(query), caseSensitive: _findCaseSensitive);

      ctrl.text = ctrl.text.replaceAll(pattern, replacement);
      _performFind();
    } on FormatException {
      // Invalid regex.
    }
  }

  void _onSearchResultTap(SearchResult result) {
    _openFileFromPath(result.filePath);
    // After opening, jump to the line.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = _editorState.controller;
      final lines = ctrl.text.split('\n');
      var offset = 0;
      for (var i = 0; i < result.lineNumber - 1 && i < lines.length; i++) {
        offset += lines[i].length + 1;
      }
      final lineEnd =
          offset +
          (result.lineNumber - 1 < lines.length
              ? lines[result.lineNumber - 1].length
              : 0);
      ctrl.selection = TextSelection(baseOffset: offset, extentOffset: lineEnd);
      setState(() => _selectedIndex = 0);
    });
  }

  void _onEditorStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // --- File operations ---

  Future<void> _openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'md',
        'dart',
        'java',
        'js',
        'py',
        'json',
        'yaml',
        'yml',
        'xml',
        'html',
        'css',
        'cpp',
        'c',
        'h',
        'go',
        'rs',
        'sh',
        'sql',
      ],
    );

    if (result != null && result.files.single.path != null) {
      await _openFileFromPath(result.files.single.path!);
    }
  }

  Future<void> _openFileFromPath(String path) async {
    await _editorState.openFile(path);
    setState(() {
      _selectedIndex = 0;
      _recentFiles
        ..remove(path)
        ..insert(0, path);
      if (_recentFiles.length > 10) {
        _recentFiles.removeLast();
      }
    });
  }

  // --- Folder operations ---

  Future<void> _openFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Folder',
    );

    if (result != null) {
      setState(() => _isFileTreeLoading = true);
      try {
        final tree = await FileTreeService.loadTree(result);
        setState(() {
          _fileTreeRoot = tree;
          _expandedPaths
            ..clear()
            ..add(result);
        });
      } finally {
        setState(() => _isFileTreeLoading = false);
      }
    }
  }

  Future<void> _toggleExpand(String path) async {
    if (_expandedPaths.contains(path)) {
      setState(() => _expandedPaths.remove(path));
      return;
    }

    // Load children on demand if the directory hasn't been populated yet.
    final node = _findNode(_fileTreeRoot, path);
    if (node != null && node.isDirectory && node.children.isEmpty) {
      final children = await FileTreeService.loadChildren(node);
      setState(() {
        _fileTreeRoot = _updateNodeChildren(_fileTreeRoot!, path, children);
      });
    }

    setState(() => _expandedPaths.add(path));
  }

  FileNode? _findNode(FileNode? root, String path) {
    if (root == null) return null;
    if (root.path == path) return root;
    for (final child in root.children) {
      final found = _findNode(child, path);
      if (found != null) return found;
    }
    return null;
  }

  FileNode _updateNodeChildren(
    FileNode root,
    String path,
    List<FileNode> children,
  ) {
    if (root.path == path) {
      return root.copyWith(children: children);
    }
    return root.copyWith(
      children: root.children
          .map((c) => _updateNodeChildren(c, path, children))
          .toList(),
    );
  }

  void _closeFolder() {
    setState(() {
      _fileTreeRoot = null;
      _expandedPaths.clear();
    });
  }

  Future<bool> _saveFile() async {
    if (_editorState.filePath != null) {
      return _editorState.save();
    } else {
      return _saveFileAs();
    }
  }

  Future<bool> _saveFileAs() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save File',
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'md',
        'dart',
        'java',
        'js',
        'py',
        'json',
        'yaml',
        'yml',
        'xml',
        'html',
        'css',
        'cpp',
        'c',
        'h',
        'go',
        'rs',
        'sh',
        'sql',
      ],
    );

    if (result != null) {
      return _editorState.saveAs(result);
    }
    return false;
  }

  void _newFile() {
    _editorState.newFile();
  }

  // --- WindowListener ---

  @override
  void onWindowClose() {
    _handleWindowClose();
  }

  Future<void> _handleWindowClose() async {
    if (_editorState.isModified) {
      final shouldClose = await _showUnsavedDialog();
      if (!shouldClose) return;
    }
    await windowManager.destroy();
  }

  Future<bool> _showUnsavedDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text(
          '${_editorState.fileName} has unsaved changes. '
          'Do you want to close without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveFile();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DragToResizeArea(
      resizeEdgeSize: 6,
      child: Container(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.windowCornerRadius),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.windowCornerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Scaffold(
              backgroundColor: colorScheme.surface,
              body: Column(
                children: [
                  AppTitleBar(
                    onSearchTap: () {
                      setState(() {
                        _selectedIndex = 2; // Switch to Search page
                      });
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          onNewFile: _newFile,
                        ),
                        Expanded(
                          child: Container(
                            color: colorScheme.surfaceContainerLow,
                            padding: const EdgeInsets.only(
                              right: AppTheme.space12,
                              bottom: AppTheme.space12,
                              top: AppTheme.space4,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.cornerLarge,
                                ),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeInOutCubic,
                                switchOutCurve: Curves.easeInOutCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale:
                                          Tween<double>(
                                            begin: 0.98,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                      child: child,
                                    ),
                                  );
                                },
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      fit: StackFit.expand,
                                      alignment: Alignment.topLeft,
                                      children: [
                                        ...previousChildren,
                                        ?currentChild,
                                      ],
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey<int>(_selectedIndex),
                                  child: _buildContent(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _EditorView(
          editorState: _editorState,
          onOpen: _openFile,
          onSave: _saveFile,
          onSaveAs: _saveFileAs,
          onNewFile: _newFile,
          showFindBar: _showFindBar,
          findBarController: _findBarController,
          replaceBarController: _replaceBarController,
          findCaseSensitive: _findCaseSensitive,
          findUseRegex: _findUseRegex,
          findMatchCount: _findMatchCount,
          findCurrentIndex: _findCurrentIndex,
          onFindChanged: _performFind,
          onFindNext: _findNext,
          onFindPrevious: _findPrevious,
          onToggleCaseSensitive: () {
            setState(() => _findCaseSensitive = !_findCaseSensitive);
            _performFind();
          },
          onToggleRegex: () {
            setState(() => _findUseRegex = !_findUseRegex);
            _performFind();
          },
          onCloseFindBar: _toggleFindBar,
          onToggleFindBar: _toggleFindBar,
          onReplaceCurrent: _replaceCurrent,
          onReplaceAll: _replaceAll,
          editorFontSize: widget.settingsService.editorFontSize,
          editorFontFamily: widget.settingsService.editorFontFamily,
        );
      case 1:
        return FilesPage(
          onFileTap: _openFileFromPath,
          recentFiles: _recentFiles,
          onRecentFileTap: _openFileFromPath,
          rootNode: _fileTreeRoot,
          expandedPaths: _expandedPaths,
          isLoading: _isFileTreeLoading,
          onOpenFolder: _openFolder,
          onToggleExpand: _toggleExpand,
          onCloseFolder: _closeFolder,
        );
      case 2:
        return SearchPage(
          workspacePath: _fileTreeRoot?.path,
          onResultTap: _onSearchResultTap,
          recentFiles: _recentFiles,
        );
      case 3:
        return SettingsPage(settingsService: widget.settingsService);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// A collapsed Navigation Rail following MD3 Expressive guidelines.
class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onNewFile,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onNewFile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 80,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: AppTheme.space12),
          // MD3 Floating Action Button (FAB)
          Tooltip(
            message: 'New File',
            child: FloatingActionButton(
              onPressed: onNewFile,
              elevation: 1,
              hoverElevation: 2,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerLarge),
              ),
              child: const Icon(Icons.add, size: 24),
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          _NavDestination(
            icon: Icons.edit_outlined,
            selectedIcon: Icons.edit,
            label: 'Editor',
            isSelected: selectedIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),
          _NavDestination(
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
            label: 'Files',
            isSelected: selectedIndex == 1,
            onTap: () => onDestinationSelected(1),
          ),
          _NavDestination(
            icon: Icons.search_outlined,
            selectedIcon: Icons.search,
            label: 'Search',
            isSelected: selectedIndex == 2,
            onTap: () => onDestinationSelected(2),
          ),
          _NavDestination(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: 'Settings',
            isSelected: selectedIndex == 3,
            onTap: () => onDestinationSelected(3),
          ),
        ],
      ),
    );
  }
}

/// A single navigation destination with pill-shaped indicator.
class _NavDestination extends StatefulWidget {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavDestination> createState() => _NavDestinationState();
}

class _NavDestinationState extends State<_NavDestination> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final indicatorColor = widget.isSelected
        ? colorScheme.secondaryContainer
        : _isHovering
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;

    final iconColor = widget.isSelected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(AppTheme.cornerFull),
                  ),
                  child: AnimatedScale(
                    scale: widget.isSelected
                        ? 1.05
                        : (_isHovering ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      widget.isSelected ? widget.selectedIcon : widget.icon,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The primary code editing view with syntax highlighting.
///
/// Renders a [CodeField] with MD3-themed syntax highlighting, a toolbar
/// for file operations, an optional find/replace bar, and a status bar.
class _EditorView extends StatelessWidget {
  const _EditorView({
    required this.editorState,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onNewFile,
    this.showFindBar = false,
    this.findBarController,
    this.replaceBarController,
    this.findCaseSensitive = false,
    this.findUseRegex = false,
    this.findMatchCount = 0,
    this.findCurrentIndex = 0,
    this.onFindChanged,
    this.onFindNext,
    this.onFindPrevious,
    this.onToggleCaseSensitive,
    this.onToggleRegex,
    this.onCloseFindBar,
    this.onToggleFindBar,
    this.onReplaceCurrent,
    this.onReplaceAll,
    this.editorFontSize = 14.0,
    this.editorFontFamily = EditorFontFamily.robotoMono,
  });

  final EditorState editorState;
  final VoidCallback onOpen;
  final Future<bool> Function() onSave;
  final Future<bool> Function() onSaveAs;
  final VoidCallback onNewFile;
  final bool showFindBar;
  final TextEditingController? findBarController;
  final TextEditingController? replaceBarController;
  final bool findCaseSensitive;
  final bool findUseRegex;
  final int findMatchCount;
  final int findCurrentIndex;
  final VoidCallback? onFindChanged;
  final VoidCallback? onFindNext;
  final VoidCallback? onFindPrevious;
  final VoidCallback? onToggleCaseSensitive;
  final VoidCallback? onToggleRegex;
  final VoidCallback? onCloseFindBar;
  final VoidCallback? onToggleFindBar;
  final VoidCallback? onReplaceCurrent;
  final VoidCallback? onReplaceAll;
  final double editorFontSize;
  final EditorFontFamily editorFontFamily;

  static String _fontFamilyName(EditorFontFamily family) => switch (family) {
    EditorFontFamily.robotoMono => 'RobotoMono',
    EditorFontFamily.sourceCodePro => 'SourceCodePro',
    EditorFontFamily.firaCode => 'FiraCode',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlightStyles = HighlightTheme.fromColorScheme(colorScheme);

    final lineNumTextStyle = TextStyle(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      fontSize: editorFontSize,
      fontFamily: _fontFamilyName(editorFontFamily),
      height: 1.5,
    );

    // Calculate dynamic gutter width based on maximum line number
    final totalLines = editorState.controller.code.lines.length;
    final safeTotalLines = totalLines > 0 ? totalLines : 1;
    final textPainter = TextPainter(
      text: TextSpan(text: '$safeTotalLines', style: lineNumTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final calculatedGutterWidth = textPainter.width + 52.0 < 80.0
        ? 80.0
        : textPainter.width + 52.0;

    return CodeTheme(
      data: CodeThemeData(styles: highlightStyles),
      child: Column(
        children: [
          // Top app bar.
          _TopAppBar(
            fileName: editorState.fileName,
            isModified: editorState.isModified,
            onOpen: onOpen,
            onSave: onSave,
            onNewFile: onNewFile,
          ),
          // Divider line (1px, outlineVariant).
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          // Find/Replace bar.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showFindBar
                ? _FindBar(
                    findBarController: findBarController!,
                    replaceBarController: replaceBarController!,
                    caseSensitive: findCaseSensitive,
                    useRegex: findUseRegex,
                    matchCount: findMatchCount,
                    currentIndex: findCurrentIndex,
                    onChanged: onFindChanged,
                    onNext: onFindNext,
                    onPrevious: onFindPrevious,
                    onToggleCaseSensitive: onToggleCaseSensitive,
                    onToggleRegex: onToggleRegex,
                    onClose: onCloseFindBar,
                    onReplaceCurrent: onReplaceCurrent,
                    onReplaceAll: onReplaceAll,
                  )
                : const SizedBox.shrink(),
          ),
          // Code editor area.
          Expanded(
            child: Container(
              color: colorScheme.surfaceContainerLowest,
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                      onOpen,
                  const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                      onSave,
                  const SingleActivator(
                    LogicalKeyboardKey.keyS,
                    control: true,
                    shift: true,
                  ): onSaveAs,
                  const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                      onNewFile,
                  const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                      onToggleFindBar ?? () {},
                  const SingleActivator(LogicalKeyboardKey.keyH, control: true):
                      onToggleFindBar ?? () {},
                  const SingleActivator(LogicalKeyboardKey.keyG, control: true):
                      onFindNext ?? () {},
                  const SingleActivator(
                    LogicalKeyboardKey.keyG,
                    control: true,
                    shift: true,
                  ): onFindPrevious ?? () {},
                },
                child: Stack(
                  children: [
                    CodeField(
                      controller: editorState.controller,
                      expands: true,
                      textStyle: editorState
                          .editorTextStyleFor(
                            fontSize: editorFontSize,
                            fontFamily: editorFontFamily,
                          )
                          .copyWith(color: colorScheme.onSurface),
                      gutterStyle: GutterStyle(
                        showErrors: false,
                        width: calculatedGutterWidth,
                        textStyle: lineNumTextStyle,
                      ),
                      background: colorScheme.surfaceContainerLowest,
                      cursorColor: colorScheme.primary,
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: colorScheme.primary,
                        selectionColor: colorScheme.primary.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    // Placeholder text when editor is empty.
                    if (editorState.controller.text.isEmpty)
                      Positioned(
                        left: calculatedGutterWidth,
                        top: 16,
                        right: 0,
                        child: IgnorePointer(
                          child: Text(
                            'Start typing...',
                            style: editorState
                                .editorTextStyleFor(
                                  fontSize: editorFontSize,
                                  fontFamily: editorFontFamily,
                                )
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.35),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Status bar.
          _StatusBar(
            cursorLine: editorState.cursorLine,
            cursorColumn: editorState.cursorColumn,
            encoding: editorState.encoding,
            lineEnding: editorState.lineEnding,
          ),
        ],
      ),
    );
  }
}

/// The top application bar with file name and action buttons.
class _TopAppBar extends StatefulWidget {
  const _TopAppBar({
    required this.fileName,
    required this.isModified,
    required this.onOpen,
    required this.onSave,
    required this.onNewFile,
  });

  final String fileName;
  final bool isModified;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onNewFile;

  @override
  State<_TopAppBar> createState() => _TopAppBarState();
}

class _TopAppBarState extends State<_TopAppBar> {
  bool _isStarred = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      color: Colors.transparent, // Blends into Card background
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            widget.fileName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star : Icons.star_border,
              color: _isStarred ? Colors.amber : colorScheme.onSurfaceVariant,
              size: 18,
            ),
            tooltip: _isStarred ? 'Unstar file' : 'Star file',
            onPressed: () {
              setState(() {
                _isStarred = !_isStarred;
              });
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(AppTheme.space8),
          ),
          const SizedBox(width: AppTheme.space4),
          // Sync/Saved status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space8,
              vertical: AppTheme.space4,
            ),
            decoration: BoxDecoration(
              color: widget.isModified
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isModified
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  size: 14,
                  color: widget.isModified
                      ? colorScheme.onSurfaceVariant
                      : Colors.green,
                ),
                const SizedBox(width: AppTheme.space4),
                Text(
                  widget.isModified ? 'Unsaved' : 'Saved to disk',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.isModified
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            iconSize: 20,
            tooltip: 'New File (Ctrl+N)',
            color: colorScheme.onSurfaceVariant,
            onPressed: widget.onNewFile,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            iconSize: 20,
            tooltip: 'Open File (Ctrl+O)',
            color: colorScheme.onSurfaceVariant,
            onPressed: widget.onOpen,
          ),
          const SizedBox(width: AppTheme.space8),
          FilledButton.tonalIcon(
            onPressed: widget.onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cornerFull),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The status bar showing cursor position, encoding, and line ending.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.cursorLine,
    required this.cursorColumn,
    required this.encoding,
    required this.lineEnding,
  });

  final int cursorLine;
  final int cursorColumn;
  final String encoding;
  final String lineEnding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.terminal_outlined,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            encoding,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          Text(
            lineEnding,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            'Ln $cursorLine, Col $cursorColumn',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}

/// An inline find/replace bar that appears below the top app bar.
///
/// Provides search input with match count, navigation (prev/next),
/// case-sensitive and regex toggles, and replace functionality.
/// Follows MD3 styling with surfaceContainerHigh background.
class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.findBarController,
    required this.replaceBarController,
    this.caseSensitive = false,
    this.useRegex = false,
    this.matchCount = 0,
    this.currentIndex = 0,
    this.onChanged,
    this.onNext,
    this.onPrevious,
    this.onToggleCaseSensitive,
    this.onToggleRegex,
    this.onClose,
    this.onReplaceCurrent,
    this.onReplaceAll,
  });

  final TextEditingController findBarController;
  final TextEditingController replaceBarController;
  final bool caseSensitive;
  final bool useRegex;
  final int matchCount;
  final int currentIndex;
  final VoidCallback? onChanged;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleCaseSensitive;
  final VoidCallback? onToggleRegex;
  final VoidCallback? onClose;
  final VoidCallback? onReplaceCurrent;
  final VoidCallback? onReplaceAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Find row.
          Row(
            children: [
              // Find input.
              SizedBox(
                width: 240,
                height: 32,
                child: TextField(
                  controller: findBarController,
                  onChanged: (_) => onChanged?.call(),
                  onSubmitted: (_) => onNext?.call(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Find',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ),
              ),
              // Match count.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                ),
                child: Text(
                  matchCount > 0
                      ? '${currentIndex + 1}/$matchCount'
                      : 'No results',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Previous/Next.
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                tooltip: 'Previous (Ctrl+Shift+G)',
                onPressed: onPrevious,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: colorScheme.onSurfaceVariant,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                tooltip: 'Next (Ctrl+G)',
                onPressed: onNext,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: colorScheme.onSurfaceVariant,
              ),
              // Toggle chips.
              _FindToggleChip(
                label: 'Aa',
                tooltip: 'Case Sensitive',
                selected: caseSensitive,
                onTap: onToggleCaseSensitive,
              ),
              _FindToggleChip(
                label: '.*',
                tooltip: 'Regular Expression',
                selected: useRegex,
                onTap: onToggleRegex,
              ),
              const Spacer(),
              // Close.
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close (Esc)',
                onPressed: onClose,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          // Replace row.
          Row(
            children: [
              SizedBox(
                width: 240,
                height: 32,
                child: TextField(
                  controller: replaceBarController,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Replace',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space8),
              IconButton(
                icon: const Icon(Icons.find_replace_outlined, size: 18),
                tooltip: 'Replace Current',
                onPressed: onReplaceCurrent,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: colorScheme.onSurfaceVariant,
              ),
              IconButton(
                icon: const Icon(Icons.find_replace, size: 18),
                tooltip: 'Replace All',
                onPressed: onReplaceAll,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small toggle chip for find bar options.
class _FindToggleChip extends StatelessWidget {
  const _FindToggleChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space8,
            vertical: AppTheme.space4,
          ),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
      ),
    );
  }
}
