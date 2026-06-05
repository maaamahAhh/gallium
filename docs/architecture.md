# Architecture Overview

Gallium is a desktop document editor built with Flutter and Material Design 3.
The architecture follows a feature-driven approach to ensure separation of
concerns and maintainability.

## Structure

```
┌─────────────────────────────────────────┐
│                  App                     │
├─────────────────────────────────────────┤
│              Features                    │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │  Editor  │ │ FileTree │ │ Settings│ │
│  └──────────┘ └──────────┘ └─────────┘ │
├─────────────────────────────────────────┤
│                UI Layer                  │
│  ┌──────────────┐ ┌──────────────────┐  │
│  │    Theme     │ │    Widgets       │  │
│  └──────────────┘ └──────────────────┘  │
└─────────────────────────────────────────┘
```

## Key Subsystems

### Features Layer (`lib/features/`)

Self-contained feature modules. Each feature owns its UI, state, and logic.

- **`editor/`**: The main text editing experience with syntax highlighting,
  file operations, find and replace, and keyboard shortcuts.
- **`file_tree/`**: File system navigation and management with expandable
  directory trees.
- **`search/`**: Full-text search across workspace files with case-sensitive
  and regex modes.
- **`settings/`**: Application preferences including theme, font size, and
  font family selection.

### UI Layer (`lib/ui/`)

Shared UI primitives and theming.

- **`theme/`**: Material Design 3 theme definition, dynamic color, and
  typography tokens.
- **`widgets/`**: Reusable M3-compliant widgets.

## Design Principles

1. **Feature Autonomy**: Each feature module is self-contained with its own
   state management, UI, and tests.
2. **Material 3 Compliance**: All UI components adhere to the Material Design 3
   specification, including dynamic color, motion tokens, and typography.
