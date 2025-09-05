// lib/services/enhanced_ride_service.dart - Fixed version
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart' as driver_models;
import 'dart:math' as math;

class EnhancedRideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Pricing constants
  static const double _basePrice = 50.0;
  static const double _sharedAloneDiscount = 0.35;
  static const double _sharedWithOthersDiscount = 0.20;
  static const double _driverRevenueShare = 0.50;
  static const double _driverRevenueShareLate = 0.40;
  static const double _reasonableArrivalTimeMinutes = 15.0;

  /// Enhanced ride request with driver allocation
  Future<RideModel> requestRideWithDriver({
    required LocationModel pickupLocation,
    required LocationModel destination,
    required RideType rideType,
    required int requiredSeats,
    String? preferredDriverId,
    required double estimatedPrice,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to request a ride');
    }

    try {
      // Find optimal driver
      final selectedDriver = await _findOptimalDriver(
        pickupLat: pickupLocation.latitude,
        pickupLng: pickupLocation.longitude,
        preferredDriverId: preferredDriverId,
        rideType: rideType,
      );

      // Calculate accurate pricing
      final pricing = await _calculateAdvancedPricing(
        distance: _calculateDistance(
          pickupLocation.latitude,
          pickupLocation.longitude,
          destination.latitude,
          destination.longitude,
        ),
        rideType: rideType,
        requiredSeats: requiredSeats,
        pickupLat: pickupLocation.latitude,
        pickupLng: pickupLocation.longitude,
      );

      // Create ride request document
      final rideData = {
        'passengerId': _currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'rideType': rideType.toString().split('.').last,
        'pickupLocation': pickupLocation.toMap(),
        'destination': destination.toMap(),
        'requiredSeats': requiredSeats,
        'estimatedPrice': pricing['passengerPrice'],
        'driverEarnings': pricing['driverEarnings'],
        'distance': pricing['distance'],
        'estimatedDuration': pricing['estimatedDuration'],
        'assignedDriverId': selectedDriver?.uid,
        'driverAssignedAt': selectedDriver != null ? FieldValue.serverTimestamp() : null,
        'driverDistanceToPickup': selectedDriver?.distanceFromUser,
        'estimatedArrivalTime': selectedDriver != null
            ? _calculateEstimatedArrival(selectedDriver.distanceFromUser ?? 0.0)
            : null,
        'pricingBreakdown': pricing,
        'searchRadius': 10.0,
        'urgencyLevel': _calculateUrgencyLevel(rideType, requiredSeats),
        'maxPassengers': _getMaxPassengers(rideType),
        'currentPassengers': 0,
        'routeFlexibility': _getRouteFlexibility(rideType),
        'passengerIds': [_currentUserId!],
      };

      // Add to rides collection
      final docRef = await _firestore.collection('rides').add(rideData);
      rideData['id'] = docRef.id;

      // If driver is assigned, notify them
      if (selectedDriver != null) {
        await _notifyDriver(docRef.id, selectedDriver.uid, rideData);
        // Update status to confirmed if driver is assigned
        await docRef.update({'status': 'confirmed'});
        rideData['status'] = 'confirmed';
      }

      return _rideFromFirestore(docRef.id, rideData);
    } catch (e) {
      throw Exception('Failed to request ride: $e');
    }
  }

  /// Find optimal driver - Fixed to match expectations and handle null safety
  Future<driver_models.DriverModel?> _findOptimalDriver({
    required double pickupLat,
    required double pickupLng,
    String? preferredDriverId,
    required RideType rideType,
    double maxDistanceKm = 15.0,
  }) async {
    try {
      // First try drivers collection
      final driversQuery = await _firestore
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .get();

      List<driver_models.DriverModel> availableDrivers = [];

      // Process drivers from drivers collection
      for (var doc in driversQuery.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        
        if (location != null) {
          final driverLat = location['latitude']?.toDouble();
          final driverLng = location['longitude']?.toDouble();
          
          if (driverLat != null && driverLng != null) {
            final distance = _calculateDistance(
              pickupLat,
              pickupLng,
              driverLat,
              driverLng,
            );

            if (distance <= maxDistanceKm) {
              availableDrivers.add(
                driver_models.DriverModel.fromMap(data, doc.id, distance)
              );
            }
          }
        }
      }

      // If no drivers found in drivers collection, try users collection
      if (availableDrivers.isEmpty) {
        final usersQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .where('isAvailable', isEqualTo: true)
            .get();

        for (var doc in usersQuery.docs) {
          final data = doc.data();
          
          if (data['currentLat'] != null && data['currentLng'] != null) {
            final distance = _calculateDistance(
              pickupLat,
              pickupLng,
              data['currentLat'].toDouble(),
              data['currentLng'].toDouble(),
            );

            if (distance <= maxDistanceKm) {
              // Convert user data to driver format
              final driverData = _convertUserToDriverData(data);
              availableDrivers.add(
                driver_models.DriverModel.fromMap(driverData, doc.id, distance)
              );
            }
          }
        }
      }

      // If preferred driver is available and within range
      if (preferredDriverId != null) {
        final preferred = availableDrivers
            .where((d) => d.uid == preferredDriverId)
            .firstOrNull;
        if (preferred != null) return preferred;
      }

      // Choose nearest available driver
      if (availableDrivers.isNotEmpty) {
        availableDrivers.sort((a, b) => 
          (a.distanceFromUser ?? double.infinity)
              .compareTo(b.distanceFromUser ?? double.infinity));
        return availableDrivers.first;
      }

      return null;
    } catch (e) {
      print('Error finding driver: $e');
      return null;
    }
  }

  /// Convert user data to driver data format
  Map<String, dynamic> _convertUserToDriverData(Map<String, dynamic> userData) {
    return {
      'uid': userData['uid'] ?? '',
      'name': userData['displayName'] ?? userData['name'] ?? 'Driver',
      'email': userData['email'] ?? '',
      'phone': userData['phone'] ?? '',
      'rating': userData['rating']?.toDouble() ?? 4.5,
      'isAvailable': userData['isAvailable'] ?? true,
      'isOnline': userData['isOnline'] ?? userData['isActive'] ?? true,
      'location': {
        'latitude': userData['currentLat']?.toDouble() ?? 0.0,
        'longitude': userData['currentLng']?.toDouble() ?? 0.0,
      },
      'vehicle': userData['vehicle'] ?? {
        'make': 'Unknown',
        'model': 'Vehicle',
        'year': '2020',
        'color': 'Unknown',
        'licensePlate': 'N/A',
      },
      'totalRides': userData['totalRides'] ?? 0,
      'acceptanceRate': userData['acceptanceRate']?.toDouble() ?? 0.9,
      'createdAt': userData['createdAt'],
      'updatedAt': userData['updatedAt'],
    };
  }

  /// Advanced pricing calculation
  Future<Map<String, dynamic>> _calculateAdvancedPricing({
    required double distance,
    required RideType rideType,
    required int requiredSeats,
    required double pickupLat,
    required double pickupLng,
  }) async {
    try {
      double basePrice = _basePrice + (distance * 8); // Example rate per km

      // Apply discounts based on ride type
      if (rideType == RideType.shared && requiredSeats == 1) {
        basePrice *= (1 - _sharedWithOthersDiscount);
      } else if (rideType == RideType.shared && requiredSeats > 1) {
        basePrice *= (1 - _sharedAloneDiscount);
      }

      // Get demand multiplier based on nearby users/drivers
      final demandMultiplier = await _getDemandMultiplier(pickupLat, pickupLng);
      basePrice *= demandMultiplier;

      // Estimate duration (minutes)
      double estimatedDuration = distance / 0.5; // avg 30km/h

      // Driver earnings
      double driverShare = estimatedDuration <= _reasonableArrivalTimeMinutes
          ? _driverRevenueShare
          : _driverRevenueShareLate;
      double driverEarnings = basePrice * driverShare;

      return {
        'passengerPrice': basePrice,
        'driverEarnings': driverEarnings,
        'distance': distance,
        'estimatedDuration': estimatedDuration.round(),
        'demandMultiplier': demandMultiplier,
        'basePrice': _basePrice + (distance * 8),
      };
    } catch (e) {
      print('Error calculating pricing: $e');
      // Return default pricing on error
      double defaultPrice = _basePrice + (distance * 8);
      return {
        'passengerPrice': defaultPrice,
        'driverEarnings': defaultPrice * _driverRevenueShare,
        'distance': distance,
        'estimatedDuration': (distance / 0.5).round(),
        'demandMultiplier': 1.0,
        'basePrice': defaultPrice,
      };
    }
  }

  /// Get demand multiplier based on supply/demand ratio
  Future<double> _getDemandMultiplier(double lat, double lng) async {
    try {
      // Count nearby users (demand)
      final usersCount = await _getNearbyCount('users', lat, lng, 
        filters: {'isActive': true});
      
      // Count nearby drivers (supply)
      final driversCount = await _getNearbyCount('drivers', lat, lng, 
        filters: {'isAvailable': true, 'isOnline': true});
      
      if (driversCount == 0) return 2.0; // High demand, no supply
      
      double demandRatio = usersCount / driversCount;
      
      // Apply surge pricing logic
      if (demandRatio > 3.0) return 2.0;      // 2x surge
      if (demandRatio > 2.0) return 1.5;      // 1.5x surge
      if (demandRatio > 1.5) return 1.3;      // 1.3x surge
      if (demandRatio < 0.5) return 0.9;      // 10% discount
      
      return 1.0; // Normal pricing
    } catch (e) {
      print('Error calculating demand: $e');
      return 1.0;
    }
  }

  /// Count nearby entities
  Future<int> _getNearbyCount(String collection, double lat, double lng, 
      {Map<String, dynamic>? filters, double radiusKm = 10.0}) async {
    try {
      Query query = _firestore.collection(collection);
      
      // Apply filters
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.where(key, isEqualTo: value);
        });
      }
      
      final snapshot = await query.limit(100).get();
      int count = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        double? docLat, docLng;
        
        // Handle different location field structures
        if (collection == 'drivers') {
          final location = data['location'] as Map<String, dynamic>?;
          docLat = location?['latitude']?.toDouble();
          docLng = location?['longitude']?.toDouble();
        } else {
          docLat = data['currentLat']?.toDouble();
          docLng = data['currentLng']?.toDouble();
        }
        
        if (docLat != null && docLng != null) {
          final distance = _calculateDistance(lat, lng, docLat, docLng);
          if (distance <= radiusKm) count++;
        }
      }
      
      return count;
    } catch (e) {
      print('Error counting nearby entities: $e');
      return 0;
    }
  }

  /// Calculate distance in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  /// Calculate estimated arrival time - Fixed to return DateTime
  DateTime _calculateEstimatedArrival(double distanceKm) {
    double avgSpeedKmPerMin = 0.5; // 30 km/h
    int etaMinutes = (distanceKm / avgSpeedKmPerMin).round();
    return DateTime.now().add(Duration(minutes: etaMinutes));
  }

  /// Calculate urgency level
  String _calculateUrgencyLevel(RideType type, int seats) {
    if (type == RideType.private) return 'high';
    if (type == RideType.shared && seats > 2) return 'medium';
    if (type == RideType.shared) return 'low';
    return 'medium';
  }

  /// Get maximum passengers for ride type
  int _getMaxPassengers(RideType rideType) {
    switch (rideType) {
      case RideType.private:
        return 1;
      case RideType.shared:
        return 4;
      case RideType.pool:
        return 6;
    }
  }

  /// Get route flexibility for ride type
  String _getRouteFlexibility(RideType rideType) {
    switch (rideType) {
      case RideType.private:
        return 'none';
      case RideType.shared:
        return 'low';
      case RideType.pool:
        return 'high';
    }
  }

  /// Notify driver of new ride request
  Future<void> _notifyDriver(
      String rideId, String driverId, Map<String, dynamic> rideData) async {
    try {
      await _firestore.collection('driver_notifications').add({
        'driverId': driverId,
        'rideId': rideId,
        'type': 'ride_request',
        'status': 'pending',
        'message': 'New ride request assigned to you',
        'rideData': {
          'pickupLocation': rideData['pickupLocation'],
          'destination': rideData['destination'],
          'estimatedPrice': rideData['driverEarnings'],
          'distance': rideData['distance'],
          'estimatedDuration': rideData['estimatedDuration'],
        },
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error notifying driver: $e');
    }
  }

  /// Create RideModel from Firestore data - Fixed with proper field mapping
  RideModel _rideFromFirestore(String id, Map<String, dynamic> data) {
    return RideModel(
      id: id,
      pickupLocation: LocationModel.fromMap(
        data['pickupLocation'] as Map<String, dynamic>? ?? {}
      ),
      destination: LocationModel.fromMap(
        data['destination'] as Map<String, dynamic>? ?? {}
      ),
      rideType: _parseRideType(data['rideType']),
      status: _parseRideStatus(data['status']),
      estimatedCost: (data['estimatedPrice'] ?? 0.0).toDouble(),
      distance: ((data['distance'] ?? 0.0).toDouble()).round(),
      maxPassengers: data['maxPassengers'] ?? 1,
      currentPassengers: data['currentPassengers'] ?? 0,
      routeFlexibility: data['routeFlexibility'] ?? 'low',
      createdAt: _parseTimestamp(data['createdAt']),
      estimatedArrival: data['estimatedArrivalTime'] is DateTime 
          ? data['estimatedArrivalTime'] as DateTime
          : (data['estimatedArrivalTime'] != null
              ? DateTime.tryParse(data['estimatedArrivalTime'].toString())
              : null),
      driverId: data['assignedDriverId'],
      passengerIds: List<String>.from(data['passengerIds'] ?? []),
    );
  }

  /// Parse ride type from string
  RideType _parseRideType(String? type) {
    switch (type?.toLowerCase()) {
      case 'private':
        return RideType.private;
      case 'shared':
        return RideType.shared;
      case 'pool':
        return RideType.pool;
      default:
        return RideType.private;
    }
  }

  /// Parse ride status from string
  RideStatus _parseRideStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return RideStatus.pending;
      case 'confirmed':
        return RideStatus.confirmed;
      case 'in_progress':
      case 'inprogress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.pending;
    }
  }

  /// Parse timestamp from Firestore
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Cancel ride request
  Future<bool> cancelRide(String rideId, {String? reason}) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _currentUserId,
        'cancellationReason': reason ?? 'Cancelled by passenger',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error cancelling ride: $e');
      return false;
    }
  }

  /// Get ride by ID
  Future<RideModel?> getRideById(String rideId) async {
    try {
      final doc = await _firestore.collection('rides').doc(rideId).get();
      if (doc.exists && doc.data() != null) {
        return _rideFromFirestore(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting ride: $e');
      return null;
    }
  }

  /// Listen to ride updates
  Stream<RideModel?> listenToRide(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return _rideFromFirestore(doc.id, doc.data()!);
          }
          return null;
        });
  }
}