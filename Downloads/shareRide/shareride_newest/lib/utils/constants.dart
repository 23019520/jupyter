import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Application-wide constants for configuration, styling, and behavior
class AppConstants {
  AppConstants._();

  // ===== APP INFO =====
  static const String appName = 'RideShare';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@rideshare.com';
  static const String privacyPolicyUrl = 'https://rideshare.com/privacy';
  static const String termsOfServiceUrl = 'https://rideshare.com/terms';

  // ===== TIMING & ANIMATION =====
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration longAnimationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration locationUpdateInterval = Duration(seconds: 30);
  static const Duration fastLocationUpdateInterval = Duration(seconds: 15);
  static const Duration rideUpdateInterval = Duration(seconds: 10);
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration longTimeout = Duration(seconds: 60);

  // ===== LOCATION SETTINGS =====
  static const int locationDistanceFilter = 10; // meters
  static const double defaultSearchRadius = 10.0; // kilometers
  static const double minSearchRadius = 5.0;
  static const double maxSearchRadius = 25.0;
  static const LatLng defaultLocation = LatLng(-23.8954, 29.4488); // Thohoyandou
  static const double defaultZoom = 15.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  static const double mapPadding = 100.0;
  static const double highAccuracyThreshold = 50.0; // meters
  static const double mediumAccuracyThreshold = 100.0; // meters

  // ===== MAP STYLING =====
  static const int routeWidth = 4;
  static const int selectedRouteWidth = 6;
  static const double markerSize = 24.0;
  static const double selectedMarkerSize = 32.0;

  // ===== UI DIMENSIONS =====
  static const double borderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;
  static const double cardElevation = 4.0;
  static const double dialogElevation = 8.0;

  // Padding and margins
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets smallPadding = EdgeInsets.all(8.0);
  static const EdgeInsets largePadding = EdgeInsets.all(24.0);
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(vertical: 16.0);

  // ===== PRICING CONFIGURATION =====
  static const double basePrice = 50.0;
  static const double privatePriceMultiplier = 2.0;
  static const double sharedDiscountWithUsers = 0.20;
  static const double sharedDiscountWithoutUsers = 0.35;
  static const double poolDiscountMultiplier = 0.7;
  static const double longDistanceThreshold = 10.0; // km
  static const double longDistanceSurcharge = 5.0; // per km above threshold
  static const double peakHourMultiplier = 1.5;
  static const double nightTimeMultiplier = 1.3;

  // ===== RIDE CONFIGURATION =====
  static const int maxPassengers = 4;
  static const int defaultSeats = 1;
  static const double maxWaitTime = 10.0; // minutes
  static const double rideTimeout = 300.0; // seconds (5 minutes)
  static const double driverArrivalThreshold = 100.0; // meters

  // ===== SEARCH & FILTERING =====
  static const int maxSearchResults = 5;
  static const int maxNearbyUsers = 20;
  static const int maxNearbyDrivers = 10;
  static const double searchDebounceDelay = 0.5; // seconds
  static const int maxRetryAttempts = 3;

  // ===== VALIDATION =====
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;
  static const double minRating = 1.0;
  static const double maxRating = 5.0;

  // ===== ICON SIZES =====
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // ===== BUTTON CONFIGURATIONS =====
  static const double buttonHeight = 48.0;
  static const double smallButtonHeight = 36.0;
  static const double largeButtonHeight = 56.0;
  static const double fabSize = 56.0;
  static const double miniFabSize = 40.0;

  // ===== FEATURE FLAGS =====
  static const bool enableBiometricAuth = true;
  static const bool enablePushNotifications = true;
  static const bool enableLocationHistory = true;
  static const bool enableRealTimeTracking = true;
  static const bool enableOfflineMode = false;

  // ===== BOX SHADOWS =====
  static List<BoxShadow> get defaultShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ];

  // ===== TEXT STYLES =====
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  // ===== MAP STYLES =====
  static const String darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#38414e"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      }
    ]
  ''';

  static const String lightMapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
  ''';
}

/// Color constants for consistent theming
class AppColors {
  AppColors._();

  // ===== PRIMARY COLORS =====
  static const Color primary = Color(0xFF3498db);
  static const Color primaryLight = Color(0xFF5dade2);
  static const Color primaryDark = Color(0xFF2980b9);
  static const Color primaryVariant = Color(0xFF1abc9c);

