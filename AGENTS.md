# Repository Guidelines

Concise guide for contributing to the Siply iOS project. Keep changes small, focused, and consistent.

## Project Structure & Module Organization
- `Siply/`: App source (Swift, SwiftUI, assets like `Assets.xcassets`).
- `SiplyTests/`: Unit tests (XCTest).
- `SiplyUITests/`: UI tests (XCUITest APIs).
- `Siply.xcodeproj/`: Xcode project; avoid renaming schemes/targets without discussion.
- Prefer feature folders: `Feature/FeatureView.swift`, `FeatureViewModel.swift`, `FeatureModel.swift`.

## Build, Test, and Development Commands
- Open in Xcode: `open Siply.xcodeproj` (build/run from Xcode).
- CLI build (Debug, iOS Simulator):
  - `xcodebuild -project Siply.xcodeproj -scheme Siply -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run tests (unit + UI):
  - `xcodebuild test -project Siply.xcodeproj -scheme Siply -destination 'platform=iOS Simulator,name=iPhone 15'`

## Coding Style & Naming Conventions
- Swift 5+, 4-space indentation, ~120-column soft limit.
- Types/protocols/enums: UpperCamelCase; vars/functions/cases: lowerCamelCase.
- One primary type per file; filename matches type. Use `// MARK: -` groups.
- Prefer `struct` and protocols; use `final` classes when needed.
- Use explicit access control; handle errors with `Result` or `async/await` (avoid `try!` outside tests).

## Architecture Overview
- SwiftUI first: thin views that render state; move logic to services/models.
- State: use `@State` local, `@Binding` downward, observable models for shared data; inject via `@Environment` where appropriate.
- Concurrency: use actors or `@MainActor` to protect mutable shared state.

## Testing Guidelines
- Framework: XCTest; mirror source structure. Names: `FeatureNameTests.swift`, methods like `test_whenX_doesY()`.
- Aim for solid coverage on business logic; add tests with features/bug fixes. Optional snapshot tests for UI.
- Run via Xcode (Product > Test) or the command above.

## Commit & Pull Request Guidelines
- Use Conventional Commits (e.g., `feat: add login screen`, `fix: crash on launch`).
- PRs include: description, linked issues, test steps, and screenshots for UI changes. Keep diffs focused and update tests with API changes.
- Agents must always supply a clear commit description when proposing commits.

## Security & Configuration Tips
- Do not commit secrets, signing files, or user-specific Xcode data (`*.xcuserdatad`, DerivedData). Respect `.gitignore`.
- Use per-developer signing; avoid hard-coded credentials and unnecessary entitlements.
