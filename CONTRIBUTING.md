# How to Contribute

We welcome contributions to this project.

## Code Reviews

All submissions, including those from project members, require review. We
use [GitHub pull requests][gh-pr] for this purpose.

[gh-pr]: https://docs.github.com/articles/about-pull-requests/

## Code Style

This project follows the [Effective Dart][effective-dart] style guide. All
code must be formatted with `dart format` and pass `dart analyze` with no
warnings or errors before submission.

[effective-dart]: https://dart.dev/effective-dart

## Code of Conduct

Please read and follow our [Code of Conduct][coc].

[coc]: CODE_OF_CONDUCT.md

## Testing

All new features and bug fixes must include appropriate tests. Run the full
test suite with:

```bash
flutter test
```

## Commit Messages

Use conventional commit format:

- `feat(editor): add markdown live preview`
- `fix(core): resolve file watcher race condition on Windows`
- `chore(deps): bump flutter from 3.23.0 to 3.24.0`
