
//----------------------------------------------------------------
// ride_type.dart - Ride type enumeration
//----------------------------------------------------------------

enum RideType {
  economy,
  standard,
  comfort,
  luxury,
  business,
  suv,
  van,
  pool,
  shared,
  private,
}

extension RideTypeExtension on RideType {
  String get displayName {
    switch (this) {
      case RideType.economy:
        return 'Economy';
      case RideType.standard:
        return 'Standard';
      case RideType.comfort:
        return 'Comfort';
      case RideType.luxury:
        return 'Luxury';
      case RideType.business:
        return 'Business';
      case RideType.suv:
        return 'SUV';
      case RideType.van:
        return 'Van';
      case RideType.pool:
        return 'Pool';
      case RideType.shared:
        return 'Shared';
      case RideType.private:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case RideType.economy:
        return 'Budget-friendly rides';
      case RideType.standard:
        return 'Standard comfort rides';
      case RideType.comfort:
        return 'Extra comfort and space';
      case RideType.luxury:
        return 'Premium luxury vehicles';
      case RideType.business:
        return 'Professional business rides';
      case RideType.suv:
        return 'SUV for groups';
      case RideType.van:
        return 'Large groups and luggage';
      case RideType.pool:
        return 'Share with others';
      case RideType.shared:
        return 'Shared ride options';
      case RideType.private:
        return 'Private dedicated ride';
    }
  }

  int get maxPassengers {
    switch (this) {
      case RideType.economy:
      case RideType.standard:
        return 4;
      case RideType.comfort:
      case RideType.luxury:
      case RideType.business:
        return 4;
      case RideType.suv:
        return 6;
      case RideType.van:
        return 8;
      case RideType.pool:
      case RideType.shared:
        return 4;
      case RideType.private:
        return 4;
    }
  }

  double get priceMultiplier {
    switch (this) {
      case RideType.economy:
        return 0.8;
      case RideType.standard:
        return 1.0;
      case RideType.comfort:
        return 1.2;
      case RideType.luxury:
        return 2.0;
      case RideType.business:
        return 1.8;
      case RideType.suv:
        return 1.4;
      case RideType.van:
        return 1.6;
      case RideType.pool:
        return 0.7;
      case RideType.shared:
        return 0.8;
      case RideType.private:
        return 2.0;
    }
  }

  /// Get the icon name for this ride type
  String get iconName {
    switch (this) {
      case RideType.economy:
        return 'economy_car';
      case RideType.standard:
        return 'standard_car';
      case RideType.comfort:
        return 'comfort_car';
      case RideType.luxury:
        return 'luxury_car';
      case RideType.business:
        return 'business_car';
      case RideType.suv:
        return 'suv';
      case RideType.van:
        return 'van';
      case RideType.pool:
        return 'pool_car';
      case RideType.shared:
        return 'shared_car';
      case RideType.private:
        return 'private_car';
    }
  }

  /// Convert string to RideType enum
  static RideType? fromString(String value) {
    return RideType.values.firstWhere(
      (type) => type.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RideType.standard,
    );
  }

  /// Get color associated with ride type
  String get colorHex {
    switch (this) {
      case RideType.economy:
        return '#4CAF50'; // Green
      case RideType.standard:
        return '#2196F3'; // Blue
      case RideType.comfort:
        return '#FF9800'; // Orange
      case RideType.luxury:
        return '#9C27B0'; // Purple
      case RideType.business:
        return '#607D8B'; // Blue Grey
      case RideType.suv:
        return '#795548'; // Brown
      case RideType.van:
        return '#FF5722'; // Deep Orange
      case RideType.pool:
        return '#00BCD4'; // Cyan
      case RideType.shared:
        return '#8BC34A'; // Light Green
      case RideType.private:
        return '#E91E63'; // Pink
    }
  }
}