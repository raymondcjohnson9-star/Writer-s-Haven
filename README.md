
# Writers Haven

Writers Haven is a writing application built with Flutter.

## Current project

- Flutter source: `lib/main.dart`
- Flutter dependencies: `pubspec.yaml`
- Existing native Android source: `app/`
- Android application ID: `com.writershaven.app`

## Build

The GitHub Actions workflow builds a debug Android APK.

1. Open the repository on GitHub.
2. Select **Actions**.
3. Open **Build Writers Haven APK**.
4. Select a successful workflow run.
5. Download the `writers-haven-debug-apk` artifact.

## Development

Flutter's Android platform files may be generated with:

`flutter create --platforms=android --project-name writers_haven .`

Review generated files before committing them.
