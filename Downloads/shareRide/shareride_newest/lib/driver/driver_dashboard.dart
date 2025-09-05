// lib/screens/driver/driver_dashboard.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/ride_model.dart';
import '../../services/location_service.dart';
import '../../services/driver_service.dart';
import '../../services/user_service.dart';
import 'dart:async';
import 'dart:math' as math;

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  
  final LocationService _locationService = LocationService();
  final DriverService _driverService = DriverService(); // Use DriverService instead of RideService
  final UserService _userService = UserService();
  
  bool _isOnline = false;
  bool _isLoading = false;
  
  List<RideRequest> _nearbyRequests = [];
  RideRequest? _currentRide;
  Timer? _locationTimer;
  Timer? _requestTimer;
  
  double _searchRadius = 10.0; // km
  double _todaysEarnings = 0.0;
  int _todaysRides = 0;
  
  // Driver stats
  Map<String, dynamic> _driverStats = {
    'rating': 4.8,
    'totalEarnings': 2450.0,
    'totalRides': 156,
    'acceptanceRate': 0.92,
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDriverStats();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _requestTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (_currentPosition != null) {
        _updateCurrentLocationMarker();
        _updateDriverLocation();
      }
    } catch (e) {
      _showError('Failed to get location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;
    
    _markers.removeWhere((m) => m.markerId.value == 'driver_location');
    
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_location'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(
          title: '🚗 Your Location',
          snippet: 'Driver position',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    
    // Add search radius
    _circles.clear();
    _circles.add(
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        radius: _searchRadius * 1000,
        fillColor: _isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        strokeColor: _isOnline ? Colors.green : Colors.grey,
        strokeWidth: 2,
      ),
    );
    
    setState(() {});
  }

  Future<void> _updateDriverLocation() async {
    if (_currentPosition != null) {
      await _driverService.updateDriverLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _isOnline,
      );
    }
  }

  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
    
    if (_isOnline) {
      _startLocationUpdates();
      _startRequestPolling();
      _searchNearbyRequests();
    } else {
      _stopLocationUpdates();
      _stopRequestPolling();
      _clearRequests();
    }
    
    _updateCurrentLocationMarker();
    _updateDriverLocation();
    _driverService.setOnlineStatus(_isOnline);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'You are now online and accepting rides!' : 'You are now offline'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
      ),
    );
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _getCurrentLocation();
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
  }

  void _startRequestPolling() {
    _requestTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _searchNearbyRequests();
    });
  }

  void _stopRequestPolling() {
    _requestTimer?.cancel();
  }

  void _clearRequests() {
    setState(() {
      _nearbyRequests.clear();
    });
    _markers.removeWhere((m) => m.markerId.value.startsWith('request_'));
  }

  Future<void> _searchNearbyRequests() async {
    if (!_isOnline || _currentPosition == null) return;
    
    try {
      final requests = await _driverService.getNearbyRideRequests(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _searchRadius,
      );
      
      setState(() {
        _nearbyRequests = requests;
      });
      
      _addRequestMarkersToMap();
      
    } catch (e) {
      print('Error searching nearby requests: $e');
    }
  }

  void _addRequestMarkersToMap() {
    // Remove existing request markers
    _markers.removeWhere((m) => m.markerId.value.startsWith('request_'));
    
    for (var request in _nearbyRequests) {
      // Pickup marker
      _markers.add(
        Marker(
          markerId: MarkerId('request_pickup_${request.id}'),
          position: LatLng(request.pickupLat, request.pickupLng),
          infoWindow: InfoWindow(
            title: '📍 Pickup Request',
            snippet: '${request.passengerName} - R${request.estimatedPrice.toStringAsFixed(2)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showRequestDetails(request),
        ),
      );
      
      // Destination marker
      _markers.add(
        Marker(
          markerId: MarkerId('request_dest_${request.id}'),
          position: LatLng(request.destinationLat, request.destinationLng),
          infoWindow: InfoWindow(
            title: '🎯 ${request.destinationName}',
            snippet: 'Destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    
    setState(() {});
  }

  void _showRequestDetails(RideRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                
                // Passenger info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF3498db),
                      child: Text(
                        request.passengerName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.passengerName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Passenger Rating: ${request.passengerRating}⭐',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRideTypeColor(request.rideType).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        request.rideType.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: _getRideTypeColor(request.rideType),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Trip details
                _buildTripDetail(
                  icon: Icons.my_location,
                  title: 'Pickup',
                  subtitle: request.pickupAddress,
                  extra: '${request.distanceToPickup.toStringAsFixed(1)} km away',
                  color: const Color(0xFF2ecc71),
                ),
                const SizedBox(height: 16),
                _buildTripDetail(
                  icon: Icons.location_on,
                  title: 'Destination',
                  subtitle: request.destinationName,
                  extra: '${request.tripDistance.toStringAsFixed(1)} km trip',
                  color: const Color(0xFFe74c3c),
                ),
                const SizedBox(height: 16),
                _buildTripDetail(
                  icon: Icons.access_time,
                  title: 'Requested',
                  subtitle: _formatDateTime(request.requestedAt),
                  extra: request.isUrgent ? 'URGENT' : '',
                  color: const Color(0xFF3498db),
                ),
                const SizedBox(height: 24),
                
                // Pricing breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Trip fare'),
                          Text('R${request.estimatedPrice.toStringAsFixed(2)}'),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Your earnings'),
                          Text(
                            'R${_calculateDriverEarnings(request).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ecc71),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profit sharing: ${_getDriverProfitPercentage(request)}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _acceptRideRequest(request);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ecc71),
                        ),
                        child: const Text('Accept', style: TextStyle(color: Colors.white)),
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

  Widget _buildTripDetail({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? extra,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (extra != null && extra.isNotEmpty)
                    Text(
                      extra,
                      style: TextStyle(
                        color: extra == 'URGENT' ? Colors.red : Colors.grey[600],
                        fontWeight: extra == 'URGENT' ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRideTypeColor(RideType rideType) {
    switch (rideType) {
      case RideType.private:
        return const Color(0xFF9b59b6);
      case RideType.shared:
        return const Color(0xFF3498db);
      case RideType.pool:
        return const Color(0xFF2ecc71);
    }
  }

  double _calculateDriverEarnings(RideRequest request) {
    const double baseAmount = 50.0;
    double earnings = request.estimatedPrice - baseAmount;
    
    // Calculate arrival time bonus
    double estimatedArrivalTime = request.distanceToPickup / 40 * 60; // minutes assuming 40km/h
    double profitPercentage = estimatedArrivalTime <= 15 ? 0.50 : 0.40; // 50% if within 15 min, 40% otherwise
    
    return baseAmount + (earnings * profitPercentage);
  }

  int _getDriverProfitPercentage(RideRequest request) {
    double estimatedArrivalTime = request.distanceToPickup / 40 * 60; // minutes
    return estimatedArrivalTime <= 15 ? 50 : 40;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _acceptRideRequest(RideRequest request) async {
    setState(() => _isLoading = true);
    
    try {
      await _driverService.acceptRideRequest(request.id);
      
      setState(() {
        _currentRide = request;
        _nearbyRequests.remove(request);
      });
      
      // Draw route to pickup
      await _drawRouteToPickup(request);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride accepted! Navigate to pickup location.'),
          backgroundColor: Color(0xFF2ecc71),
        ),
      );
      
    } catch (e) {
      _showError('Failed to accept ride: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _drawRouteToPickup(RideRequest request) async {
    if (_currentPosition == null) return;
    
    try {
      final directions = await _locationService.getDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        request.pickupLat,
        request.pickupLng,
      );
      
      // Draw polyline
      final points = _decodePolyline(directions['polyline'] as String);
      
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_to_pickup'),
          points: points,
          color: const Color(0xFF2ecc71),
          width: 4,
        ),
      );
      
      // Update map bounds
      _updateMapBounds([
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        LatLng(request.pickupLat, request.pickupLng),
      ]);
      
    } catch (e) {
      print('Failed to draw route: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    // Simplified polyline decoding - in production, use proper decoder
    List<LatLng> points = [];
    if (_currentRide != null && _currentPosition != null) {
      points.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      points.add(LatLng(_currentRide!.pickupLat, _currentRide!.pickupLng));
      points.add(LatLng(_currentRide!.destinationLat, _currentRide!.destinationLng));
    }
    return points;
  }

  void _updateMapBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _loadDriverStats() async {
    try {
      final todayEarnings = await _driverService.getTodayEarnings();
      final driverStats = await _driverService.getDriverStats();
      
      setState(() {
        _todaysEarnings = todayEarnings['earnings']?.toDouble() ?? 0.0;
        _todaysRides = todayEarnings['rides'] ?? 0;
        _driverStats = driverStats.isNotEmpty ? driverStats : _driverStats;
      });
    } catch (e) {
      print('Error loading driver stats: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFF2ecc71),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isOnline ? Icons.online_prediction : Icons.offline_bolt),
            onPressed: _toggleOnlineStatus,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'earnings',
                child: Text('View Earnings'),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status and stats bar
          Container(
            padding: const EdgeInsets.all(16),
            color: _isOnline ? const Color(0xFF2ecc71) : Colors.grey[600],
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'ONLINE - Accepting Rides' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Requests: ${_nearbyRequests.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Today\'s Rides', _todaysRides.toString()),
                    _buildStatItem('Today\'s Earnings', 'R${_todaysEarnings.toStringAsFixed(2)}'),
                    _buildStatItem('Rating', _driverStats['rating'].toStringAsFixed(1)),
                    _buildStatItem('Search Radius', '${_searchRadius.toInt()}km'),
                  ],
                ),
              ],
            ),
          ),
          
          // Search radius control
          if (_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Search Radius: '),
                  Expanded(
                    child: Slider(
                      value: _searchRadius,
                      min: 5,
                      max: 25,
                      divisions: 20,
                      label: '${_searchRadius.toInt()}km',
                      onChanged: (value) {
                        setState(() => _searchRadius = value);
                        _updateCurrentLocationMarker();
                        _searchNearbyRequests();
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Map
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                          : const LatLng(-23.8954, 29.4488),
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    myLocationEnabled: false, // We handle our own location marker
                    myLocationButtonEnabled: false,
                    onTap: (LatLng latLng) {
                      // Optional: Handle map taps
                    },
                  ),
          ),
          
          // Current ride info or online toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: _currentRide != null
                ? _buildCurrentRideCard()
                : ElevatedButton(
                    onPressed: _toggleOnlineStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOnline ? Colors.red : const Color(0xFF2ecc71),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isOnline ? 'Go Offline' : 'Go Online',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentRideCard() {
    if (_currentRide == null) return const SizedBox.shrink();
    
    return Card(
      color: const Color(0xFF2ecc71),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Ride: ${_currentRide!.passengerName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pickup: ${_currentRide!.pickupAddress}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Destination: ${_currentRide!.destinationName}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Navigate or call passenger
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text('Navigate', style: TextStyle(color: Color(0xFF2ecc71))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Complete ride
                    try {
                      await _driverService.completeRide(_currentRide!.id);
                      setState(() {
                        _currentRide = null;
                      });
                      _loadDriverStats(); // Refresh stats
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ride completed!'),
                          backgroundColor: Color(0xFF2ecc71),
                        ),
                      );
                    } catch (e) {
                      _showError('Failed to complete ride: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text('Complete', style: TextStyle(color: Color(0xFF2ecc71))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}