// This is free and unencumbered software released into the public domain.
// For more information, please refer to <https://unlicense.org>.

import 'package:flutter/material.dart';
import 'package:gallium_editor/features/settings/settings_service.dart';
import 'package:gallium_editor/ui/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// The settings page for the Gallium application.
///
/// Provides controls for theme mode, editor font size, and editor
/// font family. All changes are persisted automatically.
class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.settingsService, super.key});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),
                  _buildSection(
                    context,
                    title: 'Appearance',
                    icon: Icons.palette_outlined,
                    children: [_buildThemeModeSetting(context)],
                  ),
                  const SizedBox(height: AppTheme.space24),
                  _buildSection(
                    context,
                    title: 'Editor Settings',
                    icon: Icons.edit_note_outlined,
                    children: [
                      _buildFontSizeSetting(context),
                      const SizedBox(height: AppTheme.space16),
                      _buildFontFamilySetting(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: AppTheme.space8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.cornerMedium),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeSetting(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              ),
              Text(
                'Choose the application color theme',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SegmentedButton<ThemeModeOption>(
          segments: const [
            ButtonSegment(
              value: ThemeModeOption.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto, size: 18),
            ),
            ButtonSegment(
              value: ThemeModeOption.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode, size: 18),
            ),
            ButtonSegment(
              value: ThemeModeOption.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode, size: 18),
            ),
          ],
          selected: {settingsService.themeMode},
          onSelectionChanged: (selection) {
            settingsService.themeMode = selection.first;
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeSetting(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Font Size',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              ),
              Text(
                '${settingsService.editorFontSize.toInt()} px',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 200,
          child: Slider(
            value: settingsService.editorFontSize,
            min: 8,
            max: 32,
            divisions: 24,
            label: '${settingsService.editorFontSize.toInt()}',
            onChanged: (value) {
              settingsService.editorFontSize = value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFontFamilySetting(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Font Family',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              ),
              Text(
                'Monospace font for the code editor',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DropdownMenu<EditorFontFamily>(
          initialSelection: settingsService.editorFontFamily,
          onSelected: (value) {
            if (value != null) {
              settingsService.editorFontFamily = value;
            }
          },
          dropdownMenuEntries: EditorFontFamily.values
              .map(
                (font) => DropdownMenuEntry(
                  value: font,
                  label: font.displayName,
                  labelWidget: Text(
                    font.displayName,
                    style: _getFontStyle(font),
                  ),
                ),
              )
              .toList(),
          textStyle: _getFontStyle(settingsService.editorFontFamily),
        ),
      ],
    );
  }

  TextStyle _getFontStyle(EditorFontFamily font) {
    return switch (font) {
      EditorFontFamily.robotoMono => GoogleFonts.robotoMono(fontSize: 14),
      EditorFontFamily.sourceCodePro => GoogleFonts.sourceCodePro(fontSize: 14),
      EditorFontFamily.firaCode => GoogleFonts.firaCode(fontSize: 14),
    };
  }
}
