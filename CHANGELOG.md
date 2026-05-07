# Oversight Mobile — Changelog

All notable changes to the Oversight verifier app for iOS and Android.

## [0.1.13] — 2026-05-07 (Receipt copy + v0.4.9 Rust core)

### Added
- Result screen: added a copy-to-clipboard receipt action next to the existing
  share action, so a verifier can paste the human summary plus JSON receipt
  into a ticket, message, or notes app without invoking the platform share
  sheet.
- CI: Android and iOS workflows now run `flutter analyze`, `flutter test`, and
  `cargo test --manifest-path rust/Cargo.toml` before platform packaging.

### Changed
- Rust core pin: moved the seven verifier-safe `oversight-rust` crates from
  upstream tag `v0.4.8` to `v0.4.9`, bringing the mobile verifier onto the tag
  that includes the Rust registry v1 work, hybrid viewer follow-up, and Rust
  watermark round-trip fixes while preserving the v0.4.8 Android portability
  baseline.
- File picker: restricts manual selection to Oversight bundle extensions
  (`.oversight` and `.sealed`) and updates first-run/home copy to name both
  supported bundle forms.
- Store/release docs: clarified that v0.1.x verifies bundles offline and does
  not perform live Rekor lookups yet.
- `.gitignore`: extends local coordination-note ignores for Codex/Claude
  handoff files so private local notes do not appear as public repo changes.

## [0.1.12] — 2026-04-29 (Pinned to oversight v0.4.8 release)

### Changed
- **`rust/Cargo.toml`**: switched the seven oversight crates
  (`oversight-crypto`, `oversight-manifest`, `oversight-container`,
  `oversight-tlog`, `oversight-rekor`, `oversight-watermark`,
  `oversight-policy`) from `path = "../../oversight-gh/..."` to
  `git = "https://github.com/oversight-protocol/oversight.git", tag = "v0.4.8"`.
  v0.4.8 is the minimum desktop tag that supports 32-bit Android cross-compile
  (`armv7`, `i686`) because of the `MAX_CIPHERTEXT_BYTES` portability fix in
  that release. The integration contract is documented at
  [`docs/EMBEDDING.md`](https://github.com/oversight-protocol/oversight/blob/main/docs/EMBEDDING.md)
  in the upstream repo.
- **`.github/workflows/android.yml` and `ios.yml`**: removed the manual
  `git clone ../oversight-gh` step. Cargo now fetches the Rust core directly
  from the git tag, so CI no longer needs a sibling-checkout workaround.
- **`rust/Cargo.lock`**: regenerated against the v0.4.8 git resolution. Same
  seven oversight crates at workspace v0.5.0; only the source line changed.

### Why
- Anyone cloning `oversight-mobile` alone could not build it before. The
  path deps required also cloning oversight and renaming the directory to
  `oversight-gh` as a sibling. With the git tag pin, `git clone` followed
  by `flutter run` works from a fresh checkout.
- Reproducible mobile builds (the F-Droid story) need version-stable
  references to the Rust core. A path dep resolves to "whatever was sitting
  next to me at the time"; a tag pin resolves to a specific commit
  (`af6f725c` for v0.4.8) on every machine.
- Bumping the desktop pin is now a one-line edit in `rust/Cargo.toml` plus
  a CHANGELOG entry, with no CI surgery required.

## [0.1.9] — 2026-04-26 (Android unblock)

### Removed
- `receive_sharing_intent` dependency. The plugin compiles its Kotlin at JVM 17 while older Flutter plugin templates leave Java at 1.8, producing `Inconsistent JVM-target compatibility` on Android release builds. Every workaround (`afterEvaluate`, `plugins.withId`, task-level `JavaCompile`/`KotlinCompile` config, `jvmToolchain(17)`) hit a different gradle finalize-order error (`sourceCompatibility has been finalized`, `languageVersion is final`, …). Cut the dep to unblock; Android tap-to-auto-verify deferred.

### Notes
- iOS still ships `CFBundleDocumentTypes` + `UTExportedTypeDeclarations` so `.oversight` files appear under "Open With" in Files / Mail / AirDrop — user picks the file with **Verify a bundle** from there.
- Android still ships VIEW + SEND intent filters; harmless without a Flutter handler, ready for re-wiring with a smaller dep (likely `app_links`) in a future release.

## [0.1.6] — 2026-04-26 (sample fix + gradle pattern)

### Fixed
- **Tampered sample bundle now actually fails verification.** The previous `assets/samples/sample_tampered.oversight` flipped a byte in the ciphertext region, which the verifier (manifest-signature only) doesn't validate, so on TestFlight v0.1.4 the "Try sample (tampered)" button was incorrectly showing **VERIFIED**. Re-tampered with a byte flip inside the manifest's `content_hash` value so manifest-signature validation actually fails.
- Android gradle: replaced the `afterEvaluate { ... }` JVM-17 patch with `plugins.withId(...) { ... }` to avoid `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`. (Later removed entirely in 0.1.9.)

## [0.1.5] / [0.1.4] — 2026-04-26 (Android plumbing iterations)

### Fixed
- Android: `receive_sharing_intent` plugin's Kotlin/JVM target mismatch with older Flutter plugin Java target. Iterated through deprecated/modern Kotlin DSLs and gradle finalization races; ultimately resolved in 0.1.9 by dropping the plugin.

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
