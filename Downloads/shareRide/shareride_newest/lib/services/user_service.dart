import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/helpers.dart';
import '../models/user_model.dart';
import '../models/driver_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _driversCollection = 'drivers';
  static const String _userLocationsCollection = 'user_locations';
  static const String _driverLocationsCollection = 'driver_locations';

  // Cache
  UserModel? _currentUser;
  DriverModel? _currentDriverProfile;
  Timer? _locationUpdateTimer;
  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;

  /// Get current authenticated user ID
  Future<String?> getCurrentUserId() async {
    try {
      final user = _auth.currentUser;
      return user?.uid;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  /// Get current user profile
  Future<UserModel?> getCurrentUser() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;

      if (_currentUser != null && _currentUser!.uid == userId) {
        return _currentUser;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        return _currentUser;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Get driver profile for a user
  Future<DriverModel?> getDriverProfile(String userId) async {
    try {
      if (_currentDriverProfile != null && _currentDriverProfile!.uid == userId) {
        return _currentDriverProfile;
      }

      final doc = await _firestore
          .collection(_driversCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        _currentDriverProfile = DriverModel.fromMap(doc.data()!, doc.id);
        return _currentDriverProfile;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting driver profile: $e');
      return null;
    }
  }

  /// Update user location in real-time
  Future<void> updateUserLocation(double latitude, double longitude) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return;

      final locationData = {
        'uid': userId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Update in users collection - use set with merge to create if doesn't exist
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set({
        'uid': userId,
        'currentLat': latitude,
        'currentLng': longitude,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      // Update in user_locations collection for real-time tracking
      await _firestore
          .collection(_userLocationsCollection)
          .doc(userId)
          .set(locationData, SetOptions(merge: true));

      // If user is also a driver, update driver location
      final driverProfile = await getDriverProfile(userId);
      if (driverProfile != null) {
        await _updateDriverLocation(userId, latitude, longitude);
      }

      debugPrint('Location updated: $latitude, $longitude');
    } catch (e) {
      debugPrint('Error updating user location: $e');
      rethrow;
    }
  }

  /// Update driver location
  Future<void> _updateDriverLocation(String driverId, double latitude, double longitude) async {
    try {
      final driverLocationData = {
        'uid': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isAvailable': true,
      };

      // Update driver document - use set with merge to create if doesn't exist
      await _firestore
          .collection(_driversCollection)
          .doc(driverId)
          .set({
        'uid': driverId,
        'currentLat': latitude,
        'currentLng': longitude,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      // Update driver_locations collection
      await _firestore
          .collection(_driverLocationsCollection)
          .doc(driverId)
          .set(driverLocationData, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  /// Get nearby users within specified radius
  Future<List<UserModel>> getNearbyUsers(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      // Convert radius from km to degrees (approximate)
      final radiusDegrees = radiusKm / 111.32; // 1 degree ≈ 111.32 km

      final minLat = latitude - radiusDegrees;
      final maxLat = latitude + radiusDegrees;
      final minLng = longitude - radiusDegrees;
      final maxLng = longitude + radiusDegrees;

      // Query users within bounding box
      final query = await _firestore
          .collection(_usersCollection)
          .where('currentLat', isGreaterThanOrEqualTo: minLat)
          .where('currentLat', isLessThanOrEqualTo: maxLat)
          .where('isOnline', isEqualTo: true)
          .limit(50) // Limit results for performance
          .get();

      List<UserModel> nearbyUsers = [];
      final currentUserId = await getCurrentUserId();

      for (var doc in query.docs) {
        try {
          final userData = doc.data();
          
          // Skip current user
          if (userData['uid'] == currentUserId) continue;

          // Check longitude bounds
          final userLng = userData['currentLng']?.toDouble();
          if (userLng == null || userLng < minLng || userLng > maxLng) continue;

          // Calculate precise distance
          final userLat = userData['currentLat']?.toDouble();
          if (userLat == null) continue;

          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            userLat,
            userLng,
          ) / 1000; // Convert to kilometers

          if (distance <= radiusKm) {
            final user = UserModel.fromMap(userData);
            nearbyUsers.add(user);
          }
        } catch (e) {
          debugPrint('Error processing user document: $e');
          continue;
        }
      }

      // Sort by distance (closest first)
      nearbyUsers.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.currentLat!, a.currentLng!);
        final distanceB = _calculateDistance(latitude, longitude, b.currentLat!, b.currentLng!);
        return distanceA.compareTo(distanceB);
      });

      debugPrint('Found ${nearbyUsers.length} nearby users within ${radiusKm}km');
      return nearbyUsers;

    } catch (e) {
      debugPrint('Error getting nearby users: $e');
      return [];
    }
  }

  /// Get nearby drivers within specified radius
  Future<List<DriverModel>> getNearbyDrivers(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      // Convert radius from km to degrees (approximate)
      final radiusDegrees = radiusKm / 111.32;

      final minLat = latitude - radiusDegrees;
      final maxLat = latitude + radiusDegrees;
      final minLng = longitude - radiusDegrees;
      final maxLng = longitude + radiusDegrees;

      // Query drivers within bounding box
      final query = await _firestore
          .collection(_driversCollection)
          .where('currentLat', isGreaterThanOrEqualTo: minLat)
          .where('currentLat', isLessThanOrEqualTo: maxLat)
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .limit(50)
          .get();

      List<DriverModel> nearbyDrivers = [];

      for (var doc in query.docs) {
        try {
          final driverData = doc.data();
          
          // Check longitude bounds
          final driverLng = driverData['currentLng']?.toDouble();
          if (driverLng == null || driverLng < minLng || driverLng > maxLng) continue;

          // Calculate precise distance
          final driverLat = driverData['currentLat']?.toDouble();
          if (driverLat == null) continue;

          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            driverLat,
            driverLng,
          ) / 1000;

          if (distance <= radiusKm) {
            final driver = DriverModel.fromMap(driverData, doc.id);
            nearbyDrivers.add(driver);
          }
        } catch (e) {
          debugPrint('Error processing driver document: $e');
          continue;
        }
      }

      // Sort by distance and rating
      nearbyDrivers.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.currentLat!, a.currentLng!);
        final distanceB = _calculateDistance(latitude, longitude, b.currentLat!, b.currentLng!);

        // First sort by distance, then by rating
        final distanceComparison = distanceA.compareTo(distanceB);
        if (distanceComparison != 0) return distanceComparison;
        
        return b.rating.compareTo(a.rating); // Higher rating first
      });

      debugPrint('Found ${nearbyDrivers.length} nearby drivers within ${radiusKm}km');
      return nearbyDrivers;

    } catch (e) {
      debugPrint('Error getting nearby drivers: $e');
      return [];
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Get driver by ID
  Future<DriverModel?> getDriverById(String driverId) async {
    try {
      final doc = await _firestore
          .collection(_driversCollection)
          .doc(driverId)
          .get();

      if (doc.exists) {
        return DriverModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting driver by ID: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
      
      _currentUser = user;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Update driver profile
  Future<void> updateDriverProfile(DriverModel driver) async {
    try {
      await _firestore
          .collection(_driversCollection)
          .doc(driver.uid)
          .set(driver.toMap(), SetOptions(merge: true));
      
      _currentDriverProfile = driver;
    } catch (e) {
      debugPrint('Error updating driver profile: $e');
      rethrow;
    }
  }

  /// Set user online/offline status
  Future<void> setUserOnlineStatus(bool isOnline) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return;

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set({
        'uid': userId,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update location collection
      await _firestore
          .collection(_userLocationsCollection)
          .doc(userId)
          .set({
        'uid': userId,
        'isActive': isOnline,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Error setting user online status: $e');
    }
  }

  /// Set driver availability status
  Future<void> setDriverAvailability(bool isAvailable) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return;

      await _firestore
          .collection(_driversCollection)
          .doc(userId)
          .set({
        'uid': userId,
        'isAvailable': isAvailable,
        'isOnline': isAvailable, // Available drivers should also be online
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update driver location collection
      await _firestore
          .collection(_driverLocationsCollection)
          .doc(userId)
          .set({
        'uid': userId,
        'isAvailable': isAvailable,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Error setting driver availability: $e');
    }
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    try {
      if (query.trim().isEmpty) return [];

      final nameQuery = await _firestore
          .collection(_usersCollection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(limit)
          .get();

      final emailQuery = await _firestore
          .collection(_usersCollection)
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(limit)
          .get();

      final Set<UserModel> users = {};
      
      // Add results from name search
      for (var doc in nameQuery.docs) {
        try {
          users.add(UserModel.fromMap(doc.data()));
        } catch (e) {
          debugPrint('Error parsing user from name search: $e');
        }
      }
      
      // Add results from email search
      for (var doc in emailQuery.docs) {
        try {
          users.add(UserModel.fromMap(doc.data()));
        } catch (e) {
          debugPrint('Error parsing user from email search: $e');
        }
      }

      return users.toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Start periodic location updates
  void startLocationUpdates({Duration interval = const Duration(seconds: 30)}) {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(interval, (_) async {
      try {
        final position = await Geolocator.getCurrentPosition();
        await updateUserLocation(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('Error in periodic location update: $e');
      }
    });
  }

  /// Stop periodic location updates
  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// Listen to user profile changes
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  /// Listen to driver profile changes
  Stream<DriverModel?> getDriverStream(String driverId) {
    return _firestore
        .collection(_driversCollection)
        .doc(driverId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DriverModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Get real-time nearby users stream
  Stream<List<UserModel>> getNearbyUsersStream(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final radiusDegrees = radiusKm / 111.32;
    
    return _firestore
        .collection(_usersCollection)
        .where('currentLat', isGreaterThanOrEqualTo: latitude - radiusDegrees)
        .where('currentLat', isLessThanOrEqualTo: latitude + radiusDegrees)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserModel> users = [];
      final currentUserId = await getCurrentUserId();
      
      for (var doc in snapshot.docs) {
        try {
          final userData = doc.data();
          
          if (userData['uid'] == currentUserId) continue;
          
          final userLat = userData['currentLat']?.toDouble();
          final userLng = userData['currentLng']?.toDouble();
          
          if (userLat != null && userLng != null) {
            final distance = _calculateDistance(latitude, longitude, userLat, userLng);
            if (distance <= radiusKm) {
              users.add(UserModel.fromMap(userData));
            }
          }
        } catch (e) {
          debugPrint('Error processing user in stream: $e');
        }
      }
      
      return users;
    });
  }

  /// Get real-time nearby drivers stream
  Stream<List<DriverModel>> getNearbyDriversStream(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    final radiusDegrees = radiusKm / 111.32;
    
    return _firestore
        .collection(_driversCollection)
        .where('currentLat', isGreaterThanOrEqualTo: latitude - radiusDegrees)
        .where('currentLat', isLessThanOrEqualTo: latitude + radiusDegrees)
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      List<DriverModel> drivers = [];
      
      for (var doc in snapshot.docs) {
        try {
          final driverData = doc.data();
          
          final driverLat = driverData['currentLat']?.toDouble();
          final driverLng = driverData['currentLng']?.toDouble();
          
          if (driverLat != null && driverLng != null) {
            final distance = _calculateDistance(latitude, longitude, driverLat, driverLng);
            if (distance <= radiusKm) {
              drivers.add(DriverModel.fromMap(driverData, doc.id));
            }
          }
        } catch (e) {
          debugPrint('Error processing driver in stream: $e');
        }
      }
      
      return drivers;
    });
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Create a new user profile
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toMap());
      
      _currentUser = user;
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Create a new driver profile
  Future<void> createDriverProfile(DriverModel driver) async {
    try {
      await _firestore
          .collection(_driversCollection)
          .doc(driver.uid)
          .set(driver.toMap());
      
      _currentDriverProfile = driver;
    } catch (e) {
      debugPrint('Error creating driver profile: $e');
      rethrow;
    }
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete from users collection
      batch.delete(_firestore.collection(_usersCollection).doc(userId));
      
      // Delete from user_locations collection
      batch.delete(_firestore.collection(_userLocationsCollection).doc(userId));
      
      await batch.commit();
      
      if (_currentUser?.uid == userId) {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Error deleting user profile: $e');
      rethrow;
    }
  }

  /// Delete driver profile
  Future<void> deleteDriverProfile(String driverId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete from drivers collection
      batch.delete(_firestore.collection(_driversCollection).doc(driverId));
      
      // Delete from driver_locations collection
      batch.delete(_firestore.collection(_driverLocationsCollection).doc(driverId));
      
      await batch.commit();
      
      if (_currentDriverProfile?.uid == driverId) {
        _currentDriverProfile = null;
      }
    } catch (e) {
      debugPrint('Error deleting driver profile: $e');
      rethrow;
    }
  }

  /// Clean up resources
  void dispose() {
    _locationUpdateTimer?.cancel();
    _userStreamSubscription?.cancel();
    _currentUser = null;
    _currentDriverProfile = null;
  }

  /// Sign out and clean up
  Future<void> signOut() async {
    try {
      // Set user offline before signing out
      await setUserOnlineStatus(false);
      
      // Stop location updates
      stopLocationUpdates();
      
      // Clean up resources
      dispose();
      
      // Sign out from Firebase Auth
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}

/// Extension methods for additional functionality
extension UserServiceExtensions on UserService {
  /// Get user statistics
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      // This would typically query ride history and other collections
      // For now, return mock data
      return {
        'totalRides': 0,
        'rating': 5,
        'totalDistance': 0,
      };
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      return {};
    }
  }

  /// Update user rating
  Future<void> updateUserRating(String userId, double rating) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'rating': rating}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user rating: $e');
      rethrow;
    }
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      return false;
    }
  }
}