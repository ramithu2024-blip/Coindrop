# CoinDrop 💰

A fully offline cash envelope budgeting app built with Flutter.

## Features

- Create budget envelopes (e.g. Groceries, Rent, Transport)
- Assign starting cash amounts to each envelope
- Track spending deductions over time
- View remaining balance per envelope
- Full transaction history per envelope
- Dashboard with all envelopes and total remaining cash
- 100% offline — no internet or cloud required

## Tech Stack

- **Flutter** — UI framework
- **Provider** — State management
- **sqflite** — Local SQLite storage
- **intl** — Date and currency formatting

## Setup

1. Ensure Flutter is installed.

2. Clone the repo and navigate to the project directory.

3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

## Build APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.
