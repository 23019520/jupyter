// lib/utils/comprehensive_helpers.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;


// Panel States
  enum PanelState { collapsed, search, rideOptions, confirmation }
  
// ===== PHONE NUMBER MANAGEMENT =====
final Map<String, String> _userPhoneNumbers = {};

/// Get phone number for a user by UID
String? getPhoneNumber(String uid) => _userPhoneNumbers[uid];

/// Get formatted phone number for a user by UID
String? getFormattedPhone(String uid) {
  final phoneNumber = getPhoneNumber(uid);
  return phoneNumber != null ? StringHelper.formatPhoneNumber(phoneNumber) : null;
}

/// Add or update a user's phone number
void setUserPhoneNumber(String uid, String phoneNumber) {
  _userPhoneNumbers[uid] = phoneNumber;
}

/// Remove a user's phone number
void removeUserPhoneNumber(String uid) {
  _userPhoneNumbers.remove(uid);
}

// ===== DISTANCE AND GEOGRAPHICAL OPERATIONS =====
class DistanceHelper {
  DistanceHelper._();

  /// Calculate distance between two points in kilometers
  static double calculateDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Calculate distance between two points in meters
  static double calculateDistanceMeters(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate and format distance from current position to target
  static String calculateDisplayDistance(Position? currentPosition, double? targetLat, double? targetLng) {
    if (currentPosition == null || targetLat == null || targetLng == null) return 'Unknown';
    
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude, currentPosition.longitude, targetLat, targetLng
    );
    return formatDistance(distance);
  }

  /// Format distance in meters to human-readable string
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 100) {
      return '${(distanceInMeters / 10).round() * 10}m';
    } else if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else if (distanceInMeters < 10000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    } else {
      return '${(distanceInMeters / 1000).round()}km';
    }
  }

  

  /// Calculate bearing between two points in degrees
  static double calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    final dLng = (endLng - startLng) * (math.pi / 180);
    final startLatRad = startLat * (math.pi / 180);
    final endLatRad = endLat * (math.pi / 180);

    final y = math.sin(dLng) * math.cos(endLatRad);
    final x = math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(dLng);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  /// Check if point is within radius of center point
  static bool isWithinRadius(double centerLat, double centerLng, double pointLat, double pointLng, double radiusInKm) {
    final distance = calculateDistanceMeters(centerLat, centerLng, pointLat, pointLng);
    return distance <= radiusInKm * 1000;
  }

  /// Get compass direction from bearing
  static String getBearingDirection(double bearing) {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final index = ((bearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Calculate distance using Haversine formula (alternative to Geolocator)
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = MathHelper.degreesToRadians(lat2 - lat1);
    final dLon = MathHelper.degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(MathHelper.degreesToRadians(lat1)) * math.cos(MathHelper.degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}

// ===== TIME OPERATIONS =====
class TimeHelper {
  TimeHelper._();

  /// Calculate estimated arrival time in minutes based on distance
  static double calculateEstimatedArrivalMinutes(double distanceKm) {
    double avgSpeedKmh;
    if (distanceKm <= 2) {
      avgSpeedKmh = 25; // City traffic
    } else if (distanceKm <= 10) {
      avgSpeedKmh = 35; // Mixed traffic
    } else {
      avgSpeedKmh = 50; // Highway speeds
    }
    return (distanceKm / avgSpeedKmh) * 60;
  }

  /// Format last active time to human-readable string
  static String formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inSeconds < 30) return 'Just now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('MMM dd').format(lastActive);
  }

  /// Format duration to human-readable string
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  /// Get estimated arrival time as formatted string
  static String getEstimatedArrival(double durationInMinutes) {
    if (durationInMinutes < 1) return 'Now';
    
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: durationInMinutes.round()));
    
    if (durationInMinutes < 60) {
      return '${durationInMinutes.round()} min';
    } else {
      return DateFormat('HH:mm').format(arrival);
    }
  }

  /// Format DateTime to readable string
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Get time of day as 12-hour formatted string
  static String getTimeOfDay(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Check if current time is peak hour
  static bool isPeakHour([DateTime? dateTime]) {
    final time = dateTime ?? DateTime.now();
    final hour = time.hour;
    final isWeekday = time.weekday <= 5;
    
    if (!isWeekday) return false;
    return (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);
  }

  /// Check if current time is night time
  static bool isNightTime([DateTime? dateTime]) {
    final hour = (dateTime ?? DateTime.now()).hour;
    return hour >= 22 || hour <= 6;
  }

  /// Get time period description
  static String getTimePeriod([DateTime? dateTime]) {
    final hour = (dateTime ?? DateTime.now()).hour;
    
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 22) return 'Evening';
    return 'Night';
  }
}

