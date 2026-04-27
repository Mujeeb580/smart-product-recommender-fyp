# Backend-Frontend Integration Guide

## 🎉 Successfully Integrated!

Your Smart Product Recommender app now has **full backend-frontend integration** with:
- ✅ RESTful API endpoints
- ✅ Firebase Authentication
- ✅ Product Recommendation Engine
- ✅ AI Chat Service
- ✅ CORS-enabled for Flutter

---

## 📁 Project Structure

```
smart-product-recommender-fyp/
├── backend/                    # FastAPI Backend
│   ├── app/
│   │   ├── main.py            # Main API with routes
│   │   ├── api/
│   │   │   ├── auth/          # Authentication routes
│   │   │   ├── product_routes.py  # Product API
│   │   │   └── chat_routes.py     # Chat API
│   │   ├── core/
│   │   │   ├── firebase.py    # Firebase config
│   │   │   └── api_config.dart  # API config (Flutter)
│   │   └── recommendation/
│   │       ├── engine.py      # ML recommendation engine
│   │       └── firestore.py   # Firestore integration
│   └── requirements.txt
│
└── frontend/flutter_application_1/  # Flutter Frontend
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   └── api_config.dart     # API endpoints config
    │   └── services/
    │       ├── api_service.dart     # HTTP client
    │       ├── auth_service.dart    # Firebase auth
    │       ├── product_service.dart # Product API calls
    │       └── chat_service.dart    # Chat API calls
    └── pubspec.yaml
```

---

## 🚀 How to Run

### Backend (FastAPI)

1. **Activate virtual environment:**
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```

2. **Navigate to backend:**
   ```powershell
   cd backend
   ```

3. **Install dependencies (if not already installed):**
   ```powershell
   pip install -r requirements.txt
   ```

4. **Run the server:**
   ```powershell
   python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

5. **Access API documentation:**
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

### Frontend (Flutter)

1. **Navigate to frontend:**
   ```powershell
   cd frontend/flutter_application_1
   ```

2. **Get dependencies:**
   ```powershell
   flutter pub get
   ```

3. **Configure API URL:**
   - Open `lib/core/api_config.dart`
   - Set the correct `baseUrl`:
     - For **Android Emulator**: `http://10.0.2.2:8000`
     - For **iOS Simulator**: `http://localhost:8000`
     - For **Physical Device**: `http://YOUR_COMPUTER_IP:8000`
       (Find your IP with `ipconfig`)

4. **Run the app:**
   ```powershell
   flutter run
   ```

---

## 📡 API Endpoints

### Authentication (`/auth`)
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login (handled by Firebase on frontend)
- `GET /auth/verify-token` - Verify JWT token

### Products (`/products`)
- `GET /products/recommend` - Get recommended products
  - Query params: `?query=laptop&top_n=10`
- `GET /products/search` - Search products
  - Query params: `?q=samsung`
- `GET /products/filter` - Filter products
  - Query params: `?category=Smartphone&min_price=50000&max_price=150000`
- `GET /products/trending` - Get trending products
- `GET /products/{id}` - Get product by ID

### Chat (`/chat`)
- `POST /chat/send` - Send message and get recommendations
  - Body: `{"message": "I need a budget smartphone"}`
- `GET /chat/history` - Get chat history
- `POST /chat/save` - Save chat message

---

## 🔧 Configuration

### API Configuration (Frontend)
Located in: `frontend/flutter_application_1/lib/core/api_config.dart`

```dart
class ApiConfig {
  // Change this based on your setup
  static const String baseUrl = 'http://localhost:8000';
  
  // For Android Emulator:
  // static const String baseUrl = 'http://10.0.2.2:8000';
  
  // For Physical Device (use your machine's IP):
  // static const String baseUrl = 'http://192.168.1.100:8000';
}
```

### CORS (Backend)
Configured in `backend/app/main.py` to allow:
- Localhost connections
- Android emulator (10.0.2.2)
- All origins in development mode

---

## 🔐 Authentication Flow

1. **Sign Up:**
   - User fills registration form
   - `AuthService.signUpWithEmailPassword()` creates Firebase account
   - Backend also registers the user
   - Token is saved locally

