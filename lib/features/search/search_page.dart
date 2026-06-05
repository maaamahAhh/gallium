// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gallium_editor/features/search/search_service.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:path/path.dart' as p;

/// The Search page for the Gallium application.
///
/// Provides global search across files in the currently opened folder.
/// Results are grouped by file with matching text highlighted.
class SearchPage extends StatefulWidget {
  /// Creates the Search page.
  const SearchPage({
    required this.onResultTap,
    this.workspacePath,
    this.recentFiles = const [],
    super.key,
  });

  /// The currently opened folder path, or `null` if none.
  final String? workspacePath;

  /// Callback when a search result is tapped (to open that file and jump to line).
  final ValueChanged<SearchResult> onResultTap;

  /// Recent file paths (for searching when no workspace is open).
  final List<String> recentFiles;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _isSearching = false;
  List<SearchResult> _results = const [];

  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }

    final workspace = widget.workspacePath;
    if (workspace == null) return;

    setState(() => _isSearching = true);

    try {
      final results = await SearchService.search(
        workspace,
        query,
        caseSensitive: _caseSensitive,
        useRegex: _useRegex,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _results = const [];
          _isSearching = false;
        });
      }
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  void _onSubmitted(String _) {
    _debounce?.cancel();
    _runSearch();
  }

  void _toggleCaseSensitive() {
    setState(() => _caseSensitive = !_caseSensitive);
    _onQueryChanged();
  }

  void _toggleRegex() {
    setState(() => _useRegex = !_useRegex);
    _onQueryChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLowest, // Inside Workspace Card sheet
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          Expanded(
            child: widget.workspacePath == null
                ? _buildEmptyState(context)
                : _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _controller.text.trim().isEmpty
                ? _buildInitialState(context)
                : _results.isEmpty
                ? _buildNoResultsState(context)
                : _buildResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
      color: Colors.transparent,
      child: Row(
        children: [
          Text(
            'Search Workspace',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.cornerFull),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppTheme.space12),
          Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (_) => _onQueryChanged(),
              onSubmitted: _onSubmitted,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search files and text...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          _ToggleChip(
            label: 'Aa',
            tooltip: 'Case Sensitive',
            selected: _caseSensitive,
            onTap: _toggleCaseSensitive,
          ),
          _ToggleChip(
            label: '.*',
            tooltip: 'Regular Expression',
            selected: _useRegex,
            onTap: _toggleRegex,
          ),
          const SizedBox(width: AppTheme.space8),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            'Open a folder to search across files',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Column(children: [_buildSearchField(context)]);
  }

  Widget _buildNoResultsState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildSearchField(context),
        const Spacer(),
        Icon(
          Icons.search_off_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: AppTheme.space16),
        Text(
          'No results found',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group results by file path.
    final grouped = <String, List<SearchResult>>{};
    for (final result in _results) {
      grouped.putIfAbsent(result.filePath, () => []).add(result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(context),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space24,
            vertical: AppTheme.space4,
          ),
          child: Text(
            'Found ${_results.length} matches in ${grouped.length} files',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppTheme.space16),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final filePath = grouped.keys.elementAt(index);
              final fileResults = grouped[filePath]!;
              return _FileResultGroup(
                filePath: filePath,
                results: fileResults,
                onResultTap: widget.onResultTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A toggle chip for search options (case-sensitive, regex).
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space8,
            vertical: AppTheme.space4,
          ),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppTheme.cornerFull,
            ), // Fully rounded pill shape
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontFamily: 'RobotoMono',
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A group of search results for a single file.
class _FileResultGroup extends StatelessWidget {
  const _FileResultGroup({
    required this.filePath,
    required this.results,
    required this.onResultTap,
  });

  final String filePath;
  final List<SearchResult> results;
  final ValueChanged<SearchResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = p.basename(filePath);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(
          AppTheme.cornerMedium,
        ), // 12dp rounded card
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File header.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space16,
              vertical: 10.0,
            ),
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Text(
                    filePath,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          // Result lines.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
            child: Column(
              children: results
                  .map(
                    (result) => _ResultLine(
                      result: result,
                      onTap: () => onResultTap(result),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single result line within a file group.
class _ResultLine extends StatefulWidget {
  const _ResultLine({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  State<_ResultLine> createState() => _ResultLineState();
}

class _ResultLineState extends State<_ResultLine> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = widget.result;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.space8,
            vertical: 2.0,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: 6.0,
          ),
          decoration: BoxDecoration(
            color: _isHovering
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              AppTheme.cornerSmall,
            ), // 8dp hover highlight
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${result.lineNumber}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'RobotoMono',
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(child: _buildHighlightedText(context, result)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(BuildContext context, SearchResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = result.lineContent;
    final matchStart = result.matchStart;
    final matchEnd = result.matchEnd;

    // Clamp indices to valid range.
    final start = matchStart.clamp(0, content.length);
    final end = matchEnd.clamp(start, content.length);

    final before = content.substring(0, start);
    final match = content.substring(start, end);
    final after = content.substring(end);

    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
      fontFamily: 'RobotoMono',
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: baseStyle?.copyWith(
              backgroundColor: colorScheme.primaryContainer,
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
