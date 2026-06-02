# CoinDrop

A fully offline, encrypted cash envelope budgeting app for Android.

## Features

- **Encrypted vault** — PIN + SQLCipher, optional biometric unlock
- **Envelope budgeting** — Create envelopes, fund them, track spending
- **Payday tracking** — Weekly, fortnightly, or monthly recurring paydays with auto-allocation
- **Spending guard** — Warns when envelopes run low; optional hard limit blocks overspending
- **Money reality check** — Dashboard card: available vs allocated vs unassigned, spending trends, days until payday
- **Envelope insights** — Daily spend rate, days until depleted per envelope
- **Configurable currency** — AUD, USD, GBP, EUR
- **Screenshot blocking** — Toggle FLAG_SECURE at runtime
- **Encryption toggle** — Enable/disable DB encryption (export/import on change)
- **Themes** — Light/dark/system, custom accent colors
- **Export** — JSON and CSV
- **100% offline** — No internet or cloud required

## Tech Stack

- **Flutter** — UI framework
- **Provider** — State management
- **SQLCipher** (via `sqflite_common_ffi` + `sqlcipher_flutter_libs`) — Encrypted local storage
- **FlutterSecureStorage** — Vault hash and biometric keys

## Build APKs

### Debug APK (fast build, large file, all architectures)

```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk` (~118 MB)

### Release APK (optimized, needs ~10 min for R8/ProGuard)

```bash
# All architectures:
flutter build apk --release

# ARM64 only (smaller, for Galaxy A30 and similar):
flutter build apk --release --target-platform android-arm64 --split-per-abi
```
Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~25 MB)

> **Note:** Release builds require R8/ProGuard which needs ~3GB heap and ~10 minutes.

## Downloads

Pre-built APKs are on the [Releases page](https://github.com/ramithu2024-blip/Coindrop/releases).

| File | Type | Size | Use case |
|------|------|------|----------|
| `Coindrop-v1.0.0-debug.apk` | Debug | ~118 MB | Quick test, all CPU architectures |
| `Coindrop-v1.0.0-release-arm64-v8a.apk` | Release | ~25 MB | Daily use on arm64 devices (Galaxy A30, etc.) |

## Setup

1. Install Flutter.
2. Clone repo and `cd` into it.
3. `flutter pub get`
4. `flutter run` (for development)

## Build for release

```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```
