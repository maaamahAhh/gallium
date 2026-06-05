// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

/// A custom title bar for the Gallium application window.
///
/// Replaces the native Windows title bar with an MD3-styled version that
/// supports dragging, minimizing, maximizing, and closing the window.
/// The title bar uses [ColorScheme.surfaceContainerLow] background color.
class AppTitleBar extends StatelessWidget {
  /// Creates the custom title bar.
  const AppTitleBar({this.onSearchTap, super.key});

  /// Callback when the universal search bar is clicked.
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(
          left: AppTheme.space24, // Indent logo from left edge
          right: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.windowCornerRadius),
            topRight: Radius.circular(AppTheme.windowCornerRadius),
          ),
        ),
        child: Row(
          children: [
            // Left app logo & title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/gallium_logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Gallium',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w500, // Medium weight matching Google Sans
                    color: colorScheme.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),

            // Middle Universal Search Bar (Gmail-style)
            Expanded(
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onSearchTap,
                    child: Container(
                      width: 420,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppTheme.cornerFull,
                        ),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: AppTheme.space12),
                          Icon(
                            Icons.search,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Expanded(
                            child: Text(
                              'Search files and contents...',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right window buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindowButton(
                  icon: Icons.remove,
                  tooltip: 'Minimize',
                  onPressed: windowManager.minimize,
                ),
                _WindowButton(
                  icon: Icons.crop_square,
                  iconSize: 14,
                  tooltip: 'Maximize',
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                _WindowButton(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onPressed: windowManager.close,
                  isClose: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single window control button (minimize, maximize, close).
///
/// Styled to match MD3 aesthetics with hover states and appropriate
/// color treatment for the close button.
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 18,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color iconColor;
    if (widget.isClose && _isHovering) {
      backgroundColor = colorScheme.error;
      iconColor = colorScheme.onError;
    } else if (_isHovering) {
      backgroundColor = colorScheme.onSurface.withValues(alpha: 0.08);
      iconColor = colorScheme.onSurface;
    } else {
      backgroundColor = Colors.transparent;
      iconColor = colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            width: 36,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.cornerSmall),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
