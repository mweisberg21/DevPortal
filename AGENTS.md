# Agent Instructions

These instructions apply to the whole repository.

- Prefer narrow, behavior-focused changes.
- Keep DevPortal as a compact SwiftPM macOS app unless there is a concrete need
  for a larger workspace layout.
- Run `swift test` after code changes.
- Run `./script/build_and_run.sh --package` after packaging or app-bundle changes.
- Do not commit `.build/`, `.swiftpm/`, `dist/`, `.DS_Store`, or generated
  `Resources/AppIcon.iconset/` files.
- Add or update `CHANGELOG.md` for user-facing changes.
- Keep privacy claims current with the commands and data described in
  `docs/privacy.md`.
