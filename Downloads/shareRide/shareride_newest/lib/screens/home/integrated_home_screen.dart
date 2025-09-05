// lib/screens/home/integrated_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location_model.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../models/driver_model.dart' as models;
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../services/ride_service.dart';
import '../../services/auth_service.dart';
import '../ride/ride_request_screen.dart';
import '../shop/shop_screen.dart';
import '../more/more_screen.dart';
import '../rideshare/ride_history_screen.dart';
import '../../driver/driver_dashboard.dart';
import '../../widgets/custom_dialogs.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'dart:async';
import 'dart:math' as math;

class IntegratedHomeScreen extends StatefulWidget {
  final UserModel? invitedUser;
  
  const IntegratedHomeScreen({super.key, this.invitedUser});

  @override
  State<IntegratedHomeScreen> createState() => _IntegratedHomeScreenState();
}

class _IntegratedHomeScreenState extends State<IntegratedHomeScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Services
  final _authService = AuthService();
  late final LocationService _locationService;
  late final RideService _rideService;
  late final UserService _userService;
  
  // Controllers
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _panelController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _panelAnimation;
  
  // State Variables
  int _currentPageIndex = 0;
  Position? _currentPosition;
  LocationModel? _selectedDestination;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  
  // UI State
  bool _isLoading = false;
  bool _showDriverMode = false;
  bool _isMapExpanded = false;
  String _userRole = UserRole.passenger;
  double _searchRadius = AppConstants.defaultSearchRadius;
  
  // Collections
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  List<LocationModel> _searchResults = [];
  List<UserModel> _nearbyUsers = [];
  List<models.DriverModel> _nearbyDrivers = [];
  
  // Pricing and Route Data
  Map<String, dynamic>? _pricingInfo;
  UserModel? _invitedUser;

  @override
  void initState() {
    super.initState();
    _invitedUser = widget.invitedUser;
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

  void _initializeServices() {
    _locationService = LocationService();
    _rideService = RideService();
    _userService = UserService();
    _pageController = PageController();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _cleanup() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _panelController.dispose();
    _searchController.dispose();
    _pageController.dispose();
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
      debugPrint('Location error: $e');
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
        final driverProfile = await _userService.getDriverProfile(userId);
        _userRole = driverProfile != null ? UserRole.both : UserRole.passenger;
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      _userRole = UserRole.passenger;
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      AppConstants.locationUpdateInterval,
      (_) => _performLocationUpdate(),
    );
    
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.locationDistanceFilter,
      ),
    ).listen(
      (Position position) {
        if (mounted && ValidationHelper.isValidCoordinate(position.latitude, position.longitude)) {
          setState(() => _currentPosition = position);
          _updateMapLocation();
          _updateUserLocation();
        }
      },
      onError: (e) => debugPrint('Location stream error: $e'),
    );
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
    
    if (_mapController != null && _isMapExpanded) {
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
          title: 'Your Location',
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
        fillColor: AppColors.searchRadiusFill,
        strokeColor: AppColors.searchRadiusStroke,
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
      }
      
    } catch (e) {
      debugPrint('Failed to load nearby data: $e');
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
        final distance = DistanceHelper.calculateDistanceKm(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          user.currentLat!,
          user.currentLng!,
        );
        
        final isInvitedUser = _invitedUser?.uid == user.uid;
        
        _markers.add(
          Marker(
            markerId: MarkerId('user_${user.uid}'),
            position: LatLng(user.currentLat!, user.currentLng!),
            infoWindow: InfoWindow(
              title: '${isInvitedUser ? "Invited: " : ""}${StringHelper.capitalizeWords(user.displayName)}',
              snippet: '${FormatHelper.formatRating(user.rating)} • ${DistanceHelper.formatDistance(distance * 1000)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isInvitedUser ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueGreen
            ),
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
      
      if (lat != null && lng != null && ValidationHelper.isValidCoordinate(lat, lng)) {
        final distance = DistanceHelper.calculateDistanceKm(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );
        
        final vehicleInfo = _getVehicleInfo(driver.vehicle);
        
        _markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.uid}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: '${StringHelper.capitalizeWords(driver.name)} (Driver)',
              snippet: '$vehicleInfo • ${FormatHelper.formatRating(driver.rating)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }
    }
    
    if (mounted) setState(() {});
  }

  String _getVehicleInfo(Map<String, dynamic> vehicle) {
    if (vehicle.isEmpty) return 'Vehicle';
    
    final make = vehicle['make']?.toString() ?? '';
    final model = vehicle['model']?.toString() ?? '';
    final year = vehicle['year']?.toString() ?? '';
    
    final info = '$year $make $model'.trim();
    return info.isNotEmpty ? StringHelper.truncate(info, 20) : 'Vehicle';
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
    _expandMap();
  }

  void _addDestinationMarker(LocationModel location) {
    _markers.removeWhere((m) => m.markerId.value == 'destination');
    
    final distance = _currentPosition != null 
        ? DistanceHelper.calculateDistanceKm(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            location.latitude,
            location.longitude,
          )
        : 0.0;
    
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: StringHelper.capitalizeWords(location.name),
          snippet: '${StringHelper.truncate(location.address, 50)} • ${DistanceHelper.formatDistance(distance * 1000)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    
    if (mounted) setState(() {});
  }

  void _expandMap() {
    setState(() => _isMapExpanded = true);
    _panelController.forward();
  }

  void _collapseMap() {
    setState(() {
      _isMapExpanded = false;
      _selectedDestination = null;
      _searchResults.clear();
      _searchController.clear();
    });
    _panelController.reverse();
  }

  void _setLoadingState(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error');
    if (mounted) {
      _showError('$message: ${error.toString()}');
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToPage(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).pop();
                  await _authService.signOut();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _panelAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Landing Screen Content
              if (!_isMapExpanded) _buildLandingContent(userName, isSmallScreen, size),
              
              // Map View (slides up from bottom)
              if (_isMapExpanded) _buildMapView(),
              
              // Search Overlay
              if (_isMapExpanded) _buildSearchOverlay(),
              
              // Loading Overlay
              if (_isLoading) _buildLoadingOverlay(),
            ],
          );
        },
      ),
      appBar: _buildAppBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: _isMapExpanded 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _collapseMap,
            )
          : null,
      title: _isMapExpanded 
          ? Text(
              _invitedUser != null ? 'Invite to Ride' : 'Ride Sharing',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      actions: [
        if (_isMapExpanded) ...[
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadNearbyData,
            tooltip: 'Refresh nearby data',
          ),
          if (_nearbyDrivers.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text(_nearbyDrivers.length.toString()),
                child: const Icon(Icons.local_taxi, color: Colors.white),
              ),
              onPressed: () {}, // TODO: Show nearby drivers list
              tooltip: 'View nearby drivers',
            ),
        ],
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 20,
              ),
            ),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  await _showLogoutConfirmation();
                  break;
                case 'history':
                  _navigateToPage(const RideHistoryScreen());
                  break;
                case 'driver_mode':
                  _navigateToPage(const DriverDashboard());
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_userRole == UserRole.both) ...[
                PopupMenuItem(
                  value: 'driver_mode',
                  child: Row(
                    children: [
                      Icon(Icons.drive_eta, color: Colors.white.withOpacity(0.8), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Driver Mode',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  height: 1,
                  child: Divider(color: Colors.white.withOpacity(0.2)),
                ),
              ],
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white.withOpacity(0.8), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Ride History',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red.withOpacity(0.8), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF334155),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildLandingContent(String userName, bool isSmallScreen, Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF334155),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.06,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmallScreen ? 40 : 60),
                          _buildWelcomeSection(userName, isSmallScreen),
                          SizedBox(height: isSmallScreen ? 50 : 80),
                          _buildBrandSection(isSmallScreen),
                          SizedBox(height: isSmallScreen ? 50 : 80),
                          _buildActionCards(isSmallScreen, size),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String userName, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userName.length > 20 ? '${userName.substring(0, 20)}...' : userName,
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBrandSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
            ],
          ).createShader(bounds),
          child: Text(
            'bright dev',
            style: TextStyle(
              fontSize: isSmallScreen ? 32 : 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your ultimate campus companion',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards(bool isSmallScreen, Size screenSize) {
    final primaryCardHeight = isSmallScreen ? 160.0 : 180.0;
    final secondaryCardHeight = isSmallScreen ? 140.0 : 160.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPrimaryRideCard(primaryCardHeight, isSmallScreen),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Shop',
                subtitle: 'Campus marketplace',
                gradientColors: [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ],
                onTap: () => _navigateToPage(const ShopScreen()),
                height: secondaryCardHeight,
                isSmallScreen: isSmallScreen,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSecondaryCard(
                icon: Icons.apps_outlined,
                title: 'More',
                subtitle: 'Services & tools',
                gradientColors: [
                  const Color(0xFF8B5CF6),
                  const Color(0xFF7C3AED),
                ],
                onTap: () => _navigateToPage(const MoreScreen()),
                height: secondaryCardHeight,
                isSmallScreen: isSmallScreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryRideCard(double height, bool isSmallScreen) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _expandMap,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_taxi,
                          color: Colors.white,
                          size: isSmallScreen ? 24 : 28,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        'Ride Share',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share rides, save money',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_currentPosition != null && _nearbyUsers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_nearbyUsers.length} users nearby',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.8),
                  size: isSmallScreen ? 16 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required double height,
    required bool isSmallScreen,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(-26.2041, 28.0473),
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
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 80,
              bottom: _selectedDestination != null ? 250 : 150,
            ),
          ),
          
          // Bottom Panel for map view
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildMapBottomPanel(),
          ),
          
          // Floating Action Button
          Positioned(
            bottom: _selectedDestination != null ? 260 : 160,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  backgroundColor: Colors.white,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'radius',
                  backgroundColor: Colors.white,
                  onPressed: _showRadiusDialog,
                  child: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
        ],
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _invitedUser != null ? 'Where to with ${_invitedUser!.displayName}?' : 'Where to?',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults.clear());
                          },
                        )
                      : const Icon(Icons.mic_rounded),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: _searchLocation,
              ),
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final location = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_rounded, color: Colors.red),
                      title: Text(
                        StringHelper.capitalizeWords(location.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        location.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectDestination(location),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          if (_selectedDestination == null) ...[
            _buildQuickStats(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Tap on the map or search above to select your destination',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            _buildDestinationInfo(),
            const SizedBox(height: 16),
            _buildActionButton(),
          ],
          
          SafeArea(child: Container()),
        ],
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
            Colors.blue,
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

  Widget _buildDestinationInfo() {
    if (_selectedDestination == null) return const SizedBox.shrink();
    
    final distance = _currentPosition != null 
        ? DistanceHelper.calculateDistanceKm(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _selectedDestination!.latitude,
            _selectedDestination!.longitude,
          )
        : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To: ${StringHelper.capitalizeWords(_selectedDestination!.name)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  _selectedDestination!.address,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${distance.toStringAsFixed(1)} km away',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_nearbyDrivers.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_nearbyDrivers.length} drivers available',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final hasDrivers = _nearbyDrivers.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _requestRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasDrivers ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasDrivers ? Icons.directions_car : Icons.search),
              const SizedBox(width: 8),
              Text(
                _invitedUser != null 
                    ? 'Send Ride Invitation'
                    : hasDrivers 
                        ? 'Request Ride'
                        : 'Find Rides',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
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
    }
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: tempRadius,
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: (value) {
                  setDialogState(() => tempRadius = value);
                },
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

  Future<void> _requestRide() async {
    if (_selectedDestination == null || _currentPosition == null) {
      _showError('Please select a destination first');
      return;
    }
    
    final currentLocationModel = LocationModel(
  name: 'Current Location',
  latitude: _currentPosition!.latitude,
  longitude: _currentPosition!.longitude,
  distance: 0,
  estimatedCost: 0,
  address: 'Your current position', // ✅ works now
);



  }}