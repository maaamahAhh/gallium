// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';

import 'package:gallium_editor/features/file_tree/file_node.dart';
import 'package:gallium_editor/features/file_tree/file_tree_widget.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:path/path.dart' as p;

/// The Files page for the Gallium application.
///
/// Displays a file tree browser for navigating the workspace directory.
/// Users can open a folder, browse its contents, and click files to
/// open them in the editor.
///
/// State (rootNode, expandedPaths) is owned by the parent and passed in
/// so that it persists across tab switches.
class FilesPage extends StatelessWidget {
  /// Creates the Files page.
  const FilesPage({
    required this.onFileTap,
    this.recentFiles = const [],
    this.onRecentFileTap,
    this.rootNode,
    this.expandedPaths = const {},
    this.isLoading = false,
    this.onOpenFolder,
    this.onToggleExpand,
    this.onCloseFolder,
    super.key,
  });

  /// Callback when a file in the tree is tapped.
  final ValueChanged<String> onFileTap;

  /// List of recently opened file paths.
  final List<String> recentFiles;

  /// Callback when a recent file is tapped.
  final ValueChanged<String>? onRecentFileTap;

  /// The root node of the file tree (owned by parent).
  final FileNode? rootNode;

  /// Set of currently expanded directory paths (owned by parent).
  final Set<String> expandedPaths;

  /// Whether the file tree is currently loading.
  final bool isLoading;

  /// Callback to open a folder.
  final VoidCallback? onOpenFolder;

  /// Callback to toggle expand/collapse of a directory.
  final ValueChanged<String>? onToggleExpand;

  /// Callback to close the current folder.
  final VoidCallback? onCloseFolder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with open folder button.
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          color: Colors.transparent, // Inherits Workspace container background
          child: Row(
            children: [
              Text(
                'Explorer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                iconSize: 20,
                tooltip: 'Open Folder',
                color: colorScheme.onSurfaceVariant,
                onPressed: onOpenFolder,
              ),
              if (rootNode != null)
                IconButton(
                  icon: const Icon(Icons.close_outlined),
                  iconSize: 20,
                  tooltip: 'Close Folder',
                  color: colorScheme.onSurfaceVariant,
                  onPressed: onCloseFolder,
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
        // File tree or empty state.
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : rootNode != null
              ? FileTreeWidget(
                  root: rootNode!,
                  onFileTap: onFileTap,
                  expandedPaths: expandedPaths,
                  onToggleExpand: onToggleExpand ?? (_) {},
                )
              : _buildEmptyState(context),
        ),
        // Recent files section.
        if (recentFiles.isNotEmpty) ...[_buildRecentFiles(context)],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(child: _EmptyStateCard(onOpenFolder: onOpenFolder));
  }

  Widget _buildRecentFiles(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space16,
              AppTheme.space12,
              AppTheme.space16,
              AppTheme.space8,
            ),
            child: Text(
              'Recent Files',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppTheme.space8),
              itemCount: recentFiles.length,
              itemBuilder: (context, index) {
                final path = recentFiles[index];
                final name = p.basename(path);

                return _RecentFileTile(
                  name: name,
                  path: path,
                  onTap: () => onRecentFileTap?.call(path),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// An animated empty state card for the Files page.
class _EmptyStateCard extends StatefulWidget {
  const _EmptyStateCard({this.onOpenFolder});

  final VoidCallback? onOpenFolder;

  @override
  State<_EmptyStateCard> createState() => _EmptyStateCardState();
}

class _EmptyStateCardState extends State<_EmptyStateCard> {
  bool _isHovering = false;

  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpenFolder,
        child: AnimatedScale(
          scale: _isHovering ? 1.02 : 1.0,
          duration: _animDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOutCubic,
            width: 250,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space24,
              vertical: AppTheme.space32,
            ),
            decoration: BoxDecoration(
              color: _isHovering
                  ? colorScheme.primaryContainer.withValues(alpha: 0.12)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.cornerLarge),
              border: Border.all(
                color: _isHovering
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: _animDuration,
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    bottom: _isHovering ? AppTheme.space12 : AppTheme.space4,
                  ),
                  child: Icon(
                    Icons.folder_open_outlined,
                    size: 48,
                    color: _isHovering
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                AnimatedCrossFade(
                  duration: _animDuration,
                  firstCurve: Curves.easeOutCubic,
                  secondCurve: Curves.easeOutCubic,
                  sizeCurve: Curves.easeOutCubic,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space4),
                    child: Text(
                      'No folder open',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  secondChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Open Workspace',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        'Click to select a directory',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: _isHovering
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile for a recently opened file.
class _RecentFileTile extends StatefulWidget {
  const _RecentFileTile({
    required this.name,
    required this.path,
    required this.onTap,
  });

  final String name;
  final String path;
  final VoidCallback onTap;

  @override
  State<_RecentFileTile> createState() => _RecentFileTileState();
}

class _RecentFileTileState extends State<_RecentFileTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space4,
          ),
          decoration: BoxDecoration(
            color: _isHovering
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.cornerMedium), // 12dp
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: _isHovering
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    widget.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isHovering
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
