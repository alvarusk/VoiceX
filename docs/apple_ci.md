# Apple CI Release Flow

This document defines the GitHub Actions flow for distributing VoiceX to Apple platforms without needing a personal Mac in the day-to-day workflow.

## Goal

Work only from the Windows PC + VS Code:

1. commit changes locally
2. push to GitHub
3. let GitHub Actions build and upload iOS and macOS builds automatically

## Distribution model

- `push` to `main`
  - builds iOS and macOS on a GitHub-hosted macOS runner
  - uploads both builds to App Store Connect / TestFlight
- `push` of a tag `v*`
  - same build/upload flow
  - then submits the uploaded iOS and macOS builds to App Review automatically

Examples:

```bash
git push origin main
git tag v1.0.1
git push origin v1.0.1
```

The workflow checks that the tag version matches the `version:` name in `pubspec.yaml`.

## Build numbering

Apple build numbers are generated in CI. The workflow uses:

- version name from `pubspec.yaml`
- build number = `max(pubspec build number, GITHUB_RUN_NUMBER)`

That means you no longer need to bump the iOS/macOS build manually in Xcode for every release.

## Required GitHub configuration

### Secrets

Existing app/runtime secrets reused by Apple builds:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY`
- `R2_SECRET_KEY`
- `R2_BUCKET`
- `R2_PUBLIC_BASE`

Apple signing/upload secrets:

- `APPSTORE_API_PRIVATE_KEY`
  - the raw contents of the App Store Connect API key `.p8`
- `APPLE_CERTIFICATES_P12_BASE64`
  - base64 of a `.p12` that includes:
    - Apple Distribution certificate
    - Mac Installer Distribution certificate
- `APPLE_CERTIFICATES_P12_PASSWORD`
  - password used when exporting the `.p12`
- `APPLE_IOS_APPSTORE_PROFILE_BASE64`
  - base64 of the iOS App Store provisioning profile (`.mobileprovision`) for `com.kingdomm.voicex`
- `APPLE_MACOS_APPSTORE_PROFILE_BASE64`
  - base64 of the macOS App Store provisioning profile (`.provisionprofile`) for `com.kingdomm.voicex`

### Repository variables

- `APPSTORE_API_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPLE_AUTOMATIC_RELEASE`
  - optional
  - `false` by default
  - set to `true` when you want approved App Store submissions to release automatically after approval
- `APPLE_SUBMISSION_INFORMATION_JSON`
  - optional
  - only needed if `fastlane deliver` requires explicit submission information

## One-time Apple portal setup

### 1. App Store Connect API key

Create a **Team API key** with enough App Store Connect permissions for build upload and submission. `App Manager` is the pragmatic minimum for this flow.

Apple references:

- App Store Connect API overview:
  https://developer.apple.com/documentation/appstoreconnectapi
- Users and Access / API keys:
  https://developer.apple.com/help/app-store-connect/configure-access/app-store-connect-api

### 2. Provisioning profiles

Keep active App Store profiles for:

- iOS bundle id: `com.kingdomm.voicex`
- macOS bundle id: `com.kingdomm.voicex`

The workflow stores App Store provisioning profiles in GitHub and uses **manual signing in CI**.

That means:

- the profiles must exist and be valid in Apple Developer
- you export them once and store them as GitHub secrets

### 3. Certificates

Export the Apple signing certificates from Keychain into a single `.p12`:

- Apple Distribution
- Mac Installer Distribution

Then base64-encode that `.p12` and save it in `APPLE_CERTIFICATES_P12_BASE64`.

## How the workflow builds Apple apps

### iOS

1. `flutter build ios --config-only`
2. `pod install`
3. install the iOS App Store provisioning profile from GitHub secrets
4. `xcodebuild archive` with manual signing
5. `xcodebuild -exportArchive` to `.ipa`
6. `fastlane pilot upload`

### macOS

1. `flutter build macos --config-only`
2. `pod install`
3. install the macOS App Store provisioning profile from GitHub secrets
4. `xcodebuild archive` with manual signing
5. `xcodebuild -exportArchive` to `.pkg`
6. `fastlane pilot upload`

## TestFlight behavior

On `main`, the workflow uploads the new builds to TestFlight only.

Apple notes that users in the **App Store Connect Users** internal testing group automatically get all eligible internal builds. Reference:

- https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers

That is the intended default path while macOS is still stabilizing for App Store release.

## App Store submission behavior

On tag pushes like `v1.0.1`, the workflow uploads first and then runs `fastlane deliver submit_build` for:

- iOS (`platform ios`)
- macOS (`platform osx`)

This assumes:

- the app records already exist in App Store Connect
- metadata/screenshots/privacy/review info are already configured
- the current version is ready to submit

## Recommended operating model

### Everyday development

```bash
git push origin main
```

Result:

- Windows build -> Microsoft Store
- Android build -> Play internal track
- iOS/macOS builds -> TestFlight

### Public Apple release

1. ensure `pubspec.yaml` version name is correct
2. push the matching git tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Result:

- iOS and macOS builds upload to App Store Connect
- iOS and macOS submissions are sent to App Review automatically
- if `APPLE_AUTOMATIC_RELEASE=true`, approved builds can auto-release

## Notes and limitations

- Apple review still exists; CI can submit builds, but Apple can still reject them.
- If Apple changes required SDK/Xcode levels, update the GitHub runner image and/or workflow.
- If signing changes in the Apple Developer portal, the `.p12` or provisioning profile secrets may need refreshing.
- Xcode 26 is stricter with older iOS pods. VoiceX pins the CocoaPods iOS deployment target to `13.0` in `ios/Podfile` and disables Swift asset symbol generation for pods during `post_install` to avoid archive failures in resource bundle targets such as `DKPhotoGallery`.
- Keep local files like `ios_public.json` out of Git; the workflow generates its own CI-only defines file.

## Exact setup steps

### 1. Create the App Store Connect API key

In App Store Connect:

1. Open `Users and Access`
2. Open the `Integrations` tab
3. Open `App Store Connect API`
4. Create a **Team API key**
5. Give it at least the `App Manager` role
6. Download the `.p8` file once

Then store:

- file contents -> GitHub secret `APPSTORE_API_PRIVATE_KEY`
- key id -> GitHub variable `APPSTORE_API_KEY_ID`
- issuer id -> GitHub variable `APPSTORE_ISSUER_ID`

Notes:

- Apple only lets you download the `.p8` once
- the workflow expects the **raw file contents**, not base64, in `APPSTORE_API_PRIVATE_KEY`

### 2. Export the signing certificates to one `.p12`

Do this on the Mac that already has the working Apple certificates installed in Keychain.

In `Keychain Access`:

1. Open `login` -> `My Certificates`
2. Find:
   - `Apple Distribution`
   - `Mac Installer Distribution`
3. For each one, verify that the private key is present under the certificate
4. Multi-select both certificates with their private keys
5. Right click -> `Export 2 items...`
6. Save as:
   - `apple_signing.p12`
7. Set an export password

Then convert it to base64:

```bash
base64 -i apple_signing.p12 | pbcopy
```

Use:

- base64 output -> GitHub secret `APPLE_CERTIFICATES_P12_BASE64`
- export password -> GitHub secret `APPLE_CERTIFICATES_P12_PASSWORD`

If you prefer to inspect the file instead of copying to clipboard:

```bash
base64 -i apple_signing.p12 > apple_signing.p12.b64
```

### 3. Export provisioning profiles for GitHub

Required profiles:

- iOS App Store profile for `com.kingdomm.voicex`
- macOS App Store profile for `com.kingdomm.voicex`

Download both profiles from Apple Developer and convert them to base64 on the Mac:

```bash
base64 -i VoiceX_iOS_AppStore.mobileprovision > VoiceX_iOS_AppStore.mobileprovision.b64
base64 -i VoiceX_macOS_AppStore.provisionprofile > VoiceX_macOS_AppStore.provisionprofile.b64
```

Store them in GitHub secrets:

- `APPLE_IOS_APPSTORE_PROFILE_BASE64`
- `APPLE_MACOS_APPSTORE_PROFILE_BASE64`

### 4. Create GitHub secrets

In GitHub:

1. Open the repository
2. `Settings` -> `Secrets and variables` -> `Actions`
3. Create these **repository secrets**:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY`
- `R2_SECRET_KEY`
- `R2_BUCKET`
- `R2_PUBLIC_BASE`
- `APPSTORE_API_PRIVATE_KEY`
- `APPLE_CERTIFICATES_P12_BASE64`
- `APPLE_CERTIFICATES_P12_PASSWORD`
- `APPLE_IOS_APPSTORE_PROFILE_BASE64`
- `APPLE_MACOS_APPSTORE_PROFILE_BASE64`