// ===== COMPREHENSIVE PRICING CALCULATOR =====
class PricingCalculator {
  PricingCalculator._();

  // Base pricing constants
  static const double basePrice = 50.0;
  static const double basePricePerKm = 8.0;
  static const double privatePriceMultiplier = 2.0;
  static const double sharedDiscountWithUsers = 0.20;
  static const double sharedDiscountWithoutUsers = 0.35;
  static const double poolDiscountMultiplier = 0.7;
  static const double driverRevenueShare = 0.50;
  static const double driverRevenueShareLate = 0.40;
  static const double reasonableArrivalTimeMinutes = 15.0;
  static const double longDistanceThreshold = 10.0;
  static const double longDistanceSurcharge = 5.0;
  static const double peakHourMultiplier = 1.5;
  static const double nightTimeMultiplier = 1.3;
  static const double weekendMultiplier = 1.2;

  /// Calculate comprehensive pricing with all factors
  static Map<String, dynamic> calculateComprehensivePricing({
    required double distanceKm,
    required int nearbyUsers,
    required int nearbyDrivers,
    required String rideType,
    int requiredSeats = 1,
    DateTime? requestTime,
    bool applyDemandPricing = true,
  }) {
    final requestDateTime = requestTime ?? DateTime.now();
    
    // Base calculations
    final distancePrice = distanceKm * basePricePerKm;
    final totalBasePrice = basePrice + distancePrice;
    
    // Apply ride type pricing
    double passengerPrice = totalBasePrice;
    double discountApplied = 0.0;
    
    switch (rideType.toLowerCase()) {
      case 'private':
        passengerPrice = totalBasePrice * privatePriceMultiplier;
        break;
      case 'shared':
        final discount = nearbyUsers > 0 ? sharedDiscountWithUsers : sharedDiscountWithoutUsers;
        if (requiredSeats > 1) {
          final seatDiscount = nearbyUsers > 0 ? sharedDiscountWithUsers * 0.7 : sharedDiscountWithoutUsers * 0.7;
          discountApplied = seatDiscount;
        } else {
          discountApplied = discount;
        }
        passengerPrice = totalBasePrice * (1 - discountApplied);
        break;
      case 'pool':
        passengerPrice = totalBasePrice * poolDiscountMultiplier;
        discountApplied = 1 - poolDiscountMultiplier;
        break;
    }
    
    // Distance surcharge for long trips
    double distanceSurcharge = 0.0;
    if (distanceKm > longDistanceThreshold) {
      distanceSurcharge = (distanceKm - longDistanceThreshold) * longDistanceSurcharge;
      passengerPrice += distanceSurcharge;
    }
    
    // Time-based adjustments
    double timeMultiplier = 1.0;
    if (TimeHelper.isPeakHour(requestDateTime)) {
      timeMultiplier *= peakHourMultiplier;
    } else if (TimeHelper.isNightTime(requestDateTime)) {
      timeMultiplier *= nightTimeMultiplier;
    }
    
    // Weekend multiplier
    if (requestDateTime.weekday > 5) {
      timeMultiplier *= weekendMultiplier;
    }
    
    passengerPrice *= timeMultiplier;
    
    // Seat-based adjustments for shared/pool rides
    if (rideType.toLowerCase() != 'private' && requiredSeats > 1) {
      passengerPrice *= (1 + (requiredSeats - 1) * 0.3);
    }
    
    // Supply and demand adjustments
    double demandMultiplier = 1.0;
    if (applyDemandPricing) {
      demandMultiplier = _calculateDemandMultiplier(nearbyUsers, nearbyDrivers);
      passengerPrice *= demandMultiplier;
    }
    
    // Driver earnings calculation
    final estimatedArrivalMinutes = TimeHelper.calculateEstimatedArrivalMinutes(distanceKm);
    final isOnTime = estimatedArrivalMinutes <= reasonableArrivalTimeMinutes;
    final driverShare = isOnTime ? driverRevenueShare : driverRevenueShareLate;
    final driverEarnings = passengerPrice * driverShare;
    
    return {
      'rideType': rideType,
      'passengerPrice': passengerPrice,
      'driverEarnings': driverEarnings,
      'distance': distanceKm,
      'estimatedDuration': estimatedArrivalMinutes,
      'demandMultiplier': demandMultiplier,
      'timeMultiplier': timeMultiplier,
      'driverShare': (driverShare * 100).round(),
      'urgencyLevel': calculateUrgencyLevel(rideType, requiredSeats),
      'breakdown': {
        'basePrice': basePrice,
        'distancePrice': distancePrice,
        'discountApplied': discountApplied,
        'distanceSurcharge': distanceSurcharge,
        'timeAdjustment': passengerPrice * (timeMultiplier - 1) / timeMultiplier,
        'demandAdjustment': passengerPrice * (demandMultiplier - 1) / demandMultiplier,
        'seatAdjustment': requiredSeats > 1 ? passengerPrice * ((requiredSeats - 1) * 0.3) : 0.0,
      },
      'pricingFactors': {
        'isPeakHour': TimeHelper.isPeakHour(requestDateTime),
        'isNightTime': TimeHelper.isNightTime(requestDateTime),
        'isWeekend': requestDateTime.weekday > 5,
        'hasHighDemand': demandMultiplier > 1.2,
        'isLongDistance': distanceKm > longDistanceThreshold,
      },
    };
  }

