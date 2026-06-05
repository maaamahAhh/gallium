// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';

/// Represents a node in the file tree.
///
/// Each node is either a file or a directory. Directories may contain
/// child nodes. The [icon] is determined by the file extension.
class FileNode {
  /// Creates a file tree node.
  const FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
  });

  /// The display name of the file or directory.
  final String name;

  /// The absolute path of the file or directory.
  final String path;

  /// Whether this node represents a directory.
  final bool isDirectory;

  /// The child nodes of this directory (empty for files).
  final List<FileNode> children;

  /// Whether this directory is expanded in the tree view.
  final bool isExpanded;

  /// Returns a copy of this node with the given fields replaced.
  FileNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<FileNode>? children,
    bool? isExpanded,
  }) {
    return FileNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  /// Returns the appropriate MD3 icon for this file type.
  IconData get icon {
    if (isDirectory) return Icons.folder;

    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    return switch (ext) {
      'dart' => Icons.code,
      'java' => Icons.coffee,
      'js' || 'mjs' || 'cjs' => Icons.javascript,
      'ts' => Icons.code,
      'py' => Icons.psychology,
      'json' => Icons.data_object,
      'yaml' || 'yml' => Icons.settings,
      'xml' || 'html' || 'htm' || 'svg' => Icons.web,
      'css' || 'scss' => Icons.palette,
      'cpp' || 'c' || 'h' || 'hpp' => Icons.memory,
      'go' => Icons.speed,
      'rs' => Icons.build,
      'sh' || 'bash' => Icons.terminal,
      'sql' => Icons.storage,
      'md' || 'markdown' => Icons.article,
      'txt' => Icons.description,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => Icons.image,
      _ => Icons.insert_drive_file,
    };
  }

  /// Supported file extensions for editing.
  static const Set<String> supportedExtensions = {
    'txt',
    'md',
    'markdown',
    'dart',
    'java',
    'js',
    'mjs',
    'cjs',
    'ts',
    'py',
    'json',
    'yaml',
    'yml',
    'xml',
    'html',
    'htm',
    'svg',
    'css',
    'scss',
    'cpp',
    'c',
    'h',
    'hpp',
    'go',
    'rs',
    'sh',
    'bash',
    'sql',
  };

  /// Whether this file's extension is supported for editing.
  bool get isSupported {
    if (isDirectory) return true;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return supportedExtensions.contains(ext);
  }

  /// Sorts children: directories first, then files, both alphabetically.
  List<FileNode> get sortedChildren {
    final dirs = children.where((c) => c.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final files = children.where((c) => !c.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [...dirs, ...files];
  }
}
