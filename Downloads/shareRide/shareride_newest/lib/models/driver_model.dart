//----------------------------------------------------------------
// driver_model.dart - Driver data model
//----------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class DriverModel {
  final String uid;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final double rating;
  final int totalRides;
  final bool isAvailable;
  final bool isOnline;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime lastActive;
  final Map<String, dynamic> location;
  final List<String> rideTypes;
  final Map<String, dynamic> vehicle;
  final double? distanceFromUser;
  final Map<String, dynamic> earnings;
  final List<String> languages;
  final String status;

  DriverModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.rating,
    required this.totalRides,
    required this.isAvailable,
    required this.isOnline,
    required this.isVerified,
    required this.createdAt,
    required this.lastActive,
    required this.location,
    required this.rideTypes,
    required this.vehicle,
    this.distanceFromUser,
    required this.earnings,
    required this.languages,
    required this.status,
  });

  factory DriverModel.fromMap(Map<String, dynamic> data, String uid, [double? distance]) {
    return DriverModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRides: data['totalRides'] ?? 0,
      isAvailable: data['isAvailable'] ?? false,
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] ?? {},
      rideTypes: List<String>.from(data['rideTypes'] ?? []),
      vehicle: data['vehicle'] ?? {},
      distanceFromUser: distance,
      earnings: data['earnings'] ?? {},
      languages: List<String>.from(data['languages'] ?? ['English']),
      status: data['status'] ?? 'offline',
    );
  }

  /// Create DriverModel from JSON string
  factory DriverModel.fromJson(String jsonString) {
    final Map<String, dynamic> data = json.decode(jsonString);
    return DriverModel.fromMap(data, data['uid'] ?? '');
  }

  /// Get current latitude from location
  double? get currentLat {
    if (location['latitude'] != null) {
      return (location['latitude'] as num).toDouble();
    }
    return null;
  }

  /// Get current longitude from location
  double? get currentLng {
    if (location['longitude'] != null) {
      return (location['longitude'] as num).toDouble();
    }
    return null;
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'rating': rating,
      'totalRides': totalRides,
      'isAvailable': isAvailable,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'location': location,
      'rideTypes': rideTypes,
      'vehicle': vehicle,
      'earnings': earnings,
      'languages': languages,
      'status': status,
    };
  }

  /// Convert to JSON-serializable Map (includes uid and handles DateTime conversion)
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'rating': rating,
      'totalRides': totalRides,
      'isAvailable': isAvailable,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
      'location': location,
      'rideTypes': rideTypes,
      'vehicle': vehicle,
      'distanceFromUser': distanceFromUser,
      'earnings': earnings,
      'languages': languages,
      'status': status,
    };
  }

  /// Convert to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }

  DriverModel copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    double? rating,
    int? totalRides,
    bool? isAvailable,
    bool? isOnline,
    bool? isVerified,
    DateTime? lastActive,
    Map<String, dynamic>? location,
    List<String>? rideTypes,
    Map<String, dynamic>? vehicle,
    double? distanceFromUser,
    Map<String, dynamic>? earnings,
    List<String>? languages,
    String? status,
  }) {
    return DriverModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      isAvailable: isAvailable ?? this.isAvailable,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      location: location ?? this.location,
      rideTypes: rideTypes ?? this.rideTypes,
      vehicle: vehicle ?? this.vehicle,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      earnings: earnings ?? this.earnings,
      languages: languages ?? this.languages,
      status: status ?? this.status,
    );
  }

  /// Check if driver is currently available for rides
  bool get isCurrentlyAvailable {
    return isOnline && isAvailable && isVerified && status == 'online';
  }

  /// Get driver's vehicle type
  String get vehicleType {
    return vehicle['type'] ?? 'Unknown';
  }

  /// Get driver's vehicle model
  String get vehicleModel {
    return vehicle['model'] ?? 'Unknown';
  }

  /// Get driver's vehicle color
  String get vehicleColor {
    return vehicle['color'] ?? 'Unknown';
  }

  /// Get driver's vehicle license plate
  String get vehicleLicensePlate {
    return vehicle['licensePlate'] ?? '';
  }

  /// Get formatted distance from user
  String get formattedDistance {
    if (distanceFromUser == null) return 'Unknown distance';
    if (distanceFromUser! < 1) {
      return '${(distanceFromUser! * 1000).round()}m away';
    }
    return '${distanceFromUser!.toStringAsFixed(1)}km away';
  }

  /// Get driver's primary language
  String get primaryLanguage {
    return languages.isNotEmpty ? languages.first : 'English';
  }

  /// Check if driver speaks a specific language
  bool speaksLanguage(String language) {
    return languages.map((l) => l.toLowerCase()).contains(language.toLowerCase());
  }

  /// Get formatted rating
  String get formattedRating {
    return '${rating.toStringAsFixed(1)}⭐';
  }

  /// Get total earnings
  double get totalEarnings {
    return (earnings['total'] ?? 0.0).toDouble();
  }

  @override
  String toString() {
    return 'DriverModel(uid: $uid, name: $name, rating: $rating, isAvailable: $isAvailable, distance: $distanceFromUser)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  get vehicleInfo => null;
}
