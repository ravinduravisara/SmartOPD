# smart_opd

## Google sign-in setup

Google sign-in uses an ID token verified by the backend. Set the same web OAuth client ID in `backend/.env`:

```env
GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Build the Flutter app with that client ID:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Register the Android package `com.smartopd.smart_opd` and its signing SHA-1 in Google Cloud. For iOS, add the iOS client ID and reversed client ID to `ios/Runner/Info.plist` as described by the `google_sign_in` plugin setup.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
