# Oversight

Cryptographically-verifiable data provenance, in your pocket.

Mobile companion to the [Oversight Protocol](https://github.com/oversight-protocol/oversight).

## What it does

- **Verify** any Oversight-attested document — scan a QR, paste a hash, or open a `.oversight` bundle
- **Check the public log** — pulls live from [Sigstore Rekor](https://docs.sigstore.dev/logging/overview/) and verifies cryptographic inclusion
- **No telemetry. No accounts. No server.** The app does pure cryptography against a public, append-only log
- **Bit-identical** verification with the desktop CLI — same Rust core, same answer, every time

## What this is not

- Not a "100% secure" anything (that doesn't exist)
- Not free of platform middlemen (Apple and Google control the stores; F-Droid and reproducible builds are the trustless path — see [BUILD.md](docs/BUILD.md))
- Not a content-publishing app — verification only in v1, signing comes in v2 with hardware-backed keys

## How to install

| Platform | Where | Status |
|---|---|---|
| iOS | TestFlight, App Store | 🚧 in development |
| Android | Google Play | 🚧 in development |
| Android (no Google) | F-Droid | 🚧 planned |
| Anyone | GitHub Releases (`.apk` + reproducible build manifest) | 🚧 planned |

## How to verify the app itself

Reproducible builds are coming. When live, you'll be able to clone this repo, run one command, and confirm the binary on the App Store / Play Store / F-Droid is byte-identical to what you built locally. That's how trust actually works.

## License

Apache 2.0 — same as the protocol.
