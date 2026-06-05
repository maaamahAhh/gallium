// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';

/// MD3-aligned syntax highlighting themes for the code editor.
///
/// Maps highlight.js token class names to TextStyle objects using
/// Material Design 3 ColorScheme tokens. This ensures syntax highlighting
/// colors automatically adapt to the app's light/dark theme.
abstract final class HighlightTheme {
  /// Creates a syntax highlight theme from the current [ColorScheme].
  ///
  /// Uses MD3 color tokens to provide consistent, accessible highlighting
  /// that adapts to light and dark modes.
  static Map<String, TextStyle> fromColorScheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    // Google-style developer syntax colors
    final keywordColor = colorScheme.primary;
    final stringColor = isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32); // Soft green
    final numberColor = isDark
        ? const Color(0xFFFFB74D)
        : const Color(0xFFE65100); // Warm amber
    final typeColor = isDark
        ? const Color(0xFFC5CAE9)
        : const Color(0xFF303F9F); // Soft indigo
    final builtInColor = isDark
        ? const Color(0xFFF06292)
        : const Color(0xFFC2185B); // Pink/Magenta
    final commentColor = colorScheme.outline;

    return {
      // Keywords (if, else, return, class, etc.)
      'keyword': TextStyle(color: keywordColor, fontWeight: FontWeight.w600),
      // Built-in types and constants (int, String, true, false, null)
      'built_in': TextStyle(color: builtInColor),
      // Type annotations and class names
      'type': TextStyle(color: typeColor),
      // Literal values (numbers, booleans)
      'literal': TextStyle(color: numberColor),
      // Numbers
      'number': TextStyle(color: numberColor),
      // Operators (+, -, ==, etc.)
      'operator': TextStyle(color: colorScheme.primary),
      // Punctuation ({, }, (, ), ;, etc.)
      'punctuation': TextStyle(color: colorScheme.onSurface),
      // Strings (single and double quoted)
      'string': TextStyle(color: stringColor),
      // Substrings within interpolated strings
      'subst': TextStyle(color: colorScheme.onSurface),
      // Symbols (Ruby, etc.)
      'symbol': TextStyle(color: numberColor),
      // Variables
      'variable': TextStyle(color: colorScheme.onSurface),
      // Variable language (this, super, self)
      'variable-language': TextStyle(
        color: keywordColor,
        fontWeight: FontWeight.w600,
      ),
      // Variable constants (UPPER_CASE)
      'variable-constant': TextStyle(color: typeColor),
      // Comments (// and /* */)
      'comment': TextStyle(color: commentColor, fontStyle: FontStyle.italic),
      // Documentation comments (/// and /** */)
      'doctag': TextStyle(color: keywordColor, fontWeight: FontWeight.w600),
      // Doc comment text
      'doc': TextStyle(color: commentColor, fontStyle: FontStyle.italic),
      // Function names
      'function': TextStyle(color: colorScheme.primary),
      // Function title (function name in definition)
      'title': TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      // Class title
      'title.class': TextStyle(color: typeColor, fontWeight: FontWeight.w600),
      // Inherited class
      'title.class.inherited': TextStyle(color: typeColor),
      // Function parameters
      'params': TextStyle(color: colorScheme.onSurface),
      // Tags in HTML/XML
      'tag': TextStyle(color: keywordColor),
      // Attribute names in HTML/XML
      'attr': TextStyle(color: typeColor),
      // Attribute values
      'attribute': TextStyle(color: stringColor),
      // Selector in CSS
      'selector-tag': TextStyle(color: keywordColor),
      // Selector ID in CSS
      'selector-id': TextStyle(color: typeColor),
      // Selector class in CSS
      'selector-class': TextStyle(color: typeColor),
      // Selector attribute in CSS
      'selector-attr': TextStyle(color: stringColor),
      // Pseudo selector
      'selector-pseudo': TextStyle(color: keywordColor),
      // Meta (decorators, annotations)
      'meta': TextStyle(color: commentColor),
      // Meta keyword (@override, @deprecated)
      'meta-keyword': TextStyle(color: keywordColor),
      // Meta string (URLs in imports)
      'meta-string': TextStyle(color: stringColor),
      // Regular expressions
      'regexp': TextStyle(color: stringColor),
      // Additions (diff)
      'addition': TextStyle(
        color: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      // Deletions (diff)
      'deletion': TextStyle(
        color: colorScheme.error,
        backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.3),
      ),
      // Emphasis (bold)
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      // Strong (bold)
      'strong': const TextStyle(fontWeight: FontWeight.w700),
      // Section headings
      'section': TextStyle(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      // Links
      'link': TextStyle(
        color: stringColor,
        decoration: TextDecoration.underline,
      ),
      // Bullet lists
      'bullet': TextStyle(color: colorScheme.primary),
      // Code blocks in Markdown
      'code': TextStyle(color: typeColor),
      // Properties (JSON keys, etc.)
      'property': TextStyle(color: typeColor),
      // Name (XML tag names, etc.)
      'name': TextStyle(color: colorScheme.onSurface),
      // Template tag (Vue, Angular)
      'template-tag': TextStyle(color: commentColor),
      // Template variable
      'template-variable': TextStyle(color: colorScheme.onSurface),
      // Escaped characters
      'escape': TextStyle(color: colorScheme.error),
    };
  }
}
