# Oversight — store listing copy

Drop these directly into App Store Connect / Play Console. Word counts are
listed for the platforms that enforce them.

---

## App Store (iOS)

### App Name
```
Oversight
```
*(30 char max — fits)*

### Subtitle
```
Verify document provenance.
```
*(30 char max — fits)*

### Promotional Text
```
Open-source. Offline. Bit-identical with the desktop CLI. Verify signed Oversight bundles on-device — no account, no telemetry.
```
*(170 char max — fits)*

### Description
```
Oversight verifies that a document is exactly what its issuer claims, using cryptography that anyone can audit.

Open the app, pick a .oversight or .sealed bundle, and see in seconds whether its signature is valid, who issued it, and what content hash the signed manifest binds. The verification runs entirely on your device using the same Rust code that powers the desktop command-line tool — same answer, every time.

WHAT YOU CAN VERIFY
• The cryptographic signature on the issuer's manifest
• The exact content hash and original filename
• The issuer's public key fingerprint
• When and under what suite the document was sealed
• Whether the bundle carries recipient and watermark metadata

WHAT THE APP DOES NOT DO
• It does not phone home. There is no server, no analytics SDK, no account.
• It does not send your bundles anywhere. Verification is local.
• It does not store, log, or transmit anything you verify.

WHO THIS IS FOR
• Journalists checking a leaked document's provenance before publishing
• Lawyers handling sealed evidence
• Researchers auditing AI training-data attribution claims
• Anyone who has been told "this file is signed" and wants to confirm

OPEN AND VERIFIABLE
The full source — including the cryptographic core, the build pipeline, and this app — lives at github.com/oversight-protocol. Reproducible builds are coming so you can verify the binary on the App Store is byte-identical to what you can build yourself.

The Oversight protocol is Apache 2.0. So is this app.
```
*(4000 char max — well under)*

### Keywords
```
verify,provenance,signature,attestation,journalism,evidence,audit,offline,open source
```
*(100 char max — fits)*

### Support URL
```
https://github.com/oversight-protocol/oversight-mobile/issues
```

### Marketing URL (optional)
```
https://github.com/oversight-protocol/oversight
```

### Privacy Policy URL
```
https://github.com/oversight-protocol/oversight-mobile/blob/main/docs/PRIVACY.md
```

### App Privacy (Privacy Nutrition Labels)

Click "Get Started" → answer:

| Question | Answer |
|---|---|
| Does this app collect any data? | **No** |

That's it. Nothing else to fill in. This is the entire privacy story.

### Age Rating
17+ is overkill, 4+ is fine. The app has no content, no UGC, no anything.

### Category
- Primary: **Utilities**
- Secondary: **Productivity**

---

## Google Play (Android)

### App Name
```
Oversight
```

### Short Description
```
Verify cryptographically signed documents offline. Open source. Zero telemetry.
```
*(80 char max — fits)*

### Full Description
*(Same as App Store description above — 4000 char limit on Play also)*

### Category
**Tools**

### Content Rating
Use the IARC questionnaire. Every answer is "no" → result will be Everyone / 3+.

### Data Safety section

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **No** |
| Is all of the user data encrypted in transit? | **N/A — no data is transmitted** |
| Do you provide a way for users to request data deletion? | **N/A — no data is collected** |

### Target audience and content
- All ages
- No ads

### Tags
- Productivity
- Utility
- Open source

---

## Privacy Policy (URL-able)

Drop this in `docs/PRIVACY.md` so the Privacy URL above resolves:

```markdown
# Oversight — Privacy Policy

Effective: 2026-04-26.

The short version: Oversight collects nothing. The longer version:

## What Oversight does
Oversight is a verifier app for Oversight-protocol bundles. When you pick a
bundle, the app reads the bytes from your device, runs cryptographic checks
locally, and shows you the result. That's it.

## What Oversight does NOT do
- Oversight has no analytics SDK. It does not embed Firebase, Mixpanel,
  Amplitude, Sentry, or any other telemetry library.
- Oversight has no backend server. There is nothing to send data to.
- Oversight does not transmit, log, or persist any bundle you verify.
- Oversight does not request or use any device identifier (IDFA, AAID).
- Oversight does not request location, contacts, microphone, camera (yet — see
  below), or any other permission beyond access to files you explicitly pick.

## Permissions Oversight requests
- **File access**: only when you tap "Verify a bundle" and pick a file. The
  app reads the bytes, verifies, displays the result. Nothing is uploaded.

## Future versions
A future version will optionally let you sign documents on-device using
Apple's Secure Enclave / Google's StrongBox keystore. Even then, your private
key never leaves the secure hardware element on your phone, and the app still
sends nothing.

## Contact
Open an issue at https://github.com/oversight-protocol/oversight-mobile/issues
```