### 5. Create GitHub variables

In the same GitHub Actions settings page, create these **repository variables**:

- `APPSTORE_API_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPLE_AUTOMATIC_RELEASE`
- `APPLE_SUBMISSION_INFORMATION_JSON` (optional)

Recommended initial values:

- `APPLE_AUTOMATIC_RELEASE=false`
- `APPLE_SUBMISSION_INFORMATION_JSON` empty

### 6. First safe test

Do not start with a tag.

First test with:

```bash
git push origin main
```

Expected result:

- Windows -> Microsoft Store path still runs
- Android -> Play internal track still runs
- iOS -> upload to TestFlight
- macOS -> upload to TestFlight / App Store Connect beta flow

This first run is mainly to validate:

- API key permissions
- certificate import
- provisioning profile download
- signing on the GitHub macOS runner

### 7. Public Apple release after CI is stable

When the `main` push path is already working:

1. make sure `pubspec.yaml` version name is correct
2. push the matching tag

Example:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Expected result:

- iOS build uploads
- macOS build uploads
- both builds are submitted to App Review automatically

### 8. Recommended recovery plan if Apple CI fails

If the first Apple CI run fails:

1. do not rotate everything at once
2. read which of these failed:
   - certificate import
   - provisioning profile download
   - archive signing
   - upload to TestFlight
   - deliver submission
3. fix only that layer

Most likely first-run failure points:

- wrong `.p12` contents
- `.p12` exported without private keys
- API key role too weak
- stale or missing App Store provisioning profile
- App Store Connect metadata incomplete for auto-submission
