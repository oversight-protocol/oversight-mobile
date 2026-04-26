# Oversight Mobile — Changelog

All notable changes to the Oversight verifier app for iOS and Android.

## [0.1.3] — 2026-04-26 (UX hardening)

### Added
- **Embedded sample bundles** — ships with `sample_welcome.oversight` (valid) and `sample_tampered.oversight` (intentionally corrupted) so first-run users can see both verification outcomes without needing to receive a real bundle.
- **Try Sample buttons** on the home screen — verify either sample with one tap.
- **First-run onboarding** — three-screen explainer covering "what is Oversight", "where do bundles come from", and "what happens on this device" (TL;DR: nothing leaves it).
- **Verification history** — last 20 verifications persisted locally via `SharedPreferences`. Tap any entry to re-open the result. Clear-all from the overflow menu.
- **iOS file association** — `.oversight` and `.sealed` files in Files / Mail / AirDrop / Slack now open Oversight directly via `CFBundleDocumentTypes` + `UTExportedTypeDeclarations`.
- **Share / export verification receipt** — share button on the result screen exports a JSON receipt (full verification record) plus a human-readable summary via the iOS share sheet.
- **Tappable About + GitHub link** — opens `https://github.com/oversight-protocol/oversight` in Safari.

### Changed
- **Plain-English failure reasons** — cryptography jargon (e.g., `"manifest signature did not verify against issuer pubkey"`) translated into user-readable explanations like `"This file's signature doesn't match. The file may have been altered, or the sender's key isn't trusted."` Raw error preserved under "Technical details".
- **Result screen redesign** — primary view now shows only signer + when + tampered/clean. Full metadata wall hidden behind a "Technical details" expander.

### Notes
- This release is still **verifier-only** (V1 scope). Phone-side signing/encryption (V2) requires Secure Enclave integration and is not yet shipped.

## [0.1.2] — 2026-04-26 (TestFlight unblock)

### Fixed
- **`NSPhotoLibraryUsageDescription` + `NSCameraUsageDescription`** added to `Info.plist`. Apple ITMS-90683 was rejecting builds because the `file_picker` 11.x dependency references `PHPickerViewController` (transitive), which requires a purpose string even when the app never opens the picker.
- Bumped pubspec version `0.1.0+1` → `0.1.1+2` because Apple burns build-number slots on rejected uploads — re-uploading the same `version+build` is refused with "build already exists."

## [0.1.1] — 2026-04-26 (CI signing)

### Fixed
- iOS signing pipeline rewritten to manual signing with pre-created Apple Distribution cert and App Store provisioning profile, imported on each run via `apple-actions/import-codesign-certs`.
  - Reason: `xcodebuild -allowProvisioningUpdates` with App Store Connect API key alone cannot create new Distribution certs (Apple requires Apple-ID session for cert *creation*). Manual signing with pre-created artifacts is the only reliable no-Mac CI path today.
- `Podfile` committed with `post_install` hook setting `CODE_SIGNING_ALLOWED=NO` for all Pod targets so CocoaPods don't fight `CODE_SIGN_IDENTITY=Apple Distribution` on the Runner target.
- Removed hardcoded `"iPhone Developer"` from `Runner.xcodeproj/project.pbxproj` PBXProject configs and pinned the Runner Release target to `Apple Distribution` + `CODE_SIGN_STYLE = Automatic`.
- Stripped UTF-8 BOM and CRLF from PowerShell-pushed GitHub Actions secrets that were polluting JWT `kid` claims and breaking `xcodebuild` auth (401 on `xcbuild/listTeams.action`).

## [0.1.0] — 2026-04-26 (initial TestFlight build)

### Added
- Verifier-only iOS + Android app, Flutter UI on the Oversight Rust core via `flutter_rust_bridge`. Verification is bit-identical with the desktop `oversight verify` CLI — same Rust crate, same answer.
- `verify_bundle` FFI: parses a `.oversight` bundle, checks the manifest signature against the embedded issuer pubkey, returns a structured result (status, signature validity, manifest summary, failure reasons).
- Material 3 dark theme single-screen UI: pick a bundle, see verified / not-verified + manifest details.
- App icon (shield + transparency-log lines + checkmark, blue / green / white).
- Apache 2.0 license, listing copy, privacy policy.
- GitHub Actions: iOS — TestFlight (macos-15, fastlane fallback removed in favor of xcodebuild manual signing); Android — APK + AAB (ubuntu-latest, signed AAB on tags).
- Upstream PR `oversight-protocol/oversight#4` merged: 32-bit `usize` overflow fix in `MAX_CIPHERTEXT_BYTES` that was blocking all 32-bit Android ABIs.

### Notes
- Bundle ID: `com.oversightprotocol.oversight`.
- App Store Connect record: name **"Oversight Protocol"** (plain "Oversight" was already taken by another developer).
- Distribution: TestFlight internal first; F-Droid + reproducible builds planned for the trustless story alongside App Store + Play Store.
