// lib/services/driver_service.dart - Fixed version
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_model.dart' as driver_models;
import '../models/ride_model.dart';
import '../models/location_model.dart';
import '../utils/helpers.dart';
import 'dart:async';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get nearby ride requests for driver
  Future<List<RideRequest>> getNearbyRideRequests(
    double driverLat,
    double driverLng,
    double radiusKm,
  ) async {
    try {
      final query = await _firestore
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .limit(20)
          .get();

      List<RideRequest> nearbyRequests = [];

      for (var doc in query.docs) {
        try {
          final data = doc.data();
          
          // Skip rides that already have a driver assigned
          if (data['driverId'] != null && data['driverId'].toString().isNotEmpty) {
            continue;
          }

          final pickupLocation = data['pickupLocation'] as Map<String, dynamic>;
          final destination = data['destination'] as Map<String, dynamic>;
          
          final pickupLat = pickupLocation['latitude']?.toDouble();
          final pickupLng = pickupLocation['longitude']?.toDouble();
          
          if (pickupLat != null && pickupLng != null) {
            final distanceToPickup = DistanceHelper.calculateDistanceKm(
              driverLat, driverLng, pickupLat, pickupLng
            );

            if (distanceToPickup <= radiusKm) {
              // Get passenger info
              final passengerDoc = await _firestore
                  .collection('users')
                  .doc(data['passengerId'])
                  .get();
              
              if (passengerDoc.exists) {
                final passengerData = passengerDoc.data()!;
                
                final tripDistance = DistanceHelper.calculateDistanceKm(
                  pickupLat, pickupLng,
                  destination['latitude']?.toDouble() ?? 0.0,
                  destination['longitude']?.toDouble() ?? 0.0,
                );

                nearbyRequests.add(RideRequest(
                  id: doc.id,
                  passengerId: data['passengerId'] ?? '',
                  passengerName: passengerData['displayName'] ?? passengerData['name'] ?? 'Unknown',
                  passengerRating: (passengerData['rating'] ?? 5.0).toDouble(),
                  pickupLat: pickupLat,
                  pickupLng: pickupLng,
                  pickupAddress: pickupLocation['address'] ?? pickupLocation['name'] ?? 'Pickup Location',
                  destinationLat: destination['latitude']?.toDouble() ?? 0.0,
                  destinationLng: destination['longitude']?.toDouble() ?? 0.0,
                  destinationName: destination['name'] ?? destination['address'] ?? 'Destination',
                  rideType: _parseRideType(data['rideType']),
                  requiredSeats: data['maxPassengers'] ?? data['requiredSeats'] ?? 1,
                  estimatedPrice: (data['driverEarnings'] ?? data['estimatedCost'] ?? 0).toDouble(),
                  distanceToPickup: distanceToPickup,
                  tripDistance: tripDistance,
                  requestedAt: _parseTimestamp(data['createdAt']),
                  isUrgent: data['urgencyLevel'] == 'high',
                  routeFlexibility: data['routeFlexibility'] ?? 'none',
                ));
              }
            }
          }
        } catch (e) {
          print('Error processing ride request ${doc.id}: $e');
        }
      }

      // Sort by distance to pickup, then by urgency
      nearbyRequests.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return a.distanceToPickup.compareTo(b.distanceToPickup);
      });
      
      return nearbyRequests;
    } catch (e) {
      throw Exception('Failed to get nearby ride requests: $e');
    }
  }

  /// Accept a ride request
  Future<void> acceptRideRequest(String rideId) async {
    if (_currentUserId == null) {
      throw Exception('Driver must be logged in');
    }

    try {
      // First check if ride is still available
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) {
        throw Exception('Ride request no longer exists');
      }

      final rideData = rideDoc.data()!;
      if (rideData['status'] != 'pending' || 
          (rideData['driverId'] != null && rideData['driverId'].toString().isNotEmpty)) {
        throw Exception('Ride request is no longer available');
      }

      // Get driver's current location for ETA calculation
      final driverDoc = await _firestore.collection('drivers').doc(_currentUserId).get();
      String? estimatedArrival;
      
      if (driverDoc.exists) {
        final driverData = driverDoc.data()!;
        final driverLocation = driverData['location'] as Map<String, dynamic>?;
        if (driverLocation != null) {
          final pickupLocation = rideData['pickupLocation'] as Map<String, dynamic>;
          final distance = DistanceHelper.calculateDistanceKm(
            driverLocation['latitude']?.toDouble() ?? 0.0,
            driverLocation['longitude']?.toDouble() ?? 0.0,
            pickupLocation['latitude']?.toDouble() ?? 0.0,
            pickupLocation['longitude']?.toDouble() ?? 0.0,
          );
          
          final arrivalMinutes = TimeHelper.calculateEstimatedArrivalMinutes(distance);
          estimatedArrival = TimeHelper.getEstimatedArrival(arrivalMinutes.round() as double);
        }
      }

      // Update ride with driver info
      final updateData = {
        'driverId': _currentUserId,
        'status': 'confirmed',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (estimatedArrival != null) {
        updateData['estimatedArrivalTime'] = estimatedArrival;
      }

      await _firestore.collection('rides').doc(rideId).update(updateData);

      // Mark driver as busy
      await _setDriverAvailability(false);

      // Notify passenger
      await _notifyPassenger(rideId);
      
    } catch (e) {
      throw Exception('Failed to accept ride request: $e');
    }
  }

  /// Update driver location
  Future<void> updateDriverLocation(
    double latitude,
    double longitude,
    bool isOnline,
  ) async {
    if (_currentUserId == null) return;

    try {
      final locationData = {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Update in drivers collection with proper structure
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'location': locationData,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update in users collection (for drivers who are also users)
      await _firestore.collection('users').doc(_currentUserId).update({
        'currentLat': latitude,
        'currentLng': longitude,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': isOnline,
      });

      // Update location tracking collection
      await _firestore.collection('driver_locations').doc(_currentUserId).set({
        'driverId': _currentUserId,
        'latitude': latitude,
        'longitude': longitude,
        'isOnline': isOnline,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  /// Set driver availability
  Future<void> _setDriverAvailability(bool isAvailable) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Also update in users collection
      await _firestore.collection('users').doc(_currentUserId).update({
        'isAvailable': isAvailable,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating driver availability: $e');
    }
  }

  /// Get driver profile
  Future<driver_models.DriverModel?> getDriverProfile() async {
    if (_currentUserId == null) return null;

    try {
      final doc = await _firestore.collection('drivers').doc(_currentUserId).get();
      if (doc.exists) {
        return driver_models.DriverModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting driver profile: $e');
      return null;
    }
  }

  /// Get driver earnings for today
  Future<Map<String, dynamic>> getTodayEarnings() async {
    if (_currentUserId == null) return {'earnings': 0.0, 'rides': 0};

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final query = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      double totalEarnings = 0.0;
      int rideCount = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final driverEarnings = data['driverEarnings']?.toDouble() ?? 0.0;
        totalEarnings += driverEarnings;
        rideCount++;
      }

      return {
        'earnings': totalEarnings,
        'rides': rideCount,
      };
    } catch (e) {
      print('Error getting today\'s earnings: $e');
      return {'earnings': 0.0, 'rides': 0};
    }
  }

  /// Get driver statistics
  Future<Map<String, dynamic>> getDriverStats() async {
    if (_currentUserId == null) return {};

    try {
      final driverDoc = await _firestore.collection('drivers').doc(_currentUserId).get();
      if (!driverDoc.exists) return {};

      final data = driverDoc.data()!;
      
      // Get total rides count
      final ridesQuery = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'completed')
          .get();

      // Calculate total earnings from completed rides
      double totalEarnings = 0.0;
      for (var doc in ridesQuery.docs) {
        final rideData = doc.data();
        totalEarnings += (rideData['driverEarnings']?.toDouble() ?? 0.0);
      }

      return {
        'rating': (data['rating'] ?? 5.0).toDouble(),
        'totalRides': ridesQuery.docs.length,
        'totalEarnings': totalEarnings,
        'acceptanceRate': (data['acceptanceRate'] ?? 1.0).toDouble(),
        'vehicleInfo': data['vehicle'] ?? data['vehicleInfo'] ?? 'Unknown Vehicle',
        'isVerified': data['isVerified'] ?? false,
        'name': data['name'] ?? 'Driver',
        'phone': data['phone'] ?? '',
        'isOnline': data['isOnline'] ?? false,
        'isAvailable': data['isAvailable'] ?? false,
      };
    } catch (e) {
      print('Error getting driver stats: $e');
      return {};
    }
  }

  /// Complete a ride
  Future<void> completeRide(String rideId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark driver as available again
      await _setDriverAvailability(true);

      // Update driver's total rides count
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'totalRides': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      throw Exception('Failed to complete ride: $e');
    }
  }

  /// Cancel accepted ride
  Future<void> cancelRide(String rideId, String reason) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'cancelled',
        'cancelledBy': 'driver',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark driver as available again
      await _setDriverAvailability(true);

      // Notify passenger about cancellation
      await _notifyPassengerCancellation(rideId, reason);

    } catch (e) {
      throw Exception('Failed to cancel ride: $e');
    }
  }

  /// Listen to driver notifications
  Stream<List<Map<String, dynamic>>> getDriverNotifications() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('driver_notifications')
        .where('driverId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('driver_notifications')
          .doc(notificationId)
          .update({
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Get current active ride
  Future<RideModel?> getCurrentActiveRide() async {
    if (_currentUserId == null) return null;

    try {
      final query = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: _currentUserId)
          .where('status', whereIn: ['confirmed', 'in_progress'])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return RideModel.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting current active ride: $e');
      return null;
    }
  }

  /// Start ride (when driver reaches pickup)
  Future<void> startRide(String rideId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify passenger that ride has started
      await _notifyPassengerRideStarted(rideId);
      
    } catch (e) {
      throw Exception('Failed to start ride: $e');
    }
  }

  /// Set driver online/offline status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('drivers').doc(_currentUserId).update({
        'isOnline': isOnline,
        'isAvailable': isOnline, // When going offline, also set unavailable
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update in users collection
      await _firestore.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error setting online status: $e');
    }
  }

  /// Get ride history
  Stream<List<RideModel>> getRideHistory() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Helper methods
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

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  Future<void> _notifyPassenger(String rideId) async {
    try {
      // Get ride details
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return;

      final rideData = rideDoc.data()!;
      final passengerId = rideData['passengerId'];

      if (passengerId != null) {
        await _firestore.collection('passenger_notifications').add({
          'passengerId': passengerId,
          'rideId': rideId,
          'type': 'ride_accepted',
          'message': 'Your ride has been accepted! Driver is on the way.',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'unread',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error notifying passenger: $e');
    }
  }

  Future<void> _notifyPassengerCancellation(String rideId, String reason) async {
    try {
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return;

      final rideData = rideDoc.data()!;
      final passengerId = rideData['passengerId'];

      if (passengerId != null) {
        await _firestore.collection('passenger_notifications').add({
          'passengerId': passengerId,
          'rideId': rideId,
          'type': 'ride_cancelled',
          'message': 'Your ride has been cancelled by the driver. Reason: $reason',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'unread',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error notifying passenger of cancellation: $e');
    }
  }

  Future<void> _notifyPassengerRideStarted(String rideId) async {
    try {
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return;

      final rideData = rideDoc.data()!;
      final passengerId = rideData['passengerId'];

      if (passengerId != null) {
        await _firestore.collection('passenger_notifications').add({
          'passengerId': passengerId,
          'rideId': rideId,
          'type': 'ride_started',
          'message': 'Your ride has started! You are now on your way to your destination.',
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'unread',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error notifying passenger of ride start: $e');
    }
  }
}

/// RideRequest model for driver dashboard
class RideRequest {
  final String id;
  final String passengerId;
  final String passengerName;
  final double passengerRating;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double destinationLat;
  final double destinationLng;
  final String destinationName;
  final RideType rideType;
  final int requiredSeats;
  final double estimatedPrice;
  final double distanceToPickup;
  final double tripDistance;
  final DateTime requestedAt;
  final bool isUrgent;
  final String routeFlexibility;

  RideRequest({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
    required this.rideType,
    required this.requiredSeats,
    required this.estimatedPrice,
    required this.distanceToPickup,
    required this.tripDistance,
    required this.requestedAt,
    this.isUrgent = false,
    this.routeFlexibility = 'none',
  });

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerRating': passengerRating,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'pickupAddress': pickupAddress,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'destinationName': destinationName,
      'rideType': rideType.toString().split('.').last,
      'requiredSeats': requiredSeats,
      'estimatedPrice': estimatedPrice,
      'distanceToPickup': distanceToPickup,
      'tripDistance': tripDistance,
      'requestedAt': requestedAt.toIso8601String(),
      'isUrgent': isUrgent,
      'routeFlexibility': routeFlexibility,
    };
  }

  /// Create from map
  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      id: map['id'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? 'Unknown',
      passengerRating: (map['passengerRating'] ?? 5.0).toDouble(),
      pickupLat: (map['pickupLat'] ?? 0.0).toDouble(),
      pickupLng: (map['pickupLng'] ?? 0.0).toDouble(),
      pickupAddress: map['pickupAddress'] ?? 'Unknown Location',
      destinationLat: (map['destinationLat'] ?? 0.0).toDouble(),
      destinationLng: (map['destinationLng'] ?? 0.0).toDouble(),
      destinationName: map['destinationName'] ?? 'Unknown Destination',
      rideType: _parseRideTypeFromString(map['rideType']),
      requiredSeats: map['requiredSeats'] ?? 1,
      estimatedPrice: (map['estimatedPrice'] ?? 0.0).toDouble(),
      distanceToPickup: (map['distanceToPickup'] ?? 0.0).toDouble(),
      tripDistance: (map['tripDistance'] ?? 0.0).toDouble(),
      requestedAt: DateTime.tryParse(map['requestedAt'] ?? '') ?? DateTime.now(),
      isUrgent: map['isUrgent'] ?? false,
      routeFlexibility: map['routeFlexibility'] ?? 'none',
    );
  }

  static RideType _parseRideTypeFromString(String? type) {
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

  /// Get formatted distance to pickup
  String get formattedDistance {
    if (distanceToPickup < 1) {
      return '${(distanceToPickup * 1000).round()}m away';
    }
    return '${distanceToPickup.toStringAsFixed(1)}km away';
  }

  /// Get formatted trip distance
  String get formattedTripDistance {
    if (tripDistance < 1) {
      return '${(tripDistance * 1000).round()}m trip';
    }
    return '${tripDistance.toStringAsFixed(1)}km trip';
  }

  /// Get formatted estimated price
  String get formattedPrice {
    return 'R${estimatedPrice.toStringAsFixed(2)}';
  }

  /// Get urgency indicator text
  String get urgencyText {
    return isUrgent ? 'URGENT' : 'NORMAL';
  }
}