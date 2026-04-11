# Google Sign-In Setup Guide

## ✅ What's Been Implemented

Google Sign-In has been successfully integrated into your Flutter app with the following features:

### 1. **Dependencies Added**
- `google_sign_in: ^6.2.1` - Google Sign-In SDK
- `font_awesome_flutter: ^10.7.0` - For the Google logo icon

### 2. **AuthService Updates**
The `AuthService` class now includes:
- `signInWithGoogle()` - Method to authenticate with Google
- `signOut()` - Updated to sign out from both Firebase and Google
- Automatic backend user registration for new Google users

### 3. **UI Components**
Both login and sign-up screens now feature:
- Professional Google Sign-In button with the official Google logo
- "OR" divider between email/password and Google sign-in
- Clean white button with Google branding color (#DB4437)
- Proper loading states and error handling

---

## 🔧 Firebase Configuration Required

To make Google Sign-In work, you need to configure it in Firebase Console:

### Step 1: Enable Google Sign-In in Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **smart-product-recommender-fyp**
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** in the providers list
5. Click **Enable** toggle
6. Add your **Project support email** (required)
7. Click **Save**

### Step 2: Configure Android (if targeting Android)

1. In Firebase Console, go to **Project Settings** → **General**
2. Scroll to **Your apps** section
3. Click on your Android app
4. Make sure the **SHA-1** certificate fingerprint is added

#### Get SHA-1 Certificate:

**For Debug Mode:**
```powershell
cd frontend/flutter_application_1/android
./gradlew signingReport
```

Or use Java keytool:
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**For Release Mode:**
```powershell
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

5. Copy the SHA-1 fingerprint
6. In Firebase Console, add it under your Android app settings
7. Download the updated `google-services.json`
8. Replace the file at: `frontend/flutter_application_1/android/app/google-services.json`

### Step 3: Configure iOS (if targeting iOS)

1. In Firebase Console, go to **Project Settings** → **General**
2. Click on your iOS app
3. Download the updated `GoogleService-Info.plist`
4. Replace the file in your iOS project

5. Add the following to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` with your iOS client ID from `GoogleService-Info.plist`.

### Step 4: Configure Web (if targeting Web) ⚠️ **REQUIRED FOR WEB**

#### Get Your Web Client ID from Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **smart-product-recommender-fyp**
3. Click the **⚙️ gear icon** → **Project Settings**
4. Scroll to **Your apps** section
5. Find your **Web app** (the one with the `</>` icon)
6. Look for **Web client ID** in the **SDK setup and configuration** section
   - It will look like: `1042809810856-xxxxxxxxxx.apps.googleusercontent.com`
   - Copy this entire string

#### Update Your index.html File:

The meta tag has already been added to [web/index.html](frontend/flutter_application_1/web/index.html), but you need to replace the placeholder with your actual Web Client ID:

**Current (needs update):**
```html
<meta name="google-signin-client_id" content="1042809810856-WEB_CLIENT_ID_HERE.apps.googleusercontent.com">
```

**Updated (replace WEB_CLIENT_ID_HERE with your actual ID):**
```html
<meta name="google-signin-client_id" content="1042809810856-abc123xyz789.apps.googleusercontent.com">
```

#### Alternative: Get Client ID from Google Cloud Console

If you don't see it in Firebase Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **smart-product-recommender-fyp**
3. Navigate to **APIs & Services** → **Credentials**
4. Find the **OAuth 2.0 Client IDs** section
5. Look for the **Web client** entry
6. Copy the **Client ID**

---

## 🧪 Testing Google Sign-In

### Option 1: Test on Real Device
```powershell
cd frontend/flutter_application_1
flutter run
```

### Option 2: Test on Android Emulator
Make sure:
- Emulator has Google Play Services installed
- You're signed in to a Google account on the emulator

### Option 3: Test on Web
```powershell
cd frontend/flutter_application_1
flutter run -d chrome
```

---

## 🎨 UI Preview

The Google Sign-In button appears:
- **Login Screen**: Below the email/password login button
- **Sign-Up Screen**: Below the create account button

The button features:
- Official Google logo (red color: #DB4437)
- White background
- Grey border
- Text: "Continue with Google"
- Professional Material Design styling

---

## 🐛 Common Issues & Solutions

### Issue 1: "People API has not been used" Error ⚠️ **CRITICAL - ENABLE THIS FIRST**
**Error Message:**
```
Exception: Google sign-in failed: ClientException: {
  "error": {
    "code": 403,
    "message": "People API has not been used in project 1042809810856 before or it is disabled.",
    "status": "PERMISSION_DENIED"
  }
}
```

**Solution - Enable People API:**

**Option 1: Direct Link (Fastest)**
Click this link to enable it directly:
👉 [Enable People API for Your Project](https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=1042809810856)

1. Click the link above (it opens Google Cloud Console for your project)
2. Click the **"ENABLE"** button
3. Wait 2-3 minutes for the API to activate
4. Restart your Flutter app

**Option 2: Manual Steps**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **smart-product-recommender-fyp** (ID: 1042809810856)
3. In the search bar at the top, type: **"People API"**
4. Click on **"Google People API"** from the results
5. Click the **"ENABLE"** button
6. Wait 2-3 minutes, then restart your app

**Note:** After enabling, it may take a few minutes to propagate. If you still get the error, wait 5 minutes and try again.

### Issue 2: "ClientID not set" Error on Web
**Error Message:**
```
Exception: Google sign-in failed: Assertion failed:
appClientId != null
"ClientID not set. Either set it on a <meta name="google-signin-client_id" content="CLIENT_ID" /> tag,
or pass clientId when initializing GoogleSignIn"
```

**Solution:** 
1. Get your **Web Client ID** from Firebase Console:
   - Go to Firebase Console → Project Settings → General
   - Scroll to "Your apps" and click on your Web app
   - Copy the **Web client ID** (format: `1042809810856-xxxxxxxx.apps.googleusercontent.com`)

2. Update [web/index.html](frontend/flutter_application_1/web/index.html):
   - Find the line with `google-signin-client_id`
   - Replace `WEB_CLIENT_ID_HERE` with your actual Web Client ID
   - Save the file

3. Restart your Flutter web app:
   ```powershell
   # Stop the current app (Ctrl+C in terminal)
   cd frontend/flutter_application_1
   flutter run -d chrome
   ```

### Issue 3: "PlatformException: sign_in_failed"
**Solution:** Make sure you've added the SHA-1 certificate to Firebase Console.

### Issue 4: "Google Sign-In not working on Android"
**Solution:** 
- Ensure `google-services.json` is up-to-date
- Check that SHA-1 fingerprint is correct
- Make sure Google Play Services is available on the device

### Issue 5: "Error 10" on Android
**Solution:** 
- Check that the package name in Firebase matches your app's package name
- Verify SHA-1 certificate is added correctly

### Issue 6: User cancelled the sign-in
**Note:** This is normal behavior when users close the Google Sign-In dialog. The app will return to the login screen without error.

---

## 📝 Code Overview

### AuthService - Google Sign-In Method
```dart
Future<User?> signInWithGoogle() async {
  // Triggers Google Sign-In flow
  // Gets authentication tokens
  // Signs in to Firebase with Google credential
  // Saves user token
  // Optionally registers new users in backend
  return user;
}
```

### Login/Sign-Up Screens
```dart
Future<void> _signInWithGoogle() async {
  // Calls AuthService.signInWithGoogle()
  // Shows success/error messages
  // Navigates to home screen
}
```

---

## 🚀 Next Steps

1. ✅ Code implementation - **COMPLETED**
2. ⏳ Enable Google Sign-In in Firebase Console
3. ⏳ Add SHA-1 certificate (Android)
4. ⏳ Download updated `google-services.json`
5. ⏳ Test on device/emulator
6. ⏳ Deploy and enjoy!

---

## 📞 Support

If you encounter any issues:
1. Check the Firebase Console logs
2. Review the device/emulator logs
3. Verify all configuration steps are completed
4. Ensure Google Play Services is available (Android)

---

**Implementation Date:** March 6, 2026
**Status:** ✅ Code Complete - Configuration Required
