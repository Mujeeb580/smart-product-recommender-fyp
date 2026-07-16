// App Constants
const String appName = 'FYNDO';
const String appVersion = '1.0.0';

// API Constants (will be used when backend is ready)
const String apiBaseUrl =
    'http://localhost:8000'; // Change this when backend is deployed
const String chatEndpoint = '/api/chat';
const String productsEndpoint = '/api/products';
const String productDetailEndpoint = '/api/products/{id}';

// Timeouts
const Duration connectTimeout = Duration(seconds: 30);
const Duration receiveTimeout = Duration(seconds: 30);

// Local Storage Keys
const String userPreferencesKey = 'user_preferences';
const String chatHistoryKey = 'chat_history';
const String favoritesKey = 'favorites';

// UI Constants
const int productPageSize = 10;
const int chatPageSize = 20;

// Animation Durations
const Duration shortAnimation = Duration(milliseconds: 300);
const Duration mediumAnimation = Duration(milliseconds: 500);
const Duration longAnimation = Duration(milliseconds: 800);

// Price Constants (Pakistani Rupees)
const double minPhonePrice = 20000;
const double maxPhonePrice = 500000;

// App Messages
const String loadingMessage = 'Loading...';
const String errorMessage = 'Something went wrong. Please try again.';
const String noDataMessage = 'No data available';
const String noInternetMessage = 'No internet connection';
