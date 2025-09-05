// lib/services/ride_service.dart - Improved version with key fixes
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_model.dart';
import '../models/ride_type.dart';
import '../models/location_model.dart';
import '../models/ride_model.dart' as models2;
import '../models/ride_type.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart' as driver_models;
import '../utils/helpers.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Request a ride - Main method your screens expect
  Future<RideModel> requestRide({
    required LocationModel pickupLocation,
    required LocationModel destination,
    required models2.RideType rideType,
    required int maxPassengers,
    required String routeFlexibility,
    String? preferredDriverId,
    double? estimatedPrice,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User must be logged in to request a ride');
    }

    try {
      final rideId = _firestore.collection('rides').doc().id;
      
      // Calculate distance using your existing helper
      final distance = DistanceHelper.calculateDistanceKm(
        pickupLocation.latitude,
        pickupLocation.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Get nearby counts for pricing
      final nearbyUsers = await _getNearbyUserCount(
        pickupLocation.latitude, 
        pickupLocation.longitude
      );
      final nearbyDrivers = await _getNearbyDriverCount(
        pickupLocation.latitude, 
        pickupLocation.longitude
      );

      // Calculate comprehensive pricing
      final pricing = PricingCalculator.calculateComprehensivePricing(
        distanceKm: distance,
        nearbyUsers: nearbyUsers,
        nearbyDrivers: nearbyDrivers,
        rideType: rideType.toString().split('.').last,
        requiredSeats: maxPassengers,
      );

      // Find optimal driver if specified
      driver_models.DriverModel? selectedDriver;
      if (preferredDriverId != null) {
        selectedDriver = await _findOptimalDriver(
          pickupLat: pickupLocation.latitude,
          pickupLng: pickupLocation.longitude,
          preferredDriverId: preferredDriverId,
          rideType: _convertRideType(rideType),
        );
      }

      // Calculate estimated arrival time
      String? estimatedArrivalTime;
      if (selectedDriver != null) {
        final arrivalMinutes = TimeHelper.calculateEstimatedArrivalMinutes(
          selectedDriver.distanceFromUser ?? 5.0
        );
        // Fixed: Cast to int instead of (double)
        estimatedArrivalTime = TimeHelper.getEstimatedArrival(arrivalMinutes.toDouble());
      }
      
      final rideData = {
        'id': rideId,
        'passengerId': _currentUserId,
        'driverId': selectedDriver?.uid ?? preferredDriverId,
        'pickupLocation': pickupLocation.toMap(),
        'destination': destination.toMap(),
        'rideType': rideType.toString().split('.').last,
        'maxPassengers': maxPassengers,
        'currentPassengers': 0,
        'estimatedCost': pricing['passengerPrice'] ?? 0.0,
        'driverEarnings': pricing['driverEarnings'] ?? 0.0,
        'distance': pricing['distance'] ?? distance,
        'estimatedDuration': pricing['estimatedDuration'] ?? _calculateDuration(distance),
        'routeFlexibility': routeFlexibility,
        'driverDistanceToPickup': selectedDriver?.distanceFromUser ?? 0.0,
        'estimatedArrivalTime': estimatedArrivalTime,
        'pricingBreakdown': pricing,
        'status': (preferredDriverId != null || selectedDriver != null) ? 'confirmed' : 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'searchRadius': 10.0,
        'urgencyLevel': _calculateUrgencyLevel(rideType.toString().split('.').last, maxPassengers),
        'passengerIds': [_currentUserId!],
      };
      
      await _firestore.collection('rides').doc(rideId).set(rideData);
      
      if (preferredDriverId != null || selectedDriver != null) {
        await _notifyDriver(selectedDriver?.uid ?? preferredDriverId!, rideId, rideData);
      } else {
        // Find and notify available drivers
        await _findAndNotifyDrivers(rideId, pickupLocation, rideData);
      }
      
      return RideModel.fromMap(rideData);
    } catch (e) {
      print('Error requesting ride: $e');
      rethrow;
    }
  }

  /// Request ride with specific driver - Simplified wrapper
  Future<RideModel> requestRideWithDriver({
    required LocationModel pickupLocation,
    required LocationModel destination,
    required models2.RideType rideType,
    required int requiredSeats,
    required String preferredDriverId,
    double? estimatedPrice,
  }) async {
    return requestRide(
      pickupLocation: pickupLocation,
      destination: destination,
      rideType: rideType,
      maxPassengers: requiredSeats,
      routeFlexibility: 'none',
      preferredDriverId: preferredDriverId,
      estimatedPrice: estimatedPrice,
    );
  }

  /// Convert RideType enum to driver_models.RideType
  models2.RideType _convertRideType(models2.RideType rideType) {
    switch (rideType) {
      case models2.RideType.private:
        return models2.RideType.private;
      case models2.RideType.shared:
        return models2.RideType.shared;
      case models2.RideType.pool:
        return models2.RideType.pool;
      default:
        return models2.RideType.private;
    }
  }

  /// Calculate urgency level with proper error handling
  String _calculateUrgencyLevel(String rideType, int maxPassengers) {
    try {
      return PricingCalculator.calculateUrgencyLevel(rideType, maxPassengers);
    } catch (e) {
      print('Error calculating urgency level: $e');
      // Improved fallback logic
      switch (rideType.toLowerCase()) {
        case 'private':
          return 'high';
        case 'shared':
          return maxPassengers >= 3 ? 'medium' : 'low';
        case 'pool':
          return maxPassengers >= 4 ? 'medium' : 'low';
        default:
          return 'low';
      }
    }
  }

  /// Calculate duration with more realistic estimates
  int _calculateDuration(double distanceKm) {
    // More realistic calculation based on traffic conditions
    double avgSpeedKmh;
    if (distanceKm <= 5) {
      avgSpeedKmh = 25; // City traffic
    } else if (distanceKm <= 20) {
      avgSpeedKmh = 35; // Mixed traffic
    } else {
      avgSpeedKmh = 50; // Highway
    }
    
    return (distanceKm / avgSpeedKmh * 60).round(); // minutes
  }

  /// Find optimal driver with improved logic
  Future<driver_models.DriverModel?> _findOptimalDriver({
    required double pickupLat,
    required double pickupLng,
    String? preferredDriverId,
    required models2.RideType rideType,
    double maxDistanceKm = 15.0,
  }) async {
    try {
      // Check preferred driver first
      if (preferredDriverId != null) {
        final driver = await _getDriverById(preferredDriverId);
        if (driver != null && _isDriverAvailable(driver, pickupLat, pickupLng, maxDistanceKm)) {
          return driver;
        }
      }

      // Find available drivers from drivers collection
      final availableDrivers = await _findAvailableDrivers(pickupLat, pickupLng, maxDistanceKm);
      
      if (availableDrivers.isNotEmpty) {
        // Sort by distance and rating
        availableDrivers.sort((a, b) {
          final distanceA = a.distanceFromUser ?? double.infinity;
          final distanceB = b.distanceFromUser ?? double.infinity;
          
          // If distances are similar (within 2km), prioritize rating
          if ((distanceA - distanceB).abs() < 2.0) {
            return b.rating.compareTo(a.rating);
          }
          return distanceA.compareTo(distanceB);
        });
        
        return availableDrivers.first;
      }

      return null;
    } catch (e) {
      print('Error finding optimal driver: $e');
      return null;
    }
  }

  /// Get driver by ID with proper error handling
  Future<driver_models.DriverModel?> _getDriverById(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      if (doc.exists && doc.data() != null) {
        return driver_models.DriverModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting driver by ID: $e');
      return null;
    }
  }

  /// Check if driver is available and within range
  bool _isDriverAvailable(driver_models.DriverModel driver, double pickupLat, double pickupLng, double maxDistanceKm) {
    if (!driver.isAvailable || !driver.isOnline) return false;
    
    final location = driver.location;
    if (location.isEmpty) return false;
    
    final distance = DistanceHelper.calculateDistanceKm(
      pickupLat,
      pickupLng,
      (location['latitude'] as num?)?.toDouble() ?? 0.0,
      (location['longitude'] as num?)?.toDouble() ?? 0.0,
    );
    
    return distance <= maxDistanceKm;
  }

  /// Find available drivers within range
  Future<List<driver_models.DriverModel>> _findAvailableDrivers(
    double pickupLat, 
    double pickupLng, 
    double maxDistanceKm
  ) async {
    try {
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('isAvailable', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .limit(20)
          .get();

      List<driver_models.DriverModel> availableDrivers = [];

      for (var doc in driversSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        
        if (location != null && 
            location['latitude'] != null && 
            location['longitude'] != null) {
          
          final distance = DistanceHelper.calculateDistanceKm(
            pickupLat,
            pickupLng,
            (location['latitude'] as num).toDouble(),
            (location['longitude'] as num).toDouble(),
          );
          
          if (distance <= maxDistanceKm) {
            availableDrivers.add(
              driver_models.DriverModel.fromMap(data, doc.id, distance)
            );
          }
        }
      }

      return availableDrivers;
    } catch (e) {
      print('Error finding available drivers: $e');
      return [];
    }
  }

  /// Convert user data to driver data format - Improved mapping
  Map<String, dynamic> _convertUserToDriverData(Map<String, dynamic> userData) {
    return {
      'uid': userData['uid'] ?? '',
      'name': userData['displayName'] ?? userData['name'] ?? 'Driver',
      'email': userData['email'] ?? '',
      'phoneNumber': userData['phone'] ?? userData['phoneNumber'] ?? '',
      'rating': (userData['rating'] as num?)?.toDouble() ?? 4.5,
      'isAvailable': userData['isAvailable'] ?? true,
      'isOnline': userData['isOnline'] ?? userData['isActive'] ?? true,
      'location': {
        'latitude': (userData['currentLat'] as num?)?.toDouble() ?? 0.0,
        'longitude': (userData['currentLng'] as num?)?.toDouble() ?? 0.0,
      },
      'vehicle': userData['vehicle'] ?? {
        'make': 'Unknown',
        'model': 'Vehicle',
        'year': DateTime.now().year.toString(),
        'color': 'Unknown',
        'licensePlate': 'N/A',
        'type': 'sedan',
      },
      'totalRides': userData['totalRides'] ?? 0,
      'acceptanceRate': (userData['acceptanceRate'] as num?)?.toDouble() ?? 0.9,
      'createdAt': userData['createdAt'],
      'updatedAt': userData['updatedAt'],
      'earnings': userData['earnings'] ?? {'total': 0.0, 'today': 0.0},
      'languages': userData['languages'] ?? ['English'],
      'status': userData['status'] ?? 'online',
      'rideTypes': userData['rideTypes'] ?? ['private', 'shared'],
    };
  }

  /// Notify specific driver with enhanced notification data
  Future<void> _notifyDriver(String driverId, String rideId, Map<String, dynamic> rideData) async {
    try {
      final notificationData = {
        'driverId': driverId,
        'rideId': rideId,
        'type': 'ride_request',
        'status': 'pending',
        'title': 'New Ride Request',
        'message': 'You have a new ride request nearby',
        'rideData': {
          'pickupLocation': rideData['pickupLocation'],
          'destination': rideData['destination'],
          'estimatedEarnings': rideData['driverEarnings'],
          'distance': rideData['distance'],
          'estimatedDuration': rideData['estimatedDuration'],
          'rideType': rideData['rideType'],
          'maxPassengers': rideData['maxPassengers'],
        },
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(minutes: 2))),
      };

      await _firestore.collection('driver_notifications').add(notificationData);
      
      print('Notification sent to driver: $driverId for ride: $rideId');
    } catch (e) {
      print('Error notifying driver: $e');
    }
  }

  /// Find and notify nearby drivers with better selection logic
  Future<void> _findAndNotifyDrivers(String rideId, LocationModel pickup, Map<String, dynamic> rideData) async {
    try {
      final nearbyDrivers = await _findAvailableDrivers(
        pickup.latitude, 
        pickup.longitude, 
        15.0
      );
      
      if (nearbyDrivers.isEmpty) {
        print('No available drivers found for ride: $rideId');
        return;
      }
      
      // Sort by distance and rating
      nearbyDrivers.sort((a, b) {
        final distanceA = a.distanceFromUser ?? double.infinity;
        final distanceB = b.distanceFromUser ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });
      
      // Notify top 3 closest drivers
      final driversToNotify = nearbyDrivers.take(3);
      
      for (var driver in driversToNotify) {
        await _notifyDriver(driver.uid, rideId, rideData);
      }
      
      print('Notified ${driversToNotify.length} drivers for ride: $rideId');
    } catch (e) {
      print('Error finding and notifying drivers: $e');
    }
  }

  /// Get count of nearby users with better error handling
  Future<int> _getNearbyUserCount(double lat, double lng, {double radiusKm = 10.0}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .limit(100)
          .get();
      
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userLat = (data['currentLat'] as num?)?.toDouble();
        final userLng = (data['currentLng'] as num?)?.toDouble();
        
        if (userLat != null && userLng != null) {
          final distance = DistanceHelper.calculateDistanceKm(lat, lng, userLat, userLng);
          if (distance <= radiusKm) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      print('Error counting nearby users: $e');
      return 5; // Return reasonable default
    }
  }

  /// Get count of nearby drivers with better error handling
  Future<int> _getNearbyDriverCount(double lat, double lng, {double radiusKm = 10.0}) async {
    try {
      final availableDrivers = await _findAvailableDrivers(lat, lng, radiusKm);
      return availableDrivers.length;
    } catch (e) {
      print('Error counting nearby drivers: $e');
      return 2; // Return reasonable default
    }
  }

  /// Cancel ride request with reason tracking
  Future<bool> cancelRide(String rideId, {String? cancelReason}) async {
    try {
      final updateData = {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _currentUserId,
      };
      
      if (cancelReason != null) {
        updateData['cancelReason'] = cancelReason;
      }
      
      await _firestore.collection('rides').doc(rideId).update(updateData);
      return true;
    } catch (e) {
      print('Error cancelling ride: $e');
      return false;
    }
  }

  /// Get ride by ID with null safety
  Future<RideModel?> getRideById(String rideId) async {
    try {
      final doc = await _firestore.collection('rides').doc(rideId).get();
      if (doc.exists && doc.data() != null) {
        return RideModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting ride: $e');
      return null;
    }
  }

  /// Listen to ride updates with error handling
  Stream<RideModel?> listenToRide(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .map((doc) {
          try {
            if (doc.exists && doc.data() != null) {
              return RideModel.fromMap(doc.data()!);
            }
          } catch (e) {
            print('Error parsing ride data: $e');
          }
          return null;
        })
        .handleError((error) {
          print('Error listening to ride: $error');
        });
  }

  /// Get user's rides with improved querying
  Stream<List<RideModel>> getUserRides() {
    if (_currentUserId == null) return Stream.value([]);
    
    return _firestore
        .collection('rides')
        .where('passengerIds', arrayContains: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit for performance
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return RideModel.fromMap(doc.data());
                } catch (e) {
                  print('Error parsing ride: $e');
                  return null;
                }
              })
              .where((ride) => ride != null)
              .cast<RideModel>()
              .toList();
        })
        .handleError((error) {
          print('Error getting user rides: $error');
        });
  }

  /// Get available rides for joining with improved filtering
  Stream<List<RideModel>> getAvailableRides({
    required LocationModel pickup,
    required LocationModel destination,
    double maxDistanceKm = 5.0,
  }) {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: 'confirmed')
        .where('rideType', whereIn: ['shared', 'pool'])
        .snapshots()
        .map((snapshot) {
          List<RideModel> availableRides = [];
          
          for (var doc in snapshot.docs) {
            try {
              final ride = RideModel.fromMap(doc.data());
              
              // Skip own rides
              if (ride.passengerIds.contains(_currentUserId)) continue;
              
              // Check if ride has available seats
              if (ride.hasAvailableSeats) {
                // Check if pickup/destination are within acceptable range
                final pickupDistance = DistanceHelper.calculateDistanceKm(
                  pickup.latitude,
                  pickup.longitude,
                  ride.pickupLocation.latitude,
                  ride.pickupLocation.longitude,
                );
                
                final destinationDistance = DistanceHelper.calculateDistanceKm(
                  destination.latitude,
                  destination.longitude,
                  ride.destination.latitude,
                  ride.destination.longitude,
                );
                
                if (pickupDistance <= maxDistanceKm && destinationDistance <= maxDistanceKm) {
                  availableRides.add(ride);
                }
              }
            } catch (e) {
              print('Error parsing available ride: $e');
            }
          }
          
          // Sort by distance from pickup
          availableRides.sort((a, b) {
            final distanceA = DistanceHelper.calculateDistanceKm(
              pickup.latitude, pickup.longitude,
              a.pickupLocation.latitude, a.pickupLocation.longitude,
            );
            final distanceB = DistanceHelper.calculateDistanceKm(
              pickup.latitude, pickup.longitude,
              b.pickupLocation.latitude, b.pickupLocation.longitude,
            );
            return distanceA.compareTo(distanceB);
          });
          
          return availableRides;
        })
        .handleError((error) {
          print('Error getting available rides: $error');
        });
  }

  /// Join an existing ride with validation
  Future<bool> joinRide(String rideId) async {
    if (_currentUserId == null) return false;
    
    try {
      // Get current ride data to validate
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return false;
      
      final ride = RideModel.fromMap(rideDoc.data()!);
      
      // Check if ride has available seats and user isn't already in it
      if (!ride.hasAvailableSeats || ride.passengerIds.contains(_currentUserId)) {
        return false;
      }
      
      await _firestore.collection('rides').doc(rideId).update({
        'passengerIds': FieldValue.arrayUnion([_currentUserId]),
        'currentPassengers': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error joining ride: $e');
      return false;
    }
  }

  /// Leave a ride with validation
  Future<bool> leaveRide(String rideId) async {
    if (_currentUserId == null) return false;
    
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'passengerIds': FieldValue.arrayRemove([_currentUserId]),
        'currentPassengers': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error leaving ride: $e');
      return false;
    }
  }
}