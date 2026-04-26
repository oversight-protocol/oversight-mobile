# Releasing Oversight

The full release loop runs in GitHub Actions. You don't need a Mac. You don't
even need to clone the repo to ship a build — push a tag and a TestFlight build
appears.

## One-time setup

### 1. Apple Developer (iOS)

You already have an active Apple Developer account ($99/yr) and TestFlight set
up. You need three pieces of information from Apple, then four secrets pasted
into GitHub.

1. **Register the bundle ID** at
   [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list)
   - Click `+` → App IDs → App
   - Description: `Oversight`
   - Bundle ID (Explicit): `com.oversightprotocol.oversight`
   - Capabilities: leave defaults (we don't need push, iCloud, etc.)
2. **Create the App Store Connect app record** at
   [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
   - `+` → New App
   - Platform: iOS
   - Name: `Oversight`
   - Primary language: English (US)
   - Bundle ID: pick `com.oversightprotocol.oversight`
   - SKU: `oversight-mobile-001`
3. **Generate an App Store Connect API key**
   - [appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
   - `+` → Name: `oversight-ci`, Access: `App Manager`
   - **Download the .p8 file** — Apple will only let you do this ONCE.
   - Note the **Key ID** (10 chars) and the **Issuer ID** (UUID at top of page)
4. **Note your Team ID** — top right of [developer.apple.com/account](https://developer.apple.com/account) → Membership

### 2. GitHub secrets (iOS)

Go to [github.com/oversight-protocol/oversight-mobile/settings/secrets/actions](https://github.com/oversight-protocol/oversight-mobile/settings/secrets/actions) and add:

| Secret name | Value |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | The 10-char Key ID from step 3 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | The Issuer UUID from step 3 |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` (run on the .p8 you downloaded) |
| `APPLE_TEAM_ID` | Your 10-char Team ID from step 4 |

To produce the base64 of the .p8 file (run wherever you downloaded it):
```bash
base64 -i AuthKey_XXXXXXXX.p8 | pbcopy   # macOS
base64 -w0 AuthKey_XXXXXXXX.p8           # Linux
certutil -encode AuthKey_XXXXXXXX.p8 out.b64 && type out.b64   # Windows
```

### 3. Android signing key (one-time)

Generate an upload keystore (do this on the dev box, **never commit the .jks**):

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -alias upload \
  -storepass <pick a strong password> \
  -keypass <same or different> \
  -dname "CN=Zion Boggan, O=Oversight Protocol, C=US"
```

Then add these GitHub secrets:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | The store password you chose |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | The key password you chose |

**Back up the .jks file somewhere safe.** If you lose it, you can never push
updates to your Play Store listing — only a brand new app.

## Cutting a release

```bash
# bump version in pubspec.yaml: e.g. version: 0.1.0+1
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions does the rest:
- iOS workflow builds + signs + uploads to TestFlight (~15 min on macos-14)
- Android workflow builds the signed AAB (~8 min on ubuntu-latest)

Both AAB and IPA are also uploaded as workflow artifacts so you can grab them
from the Actions tab if you need to inspect.

## First-time TestFlight install on your iPhone

1. After the iOS workflow finishes, go to App Store Connect → My Apps → Oversight → TestFlight
2. Wait ~5 min for "Processing" to finish
3. Add yourself as an internal tester (email zionboggan@gmail.com)
4. Open TestFlight on your iPhone, install the build
