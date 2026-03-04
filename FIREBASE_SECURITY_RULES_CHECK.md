# Firebase Security Rules Check

## ⚠️ URGENT: Verify Your Firebase Security Rules

Since your Firebase API keys were exposed in GitHub, it's critical to ensure your Firebase Security Rules are properly configured to prevent unauthorized access.

## 🔍 What to Check

### 1. Firestore Database Rules
**Link:** https://console.firebase.google.com/project/smart-product-recommender-fyp/firestore/rules

#### ❌ BAD (Insecure - Anyone can read/write):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ❌ INSECURE!
    }
  }
}
```

#### ✅ GOOD (Secure - Authentication required):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Products: read by all, write by authenticated users only
    match /products/{productId} {
      allow read: if true;
      allow create, update, delete: if request.auth != null;
    }
    
    // Chat messages: only for authenticated users
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
                           request.auth.uid == resource.data.userId;
    }
    
    // Recommendations: authenticated users only
    match /recommendations/{recId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 2. Realtime Database Rules
**Link:** https://console.firebase.google.com/project/smart-product-recommender-fyp/database/smart-product-recommender-fyp-default-rtdb/rules

#### ❌ BAD:
```json
{
  "rules": {
    ".read": true,
    ".write": true   // ❌ INSECURE!
  }
}
```

#### ✅ GOOD:
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null",
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

### 3. Storage Rules
**Link:** https://console.firebase.google.com/project/smart-product-recommender-fyp/storage/rules

#### ✅ GOOD:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /product-images/{imageId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🚨 IMMEDIATE ACTION REQUIRED

1. **Go to Firebase Console:** https://console.firebase.google.com/project/smart-product-recommender-fyp
2. **Check each section:**
   - ✅ Firestore Rules
   - ✅ Realtime Database Rules  
   - ✅ Storage Rules
   - ✅ Authentication settings

3. **If you see `allow read, write: if true;` → CHANGE IT IMMEDIATELY!**

4. **Test your rules:**
   - Try accessing Firestore without authentication
   - It should be denied (unless specifically allowed for public data)

## 📊 Check Firebase Usage

### Look for Suspicious Activity:
1. **Authentication → Users**
   - Check for unknown email addresses
   - Look for unusual number of users created recently

2. **Firestore → Data**
   - Check for unexpected data modifications
   - Look for spam or malicious content

3. **Usage → Dashboard**
   - Check for unusual spikes in reads/writes
   - Look for unexpected traffic

## 🔄 If You Find Issues

### Signs of Compromise:
- ❌ Unknown users in Authentication
- ❌ Unexpected data in Firestore
- ❌ High usage spikes
- ❌ Insecure rules (allow read, write: if true)

### Recovery Steps:
1. **Immediately update Security Rules** to require authentication
2. **Delete unauthorized users** from Authentication → Users
3. **Remove malicious data** from Firestore
4. **Rotate API keys:**
   - Delete exposed API keys in Google Cloud Console
   - Regenerate new ones
   - Run `flutterfire configure` again

5. **Monitor usage** for next 24-48 hours

## ✅ Verification Checklist

After checking, confirm:
- [ ] Firestore rules require authentication (except public data)
- [ ] Realtime Database rules require authentication
- [ ] Storage rules require authentication
- [ ] No unknown users in Authentication
- [ ] No suspicious data in Firestore
- [ ] Usage dashboard looks normal
- [ ] All insecure rules have been updated

## 📝 Current Configuration Status

**Backend Service Account:**
- ✅ `firebase-key.json` is secure (not in Git, in .gitignore)
- ✅ Backend uses Firebase Admin SDK with full access (secure)

**Frontend Client:**
- ✅ `google-services.json` removed from Git
- ✅ `firebase_options.dart` removed from Git
- ✅ Files added to .gitignore
- ⚠️ **ACTION REQUIRED:** Verify Security Rules (see above)

## 🆘 Need Help?

If you're unsure about your Security Rules or find evidence of compromise:
1. Set all rules to require authentication immediately
2. Contact Firebase support
3. Review Firebase documentation: https://firebase.google.com/docs/rules

---

**Priority:** 🔴 HIGH - Complete this check within 24 hours
