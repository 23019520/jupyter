// lib/models/ride_model.dart - Updated to work with the fixed RideService
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_model.dart';

enum RideType {
  private,
  shared,
  pool,
}

enum RideStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
}

class RideModel {
  final String id;
  final LocationModel pickupLocation;
  final LocationModel destination;
  final RideType rideType;
  final RideStatus status;
  final double estimatedCost;
  final int distance; // in meters
  final int maxPassengers;
  final int currentPassengers;
  final String routeFlexibility;
  final DateTime createdAt;
  final DateTime? estimatedArrival;
  final String? driverId;
  final String? driverName;
  final String? vehicleInfo;
  final List<String> passengerIds;
  final Map<String, dynamic>? metadata;

  RideModel({
    required this.id,
    required this.pickupLocation,
    required this.destination,
    required this.rideType,
    required this.status,
    required this.estimatedCost,
    required this.distance,
    required this.maxPassengers,
    required this.currentPassengers,
    required this.routeFlexibility,
    required this.createdAt,
    this.estimatedArrival,
    this.driverId,
    this.driverName,
    this.vehicleInfo,
    List<String>? passengerIds,
    this.metadata,
  }) : passengerIds = passengerIds ?? [];

  // Calculate cost per passenger for shared rides
  double get costPerPassenger {
    if (rideType == RideType.shared && maxPassengers > 0) {
      return estimatedCost / maxPassengers;
    }
    return estimatedCost;
  }

  // Check if ride has available seats
  bool get hasAvailableSeats {
    return currentPassengers < maxPassengers;
  }

  // Get number of available seats
  int get availableSeats {
    return maxPassengers - currentPassengers;
  }

  // Check if ride is active (not cancelled or completed)
  bool get isActive {
    return status != RideStatus.cancelled && status != RideStatus.completed;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pickupLocation': pickupLocation.toMap(),
      'destination': destination.toMap(),
      'rideType': rideType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'estimatedCost': estimatedCost,
      'distance': distance,
      'maxPassengers': maxPassengers,
      'currentPassengers': currentPassengers,
      'routeFlexibility': routeFlexibility,
      'createdAt': createdAt.toIso8601String(),
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'driverId': driverId,
      'driverName': driverName,
      'vehicleInfo': vehicleInfo,
      'passengerIds': passengerIds,
      'metadata': metadata,
    };
  }

  // Updated fromMap method to handle both cases
  factory RideModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return RideModel(
      id: docId ?? map['id'] ?? '',
      pickupLocation: LocationModel.fromMap(map['pickupLocation'] ?? {}),
      destination: LocationModel.fromMap(map['destination'] ?? {}),
      rideType: _parseRideType(map['rideType']),
      status: _parseRideStatus(map['status']),
      estimatedCost: (map['estimatedCost'] ?? map['estimatedPrice'] ?? 0.0).toDouble(),
      distance: map['distance'] ?? 0,
      maxPassengers: map['maxPassengers'] ?? 1,
      currentPassengers: map['currentPassengers'] ?? 0,
      routeFlexibility: map['routeFlexibility'] ?? 'low',
      createdAt: _parseDateTime(map['createdAt']),
      estimatedArrival: _parseDateTime(map['estimatedArrival'] ?? map['estimatedArrivalTime']),
      driverId: map['driverId'] ?? map['assignedDriverId'],
      driverName: map['driverName'],
      vehicleInfo: map['vehicleInfo'],
      passengerIds: List<String>.from(map['passengerIds'] ?? []),
      metadata: map['metadata'],
    );
  }

  // Helper method to parse DateTime from various formats
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static RideType _parseRideType(String? type) {
    switch (type) {
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

  static RideStatus _parseRideStatus(String? status) {
    switch (status) {
      case 'pending':
        return RideStatus.pending;
      case 'confirmed':
        return RideStatus.confirmed;
      case 'inProgress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.pending;
    }
  }

  RideModel copyWith({
    String? id,
    LocationModel? pickupLocation,
    LocationModel? destination,
    RideType? rideType,
    RideStatus? status,
    double? estimatedCost,
    int? distance,
    int? maxPassengers,
    int? currentPassengers,
    String? routeFlexibility,
    DateTime? createdAt,
    DateTime? estimatedArrival,
    String? driverId,
    String? driverName,
    String? vehicleInfo,
    List<String>? passengerIds,
    Map<String, dynamic>? metadata,
  }) {
    return RideModel(
      id: id ?? this.id,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destination: destination ?? this.destination,
      rideType: rideType ?? this.rideType,
      status: status ?? this.status,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      distance: distance ?? this.distance,
      maxPassengers: maxPassengers ?? this.maxPassengers,
      currentPassengers: currentPassengers ?? this.currentPassengers,
      routeFlexibility: routeFlexibility ?? this.routeFlexibility,
      createdAt: createdAt ?? this.createdAt,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      passengerIds: passengerIds ?? this.passengerIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'RideModel(id: $id, from: ${pickupLocation.name}, to: ${destination.name}, type: $rideType, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RideModel && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}