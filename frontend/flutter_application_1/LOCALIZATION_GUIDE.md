# Multi-Language Support Guide

## Overview
Your app now supports 6 languages with full translation capabilities:
- English (US)
- English (UK)
- Urdu
- Arabic (with RTL support)
- French
- German

## How It Works

### 1. Translation Files
All translations are stored in `assets/translations/` directory:
- `en-US.json` - English (United States)
- `en-GB.json` - English (United Kingdom)
- `ur.json` - Urdu
- `ar.json` - Arabic
- `fr.json` - French
- `de.json` - German

### 2. Using Translations in Code

To use a translated string in your Dart code:

```dart
import 'package:easy_localization/easy_localization.dart';

// Basic usage
Text('home'.tr())

// With parameters
Text('welcome_message'.tr(args: ['John']))

// Pluralization
Text('items_count'.plural(5))
```

### 3. Adding New Translations

To add a new translatable string:

1. **Add to ALL translation files**:
   ```json
   {
     "new_key": "Translation text",
     ...
   }
   ```

2. **Use in your code**:
   ```dart
   Text('new_key'.tr())
   ```

### 4. Changing Language

Users can change the language from Settings → Language. The change is immediate and persists across app restarts.

Programmatically:
```dart
import 'package:easy_localization/easy_localization.dart';

// Change to French
await context.setLocale(Locale('fr'));

// Change to English (US)
await context.setLocale(Locale('en', 'US'));

// Get current locale
Locale currentLocale = context.locale;
```

## Examples of Translated Screens

### Currently Translated:
- ✅ Settings Screen
- ✅ Language Settings Screen
- ✅ Home Screen (partial)
  - Categories section
  - Quick filters
  - Search bar
  - Category cards

### To Translate:
To translate more screens, follow this pattern:

1. **Import easy_localization**:
   ```dart
   import 'package:easy_localization/easy_localization.dart';
   ```

2. **Replace hardcoded strings**:
   ```dart
   // Before
   Text('Hello')
   
   // After
   Text('hello'.tr())
   ```

3. **Add translation to all JSON files**:
   ```json
   {
     "hello": "Hello"  // en-US.json
     "hello": "مرحبا"  // ar.json
     "hello": "Bonjour"  // fr.json
   }
   ```

## Available Translation Keys

Here are the currently available translation keys:

### App General
- `app_name` - Application name
- `home` - Home
- `chat` - Chat
- `profile` - Profile
- `settings` - Settings

### Categories
- `categories` - Categories
- `mobiles` - Mobiles
- `laptops` - Laptops
- `models` - Models

### Filters & Search
- `quick_filters` - Quick Filters
- `budget` - Budget
- `brand` - Brand
- `rating` - Rating 4+
- `trending_deals` - Trending deals
- `search_electronics` - Search electronics...

### Authentication
- `login` - Login
- `sign_up` - Sign Up
- `email` - Email
- `password` - Password
- `confirm_password` - Confirm Password
- `forgot_password` - Forgot Password?
- `create_account` - Create account
- `already_have_account` - Already have an account?
- `dont_have_account` - Don't have an account?

### Settings Categories
- `preferences` - Preferences
- `security` - Security
- `general` - General
- `notifications` - Notifications
- `dark_mode` - Dark Mode
- `enabled` - Enabled
- `disabled` - Disabled
- `language` - Language
- `storage` - Storage
- `biometrics` - Biometrics

### Settings Items
- `enable_product_recommendations` - Enable product recommendations
- `change_password` - Change Password
- `update_password` - Update your password
- `enable_face_id_fingerprint` - Enable Face ID / Fingerprint
- `manage_cached_data` - Manage cached data
- `help_support` - Help & Support
- `contact_support_team` - Contact our support team
- `about` - About
- `app_info_version` - App info and version
- `privacy_policy` - Privacy Policy
- `terms_conditions` - Terms & Conditions
- `logout` - Logout
- `sign_out_account` - Sign out of your account
- `edit_profile` - Edit Profile

### Descriptions
- `latest_smartphones` - Latest smartphones with cutting-edge technology
- `high_performance_laptops` - High-performance laptops for every need
- `language_set_to` - Language set to

## Testing Different Languages

1. Run the app
2. Navigate to Settings
3. Tap on "Language"
4. Select any language from the list
5. The entire app will switch to that language immediately

## RTL (Right-to-Left) Support

Arabic language automatically enables RTL layout. The `easy_localization` package handles this automatically.

## Best Practices

1. **Always use translation keys**: Never hardcode user-facing text
2. **Keep keys consistent**: Use lowercase with underscores (e.g., `user_profile`)
3. **Add to all languages**: When adding a new key, update ALL translation files
4. **Test all languages**: Ensure translations fit in the UI for all languages
5. **Use descriptive keys**: `login_button` is better than `btn1`

## Troubleshooting

### Translation not showing?
- Check if the key exists in the current language's JSON file
- Verify you imported `easy_localization` package
- Ensure you're using `.tr()` extension

### Language not changing?
- Check if the locale is in `supportedLocales` in main.dart
- Verify the translation file exists for that locale
- Restart the app if needed

### Missing translations?
If a key is missing in a translation file, it will fallback to English (US) automatically.

## Technical Details

### Package Used
- **easy_localization**: ^3.0.7

### Configuration
- **Path**: `assets/translations/`
- **Fallback Locale**: English (US)
- **Supported Locales**: 6 languages

### Files Modified
- `main.dart` - Added EasyLocalization wrapper
- `pubspec.yaml` - Added package and assets
- `language_settings_screen.dart` - Implements language switching
- `settings_screen.dart` - Uses translations
- `home_screen.dart` - Uses translations
