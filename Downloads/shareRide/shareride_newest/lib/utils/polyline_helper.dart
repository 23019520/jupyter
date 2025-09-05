// lib/utils/polyline_helper.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class PolylineHelper {
  /// Decodes a Google Maps encoded polyline string into a list of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
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
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Encodes a list of LatLng points into a Google Maps polyline string
  static String encodePolyline(List<LatLng> points) {
    StringBuffer encoded = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (LatLng point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      int dLat = lat - prevLat;
      int dLng = lng - prevLng;

      encoded.write(_encodeSignedNumber(dLat));
      encoded.write(_encodeSignedNumber(dLng));

      prevLat = lat;
      prevLng = lng;
    }

    return encoded.toString();
  }

  /// Helper method to encode a signed number for polyline encoding
  static String _encodeSignedNumber(int num) {
    int sgn_num = num << 1;
    if (num < 0) {
      sgn_num = ~sgn_num;
    }
    return _encodeNumber(sgn_num);
  }

  /// Helper method to encode a number for polyline encoding
  static String _encodeNumber(int num) {
    StringBuffer encoded = StringBuffer();
    while (num >= 0x20) {
      encoded.writeCharCode((0x20 | (num & 0x1f)) + 63);
      num >>= 5;
    }
    encoded.writeCharCode(num + 63);
    return encoded.toString();
  }

  /// Calculates the distance between two points using Haversine formula
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (3.14159265359 / 180);
    double lat2Rad = point2.latitude * (3.14159265359 / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in kilometers
  }

  /// Calculates the bearing between two points
  static double calculateBearing(LatLng point1, LatLng point2) {
    double lat1Rad = point1.latitude * (3.14159265359 / 180);
    double lat2Rad = point2.latitude * (3.14159265359 / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    double y = sin(deltaLngRad) * cos(lat2Rad);
    double x = cos(lat1Rad) * sin(lat2Rad) - 
               sin(lat1Rad) * cos(lat2Rad) * cos(deltaLngRad);

    double bearingRad = atan2(y, x);
    double bearingDeg = bearingRad * (180 / 3.14159265359);

    return (bearingDeg + 360) % 360; // Normalize to 0-360 degrees
  }

  /// Simplifies a polyline by removing points that are too close together
  static List<LatLng> simplifyPolyline(List<LatLng> points, {double tolerance = 0.0001}) {
    if (points.length <= 2) return points;

    List<LatLng> simplified = [points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      double distance = calculateDistance(simplified.last, points[i]);
      if (distance > tolerance) {
        simplified.add(points[i]);
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

    for (LatLng point in points) {
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

    for (LatLng point in points) {
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
      List<LatLng> decoded = decodePolyline(encoded);
      return decoded.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}