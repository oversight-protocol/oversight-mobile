# Oversight — Privacy Policy

**Effective:** 2026-04-26.

**The short version:** Oversight collects nothing.

The longer version:

## What Oversight does
Oversight is a verifier app for Oversight-protocol bundles. When you pick a
bundle, the app reads the bytes from your device, runs cryptographic checks
locally, and shows you the result. That's it.

## What Oversight does NOT do
- Oversight has no analytics SDK. It does not embed Firebase, Mixpanel,
  Amplitude, Sentry, or any other telemetry library.
- Oversight has no backend server. There is nothing to send data to.
- Oversight does not transmit, log, or persist any bundle you verify.
- Oversight does not request or use any device identifier (IDFA on iOS,
  AAID on Android).
- Oversight does not request location, contacts, microphone, camera (yet —
  see below), or any other permission beyond access to files you explicitly
  pick.

## Permissions Oversight requests
- **File access**: only when you tap "Verify a bundle" and pick a file. The
  app reads the bytes, verifies, displays the result. Nothing is uploaded
  anywhere.

## Honest caveats about platform middlemen
Oversight is distributed through the Apple App Store and Google Play Store.
Apple and Google log every install against your Apple ID / Google account
at the operating-system level. We have no control over that and cannot
disable it. If that is unacceptable in your threat model, install from
F-Droid (planned) or directly from a release `.apk` published on GitHub.

## Future versions
A future version will optionally let you sign documents on-device using
Apple's Secure Enclave / Google's StrongBox keystore. Even then, your
private key never leaves the secure hardware element on your phone, and
the app still sends nothing over the network.

## Verifying this claim
You don't have to take our word for it. The full source code is at
[github.com/oversight-protocol/oversight-mobile](https://github.com/oversight-protocol/oversight-mobile).
A reproducible-build pipeline is on the roadmap so you can confirm the
binary on the App Store / Play Store is byte-identical to what you can
build yourself.

## Contact
Open an issue at
[github.com/oversight-protocol/oversight-mobile/issues](https://github.com/oversight-protocol/oversight-mobile/issues).