  /// Calculate pricing for all ride types
  static Map<String, double> calculateAllRideTypes({
    required double distanceKm,
    required int nearbyUsers,
    required int nearbyDrivers,
    DateTime? requestTime,
  }) {
    final results = <String, double>{};
    
    for (final rideType in ['private', 'shared', 'pool']) {
      final pricing = calculateComprehensivePricing(
        distanceKm: distanceKm,
        nearbyUsers: nearbyUsers,
        nearbyDrivers: nearbyDrivers,
        rideType: rideType,
        requestTime: requestTime,
      );
      results[rideType] = pricing['passengerPrice'];
    }
    
    return results;
  }

  /// Calculate urgency level based on ride parameters
  static String calculateUrgencyLevel(String rideType, int requiredSeats) {
    if (rideType.toLowerCase() == 'private') return 'high';
    if (rideType.toLowerCase() == 'shared' && requiredSeats > 2) return 'medium';
    if (rideType.toLowerCase() == 'shared') return 'low';
    return 'medium';
  }

  /// Calculate demand-based multiplier
  static double _calculateDemandMultiplier(int nearbyUsers, int nearbyDrivers) {
    if (nearbyDrivers == 0) return 2.0;
    
    final demandSupplyRatio = nearbyUsers / nearbyDrivers;
    
    if (demandSupplyRatio >= 4.0) return 1.8;
    if (demandSupplyRatio >= 3.0) return 1.6;
    if (demandSupplyRatio >= 2.0) return 1.4;
    if (demandSupplyRatio >= 1.5) return 1.2;
    if (demandSupplyRatio >= 1.0) return 1.1;
    if (demandSupplyRatio >= 0.5) return 1.0;
    
    return 0.9;
  }

  /// Get pricing tier based on distance and time
  static String getPricingTier(double distanceKm, DateTime tripTime) {
    if (distanceKm > 20) return 'long_distance';
    if (TimeHelper.isPeakHour(tripTime)) return 'peak_time';
    if (TimeHelper.isNightTime(tripTime)) return 'night_time';
    if (tripTime.weekday > 5) return 'weekend';
    return 'standard';
  }

  /// Estimate cost with simple calculation for quick estimates
  static double estimateQuickCost(double distanceInMeters, {double ratePerKm = 15.0}) {
    final distanceInKm = distanceInMeters / 1000;
    const baseCost = 10.0;
    return baseCost + (distanceInKm * ratePerKm);
  }
}

// ===== ENHANCED POLYLINE HELPER =====
class PolylineHelper {
  PolylineHelper._();

  /// Decode Google polyline string to LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Encode a list of LatLng points into a Google Maps polyline string
  static String encodePolyline(List<LatLng> points) {
    final encoded = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1E5).round();
      final lng = (point.longitude * 1E5).round();

