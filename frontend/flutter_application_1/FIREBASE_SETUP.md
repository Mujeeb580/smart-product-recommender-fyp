# Firebase Configuration Setup

## Required Files (Not in Git)

The following files are required for the app to work but are excluded from Git for security:

```
frontend/flutter_application_1/
├── lib/
│   └── firebase_options.dart          ← Generate this
└── android/
    └── app/
        └── google-services.json       ← Generate this
```

## Quick Setup (Recommended)

### 1. Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 2. Navigate to Flutter Project
```bash
cd frontend/flutter_application_1
```

### 3. Run FlutterFire Configuration
```bash
flutterfire configure
```

### 4. Select Your Firebase Project
- Project: **smart-product-recommender-fyp**
- Select platforms: **Web, Android, iOS**

This automatically generates:
- ✅ `lib/firebase_options.dart`
- ✅ `android/app/google-services.json`
- ✅ `ios/Runner/GoogleService-Info.plist`

## Manual Setup (Alternative)

If FlutterFire CLI doesn't work, manually download from Firebase Console:

### For Android:
1. Go to [Firebase Console](https://console.firebase.google.com/project/smart-product-recommender-fyp/settings/general)
2. Click on Android app: `com.example.flutter_application_1`
3. Download `google-services.json`
4. Place in: `android/app/google-services.json`

### For iOS:
1. Same Firebase Console page
2. Click on iOS app
3. Download `GoogleService-Info.plist`
4. Place in: `ios/Runner/GoogleService-Info.plist`

### For Web/All Platforms:
1. Run `flutterfire configure` (easiest way)
2. Or manually create `lib/firebase_options.dart` using Firebase project settings

## Verification

After setup, verify files exist:
```bash
# Check files exist
ls lib/firebase_options.dart
ls android/app/google-services.json
ls ios/Runner/GoogleService-Info.plist

# Check files are NOT tracked by Git
git status
# Should NOT show these files as changes
```

## Troubleshooting

### Error: "Firebase not initialized"
- Run `flutterfire configure`
- Ensure `firebase_options.dart` exists
- Check `main.dart` has Firebase initialization

### Error: "google-services.json missing"
- Download from Firebase Console
- Place in correct directory: `android/app/`

### Error: "No Firebase App '[DEFAULT]' has been created"
- Check `lib/firebase_options.dart` exists
- Verify Firebase initialization in `main.dart`:
  ```dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  ```

## Security Note

⚠️ **These files contain API keys and are kept out of Git for security.**

While Firebase client API keys are designed to be in client apps, keeping them out of public repositories is a best practice. Security is enforced through Firebase Security Rules, not by hiding these keys.

## Need Help?

Contact the project maintainer if you need:
- Firebase Console access
- Help with configuration
- API key rotation
