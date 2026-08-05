# Repository Guidelines

## Project Structure & Module Organization

This repository contains a Flutter application with Firebase backend functions.

* `lib/`: Application code organized by feature (`home/`, `certificate/`, `notification/`, `auth/`, `study/`, `mypage/`) plus shared `services/` and `widgets/`.
* `functions/`: Node.js 20 Firebase Functions. Notification functions live in `functions/notifications/` and are exported through its `index.js`.
* `test/`: Flutter tests. Name test files with the `_test.dart` suffix.
* `assets/`: Images, icons, and ML models declared in `pubspec.yaml`.
* `android/`: Primary supported platform configuration.
* `firebase.json` and `firestore.indexes.json`: Firebase deployment and Firestore index/TTL configuration.

## Build, Test, and Development Commands

Run commands from the repository root unless noted:

```bash
flutter pub get             # Install Flutter dependencies
flutter run                 # Run on a connected Android device/emulator
flutter analyze             # Apply flutter_lints static analysis
dart format <modified-files> # Format only modified Dart files
flutter test <test-file>    # Run a relevant Flutter test file
flutter test                # Run all Flutter tests only when necessary
flutter build apk --debug   # Produce a debug Android APK only when necessary
cd functions && npm install # Install backend dependencies
cd functions && npm run serve
firebase deploy --only functions
firebase deploy --only firestore:indexes
```

Use the narrowest relevant command for the current change. Do not automatically run every command listed above.

Deploy only the Functions or indexes relevant to the change. Never deploy unrelated resources.

## Coding Style & Naming Conventions

Use two-space indentation for Dart and JavaScript. Follow `flutter_lints`.

Format only modified Dart files unless the user explicitly requests a full-project format.

Dart files use `snake_case.dart`, types use `UpperCamelCase`, and members use `lowerCamelCase`.

Keep feature-specific UI, models, and services inside their feature directory. Reuse existing services, widgets, and project patterns before creating new abstractions.

Name Firebase notification modules `*_notification.js` and register them in `functions/notifications/index.js`. Do not expand the root Functions entry point.

## Testing Guidelines

Use `flutter_test` with descriptive `group` and `testWidgets` names. Add regression coverage for changed behavior and keep fixtures deterministic.

Run the narrowest relevant verification first:

1. Format only the modified Dart files.
2. Run `flutter analyze` for ordinary Dart code changes.
3. Run only relevant tests where possible.
4. Run the full Flutter test suite only when necessary or explicitly requested.
5. Run Android builds only when required to verify platform-specific or build-related changes.

For Firebase Functions, at minimum run `node --check <file>` for modified JavaScript files. Test Firebase-dependent behavior with the emulator where practical and necessary.

Never trigger production push notifications merely as a test.

Do not run Firebase emulators, Android builds, or lengthy full-project checks when they are unrelated to the requested change.

## Commit & Pull Request Guidelines

Follow the existing concise Conventional Commit style: `feat:`, `fix:`, or `style:` followed by a Korean or English summary.

Keep commits focused. Pull requests should describe behavior changes, list verification commands, link relevant issues, and include screenshots for UI changes.

Call out Firestore schema, index, scheduler, or deployment changes explicitly.

Do not commit, push, create or update pull requests, respond to remote reviews, or merge branches unless explicitly requested by the user.

When working on a pull request, modify the PR source branch only unless the user explicitly requests another target. Do not perform the final merge unless explicitly requested.

## Security & Agent-Specific Instructions

Never commit `.env`, tokens, service credentials, private certificates, or other secrets. Use Firebase Secrets for backend credentials.

Keep changes limited to the requested feature.

Treat an explicit user request to modify a feature as approval to edit the files reasonably required for that feature. Before editing unrelated files or expanding the scope beyond the requested feature, explain why and obtain approval.

Do not modify generated files unless the current task explicitly requires it.

Do not modify Firebase configuration files, Android platform configuration, `pubspec.yaml`, Firestore rules, indexes, or deployment settings unless they are required by the requested task.

Before adding a new dependency, explain why the dependency is needed and check whether an existing dependency or project utility can satisfy the requirement.

Never run Firebase deployment commands unless the user explicitly requests deployment in the current task.

Do not commit, push, create or update pull requests, respond to remote reviews, or merge branches unless explicitly requested by the user.