      final dLat = lat - prevLat;
      final dLng = lng - prevLng;

      encoded.write(_encodeSignedNumber(dLat));
      encoded.write(_encodeSignedNumber(dLng));

      prevLat = lat;
      prevLng = lng;
    }

    return encoded.toString();
  }

  /// Helper method to encode a signed number for polyline encoding
  static String _encodeSignedNumber(int num) {
    int sgnNum = num << 1;
    if (num < 0) {
      sgnNum = ~sgnNum;
    }
    return _encodeNumber(sgnNum);
  }

  /// Helper method to encode a number for polyline encoding
  static String _encodeNumber(int num) {
    final encoded = StringBuffer();
    while (num >= 0x20) {
      encoded.writeCharCode((0x20 | (num & 0x1f)) + 63);
      num >>= 5;
    }
    encoded.writeCharCode(num + 63);
    return encoded.toString();
  }

  /// Calculate polyline bounds
  static LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      throw ArgumentError('Points list cannot be empty');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    const padding = 0.001;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  /// Simplify polyline by removing points that are too close
  static List<LatLng> simplifyPolyline(List<LatLng> points, {double tolerance = 0.0001}) {
    if (points.length <= 2) return points;
    
    final simplified = <LatLng>[points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final last = simplified.last;
      
      final distance = DistanceHelper.calculateDistanceMeters(
        last.latitude, last.longitude,
        current.latitude, current.longitude,
      );
      
      if (distance > tolerance * 111000) {
        simplified.add(current);
      }
    }
    
    simplified.add(points.last);
    return simplified;
  }

  /// Gets the center point of a polyline
  static LatLng getPolylineCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points.first;

    double totalLat = 0;
    double totalLng = 0;

    for (final point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return LatLng(totalLat / points.length, totalLng / points.length);
  }

  /// Gets the bounding box for a list of points
  static LatLngBounds getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Validates if a polyline string is properly encoded
  static bool isValidPolyline(String encoded) {
    if (encoded.isEmpty) return false;
    
    try {
      final decoded = decodePolyline(encoded);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

// ===== MAP UTILITIES AND CAMERA OPERATIONS =====
class MapHelper {
  MapHelper._();

  /// Get marker color hue based on status
  static double getMarkerHue(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'online':
      case 'current':
        return BitmapDescriptor.hueGreen;
      case 'busy':
      case 'occupied':
        return BitmapDescriptor.hueRed;
      case 'driver':
      case 'pickup':
        return BitmapDescriptor.hueBlue;
      case 'destination':
        return BitmapDescriptor.hueRed;
      case 'warning':
        return BitmapDescriptor.hueOrange;
      case 'offline':
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueBlue;
    }
  }

  /// Calculate appropriate zoom level based on distance
  static double calculateZoomLevel(double distanceInKm) {
    if (distanceInKm <= 0.5) return 17.0;
    if (distanceInKm <= 1) return 16.0;
    if (distanceInKm <= 2) return 15.0;
    if (distanceInKm <= 5) return 14.0;
    if (distanceInKm <= 10) return 13.0;
    if (distanceInKm <= 20) return 12.0;
    if (distanceInKm <= 50) return 11.0;
    if (distanceInKm <= 100) return 10.0;
    return 9.0;
  }

  /// Get camera position to fit all markers with proper padding
  static CameraPosition getCameraPositionToFitMarkers(
    List<LatLng> positions, {
    double padding = 100.0,
    double? maxZoom,
  }) {
    if (positions.isEmpty) {
      throw ArgumentError('Positions list cannot be empty');
    }

    if (positions.length == 1) {
      return CameraPosition(
        target: positions.first,
        zoom: maxZoom ?? 16.0,
      );
    }

    final bounds = PolylineHelper.calculateBounds(positions);
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );

    final distance = DistanceHelper.calculateDistanceKm(
      bounds.southwest.latitude,
      bounds.southwest.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );

    final zoom = math.min(
      calculateZoomLevel(distance),
      maxZoom ?? 18.0,
    );

    return CameraPosition(
      target: center,
      zoom: zoom,
    );
  }

  /// Create custom marker icon based on vehicle type and status
  static Future<BitmapDescriptor> createCustomMarker({
    required String status,
    String? vehicleType,
    Color? customColor,
  }) async {
    return BitmapDescriptor.defaultMarkerWithHue(
      customColor != null 
          ? _colorToHue(customColor)
          : getMarkerHue(status)
    );
  }

  /// Convert color to hue value
  static double _colorToHue(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }
}

