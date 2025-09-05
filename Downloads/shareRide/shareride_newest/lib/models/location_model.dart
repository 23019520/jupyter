class LocationModel {
  final String name;           // For ShareRideScreen
  final String address;        // For LocationService (can be same as name)
  final double latitude;
  final double longitude;
  final int distance;          // in meters - for ShareRideScreen
  final double estimatedCost;  // for ShareRideScreen  
  final DateTime timestamp;    // for LocationService
  final double? distanceFromUser; // for LocationService (optional)

  LocationModel({
    required this.name,
     this.address = '',          // Optional - will use name if not provided
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.estimatedCost,
    DateTime? timestamp,       // Optional - will use current time if not provided
    this.distanceFromUser,
  })  :
    timestamp = timestamp ?? DateTime.now();

  // Factory constructor for LocationService usage
  factory LocationModel.fromCoordinates({
    required double latitude,
    required double longitude,
    required String address,
    DateTime? timestamp,
    double? distanceFromUser,
  }) {
    return LocationModel(
      name: address,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distance: 0, // Will be calculated elsewhere
      estimatedCost: 0.0, // Will be calculated elsewhere
      timestamp: timestamp,
      distanceFromUser: distanceFromUser,
    );
  }

  // Factory constructor for ShareRideScreen usage
  factory LocationModel.forRide({
    required String name,
    required double latitude,
    required double longitude,
    required int distance,
    required double estimatedCost,
  }) {
    return LocationModel(
      name: name,
      latitude: latitude,
      longitude: longitude,
      distance: distance,
      estimatedCost: estimatedCost,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'estimatedCost': estimatedCost,
      'timestamp': timestamp.toIso8601String(),
      'distanceFromUser': distanceFromUser,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      name: map['name'] ?? map['address'] ?? '',
      address: map['address'] ?? map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      distance: map['distance'] ?? 0,
      estimatedCost: map['estimatedCost']?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      distanceFromUser: map['distanceFromUser']?.toDouble(),
    );
  }

  // Copy method for updating specific fields
  LocationModel copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? distance,
    double? estimatedCost,
    DateTime? timestamp,
    double? distanceFromUser,
  }) {
    return LocationModel(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      timestamp: timestamp ?? this.timestamp,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
    );
  }

  @override
  String toString() {
    return 'LocationModel(name: $name, lat: $latitude, lng: $longitude, distance: ${distance}m)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.name == name;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^ longitude.hashCode ^ name.hashCode;
  }
}