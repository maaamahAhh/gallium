# ADR 0001: Initial Architecture

## Status

Accepted

## Context

We need to establish the foundational architecture for Gallium, a desktop
document editor built with Flutter and Material Design 3. The architecture must
support:

- Clean separation between business logic and UI
- Feature-driven development with autonomous modules
- Cross-platform support (Windows, macOS, Linux)
- Material Design 3 compliance with dynamic theming
- High-performance text editing

## Decision

We will adopt a layered, feature-driven architecture with four primary layers:

1. **Core Layer**: Pure Dart logic with no Flutter dependencies. Handles text
   buffer management.
2. **Features Layer**: Self-contained feature modules, each with its own UI,
   state, and logic.
3. **UI Layer**: Shared M3 theme definitions and reusable widgets.
4. **Platform Layer**: Platform-specific adaptations abstracted behind
   interfaces.

## Consequences

### Positive

- Core logic can be tested without Flutter widget overhead.
- Features can be developed and tested independently.
- Adding new platforms requires only a new platform adapter.
- M3 theming is centralized and consistent.

### Negative

- More files and directories compared to a flat structure.
- Requires discipline to maintain layer boundaries.