// ===== COMPREHENSIVE VALIDATION =====
class ValidationHelper {
  ValidationHelper._();

  /// Validate coordinates
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Validate distance
  static bool isValidDistance(double? distance) {
    if (distance == null) return false;
    return distance >= 0 && distance <= 1000;
  }

  /// Validate price
  static bool isValidPrice(double? price) {
    if (price == null) return false;
    return price >= 0 && price <= 50000;
  }

  /// Validate email address
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone number (international format)
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(cleaned);
  }

  /// Validate South African phone number
  static bool isValidSAPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return RegExp(r'^\+27[0-9]{9}$|^0[0-9]{9}$').hasMatch(cleaned);
  }

  /// Validate name
  static bool isValidName(String? name) {
    if (name == null || name.isEmpty) return false;
    final trimmed = name.trim();
    return trimmed.length >= 2 && trimmed.length <= 50 && 
           RegExp(r"^[a-zA-Z\s\-'\.]+$").hasMatch(trimmed);
  }

  /// Validate ride type
  static bool isValidRideType(String? rideType) {
    if (rideType == null) return false;
    return ['private', 'shared', 'pool'].contains(rideType.toLowerCase());
  }

  /// Get validation error message for email
  static String? getEmailError(String? email) {
    if (email == null || email.isEmpty) return 'Email is required';
    if (!isValidEmail(email)) return 'Please enter a valid email address';
    return null;
  }

  /// Get validation error message for phone
  static String? getPhoneError(String? phone) {
    if (phone == null || phone.isEmpty) return 'Phone number is required';
    if (!isValidPhone(phone)) return 'Please enter a valid phone number';
    return null;
  }

  /// Get validation error message for name
  static String? getNameError(String? name) {
    if (name == null || name.isEmpty) return 'Name is required';
    if (!isValidName(name)) return 'Please enter a valid name (2-50 characters)';
    return null;
  }
}

// ===== STRING FORMATTING AND MANIPULATION =====
class StringHelper {
  StringHelper._();

  /// Capitalize first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => 
        word.isEmpty ? word : word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
  }

  /// Capitalize first letter only
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Generate initials from name
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, math.min(2, words[0].length)).toUpperCase();
    }
    
    return words.take(2)
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join('');
  }

  /// Clean phone number to digits and + only
  static String cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    final cleaned = cleanPhoneNumber(phoneNumber);
    
    if (cleaned.startsWith('+27') && cleaned.length == 12) {
      return '+27 ${cleaned.substring(3, 5)} ${cleaned.substring(5, 8)} ${cleaned.substring(8)}';
    }
    
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }
    
    return phoneNumber;
  }

  /// Create URL-friendly slug from text
  static String createSlug(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-'), '');
  }
}

// ===== FORMATTING HELPER FOR DISPLAY VALUES =====
class FormatHelper {
  FormatHelper._();

  /// Format currency amount
  static String formatCurrency(double amount, {String currency = 'R'}) {
    if (amount >= 1000000) {
      return '$currency${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$currency${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '$currency${amount.toStringAsFixed(0)}';
  }

  /// Format rating with star
  static String formatRating(double rating) {
    return '${rating.toStringAsFixed(1)}⭐';
  }

  /// Format percentage
  static String formatPercentage(double value, {int decimalPlaces = 1}) {
    return '${value.toStringAsFixed(decimalPlaces)}%';
  }

  /// Format large numbers with K, M suffixes
  static String formatLargeNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Format duration in a readable way
  static String formatReadableDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else {
      return '${duration.inMinutes} min${duration.inMinutes == 1 ? '' : 's'}';
    }
  }
}

// ===== COLOR HELPER UTILITIES =====
class ColorHelper {
  ColorHelper._();

  /// Get color based on rating (0-5 scale)
  static Color getRatingColor(double rating) {
    if (rating >= 4.5) return const Color(0xFF4CAF50);
    if (rating >= 4.0) return const Color(0xFF8BC34A);
    if (rating >= 3.5) return const Color(0xFFFFC107);
    if (rating >= 3.0) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  /// Get color based on ride type
  static Color getRideTypeColor(String rideType) {
    switch (rideType.toLowerCase()) {
      case 'private':
        return const Color(0xFF9C27B0);
      case 'shared':
        return const Color(0xFF2196F3);
      case 'pool':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF607D8B);
    }
  }

