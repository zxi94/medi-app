# MediScan AI Flutter App

Flutter client for the Chest X-ray Diagnosis system. The app supports patient, doctor, and admin roles with dynamic user greetings, authenticated profile loading, patient-doctor chat, and admin management.

## Features

- Provider-based authentication state.
- Dynamic welcome messages from `/auth/me` and login responses.
- Patient and doctor dashboards.
- Real-time Care Chat backed by server-sent events.
- Admin Management page for listing, creating, editing, deleting, and reviewing users.
- Account avatar dropdown with profile, admin console, and logout actions.
- Responsive layouts for mobile and wide desktop/tablet screens.

## Run Locally

Start the backend first on port `5001`, then run:

```powershell
cd "D:\Graduation project\ai_xray_diagnosis_app\Chest-X_ray-diagnosis-system-Flutter_app"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5001
```

For Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

For a physical phone connected by USB cable:

```powershell
adb reverse tcp:5001 tcp:5001
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

For a physical phone on the same Wi-Fi network:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_IP:5001
```

## Key Files

- `lib/providers/auth_provider.dart`: signed-in user, token, role, and profile refresh.
- `lib/services/auth_service.dart`: login/signup/profile API integration.
- `lib/services/chat_service.dart`: contacts, threads, messages, and SSE stream.
- `lib/services/admin_service.dart`: admin user and activity APIs.
- `lib/screens/shared/care_chat_screen.dart`: patient-doctor chat UI.
- `lib/screens/auth/admin/admin_main.dart`: admin management UI.
- `lib/widgets/shared_widgets.dart`: shared top bar, avatar dropdown, cards, badges.

## Verification

```powershell
flutter analyze --no-fatal-infos
flutter test
```

The current analyzer output has no errors or warnings; remaining messages are informational lints from the existing codebase such as deprecated `withOpacity` usage and const suggestions.

## Deployment Notes

- Build with the production backend URL:

```powershell
flutter build web --dart-define=API_BASE_URL=https://api.example.com
```

- Keep the backend behind HTTPS.
- Configure CORS on the backend to match the deployed Flutter origin.
- For mobile builds, ensure the backend URL is reachable from the device network.
