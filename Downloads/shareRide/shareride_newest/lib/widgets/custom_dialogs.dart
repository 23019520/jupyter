import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_type.dart';
import '../models/user_model.dart' ;
import '../models/driver_model.dart' as models2;
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class CustomDialogs {
  // Cache for computed distances to avoid recalculation
  static final Map<String, double> _distanceCache = {};

  /// Shows user profile dialog with ride invitation option
  static void showUserProfile({
    required BuildContext context,
    required UserModel user,
    Position? currentPosition,
    required VoidCallback onInviteToRide,
  }) {
    final distance = _computeUserDistance(currentPosition, user);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info
              _UserProfileHeader(user: user),
              
              const SizedBox(height: 24),
              
              // User Stats
              _buildProfileSection(
                icon: Icons.person,
                title: 'Rider Information',
                children: [
                  _buildStatRow('Total Rides', user.totalRides.toString()),
                  _buildStatRow('Experience', user.experienceLevel),
                  _buildStatRow('Rating', user.ratingDisplay),
                  if (distance != null)
                    _buildStatRow('Distance', '${distance.toStringAsFixed(1)} km away'),
                  if (user.phone?.isNotEmpty == true)
                    _buildStatRow('Phone', _formatPhoneNumber(user.phone!)),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              _ActionButtonRow(
                primaryLabel: 'Invite to Ride',
                primaryIcon: Icons.group_add,
                onPrimary: () {
                  Navigator.pop(context);
                  onInviteToRide();
                },
                onSecondary: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows driver profile dialog with ride request option
  static void showDriverProfile({
    required BuildContext context,
    required models2.DriverModel driverModel,
    Position? currentPosition,
    required VoidCallback onRequestRide,
  }) {
    final distance = _computeDriverDistance(currentPosition, driverModel);
    final vehicleInfo = _buildVehicleInfo(driverModel.vehicle);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Header
                _DriverProfileHeader(driver: driverModel),
                
                const SizedBox(height: 24),
                
                // Vehicle Information
                if (vehicleInfo.isNotEmpty)
                  _buildProfileSection(
                    icon: Icons.directions_car,
                    title: 'Vehicle Details',
                    children: [
                      _buildStatRow('Vehicle', vehicleInfo),
                      if (driverModel.vehicle['licensePlate']?.isNotEmpty == true)
                        _buildStatRow('License Plate', 
                          driverModel.vehicle['licensePlate']!.toUpperCase()),
                      if (driverModel.vehicle['color']?.isNotEmpty == true)
                        _buildStatRow('Color', 
                          _capitalize(driverModel.vehicle['color']!)),
                    ],
                  ),
                
                const SizedBox(height: 20),
                
                // Driver Stats
                _buildProfileSection(
                  icon: Icons.analytics_outlined,
                  title: 'Driver Statistics',
                  children: [
                    _buildStatRow('Rating', 
                      '${driverModel.rating.toStringAsFixed(1)} ⭐'),
                    if (distance != null)
                      _buildStatRow('Distance', 
                        '${distance.toStringAsFixed(1)} km away'),
                    _buildStatRow('Status', 
                      driverModel.isAvailable ? 'Available now' : 'Currently busy'),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                _ActionButtonRow(
                  primaryLabel: 'Request Ride',
                  primaryIcon: Icons.directions_car,
                  primaryEnabled: driverModel.isAvailable,
                  onPrimary: driverModel.isAvailable ? () {
                    Navigator.pop(context);
                    onRequestRide();
                  } : null,
                  onSecondary: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows ride options bottom sheet for booking rides
  static void showRideOptions({
    required BuildContext context,
    required models2.DriverModel driverModel,
    required LocationModel destination,
    required Position currentPosition,
    Map<String, dynamic>? pricingInfo,
    required int nearbyUsers,
    required int nearbyDrivers,
    required Function(models2.DriverModel) onBookRide,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Driver info
                  _buildDriverHeader(driverModel),
                  const SizedBox(height: 24),
                  
                  // Ride type options
                  const Text(
                    'Choose Your Ride:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  if (pricingInfo != null) ...[
                    _buildRideTypeCard(
                      context: context,
                      title: 'Private Ride',
                      subtitle: 'Just you, premium comfort',
                      price: pricingInfo['private']?.toDouble() ?? 0.0,
                      icon: Icons.person,
                      color: Colors.purple,
                      savings: null,
                      onTap: () {
                        Navigator.pop(context);
                        onBookRide(RideType.private as models2.DriverModel);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildRideTypeCard(
                      context: context,
                      title: 'Shared Ride',
                      subtitle: 'Share with other riders',
                      price: pricingInfo['shared']?.toDouble() ?? 0.0,
                      icon: Icons.people,
                      color: Colors.blue,
                      savings: nearbyUsers == 0 ? '35% off' : '20% off',
                      onTap: () {
                        Navigator.pop(context);
                        onBookRide(RideType.shared as models2.DriverModel);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildRideTypeCard(
                      context: context,
                      title: 'Pool Ride',
                      subtitle: 'Multiple stops, multiple riders',
                      price: pricingInfo['pool']?.toDouble() ?? 0.0,
                      icon: Icons.groups,
                      color: Colors.green,
                      savings: '30% off',
                      onTap: () {
                        Navigator.pop(context);
                        onBookRide(RideType.pool as models2.DriverModel);
                      },
                    ),
                  ] else ...[
                    // Fallback when pricing info is not available
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pricing information is being calculated...',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Trip details
                  _buildTripDetails(destination, pricingInfo, nearbyDrivers),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows confirmation dialog for ride booking
  static Future<bool> showBookingConfirmation({
    required BuildContext context,
    required models2.DriverModel rideType,
    required models2.DriverModel driverModel,
    required double estimatedPrice,
    LocationModel? destination,
  }) async {
    final vehicleInfo = _buildVehicleInfo(driverModel.vehicle);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirm Booking'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookingDetailRow(
                label: 'Driver',
                value: driverModel.name,
                icon: Icons.person,
              ),
              if (vehicleInfo.isNotEmpty)
                _BookingDetailRow(
                  label: 'Vehicle',
                  value: vehicleInfo,
                  icon: Icons.directions_car,
                ),
              _BookingDetailRow(
                label: 'Ride Type',
                value: rideType.name.toUpperCase(),
                icon: Icons.category,
              ),
              if (destination != null)
                _BookingDetailRow(
                  label: 'Destination',
                  value: destination.name,
                  icon: Icons.location_on,
                ),
              _BookingDetailRow(
                label: 'Estimated Price',
                value: 'R${estimatedPrice.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                isHighlighted: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 Your driver will be notified and will contact you shortly.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Shows error dialog with retry option
  static void showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onRetry,
    bool isDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Shows loading dialog with optional progress indicator
  static void showLoadingDialog({
    required BuildContext context,
    required String message,
    bool showProgress = false,
    double? progress,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress && progress != null)
                LinearProgressIndicator(value: progress)
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows success dialog with custom action
  static void showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onPressed?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  // Helper methods for distance calculations with caching
  static double? _computeUserDistance(Position? currentPosition, UserModel user) {
    if (currentPosition == null || !user.hasLocation) return null;
    
    final key = '${currentPosition.latitude},${currentPosition.longitude}-${user.currentLat},${user.currentLng}';
    
    if (_distanceCache.containsKey(key)) {
      return _distanceCache[key];
    }
    
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      user.currentLat!,
      user.currentLng!,
    ) / 1000;
    
    _distanceCache[key] = distance;
    return distance;
  }

  static double? _computeDriverDistance(Position? currentPosition, models2.DriverModel driverModel) {
    if (currentPosition == null) return driverModel.distanceFromUser;
    
    double? lat, lng;
    
    // Try different location key formats
    if (driverModel.location.containsKey('latitude') && 
        driverModel.location.containsKey('longitude')) {
      lat = driverModel.location['latitude']?.toDouble();
      lng = driverModel.location['longitude']?.toDouble();
    } else if (driverModel.location.containsKey('lat') && 
               driverModel.location.containsKey('lng')) {
      lat = driverModel.location['lat']?.toDouble();
      lng = driverModel.location['lng']?.toDouble();
    }
    
    if (lat == null || lng == null) return driverModel.distanceFromUser;
    
    final key = '${currentPosition.latitude},${currentPosition.longitude}-$lat,$lng';
    
    if (_distanceCache.containsKey(key)) {
      return _distanceCache[key];
    }
    
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      lat,
      lng,
    ) / 1000;
    
    _distanceCache[key] = distance;
    return distance;
  }

  // Helper method to build vehicle information
  static String _buildVehicleInfo(Map<String, dynamic> vehicle) {
    if (vehicle.isEmpty) return '';
    
    final parts = <String>[];
    
    if (vehicle['year']?.toString().isNotEmpty == true) {
      parts.add(vehicle['year'].toString());
    }
    if (vehicle['make']?.toString().isNotEmpty == true) {
      parts.add(vehicle['make'].toString());
    }
    if (vehicle['model']?.toString().isNotEmpty == true) {
      parts.add(vehicle['model'].toString());
    }
    
    return parts.join(' ').trim();
  }

  // Utility methods
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String _formatPhoneNumber(String phone) {
    // Basic phone formatting - can be enhanced based on requirements
    return phone.replaceAllMapped(RegExp(r'(\d{3})(\d{3})(\d{4})'), 
        (Match m) => '(${m[1]}) ${m[2]}-${m[3]}');
  }

  // Clear distance cache periodically to prevent memory leaks
  static void clearDistanceCache() {
    _distanceCache.clear();
  }

  // Helper Widgets
  static Widget _buildProfileSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children.map((child) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: child,
        )),
      ],
    );
  }

  static Widget _buildStatRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildDriverHeader(models2.DriverModel driverModel) {
    final vehicleInfo = _buildVehicleInfo(driverModel.vehicle);

    return Row(
      children: [
        Hero(
          tag: 'driver_${driverModel.uid}',
          child: CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              driverModel.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driverModel.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vehicleInfo.isNotEmpty 
                    ? '$vehicleInfo • ${driverModel.rating.toStringAsFixed(1)}⭐'
                    : '${driverModel.rating.toStringAsFixed(1)}⭐',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: driverModel.isAvailable 
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            driverModel.isAvailable ? 'Available' : 'Busy',
            style: TextStyle(
              color: driverModel.isAvailable ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildRideTypeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double price,
    required IconData icon,
    required Color color,
    String? savings,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (savings != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              savings,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (savings != null)
                    Text(
                      'Save money!',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildTripDetails(
    LocationModel destination,
    Map<String, dynamic>? pricingInfo,
    int nearbyDrivers,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.my_location, color: Colors.blue, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Current Location',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.location_on, color: Colors.red, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (pricingInfo != null) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${pricingInfo['distance']?.toStringAsFixed(1) ?? '—'} km',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  '$nearbyDrivers driver${nearbyDrivers != 1 ? 's' : ''} nearby',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Helper widgets as separate classes for better organization
class _UserProfileHeader extends StatelessWidget {
  final UserModel user;

  const _UserProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Hero(
          tag: 'user_${user.uid}',
          child: CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              user.displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverProfileHeader extends StatelessWidget {
  final models2.DriverModel driver;

  const _DriverProfileHeader({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Hero(
          tag: 'driver_${driver.uid}',
          child: CircleAvatar(
            radius: 30,
            backgroundColor: driver.isAvailable ? Colors.green : Colors.grey,
            child: Text(
              driver.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${driver.rating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: driver.isAvailable
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      driver.isAvailable ? 'Available' : 'Busy',
                      style: TextStyle(
                        color: driver.isAvailable ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButtonRow extends StatelessWidget {
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool primaryEnabled;
  final String secondaryLabel;

  const _ActionButtonRow({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.onSecondary,
    this.primaryEnabled = true,
    this.secondaryLabel = 'Close',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onSecondary,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(secondaryLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryEnabled 
                  ? AppColors.primary 
                  : Colors.grey,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: primaryEnabled ? onPrimary : null,
          ),
        ),
      ],
    );
  }
}

class _BookingDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  const _BookingDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon, 
              size: 16, 
              color: isHighlighted ? AppColors.primary : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                    color: isHighlighted ? AppColors.primary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}