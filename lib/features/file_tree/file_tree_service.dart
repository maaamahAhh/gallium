// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:io';

import 'package:gallium_editor/features/file_tree/file_node.dart';

/// Service for reading and watching the file system.
///
/// Provides methods for loading directory trees.
abstract final class FileTreeService {
  /// Loads the directory tree starting from [rootPath].
  ///
  /// Returns a [FileNode] representing the root directory with its
  /// children populated recursively. Only the top-level directories
  /// have their children loaded; deeper levels are loaded on demand.
  static Future<FileNode> loadTree(String rootPath) async {
    final rootDir = Directory(rootPath);
    final rootName = rootPath.split(Platform.pathSeparator).last;

    final children = await _loadDirectoryContents(rootDir, maxDepth: 2);
    return FileNode(
      name: rootName,
      path: rootPath,
      isDirectory: true,
      children: children,
    );
  }

  /// Loads the children of a directory node on demand.
  ///
  /// Used when a directory is expanded in the tree view for the first time.
  static Future<List<FileNode>> loadChildren(FileNode node) async {
    if (!node.isDirectory) return [];

    final dir = Directory(node.path);
    return _loadDirectoryContents(dir, maxDepth: 1);
  }

  static Future<List<FileNode>> _loadDirectoryContents(
    Directory dir, {
    required int maxDepth,
    int currentDepth = 0,
  }) async {
    final children = <FileNode>[];

    try {
      final entities = dir.listSync()..sort(_compareFileSystemEntities);

      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last;

        // Skip hidden files/directories (starting with '.').
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          var subChildren = <FileNode>[];
          if (currentDepth < maxDepth - 1) {
            subChildren = await _loadDirectoryContents(
              entity,
              maxDepth: maxDepth,
              currentDepth: currentDepth + 1,
            );
          }

          children.add(
            FileNode(
              name: name,
              path: entity.path,
              isDirectory: true,
              children: subChildren,
            ),
          );
        } else if (entity is File) {
          children.add(
            FileNode(name: name, path: entity.path, isDirectory: false),
          );
        }
      }
    } on FileSystemException {
      // Permission denied or similar — skip this directory.
    }

    return children;
  }
}

/// Compares two file system entities for sorting.
///
/// Directories come before files. Within each group, names are sorted
/// alphabetically (case-insensitive).
int _compareFileSystemEntities(FileSystemEntity a, FileSystemEntity b) {
  final aIsDir = a is Directory;
  final bIsDir = b is Directory;
  if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
  final aName = a.path.split(Platform.pathSeparator).last.toLowerCase();
  final bName = b.path.split(Platform.pathSeparator).last.toLowerCase();
  return aName.compareTo(bName);
}
