# Enable Firebase Authentication - Step by Step Guide

## 🔥 Firebase Console is Now Open

You should see the Firebase Authentication page for your project: **Smart Product Recommender FYP**

---

## 📋 Step-by-Step Instructions

### Step 1: Get Started (If First Time)
If you see a **"Get started"** button:
1. Click the **"Get started"** button
2. This will initialize Firebase Authentication for your project

### Step 2: Go to Sign-in Method Tab
1. Look for tabs at the top (Users, Sign-in method, Templates, Usage, Settings)
2. Click on **"Sign-in method"** tab
3. You'll see a list of authentication providers

### Step 3: Enable Email/Password
1. Find **"Email/Password"** in the list (usually first one)
2. Click on the **"Email/Password"** row
3. A dialog will open

### Step 4: Toggle Enable Switch
1. In the dialog, you'll see two toggles:
   - **Email/Password** ← Toggle this ON
   - Email link (passwordless sign-in) ← Leave this OFF for now
2. Click the blue **"Save"** button

### Step 5: Verify It's Enabled
You should now see:
- ✅ **Email/Password** status is **"Enabled"**
- It appears in the "Sign-in providers" section

---

## 🧪 Test Firebase Authentication

After enabling, you can test it by creating a test user:

### Create a Test User (Optional)
1. Click on the **"Users"** tab
2. Click **"Add user"** button
3. Enter:
   - Email: `test@example.com`
   - Password: `Test123456!`
4. Click **"Add user"**

---

## 🎯 Alternative: Using Firebase CLI

If the console isn't working, you can enable authentication via CLI:

```powershell
# In your terminal
firebase auth:enable EMAIL_PASSWORD --project smart-product-recommender-fyp
```

---

## 🚨 If You Don't See the Authentication Tab

### Check Project Permissions
1. Make sure you're logged into the correct Google account
2. Verify you have owner/editor access to the project
3. Try refreshing the page (Ctrl + F5)

### Check Project URL
The URL should be:
```
https://console.firebase.google.com/project/smart-product-recommender-fyp/authentication
```

### Still Not Working?
If you see "No authentication providers configured":
1. Click any provider (like Email/Password)
2. This will automatically initialize authentication
3. Then follow the steps above

---

## ✅ Verification Checklist

After enabling, verify:
- [ ] Email/Password shows as "Enabled" in Firebase Console
- [ ] You can see the "Users" tab
- [ ] Your Flutter app can attempt sign up (may show errors, but connection works)

---

## 🔍 Quick Test in Your App

Once enabled, test sign up in your Flutter app:

1. Open your app (running in Chrome)
2. Go to the Sign Up screen
3. Enter:
   - Email: `test@test.com`
   - Password: `Test1234!`
4. Click Sign Up

You should either:
- ✅ See success (user created)
- ⚠️ See "email already exists" (if you test again)

If you see network errors, check:
- Firebase Authentication is enabled
- Internet connection is working
- No firewall blocking Firebase

---

## 📞 Need Help?

**Common Issues:**

1. **"No authentication providers configured"**
   - Solution: Click Email/Password and enable it

2. **"Access denied" or permission errors**
   - Solution: Check if you're the project owner in Firebase Console

3. **"Network request failed"**
   - Solution: Check internet connection, try refreshing

4. **Button doesn't respond**
   - Solution: Try a different browser or clear cache

---

**Last Updated**: March 4, 2026
**Status**: Waiting for Email/Password to be enabled in Firebase Console