  // ===== SECONDARY COLORS =====
  static const Color secondary = Color(0xFF2ecc71);
  static const Color secondaryLight = Color(0xFF58d68d);
  static const Color secondaryDark = Color(0xFF27ae60);

  // ===== ACCENT COLORS =====
  static const Color accent = Color(0xFFe74c3c);
  static const Color accentLight = Color(0xFFec7063);
  static const Color accentDark = Color(0xFFc0392b);

  // ===== SEMANTIC COLORS =====
  static const Color success = Color(0xFF2ecc71);
  static const Color warning = Color(0xFFf39c12);
  static const Color error = Color(0xFFe74c3c);
  static const Color info = Color(0xFF3498db);

  // ===== NEUTRAL COLORS =====
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF95a5a6);
  static const Color greyLight = Color(0xFFbdc3c7);
  static const Color greyDark = Color(0xFF7f8c8d);
  static const Color greyExtraLight = Color(0xFFecf0f1);

  // ===== TEXT COLORS =====
  static const Color textPrimary = Color(0xFF2c3e50);
  static const Color textSecondary = Color(0xFF7f8c8d);
  static const Color textLight = Color(0xFFbdc3c7);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF2c3e50);

  // ===== BACKGROUND COLORS =====
  static const Color background = Color(0xFFf8f9fa);
  static const Color backgroundDark = Color(0xFF2c3e50);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF34495e);

  // ===== RIDE TYPE COLORS =====
  static const Color privateRide = Color(0xFF9b59b6);
  static const Color sharedRide = Color(0xFF3498db);
  static const Color poolRide = Color(0xFF2ecc71);

  // ===== STATUS COLORS =====
  static const Color available = Color(0xFF2ecc71);
  static const Color busy = Color(0xFFe74c3c);
  static const Color offline = Color(0xFF95a5a6);
  static const Color pending = Color(0xFFf39c12);

  // ===== MAP COLORS =====
  static const Color routeColor = Color(0xFF3498db);
  static const Color alternateRouteColor = Color(0xFF95a5a6);
  static const Color searchRadiusStroke = Color(0xFF3498db);
  static Color get searchRadiusFill => const Color(0xFF3498db).withOpacity(0.1);

  // ===== GRADIENT COLORS =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFe67e22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== OPACITY VARIANTS =====
  static Color get primaryWithOpacity => primary.withOpacity(0.1);
  static Color get successWithOpacity => success.withOpacity(0.1);
  static Color get errorWithOpacity => error.withOpacity(0.1);
  static Color get warningWithOpacity => warning.withOpacity(0.1);

  // ===== HELPER METHODS =====
  static Color getRideTypeColor(String rideType) {
    switch (rideType.toLowerCase()) {
      case 'private':
        return privateRide;
      case 'shared':
        return sharedRide;
      case 'pool':
        return poolRide;
      default:
        return primary;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'online':
        return available;
      case 'busy':
      case 'in_ride':
        return busy;
      case 'offline':
        return offline;
      case 'pending':
        return pending;
      default:
        return grey;
    }
  }
}

/// Marker and UI element identifiers
class MarkerIds {
  MarkerIds._();

  static const String currentLocation = 'current_location';
  static const String destination = 'destination';
  static const String userPrefix = 'user_';
  static const String driverPrefix = 'driver_';
  static const String pickupLocation = 'pickup_location';
  static const String waypoint = 'waypoint_';
}

/// Circle identifiers for map circles
class CircleIds {
  CircleIds._();

  static const String searchRadius = 'search_radius';
  static const String driverRadius = 'driver_radius_';
  static const String geofence = 'geofence_';
}

/// Polyline identifiers for routes
class PolylineIds {
  PolylineIds._();

  static const String mainRoute = 'main_route';
  static const String alternateRoute = 'alternate_route_';
  static const String driverRoute = 'driver_route';
}

/// User role definitions
class UserRole {
  UserRole._();

  static const String passenger = 'passenger';
  static const String driver = 'driver';
  static const String both = 'both';
  static const String admin = 'admin';
}

/// Ride status definitions
class RideStatus {
  RideStatus._();

