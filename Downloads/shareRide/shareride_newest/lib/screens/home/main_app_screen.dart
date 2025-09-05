import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location_model.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../models/driver_model.dart' as models;
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../services/ride_service.dart';
import '../../screens/ride/ride_request_screen.dart';
import '../../driver/driver_dashboard.dart';
import '../../widgets/custom_dialogs.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart'; // Using your theme.dart file
import 'dart:async';
import 'dart:math' as math;

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Controllers and Services
  GoogleMapController? _mapController;
  late final LocationService _locationService;
  late final RideService _rideService;
  late final UserService _userService;
  final TextEditingController _searchController = TextEditingController();
  
  // Animation Controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late AnimationController _mapOverlayController;
  late AnimationController _panelAnimationController;
  late Animation<Offset> _panelSlideAnimation;
  
  // State Variables
  Position? _currentPosition;
  LocationModel? _selectedDestination;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  
  // UI State
  bool _isLoading = false;
  bool _showDriverMode = false;
  bool _isPanelExpanded = false;
  String _userRole = 'passenger';
  double _searchRadius = 5.0; // Default search radius in km
  
  // Collections
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  List<LocationModel> _searchResults = [];
  List<UserModel> _nearbyUsers = [];
  List<models.DriverModel> _nearbyDrivers = [];
  
  // Pricing and Route Data
  Map<String, dynamic>? _pricingInfo;
  List<LatLng>? _routePoints;
  String? _routePolyline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _setupAnimations();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _startLocationUpdates();
        break;
      case AppLifecycleState.paused:
        _pauseLocationUpdates();
        break;
      default:
        break;
    }
  }

  void _initializeServices() {
    _locationService = LocationService();
    _rideService = RideService();
    _userService = UserService();
  }

  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    
    _mapOverlayController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _panelSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _cleanup() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    
    // Safe disposal - controllers handle their own state internally
    _fabAnimationController.dispose();
    _mapOverlayController.dispose();
    _panelAnimationController.dispose();
    _searchController.dispose();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    
    _setLoadingState(true);
    
    try {
      await Future.wait([
        _getCurrentLocation(),
        _checkUserRole(),
      ]);
      
      _startLocationUpdates();
      await _loadNearbyData();
      
      // Simply start animation if mounted - controller handles disposal internally
      if (mounted) {
        _fabAnimationController.forward();
      }
      
    } catch (e) {
      _handleError('Failed to initialize app', e);
    } finally {
      _setLoadingState(false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _hasLocationPermission();
      if (!hasPermission) {
        final granted = await _requestLocationPermission();
        if (!granted) {
          throw Exception('Location permission denied');
        }
      }

      _currentPosition = await _locationService.getCurrentPosition();
      if (_currentPosition != null) {
        await _updateMapLocation();
        await _updateUserLocation();
      }
    } catch (e) {
      throw Exception('Location error: $e');
    }
  }

  Future<bool> _hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse;
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse;
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = await _userService.getCurrentUserId();
      if (userId != null) {
        // Check if user has driver profile
        _userRole = 'passenger'; // Default to passenger
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      _userRole = 'passenger';
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30), // Update every 30 seconds
      (_) => _performLocationUpdate(),
    );
    
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() => _currentPosition = position);
          _updateMapLocation();
          _updateUserLocation();
        }
      },
      onError: (e) => _handleError('Location stream error', e),
    );
  }

  void _pauseLocationUpdates() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
  }

  Future<void> _performLocationUpdate() async {
    try {
      await _getCurrentLocation();
      await _loadNearbyData();
    } catch (e) {
      debugPrint('Location update failed: $e');
    }
  }

  Future<void> _updateMapLocation() async {
    if (_currentPosition == null || !mounted) return;
    
    _addCurrentLocationMarker();
    _addSearchRadiusCircle();
    
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  Future<void> _updateUserLocation() async {
    if (_currentPosition != null) {
      try {
        await _userService.updateUserLocation(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      } catch (e) {
        debugPrint('Failed to update user location: $e');
      }
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition == null) return;
    
    _markers.removeWhere((m) => m.markerId.value == 'current_location');
    
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(
          title: '📍 Your Location',
          snippet: 'Current position',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    
    if (mounted) setState(() {});
  }

  void _addSearchRadiusCircle() {
    if (_currentPosition == null) return;
    
    _circles.clear();
    _circles.add(
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _searchRadius * 1000,
        fillColor: Colors.blue.withOpacity(0.1),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    );
    
    if (mounted) setState(() {});
  }

  Future<void> _loadNearbyData() async {
    if (_currentPosition == null) return;
    
    try {
      final nearbyUsers = _userService.getNearbyUsers(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );
      
      final nearbyDrivers = _userService.getNearbyDrivers(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );
      
      final results = await Future.wait([nearbyUsers, nearbyDrivers]);
      
      if (mounted) {
        setState(() {
          _nearbyUsers = results[0] as List<UserModel>;
          _nearbyDrivers = (results[1] as List).cast<models.DriverModel>();
        });
        
        _addNearbyMarkersToMap();
        await _updatePricingIfDestinationSelected();
      }
      
    } catch (e) {
      _handleError('Failed to load nearby data', e);
    }
  }

  void _addNearbyMarkersToMap() {
    // Remove existing nearby markers
    _markers.removeWhere((m) => 
        m.markerId.value.startsWith('user_') || 
        m.markerId.value.startsWith('driver_'));
    
    // Add nearby users
    for (var user in _nearbyUsers) {
      if (user.hasLocation && _currentPosition != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('user_${user.uid}'),
            position: LatLng(user.currentLat!, user.currentLng!),
            infoWindow: InfoWindow(
              title: '👤 ${user.displayName}',
              snippet: '${user.rating.toStringAsFixed(1)} ⭐',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            onTap: () => _showUserProfileDialog(user),
          ),
        );
      }
    }
    
    // Add nearby drivers
    for (var driver in _nearbyDrivers) {
      final location = driver.location;
      double? lat, lng;
      
      if (location.containsKey('latitude') && location.containsKey('longitude')) {
        lat = location['latitude']?.toDouble();
        lng = location['longitude']?.toDouble();
      } else if (location.containsKey('lat') && location.containsKey('lng')) {
        lat = location['lat']?.toDouble();
        lng = location['lng']?.toDouble();
      }
      
      if (lat != null && lng != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.uid}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: '🚗 ${driver.name}',
              snippet: '${driver.rating.toStringAsFixed(1)} ⭐ • ${driver.isAvailable ? "Available" : "Busy"}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              driver.isAvailable ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed
            ),
            onTap: () => _showDriverProfileDialog(driver),
          ),
        );
      }
    }
    
    if (mounted) setState(() {});
  }

  // Search functionality
  Timer? _searchDebounce;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    
    _searchDebounce?.cancel();
    
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          final results = await _locationService.getAutocompleteSuggestions(query);
          if (mounted) {
            setState(() => _searchResults = results.take(5).toList());
          }
        } catch (e) {
          _handleError('Search failed', e);
        }
      },
    );
  }

  Future<void> _selectDestination(LocationModel location) async {
    setState(() {
      _selectedDestination = location;
      _searchResults.clear();
      _searchController.clear();
    });
    
    _addDestinationMarker(location);
    await _calculateAndDrawRoute();
    _updateMapBounds();
  }

  void _addDestinationMarker(LocationModel location) {
    _markers.removeWhere((m) => m.markerId.value == 'destination');
    
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: '🎯 ${location.name}',
          snippet: location.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    
    if (mounted) setState(() {});
  }

  Future<void> _calculateAndDrawRoute() async {
    if (_currentPosition == null || _selectedDestination == null) return;
    
    try {
      final directions = await _locationService.getDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
      );
      
      final distance = (directions['distance'] as int).toDouble();
      final polyline = directions['polyline'] as String;
      
      _routePolyline = polyline;
      _pricingInfo = await _calculateComprehensivePricing(distance);
      _drawRoute(polyline);
      
      if (mounted) setState(() {});
      
    } catch (e) {
      _handleError('Failed to calculate route', e);
    }
  }

  Future<void> _updatePricingIfDestinationSelected() async {
    if (_selectedDestination != null && _currentPosition != null) {
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
      );
      _pricingInfo = await _calculateComprehensivePricing(distance);
      if (mounted) setState(() {});
    }
  }

  void _drawRoute(String encodedPolyline) {
    // Decode polyline here - you'll need to implement this or use a package
    final points = _decodePolyline(encodedPolyline);
    
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('main_route'),
        points: points,
        color: const Color(0xFF3498db),
        width: 4,
        patterns: [],
      ),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    // Simple polyline decoder - you might want to use a proper package
    List<LatLng> points = [];
    // Add decoding logic here or use a package like google_polyline_algorithm
    return points;
  }

  void _updateMapBounds() {
    if (_mapController == null || 
        _currentPosition == null || 
        _selectedDestination == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_currentPosition!.latitude, _selectedDestination!.latitude),
        math.min(_currentPosition!.longitude, _selectedDestination!.longitude),
      ),
      northeast: LatLng(
        math.max(_currentPosition!.latitude, _selectedDestination!.latitude),
        math.max(_currentPosition!.longitude, _selectedDestination!.longitude),
      ),
    );
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<Map<String, dynamic>> _calculateComprehensivePricing(double distanceMeters) async {
    final distanceKm = distanceMeters / 1000;
    const basePrice = 50.0;
    
    return {
      'distance': distanceKm,
      'passengerPrice': basePrice + (distanceKm * 5),
      'driverEarnings': basePrice * 0.8 + (distanceKm * 4),
      'estimatedDuration': (distanceKm / 30 * 60).round(), // minutes
      'urgencyLevel': 'normal',
      'demandMultiplier': 1.0,
    };
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _showUserProfileDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User: ${user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rating: ${user.rating.toStringAsFixed(1)}⭐'),
            Text('Total Rides: ${user.totalRides}'),
            if (user.experienceLevel.isNotEmpty)
              Text('Experience: ${user.experienceLevel}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _inviteUserToRide(user);
            },
            child: const Text('Invite to Ride'),
          ),
        ],
      ),
    );
  }

  void _showDriverProfileDialog(models.DriverModel driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Driver: ${driver.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rating: ${driver.rating.toStringAsFixed(1)}⭐'),
            Text('Available: ${driver.isAvailable ? "Yes" : "No"}'),
            if (driver.vehicle.isNotEmpty)
              Text('Vehicle: ${_getVehicleInfo(driver.vehicle)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (driver.isAvailable)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRideOptionsDialog(driver);
              },
              child: const Text('Request Ride'),
            ),
        ],
      ),
    );
  }

  String _getVehicleInfo(Map<String, dynamic> vehicle) {
    if (vehicle.isEmpty) return 'Vehicle';
    
    final make = vehicle['make']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    final year = vehicle['year']?.toString() ?? '';
    
    return '$year $make $model'.trim();
  }

  void _showRideOptionsDialog(models.DriverModel driver) {
    if (_selectedDestination == null) {
      _showError('Please select a destination first');
      return;
    }

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
          minChildSize: 0.4,
          maxChildSize: 0.8,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Book Ride with ${driver.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'To: ${_selectedDestination!.name}',
                  style: TextStyle(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      if (_pricingInfo != null) ...[
                        _buildRideOptionCard('Private', 'private', _pricingInfo!, driver),
                        const SizedBox(height: 12),
                        _buildRideOptionCard('Shared', 'shared', _pricingInfo!, driver),
                        const SizedBox(height: 12),
                        _buildRideOptionCard('Pool', 'pool', _pricingInfo!, driver),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    if (_selectedDestination == null) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[400]!, Colors.grey[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_searching_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Select Destination First',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final availableDrivers = _nearbyDrivers.where((driver) => driver.isAvailable).toList();
    
    String buttonText;
    IconData buttonIcon;
    Color primaryColor = const Color(0xFF3498db);
    
    if (availableDrivers.isNotEmpty) {
      buttonText = 'Request Ride (${availableDrivers.length} drivers nearby)';
      buttonIcon = Icons.local_taxi_rounded;
    } else {
      buttonText = 'Find Drivers';
      buttonIcon = Icons.search_rounded;
      primaryColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _handleMainActionPress,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(buttonIcon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRideOptionCard(String title, String rideType, Map<String, dynamic> pricingInfo, models.DriverModel driver) {
    final basePrice = pricingInfo['passengerPrice'] ?? 50.0;
    double price = basePrice;
    
    // Adjust price based on ride type
    switch (rideType) {
      case 'private':
        price = basePrice;
        break;
      case 'shared':
        price = basePrice * 0.8;
        break;
      case 'pool':
        price = basePrice * 0.65;
        break;
    }

    IconData icon;
    String description;
    Color color;
    
    switch (rideType) {
      case 'private':
        icon = Icons.person;
        description = 'Just you - fastest route';
        color = Colors.purple;
        break;
      case 'shared':
        icon = Icons.people;
        description = 'Share with 1-2 others - save money';
        color = Colors.blue;
        break;
      case 'pool':
        icon = Icons.groups;
        description = 'Share with up to 4 others - best value';
        color = Colors.green;
        break;
      default:
        icon = Icons.directions_car;
        description = 'Standard ride';
        color = Colors.grey;
    }
    
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _bookRide(rideType, driver);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Book',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _inviteUserToRide(UserModel user) {
    if (_selectedDestination == null) {
      _showError('Please select a destination first');
      return;
    }
    
    if (_currentPosition == null) {
      _showError('Current location not available');
      return;
    }
    
    final currentLocationModel = LocationModel(
      name: 'Current Location',
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      distance: 0,
      estimatedCost: _pricingInfo?['passengerPrice'] ?? 0,
      address: 'Your current position',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RideRequestScreen(
          destination: _selectedDestination!,
          currentLocation: currentLocationModel,
          invitedUser: user,
        ),
      ),
    );
  }

  Future<void> _bookRide(String rideType, models.DriverModel driver) async {
    if (_selectedDestination == null || _currentPosition == null) {
      _showError('Missing location data');
      return;
    }
    
    _setLoadingState(true);
    
    try {
      final pickupLocation = LocationModel(
        name: 'Current Location',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        distance: 0,
        estimatedCost: 0,
        address: 'Your current position',
      );
      
      RideType rideTypeEnum;
      switch (rideType) {
        case 'private':
          rideTypeEnum = RideType.private;
          break;
        case 'shared':
          rideTypeEnum = RideType.shared;
          break;
        case 'pool':
          rideTypeEnum = RideType.pool;
          break;
        default:
          rideTypeEnum = RideType.private;
      }
      
      final estimatedPrice = _getPriceForRideType(rideType);
      
      await _rideService.requestRideWithDriver(
        pickupLocation: pickupLocation,
        destination: _selectedDestination!,
        rideType: rideTypeEnum,
        requiredSeats: 1,
        preferredDriverId: driver.uid,
        estimatedPrice: estimatedPrice,
      );
      
      _showSuccess('Ride requested successfully! ${driver.name} has been notified.');
      
    } catch (e) {
      _handleError('Failed to book ride', e);
    } finally {
      _setLoadingState(false);
    }
  }

  double _getPriceForRideType(String rideType) {
    if (_pricingInfo == null) return 50.0;
    
    final basePrice = _pricingInfo!['passengerPrice'] ?? 50.0;
    
    switch (rideType) {
      case 'private':
        return basePrice;
      case 'shared':
        return basePrice * 0.8;
      case 'pool':
        return basePrice * 0.65;
      default:
        return basePrice;
    }
  }

  void _setLoadingState(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error');
    if (mounted) {
      _showError(message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _toggleBottomPanel() {
    if (!mounted) return;
    
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
    });
    
    // No need to check disposal - controller methods handle this internally
    if (_isPanelExpanded) {
      _panelAnimationController.forward();
    } else {
      _panelAnimationController.reverse();
    }
  }

  // UI Build Methods
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMap(),
          _buildSearchOverlay(),
          _buildBottomPanel(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'ShareRide',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFF3498db),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadNearbyData,
          tooltip: 'Refresh nearby data',
        ),
        _buildAppBarMenu(),
      ],
    );
  }

  Widget _buildAppBarMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)
      ),
      itemBuilder: (context) => [
        if (_userRole == 'both') ...[
          PopupMenuItem(
            value: 'driver_mode',
            child: Row(
              children: [
                Icon(_showDriverMode ? Icons.person_rounded : Icons.drive_eta_rounded),
                const SizedBox(width: 12),
                Text(_showDriverMode ? 'Passenger Mode' : 'Driver Mode'),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [Icon(Icons.person_rounded), SizedBox(width: 12), Text('Profile')],
          ),
        ),
        const PopupMenuItem(
          value: 'history',
          child: Row(
            children: [Icon(Icons.history_rounded), SizedBox(width: 12), Text('Ride History')],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [Icon(Icons.settings_rounded), SizedBox(width: 12), Text('Settings')],
          ),
        ),
      ],
      onSelected: _handleMenuSelection,
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'driver_mode':
        _toggleDriverMode();
        break;
      case 'profile':
        debugPrint('Navigate to profile');
        break;
      case 'history':
        debugPrint('Navigate to history');
        break;
      case 'settings':
        debugPrint('Navigate to settings');
        break;
    }
  }

  void _toggleDriverMode() {
    setState(() => _showDriverMode = !_showDriverMode);
    if (_showDriverMode) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DriverDashboard()),
      );
    }
  }

  Widget _buildMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // Apply dark theme if needed
        if (Theme.of(context).brightness == Brightness.dark) {
          controller.setMapStyle('''
            [
              {
                "elementType": "geometry",
                "stylers": [{"color": "#242f3e"}]
              },
              {
                "elementType": "labels.text.stroke",
                "stylers": [{"color": "#242f3e"}]
              },
              {
                "elementType": "labels.text.fill",
                "stylers": [{"color": "#746855"}]
              }
            ]
          ''');
        }
      },
      initialCameraPosition: CameraPosition(
        target: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(-23.8954, 29.4488), // Default to Limpopo area
        zoom: 15,
      ),
      markers: _markers,
      polylines: _polylines,
      circles: _circles,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight,
        bottom: 200,
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return SafeArea(
      child: Positioned(
        top: 16,
        left: 16,
        right: 16,
        child: Column(
          children: [
            _buildSearchBar(),
            if (_searchResults.isNotEmpty) _buildSearchResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Where to?',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults.clear());
                  },
                )
              : Icon(Icons.mic_rounded, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: _searchLocation,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
        itemBuilder: (context, index) {
          final location = _searchResults[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
            ),
            title: Text(
              location.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              location.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            onTap: () => _selectDestination(location),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleBottomPanel,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStats(),
                  ],
                ),
              ),
            ),
            if (_selectedDestination != null && _pricingInfo != null) ...[
              Divider(height: 1, color: Colors.grey[300]),
              _buildPricingPreview(),
            ],
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildMainActionButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip(
            _nearbyUsers.length.toString(),
            'Users',
            Icons.people_rounded,
            Colors.green,
          ),
          _buildStatChip(
            _nearbyDrivers.length.toString(),
            'Drivers',
            Icons.local_taxi_rounded,
            Colors.orange,
          ),
          _buildStatChip(
            '${_searchRadius.toInt()}km',
            'Radius',
            Icons.radar_rounded,
            const Color(0xFF3498db),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPreview() {
    if (_pricingInfo == null) return const SizedBox.shrink();
    
    final distance = _pricingInfo!['distance'] ?? 0.0;
    final formattedDistance = '${distance.toStringAsFixed(1)} km';
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To: ${_selectedDestination!.name}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formattedDistance,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPriceChip('Private', 'private', Colors.purple, Icons.person_rounded),
                const SizedBox(width: 8),
                _buildPriceChip('Shared', 'shared', Colors.blue, Icons.people_rounded),
                const SizedBox(width: 8),
                _buildPriceChip('Pool', 'pool', Colors.green, Icons.groups_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChip(String type, String rideType, Color color, IconData icon) {
    final basePrice = _pricingInfo!['passengerPrice'] ?? 50.0;
    double price = basePrice;
    
    switch (rideType) {
      case 'private':
        price = basePrice;
        break;
      case 'shared':
        price = basePrice * 0.8;
        break;
      case 'pool':
        price = basePrice * 0.65;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Text(
                'R${price.toStringAsFixed(0)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
          ),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498db)),
                ),
                SizedBox(height: 16),
                Text('Loading...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'location',
          backgroundColor: Colors.white,
          onPressed: _recenterMap,
          child: const Icon(Icons.my_location_rounded, color: Color(0xFF3498db)),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'radius',
          backgroundColor: Colors.white,
          onPressed: _showRadiusDialog,
          child: Icon(Icons.tune_rounded, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _recenterMap() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    } else {
      _showError('Location not available');
    }
  }

  void _handleMainActionPress() {
    if (_selectedDestination == null) {
      _showError('Please select a destination first');
      return;
    }
    
    final availableDrivers = _nearbyDrivers.where((driver) => driver.isAvailable).toList();
    
    if (availableDrivers.isNotEmpty) {
      // Show ride options with the closest available driver
      availableDrivers.sort((a, b) {
        final distanceA = _calculateDriverDistance(a);
        final distanceB = _calculateDriverDistance(b);
        return distanceA.compareTo(distanceB);
      });
      _showRideOptionsDialog(availableDrivers.first);
    } else {
      // Navigate to general ride request screen
      final currentLocationModel = LocationModel(
        name: 'Current Location',
        latitude: _currentPosition?.latitude ?? -23.8954,
        longitude: _currentPosition?.longitude ?? 29.4488,
        distance: 0,
        estimatedCost: _pricingInfo?['passengerPrice'] ?? 0,
        address: 'Your current position',
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideRequestScreen(
            destination: _selectedDestination!,
            currentLocation: currentLocationModel,
            invitedUser: null,
          ),
        ),
      );
    }
  }

  double _calculateDriverDistance(models.DriverModel driver) {
    if (_currentPosition == null || driver.location.isEmpty) return 0.0;
    
    final location = driver.location;
    double? lat, lng;
    
    if (location.containsKey('latitude') && location.containsKey('longitude')) {
      lat = location['latitude']?.toDouble();
      lng = location['longitude']?.toDouble();
    } else if (location.containsKey('lat') && location.containsKey('lng')) {
      lat = location['lat']?.toDouble();
      lng = location['lng']?.toDouble();
    }
    
    if (lat == null || lng == null) return 0.0;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    ) / 1000; // Convert to km
  }

  void _showRadiusDialog() {
    double tempRadius = _searchRadius;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Search Radius'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempRadius.toInt()} km',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3498db),
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempRadius,
                min: 1,
                max: 15,
                divisions: 14,
                label: '${tempRadius.toInt()} km',
                onChanged: (value) {
                  setDialogState(() => tempRadius = value);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expected Users'),
                        Text('~${(tempRadius * 2).round()}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expected Drivers'),
                        Text('~${(tempRadius * 1.5).round()}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _searchRadius = tempRadius);
                _addSearchRadiusCircle();
                _loadNearbyData();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}