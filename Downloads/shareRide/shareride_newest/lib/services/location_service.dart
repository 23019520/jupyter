import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../models/location_model.dart';

class LocationService {
  static LocationService? _instance;
  LocationService._internal();
  
  factory LocationService() {
    _instance ??= LocationService._internal();
    return _instance!;
  }

  static const String _googleMapsApiKey = 'AIzaSyCrTa1Z2dv1NN1Tq4VwhhWetcILPN7FIAI';
  final Dio _dio = Dio();
  
  Position? _currentPosition;
  String? _currentAddress;

  // Get current position with enhanced error handling
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return _currentPosition;
    } catch (e) {
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  // Enhanced Places API search
  Future<List<LocationModel>> searchPlaces(String query) async {
    try {
      if (_currentPosition == null) {
        await getCurrentPosition();
      }
      
      final url = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
      final response = await _dio.get(url, queryParameters: {
        'query': query,
        'key': _googleMapsApiKey,
        if (_currentPosition != null) 'location': '${_currentPosition!.latitude},${_currentPosition!.longitude}',
        if (_currentPosition != null) 'radius': '50000', // 50km radius
        'type': 'establishment',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results.map((place) {
            final location = place['geometry']['location'];
            final lat = location['lat'] as double;
            final lng = location['lng'] as double;
            
            double? distance;
            double estimatedCost = 0.0;
            
            if (_currentPosition != null) {
              distance = calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                lat,
                lng,
              );
              estimatedCost = estimateCost(distance);
            }
            
            return LocationModel(
              name: place['name'] ?? 'Unknown Location',
              address: place['formatted_address'] ?? '',
              latitude: lat,
              longitude: lng,
              distance: distance?.round() ?? 0,
              estimatedCost: estimatedCost,
              timestamp: DateTime.now(),
              distanceFromUser: distance,
            );
          }).toList();
        } else {
          throw Exception('Places API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to search places: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to search places: ${e.toString()}');
    }
  }

  // Get detailed directions between two points
  Future<Map<String, dynamic>> getDirections(
    double originLat, double originLng,
    double destLat, double destLng,
  ) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json';
      final response = await _dio.get(url, queryParameters: {
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'key': _googleMapsApiKey,
        'mode': 'driving',
        'alternatives': 'true',
        'traffic_model': 'best_guess',
        'departure_time': 'now',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          return {
            'distance': leg['distance']['value'], // in meters
            'duration': leg['duration']['value'], // in seconds
            'duration_text': leg['duration']['text'],
            'distance_text': leg['distance']['text'],
            'polyline': route['overview_polyline']['points'],
            'steps': leg['steps'],
          };
        } else {
          throw Exception('No routes found');
        }
      } else {
        throw Exception('Failed to get directions: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to get directions: ${e.toString()}');
    }
  }

  // Enhanced geocoding with Google APIs
  Future<List<LocationModel>> geocodeAddress(String address) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json';
      final response = await _dio.get(url, queryParameters: {
        'address': address,
        'key': _googleMapsApiKey,
        if (_currentPosition != null) 'region': 'ZA', // Bias towards South Africa
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          return results.map((result) {
            final location = result['geometry']['location'];
            final lat = location['lat'] as double;
            final lng = location['lng'] as double;
            
            double? distance;
            double estimatedCost = 0.0;
            
            if (_currentPosition != null) {
              distance = calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                lat,
                lng,
              );
              estimatedCost = estimateCost(distance);
            }
            
            return LocationModel(
              name: result['address_components'][0]['long_name'] ?? address,
              address: result['formatted_address'],
              latitude: lat,
              longitude: lng,
              distance: distance?.round() ?? 0,
              estimatedCost: estimatedCost,
              timestamp: DateTime.now(),
              distanceFromUser: distance,
            );
          }).toList();
        } else {
          throw Exception('Geocoding error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to geocode address: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to geocode address: ${e.toString()}');
    }
  }

  // Reverse geocoding with enhanced details
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json';
      final response = await _dio.get(url, queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': _googleMapsApiKey,
        'result_type': 'street_address|route|neighborhood|locality',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      
      // Fallback to built-in geocoding
      return await getAddressFromCoordinates(latitude, longitude);
    } catch (e) {
      // Fallback to built-in geocoding
      return await getAddressFromCoordinates(latitude, longitude);
    }
  }

  // Get current location with address (enhanced)
  Future<LocationModel?> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      final address = await reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return LocationModel(
        name: 'Current Location',
        address: address ?? 'Current Location',
        latitude: position.latitude,
        longitude: position.longitude,
        distance: 0,
        estimatedCost: 0.0,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  // Existing methods (kept for compatibility)
  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final components = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
        ].where((component) => component != null && component.isNotEmpty);
        
        if (components.isNotEmpty) {
          return components.join(', ');
        }
      }
      
      return 'Location at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    } catch (e) {
      return 'Location at ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  double? calculateDistanceFromCurrent(double latitude, double longitude) {
    if (_currentPosition == null) return null;
    
    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  Future<bool> _checkLocationPermission() async {
    PermissionStatus permission = await Permission.location.status;
    
    if (permission.isDenied) {
      permission = await Permission.location.request();
    }
    
    if (permission.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    
    return permission.isGranted;
  }

  Future<bool> requestLocationPermission() async {
    try {
      PermissionStatus permission = await Permission.location.request();
      return permission.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<LocationPermission> getLocationPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;

  void clearCache() {
    _currentPosition = null;
    _currentAddress = null;
  }

  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  double estimateCost(double distanceInMeters, {double ratePerKm = 15.0}) {
    final distanceInKm = distanceInMeters / 1000;
    final baseCost = 10.0; // Base fare
    return baseCost + (distanceInKm * ratePerKm);
  }

  // Autocomplete suggestions using Google Places Autocomplete
  Future<List<LocationModel>> getAutocompleteSuggestions(String input) async {
    if (input.isEmpty) return [];
    
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      final response = await _dio.get(url, queryParameters: {
        'input': input,
        'key': _googleMapsApiKey,
        'types': 'establishment|geocode',
        'components': 'country:za', // Restrict to South Africa
        if (_currentPosition != null) 'location': '${_currentPosition!.latitude},${_currentPosition!.longitude}',
        if (_currentPosition != null) 'radius': '50000',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          
          // Get detailed information for each prediction
          List<LocationModel> results = [];
          for (var prediction in predictions.take(5)) { // Limit to 5 suggestions
            final placeId = prediction['place_id'];
            final details = await _getPlaceDetails(placeId);
            if (details != null) {
              results.add(details);
            }
          }
          
          return results;
        }
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<LocationModel?> _getPlaceDetails(String placeId) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json';
      final response = await _dio.get(url, queryParameters: {
        'place_id': placeId,
        'key': _googleMapsApiKey,
        'fields': 'name,formatted_address,geometry,place_id',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          
          double? distance;
          double estimatedCost = 0.0;
          
          if (_currentPosition != null) {
            distance = calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              lat,
              lng,
            );
            estimatedCost = estimateCost(distance);
          }
          
          return LocationModel(
            name: result['name'] ?? 'Unknown Location',
            address: result['formatted_address'] ?? '',
            latitude: lat,
            longitude: lng,
            distance: distance?.round() ?? 0,
            estimatedCost: estimatedCost,
            timestamp: DateTime.now(),
            distanceFromUser: distance,
          );
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}