  static const String requested = 'requested';
  static const String accepted = 'accepted';
  static const String driverEnRoute = 'driver_en_route';
  static const String arrived = 'arrived';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

/// Payment status definitions
class PaymentStatus {
  PaymentStatus._();

  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String completed = 'completed';
  static const String failed = 'failed';
  static const String refunded = 'refunded';
}

/// Notification types
class NotificationType {
  NotificationType._();

  static const String rideRequest = 'ride_request';
  static const String rideAccepted = 'ride_accepted';
  static const String driverArrived = 'driver_arrived';
  static const String rideStarted = 'ride_started';
  static const String rideCompleted = 'ride_completed';
  static const String rideCancelled = 'ride_cancelled';
  static const String paymentProcessed = 'payment_processed';
  static const String promotion = 'promotion';
  static const String systemUpdate = 'system_update';
}

/// App-wide key constants
class AppKeys {
  AppKeys._();

  // SharedPreferences keys
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';
  static const String lastKnownLocation = 'last_known_location';
  static const String searchRadius = 'search_radius';
  static const String notificationEnabled = 'notification_enabled';
  static const String darkMode = 'dark_mode';
  static const String biometricEnabled = 'biometric_enabled';

  // Secure storage keys
  static const String refreshToken = 'refresh_token';
  static const String biometricKey = 'biometric_key';
  static const String paymentToken = 'payment_token';

  // API endpoints (relative paths)
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String refreshEndpoint = '/auth/refresh';
  static const String ridesEndpoint = '/rides';
  static const String usersEndpoint = '/users';
  static const String driversEndpoint = '/drivers';
  static const String locationsEndpoint = '/locations';
  static const String paymentsEndpoint = '/payments';
}

/// Regular expressions for validation
class AppRegex {
  AppRegex._();

  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp phone = RegExp(
    r'^[\+]?[1-9][\d]{0,15}$',
  );

  static final RegExp name = RegExp(
    r'^[a-zA-Z\s]{2,50}$',
  );

  static final RegExp licensePlate = RegExp(
    r'^[A-Z0-9\-\s]{2,10}$',
  );

  static final RegExp numericOnly = RegExp(
    r'^[0-9]+$',
  );

  static final RegExp alphaNumeric = RegExp(
    r'^[a-zA-Z0-9]+$',
  );
}

/// Validation utility methods
class AppValidator {
  AppValidator._();

  /// Validates email format
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return AppRegex.email.hasMatch(email);
  }

  /// Validates phone number
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    return AppRegex.phone.hasMatch(phone);
  }

  /// Validates name
  static bool isValidName(String? name) {
    if (name == null || name.isEmpty) return false;
    return AppRegex.name.hasMatch(name);
  }

  /// Validates license plate
  static bool isValidLicensePlate(String? licensePlate) {
    if (licensePlate == null || licensePlate.isEmpty) return false;
    return AppRegex.licensePlate.hasMatch(licensePlate);
  }

  /// Validates numeric only string
  static bool isNumericOnly(String? text) {
    if (text == null || text.isEmpty) return false;
    return AppRegex.numericOnly.hasMatch(text);
  }

  /// Validates alphanumeric string
  static bool isAlphaNumeric(String? text) {
    if (text == null || text.isEmpty) return false;
    return AppRegex.alphaNumeric.hasMatch(text);
  }

  /// Get email validation error message
  static String? getEmailError(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    if (!isValidEmail(email)) return 'Please enter a valid email address';
    return null;
  }

  /// Get phone validation error message
  static String? getPhoneError(String? phone) {
    if (phone == null || phone.isEmpty) return 'Phone number is required';
    if (phone.length < AppConstants.minPhoneLength) return 'Phone number too short';
    if (phone.length > AppConstants.maxPhoneLength) return 'Phone number too long';
    if (!isValidPhone(phone)) return 'Please enter a valid phone number';
    return null;
  }

  /// Get name validation error message
  static String? getNameError(String? name) {
    if (name == null || name.isEmpty) return 'Name is required';
    if (name.length < AppConstants.minNameLength) return 'Name too short';
    if (name.length > AppConstants.maxNameLength) return 'Name too long';
    if (!isValidName(name)) return 'Please enter a valid name';
    return null;
  }

  /// Validate rating
  static bool isValidRating(double? rating) {
    if (rating == null) return false;
    return rating >= AppConstants.minRating && rating <= AppConstants.maxRating;
  }
}
