// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:io';

/// A single match within a file search.
///
/// Contains the file path, line number, the full line content,
/// and the start/end indices of the matching portion within the line.
class SearchResult {
  /// Creates a search result.
  const SearchResult({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.matchStart,
    required this.matchEnd,
  });

  /// The absolute path of the file containing the match.
  final String filePath;

  /// The 1-based line number where the match was found.
  final int lineNumber;

  /// The full content of the matching line.
  final String lineContent;

  /// The start index of the match within [lineContent].
  final int matchStart;

  /// The end index of the match within [lineContent] (exclusive).
  final int matchEnd;
}

/// Provides file search functionality for the Gallium editor.
///
/// Searches across all text files in a workspace directory for a given
/// query string, supporting case-sensitive and regex modes.
abstract final class SearchService {
  /// Searches [workspacePath] for [query].
  ///
  /// When [caseSensitive] is `true`, the search respects letter casing.
  /// When [useRegex] is `true`, [query] is treated as a regular expression.
  ///
  /// Returns a list of [SearchResult] sorted by file path and line number.
  /// Throws [ArgumentError] if [query] is empty.
  static Future<List<SearchResult>> search(
    String workspacePath,
    String query, {
    bool caseSensitive = false,
    bool useRegex = false,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError('Query must not be empty');
    }

    final results = <SearchResult>[];
    final dir = Directory(workspacePath);

    if (!await dir.exists()) {
      return results;
    }

    RegExp regex;
    try {
      if (useRegex) {
        regex = RegExp(query, caseSensitive: caseSensitive, unicode: true);
      } else {
        regex = RegExp(
          RegExp.escape(query),
          caseSensitive: caseSensitive,
          unicode: true,
        );
      }
    } on FormatException {
      return results;
    }

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;

        // Skip binary-like and hidden files.
        if (_shouldSkipFile(path)) continue;

        try {
          final lines = await entity.readAsLines();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            for (final match in regex.allMatches(line)) {
              results.add(
                SearchResult(
                  filePath: path,
                  lineNumber: i + 1,
                  lineContent: line,
                  matchStart: match.start,
                  matchEnd: match.end,
                ),
              );
            }
          }
        } on FileSystemException {
          // Skip files that cannot be read (binary, locked, etc.).
          continue;
        }
      }
    }

    // Sort by file path, then by line number.
    results.sort((a, b) {
      final pathCompare = a.filePath.compareTo(b.filePath);
      if (pathCompare != 0) return pathCompare;
      return a.lineNumber.compareTo(b.lineNumber);
    });

    return results;
  }

  /// Whether a file should be skipped during search.
  static bool _shouldSkipFile(String path) {
    const skipExtensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.ico',
      '.svg',
      '.woff',
      '.woff2',
      '.ttf',
      '.eot',
      '.zip',
      '.gz',
      '.tar',
      '.exe',
      '.dll',
      '.so',
      '.dylib',
      '.class',
      '.jar',
      '.wasm',
    };

    final segments = path.split(Platform.pathSeparator);
    // Skip hidden directories (e.g., .git, .dart_tool).
    if (segments.any((s) => s.startsWith('.') && s != '.')) return true;

    final ext = path.contains('.') ? '.${path.split('.').last}' : '';
    return skipExtensions.contains(ext.toLowerCase());
  }
}
