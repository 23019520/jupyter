import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final DateTime createdAt;
  final DateTime? lastActive; // ADD THIS - missing lastActive property
  final int totalRides;
  final double totalSpent;
  final double rating;
  final double? currentLat;
  final double? currentLng;
  final double? distanceFromUser;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.createdAt,
    this.lastActive, // ADD THIS
    required this.totalRides,
    required this.totalSpent,
    required this.rating,
    this.currentLat,
    this.currentLng,
    this.distanceFromUser,
  });

  // fromMap constructor for consistency
  factory UserModel.fromMap(Map<String, dynamic> map, [String? uid, double? distance]) {
    return UserModel(
      uid: uid ?? map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt']))
          : DateTime.now(),
      lastActive: map['lastActive'] != null // ADD THIS
          ? (map['lastActive'] is Timestamp 
              ? (map['lastActive'] as Timestamp).toDate()
              : DateTime.parse(map['lastActive']))
          : null,
      totalRides: map['totalRides'] ?? 0,
      totalSpent: (map['totalSpent'] ?? 0.0).toDouble(),
      rating: (map['rating'] ?? 4.5).toDouble(),
      currentLat: map['currentLat']?.toDouble(),
      currentLng: map['currentLng']?.toDouble(),
      distanceFromUser: distance ?? map['distanceFromUser']?.toDouble(),
    );
  }

  // fromFirestore constructor for Firestore integration
  factory UserModel.fromFirestore(DocumentSnapshot doc, [double? distance]) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id, distance);
  }

  // toMap for saving to database
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null, // ADD THIS
      'totalRides': totalRides,
      'totalSpent': totalSpent,
      'rating': rating,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'distanceFromUser': distanceFromUser,
    };
  }

  // copyWith method for creating modified copies
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? lastActive,
    int? totalRides,
    double? totalSpent,
    double? rating,
    double? currentLat,
    double? currentLng,
    double? distanceFromUser,
  }) {
    return UserModel(
      uid: uid, // uid should not be changed
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive, // ADD THIS
      totalRides: totalRides ?? this.totalRides,
      totalSpent: totalSpent ?? this.totalSpent,
      rating: rating ?? this.rating,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
    );
  }

  // toString method for debugging
  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, email: $email, rating: $rating, totalRides: $totalRides, distance: $distanceFromUser, lastActive: $lastActive)';
  }

  // Equality operators
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  // Helper methods
  bool get hasLocation => currentLat != null && currentLng != null;
  
  String get displayName => name.isNotEmpty ? name : 'User';
  
  String get ratingDisplay => '${rating.toStringAsFixed(1)}⭐';
  
  bool get isExperienced => totalRides >= 10;
  
  String get experienceLevel {
    if (totalRides == 0) return 'New User';
    if (totalRides < 5) return 'Beginner';
    if (totalRides < 20) return 'Regular';
    if (totalRides < 50) return 'Experienced';
    return 'Expert';
  }
}