  /// Get status color for trip/ride status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting':
        return const Color(0xFFFF9800);
      case 'confirmed':
      case 'accepted':
      case 'available':
        return const Color(0xFF2196F3);
      case 'in_progress':
      case 'active':
      case 'driving':
        return const Color(0xFF4CAF50);
      case 'completed':
      case 'finished':
        return const Color(0xFF8BC34A);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFF44336);
      case 'busy':
      case 'paused':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF607D8B);
    }
  }

  /// Get priority color
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return const Color(0xFFF44336);
      case 'medium':
      case 'normal':
        return const Color(0xFFFF9800);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF607D8B);
    }
  }

  /// Generate color from string (for avatars, etc.)
  static Color generateColorFromString(String text) {
    final hash = text.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    
    return Color.fromRGBO(r, g, b, 1.0);
  }

  /// Lighten a color by a percentage
  static Color lighten(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = math.min(1.0, hsl.lightness + amount);
    return hsl.withLightness(lightness).toColor();
  }

  /// Darken a color by a percentage
  static Color darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = math.max(0.0, hsl.lightness - amount);
    return hsl.withLightness(lightness).toColor();
  }
}


// ===== MATHEMATICAL HELPER UTILITIES =====
class MathHelper {
  MathHelper._();

  /// Calculate percentage of value from total
  static double percentage(double value, double total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// Round to specified decimal places
  static double roundToDecimal(double value, int decimalPlaces) {
    final factor = math.pow(10, decimalPlaces);
    return (value * factor).round() / factor;
  }

  /// Clamp value between min and max
  static double clamp(double value, double min, double max) {
    return math.min(max, math.max(min, value));
  }

  /// Calculate average from list of values
  static double average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Find median value from list
  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    
    if (sorted.length.isOdd) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
  }

  /// Calculate standard deviation
  static double standardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    
    final mean = average(values);
    final variance = values
        .map((value) => math.pow(value - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }

  /// Convert degrees to radians
  static double degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Convert radians to degrees
  static double radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  /// Generate random number within range
  static double randomInRange(double min, double max) {
    final random = math.Random();
    return min + random.nextDouble() * (max - min);
  }

  /// Check if number is within tolerance of target
  static bool isWithinTolerance(double value, double target, double tolerance) {
    return (value - target).abs() <= tolerance;
  }
}

// ===== DEVICE AND PLATFORM HELPER =====
class DeviceHelper {
  DeviceHelper._();

  /// Get appropriate keyboard type for input
  static TextInputType getKeyboardType(String inputType) {
    switch (inputType.toLowerCase()) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'decimal':
        return const TextInputType.numberWithOptions(decimal: true);
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }
}

// ===== GLOBAL NAVIGATOR KEY =====
class NavigatorKey {
  static GlobalKey<NavigatorState>? _key;
  
  static GlobalKey<NavigatorState> get key {
    _key ??= GlobalKey<NavigatorState>();
    return _key!;
  }
  
  static BuildContext? get currentContext => key.currentContext;
}

// ===== UTILITY EXTENSIONS =====
extension ListExtensions<T> on List<T> {
  T? getOrNull(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }

  bool get isNullOrEmpty => isEmpty;
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}

extension StringExtensions on String {
  bool get isNullOrEmpty => isEmpty;
  bool get isBlank => trim().isEmpty;
  String truncate(int length) => StringHelper.truncate(this, length);
  String get capitalize => StringHelper.capitalize(this);
  String get capitalizeWords => StringHelper.capitalizeWords(this);
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');
  bool get isValidEmail => ValidationHelper.isValidEmail(this);
  bool get isValidPhone => ValidationHelper.isValidPhone(this);
}

extension DateTimeExtensions on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  String get readable => TimeHelper.formatDateTime(this);
  String get timeOnly => TimeHelper.getTimeOfDay(this);
  bool get isWeekend => weekday == DateTime.saturday || weekday == DateTime.sunday;

  int get ageInYears {
    final now = DateTime.now();
    int age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }
}