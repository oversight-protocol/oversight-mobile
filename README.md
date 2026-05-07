# Oversight

Cryptographically-verifiable data provenance, in your pocket.

Mobile companion to the [Oversight Protocol](https://github.com/oversight-protocol/oversight).

## What it does

- **Verify** any Oversight-attested document — open a `.oversight` / `.sealed` bundle and check the signed manifest
- **Inspect provenance locally** — issuer, original filename, content hash, signature status, suite, and watermark metadata
- **No telemetry. No accounts. No server.** The app does pure cryptography against bytes you choose on this device
- **Bit-identical** verification with the desktop CLI — same Rust core, same answer, every time

## What this is not

- Not a "100% secure" anything (that doesn't exist)
- Not free of platform middlemen (Apple and Google control the stores; F-Droid and reproducible builds are the trustless path, both planned)
- Not a content-publishing app, verification only in v1, signing comes in v2 with hardware-backed keys

## Status

| Platform | Channel | Status |
|---|---|---|
| iOS | TestFlight (internal) | **Live — v0.1.11; v0.1.13 ready to tag** |
| iOS | App Store | After internal beta passes external review |
| Android | Internal track / debug APK | **Live — v0.1.11; v0.1.13 ready to tag** |
| Android | Google Play | After internal beta |
| Android (no Google) | F-Droid | Planned |
| Anyone | GitHub Releases (`.apk` + reproducible build manifest) | Planned |

The current internal beta is closed (single-tester) while I shake out platform-specific issues. External TestFlight invitations open after the iOS 26 SDK migration settles and the export-compliance plumbing is clean.

## How it's built

- **Flutter** for the UI layer (Dart, single codebase, both platforms)
- **Rust** for the verification core, embedded via [`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge). The seven verifier-safe `oversight-rust` crates that power the desktop CLI are linked into the mobile binary, so a manifest that verifies on a laptop verifies the same way on your phone, with no second implementation to drift. As of the current `main` branch the Rust dependency is pinned to the upstream [`v0.4.9` release tag](https://github.com/oversight-protocol/oversight/releases/tag/v0.4.9); see the integration contract at [`docs/EMBEDDING.md`](https://github.com/oversight-protocol/oversight/blob/main/docs/EMBEDDING.md) upstream
- **iOS** builds run on GitHub-hosted macOS runners (`macos-26`, Xcode 26, iOS 26 SDK). No local Mac is required for the project, everything from cert import to TestFlight upload is reproducible from CI
- **Android** builds run locally and on CI; release AABs are signed with a PKCS12 upload keystore that lives outside the repo

## Build it yourself

A fresh clone is enough. Cargo pulls the upstream Rust core directly from the pinned git tag, so there is no sibling-checkout step.

```bash
git clone https://github.com/oversight-protocol/oversight-mobile.git
cd oversight-mobile
flutter pub get
flutter run                        # runs against an attached device or simulator
flutter build apk --debug          # Android debug APK
flutter build appbundle --release  # Android release AAB (signing required)
flutter build ios --release        # iOS release (signing required)
```

To bump the upstream Rust pin, change the `tag = "..."` lines in [`rust/Cargo.toml`](rust/Cargo.toml) and add a CHANGELOG entry. CI does not need any other change.

## How to verify the app itself

Reproducible builds are coming. When live, you will be able to clone this repo, run one command, and confirm the binary on the App Store / Play Store / F-Droid is byte-identical to what you built locally. That is how trust actually works.

Until reproducible builds land, the most honest fallback is the source of truth in this repo: every release is tagged, every tag has a matching CI run, and every CI run uploads its artifacts. You can read the workflow yourself in [`.github/workflows/`](.github/workflows/).

## License

Apache 2.0 — same as the protocol.
