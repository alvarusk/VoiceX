# iPhone and iPad Preparation Plan

This is the next-step checklist for preparing VoiceX for iPhone and iPad from the Mac mini.

## Goal

Decide whether the current app can ship on iOS/iPadOS as-is, and then move through the minimum App Store path without mixing it with the finished macOS release work.

## Recommended order

1. Functional audit
2. iOS project configuration
3. iPhone/iPad UX review
4. device build
5. archive/upload

## 1. Functional audit

Before opening Xcode, check whether the current desktop-oriented workflow makes sense on touch devices.

Questions to answer:

- Is the review screen usable without keyboard shortcuts?
- Are dialogs and tables readable on iPhone?
- Is iPad the real target and iPhone only a fallback?
- Do import/export flows work with iOS file pickers?
- Do voice features behave correctly on iOS?
- Do any desktop-only assumptions remain in the UI?

Recommendation:

- Treat iPad as the primary Apple mobile target.
- Treat iPhone as supported only if the review flow remains usable.

## 2. iOS project configuration

Open:

```bash
open ios/Runner.xcworkspace
```

Then in Xcode:

1. select `Runner` target
2. set the Apple Developer team
3. confirm a real iOS bundle identifier
4. review `Signing & Capabilities`
5. confirm microphone and speech usage descriptions in `ios/Runner/Info.plist`

Expected privacy keys:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

## 3. iPhone/iPad UX review

This should happen before trying to publish.

Minimum manual checks:

1. launch on iPhone simulator
2. launch on iPad simulator
3. import a file
4. navigate review UI
5. edit a subtitle line
6. test settings
7. test voice permission prompts
8. test dark/light layout if relevant

Likely areas to adjust:

- dense desktop layouts
- button sizing
- hover/keyboard assumptions
- file picker flow
- video review controls
- modal sizes

## 4. Terminal prep for iOS

If CocoaPods or Flutter state is stale:

```bash
cd /Users/m1/VoiceX
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug --simulator
```

For a device build later:

```bash
flutter build ipa
```

## 5. App Store prep for iOS/iPadOS

Once the app is usable on devices:

1. create/select the iOS app record in App Store Connect
2. complete metadata
3. add iPhone screenshots
4. add iPad screenshots if supporting iPad
5. complete App Privacy
6. archive from Xcode
7. upload
8. submit for review

## Suggested next session plan

Use the next dedicated Apple session for this exact sequence:

1. open `ios/Runner.xcworkspace`
2. verify signing
3. run on iPhone simulator
4. run on iPad simulator
5. list concrete UI/flow breakages
6. decide:
   - iPad-first
   - iPhone + iPad
   - postpone iPhone support

## Definition of "ready for iOS"

VoiceX should not be considered ready for iOS until all of these are true:

1. app launches on simulator and physical device
2. import/export path works
3. review flow is usable without a keyboard
4. permissions are declared and tested
5. no desktop-only plugin breaks the build
6. the main review screen is acceptable on iPad

## Practical recommendation

Next session target:

- do not aim to publish iOS immediately
- aim to produce a reliable iOS/iPad diagnosis and first successful simulator/device build

That is the fastest safe path. Once that is stable, the App Store upload phase will be much simpler than the macOS setup was.
