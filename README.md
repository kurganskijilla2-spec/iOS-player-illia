# illia

Невеликий iOS-плеєр для локальних аудіофайлів. Додаток імпортує MP3, M4A, WAV, AIFF, AAC та CAF із «Файлів», відтворює їх у фоні та показує керування на екрані блокування. Імпортована медіатека зберігається між запусками.

## Відкрити та зібрати локально

Потрібен Mac із Xcode та XcodeGen.

```sh
brew install xcodegen
xcodegen generate
open illia.xcodeproj
```

Збірка для симулятора:

```sh
xcodebuild build \
  -project illia.xcodeproj \
  -scheme illia \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Запуск тестів на доступному iPhone Simulator:

```sh
xcodebuild test -project illia.xcodeproj -scheme illia \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## GitHub Actions

- **iOS CI** запускається для кожного pull request і push у `main`. Він генерує Xcode-проєкт, знаходить доступний iPhone Simulator і запускає XCTest.
- **Unsigned iOS archive** запускається вручну у вкладці **Actions**. Він збирає непідписаний `.xcarchive` і завантажує його як артефакт. Для цього процесу не потрібні секрети підпису.

Архів без підпису потрібен для перевірки збірки; його не можна встановити на пристрій або відправити в App Store без підписання.