2. **Sign In:**
   - User enters credentials
   - Firebase authenticates
   - ID token is retrieved and saved
   - Token is used for API requests

3. **API Requests:**
   - Token is attached to headers: `Authorization: Bearer <token>`
   - Backend verifies token on protected routes

---

## 🎯 Features Implemented

### ✅ Backend Features
- FastAPI REST API with automatic docs
- Firebase Admin SDK for authentication
- Firestore database integration
- ML-based product recommendation engine
- Semantic search using sentence-transformers
- AI chat with intent recognition
- CORS enabled for Flutter
- Error handling and validation

### ✅ Frontend Features
- HTTP client with error handling
- Firebase Authentication service
- Token management (local storage)
- Product service with API integration
- Chat service with AI responses
- Fallback to dummy data if API fails
- Loading states and error messages
- Multi-language support

---

## 🛠️ Troubleshooting

### Backend Issues

**"ModuleNotFoundError: No module named 'sklearn'"**
```powershell
pip install scikit-learn sentence-transformers torch
```

**"firebase-key.json not found"**
- Ensure `backend/firebase-key.json` exists
- Download from Firebase Console if missing

**Port already in use:**
```powershell
# Use a different port
uvicorn app.main:app --port 8001
```

### Frontend Issues

**"Connection refused" or "No internet connection"**
- Check if backend is running
- Verify `baseUrl` in `api_config.dart`
- For physical device, ensure same WiFi network

**"Failed to build for Android"**
```powershell
flutter clean
flutter pub get
flutter run
```

**Missing packages:**
```powershell
flutter pub get
```

---

## 📊 Data Flow

```
User Action (Flutter) 
    ↓
Service Layer (product_service.dart, chat_service.dart)
    ↓
API Service (api_service.dart) - HTTP Request
    ↓
Backend API (FastAPI main.py)
    ↓
Route Handler (product_routes.py, chat_routes.py)
    ↓
Business Logic (recommendation engine)
    ↓
Firestore Database
    ↓
Response (JSON)
    ↓
Service Layer (converts to models)
    ↓
UI Update (Flutter widgets)
```

---

## 🔄 Next Steps

1. **Deploy Backend:**
   - Use services like Railway, Render, or Google Cloud Run
   - Update `baseUrl` in Flutter app

2. **Add More Features:**
   - User profiles
   - Favorites/Wishlist
   - Purchase history
   - Push notifications
   - Social sharing

3. **Optimize:**
   - Add caching (SharedPreferences, Hive)
   - Implement pagination
   - Add offline mode
   - Optimize image loading

4. **Security:**
   - Add rate limiting
   - Implement input validation
   - Use environment variables
   - Set up proper CORS in production

---

## 📝 Testing

### Test Backend Endpoints

Using PowerShell:
```powershell
# Test root endpoint
Invoke-WebRequest -Uri "http://localhost:8000" | Select-Object -ExpandProperty Content

# Test recommendations
Invoke-WebRequest -Uri "http://localhost:8000/products/recommend?query=gaming laptop" | Select-Object -ExpandProperty Content

# Test chat
$body = @{message="I need a budget phone"} | ConvertTo-Json
Invoke-WebRequest -Uri "http://localhost:8000/chat/send" -Method POST -Body $body -ContentType "application/json" | Select-Object -ExpandProperty Content
```

---

## 📚 Dependencies Added

### Backend (Already in requirements.txt)
- fastapi
- uvicorn
- firebase-admin
- scikit-learn
- sentence-transformers
- torch

### Frontend (Added to pubspec.yaml)
- http: ^1.2.0
- firebase_core: ^2.24.2
- firebase_auth: ^4.16.0

---

## 💡 Tips

1. **Always run backend before frontend**
2. **Check API URL matches your setup**
3. **Use dummy fallback during development**
4. **Monitor both terminal outputs**
5. **Check Firebase console for auth issues**

---

## 🎓 Learning Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Firebase Auth Flutter](https://firebase.flutter.dev/docs/auth/overview)
- [Sentence Transformers](https://www.sbert.net/)

---

**Created on:** March 4, 2026  
**Status:** ✅ Fully Integrated and Tested  
**Branches:**
- `backend` - Backend API implementation
- `frontend` - Flutter app with API integration

Happy Coding! 🚀
