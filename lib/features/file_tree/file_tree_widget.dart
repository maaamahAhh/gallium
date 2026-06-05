// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';

import 'package:gallium_editor/features/file_tree/file_node.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';

/// A recursive tree view for displaying files and directories.
///
/// Each directory node can be expanded/collapsed. Files show an icon
/// based on their type. The tree follows MD3 styling with proper
/// spacing, colors, and hover states.
class FileTreeWidget extends StatelessWidget {
  /// Creates the file tree widget.
  const FileTreeWidget({
    required this.root,
    required this.onFileTap,
    required this.expandedPaths,
    required this.onToggleExpand,
    super.key,
  });

  /// The root node of the file tree.
  final FileNode root;

  /// Callback when a file is tapped.
  final ValueChanged<String> onFileTap;

  /// Set of currently expanded directory paths.
  final Set<String> expandedPaths;

  /// Callback when a directory is expanded/collapsed.
  final ValueChanged<String> onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: root.sortedChildren.length,
      itemBuilder: (context, index) {
        return _FileTreeNode(
          node: root.sortedChildren[index],
          depth: 0,
          onFileTap: onFileTap,
          expandedPaths: expandedPaths,
          onToggleExpand: onToggleExpand,
        );
      },
    );
  }
}

/// A single node in the file tree (file or directory).
class _FileTreeNode extends StatefulWidget {
  const _FileTreeNode({
    required this.node,
    required this.depth,
    required this.onFileTap,
    required this.expandedPaths,
    required this.onToggleExpand,
  });

  final FileNode node;
  final int depth;
  final ValueChanged<String> onFileTap;
  final Set<String> expandedPaths;
  final ValueChanged<String> onToggleExpand;

  @override
  State<_FileTreeNode> createState() => _FileTreeNodeState();
}

class _FileTreeNodeState extends State<_FileTreeNode> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpanded = widget.expandedPaths.contains(widget.node.path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The node row.
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () {
              if (widget.node.isDirectory) {
                widget.onToggleExpand(widget.node.path);
              } else {
                widget.onFileTap(widget.node.path);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 32,
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.space8,
                vertical: 1,
              ),
              padding: EdgeInsets.only(
                left: AppTheme.space8 + (widget.depth * 16.0),
                right: AppTheme.space8,
              ),
              decoration: BoxDecoration(
                color: _isHovering
                    ? colorScheme.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
              ),
              child: Row(
                children: [
                  // Expand/collapse arrow for directories.
                  if (widget.node.isDirectory)
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.25 : 0,
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: AppTheme.space4),
                  // File/directory icon.
                  Icon(
                    widget.node.isDirectory
                        ? (isExpanded ? Icons.folder_open : Icons.folder)
                        : widget.node.icon,
                    size: 18,
                    color: widget.node.isDirectory
                        ? colorScheme.primary
                        : widget.node.isSupported
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  // File/directory name.
                  Expanded(
                    child: Text(
                      widget.node.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: _isHovering
                            ? FontWeight.w500
                            : FontWeight.normal,
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
        // Animated Collapsible Children.
        _CollapsibleSection(
          isExpanded: isExpanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: widget.node.sortedChildren
                .map(
                  (child) => _FileTreeNode(
                    node: child,
                    depth: widget.depth + 1,
                    onFileTap: widget.onFileTap,
                    expandedPaths: widget.expandedPaths,
                    onToggleExpand: widget.onToggleExpand,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// A helper widget to animate size expansions in Material Design 3 style.
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({required this.isExpanded, required this.child});

  final bool isExpanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: isExpanded ? child : const SizedBox.shrink(),
    );
  }
}
