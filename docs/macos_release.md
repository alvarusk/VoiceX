# macOS Release Guide

This document captures the working release flow used to submit VoiceX to the Mac App Store.

## Scope

Applies to:

- Flutter desktop target: `macos`
- Xcode archive + App Store Connect upload
- GitHub push from the Mac mini

## One-time setup

1. Open the macOS workspace, not the iOS one:

```bash
open macos/Runner.xcworkspace
```

2. In Xcode, use `Product > Destination > Any Mac`.
3. In `Runner > Signing & Capabilities`:
   - enable `Automatically manage signing`
   - select the Apple Developer team
   - use the macOS bundle identifier `com.kingdomm.voicex`
4. In `App Sandbox`, enable:
   - `Outgoing Connections (Client)`
   - `User Selected File: Read/Write`
   - `Audio Input`
5. In `macos/Runner/Info.plist`, keep:
   - `LSApplicationCategoryType = public.app-category.productivity`
   - microphone usage description
   - speech recognition usage description

## Repo changes required for macOS

These changes were needed for a successful build/archive flow:

- `pubspec.yaml`
  - pin `file_picker` to `10.3.10`
- `macos/Runner.xcodeproj/project.pbxproj`
  - raise macOS deployment target to `11.0`
- `macos/Runner/Info.plist`
  - add `LSApplicationCategoryType`
- `macos/Runner/DebugProfile.entitlements`
  - add audio input
  - add user-selected file read/write
  - add network client
- `macos/Runner/Release.entitlements`
  - add audio input
  - add user-selected file read/write
  - add network client
- `macos/Podfile`
  - keep `platform :osx, '11.0'`

## Build preparation from Terminal

If Xcode complains about missing `macos/Flutter/ephemeral` files or plugin state:

```bash
cd /Users/m1/VoiceX
flutter clean
flutter pub get
cd macos
pod install
cd ..
flutter build macos --debug
```

## Archive flow in Xcode

1. Open `macos/Runner.xcworkspace`.
2. Select `Runner` target.
3. Confirm `Any Mac`.
4. `Product > Clean Build Folder`
5. `Product > Archive`

If validation fails with:

- missing app category:
  - add `LSApplicationCategoryType` to `macos/Runner/Info.plist`
- "No Team Found in Archive":
  - re-check `Signing & Capabilities`
  - create a new archive after confirming the team

## Upload flow

Inside Organizer:

1. Select the new archive.
2. `Validate App`
3. Fix blocking errors if any.
4. `Distribute App > App Store Connect > Upload`

## App Store Connect metadata used

Suggested macOS listing values:

- Name: `VoiceX`
- Subtitle: `ASS subtitle review with AI`
- Primary Category: `Productivity`
- Secondary Category: `Utilities`

Minimum screenshots for macOS:

- 1 required
- 4 recommended

Suggested screenshot set:

1. project/folder view
2. import workflow
3. line-by-line review
4. settings/glossaries/voice tools

## Git and auth notes on the Mac mini

HTTPS password auth for GitHub will fail. Use SSH.

Setup summary:

```bash
ssh-keygen -t ed25519 -C "your_github_email"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
git remote set-url origin git@github.com:alvarusk/VoiceX.git
ssh -T git@github.com
git push origin main
```

## Files that should not be committed

Do not commit generated or machine-local artifacts such as:

- `Pods/`
- `Podfile.lock`
- `.dart_tool/`
- `build/`
- `DerivedData`
- `macos/Flutter/ephemeral`
- generated plugin registrants
- random shell output files created by mistake

## Recommended release checklist

Before the next macOS release:

1. bump version/build
2. run `flutter pub get`
3. run `pod install` in `macos/`
4. build once from Terminal if Xcode state is stale
5. archive in Xcode
6. validate
7. upload
8. update App Store Connect metadata if needed
9. push only the permanent repo changes
