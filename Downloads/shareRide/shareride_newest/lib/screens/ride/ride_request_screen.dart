// lib/screens/ride/ride_request_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/location_model.dart';
import '../../models/ride_model.dart';
import '../../models/user_model.dart';
import '../../models/driver_model.dart';
import '../../services/location_service.dart';
import '../../services/ride_service.dart';
import '../../services/user_service.dart';
import '../../utils/polyline_helper.dart';
import 'dart:math' as math;
// Add this to your RideRequestScreen class constructor

class RideRequestScreen extends StatefulWidget {
  final LocationModel destination;
  final LocationModel currentLocation;
  final UserModel? invitedUser;

  const RideRequestScreen({
    super.key,
    required this.destination,
    required this.currentLocation,
    this.invitedUser,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  // Controllers and Services
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final RideService _rideService = RideService();
  final UserService _userService = UserService();
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  // State Variables
  Position? _currentPosition;
  LocationModel? _pickupLocation;
  LocationModel? _destinationLocation;
  bool _isLoading = false;
  String _statusMessage = '';
  
  // Map Elements
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  
  // Ride Parameters
  RideType _selectedRideType = RideType.shared;
  int _requiredSeats = 1;
  double _searchRadius = 5.0; // km
  
  // Nearby Data
  List<UserModel> _nearbyUsers = [];
  List<DriverModel> _nearbyDrivers = [];
  
  // Trip Data
  double? _estimatedDistance;
  double? _estimatedPrice;
  String? _routeDuration;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // INITIALIZATION METHODS
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (_currentPosition != null) {
        final address = await _locationService.reverseGeocode(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        
        _pickupLocation = LocationModel(
          name: 'Current Location',
          address: address ?? 'Your Location',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          distance: 0,
          estimatedCost: 0.0,
        );
        
        _addCurrentLocationMarker();
        await _searchNearbyUsersAndDrivers();
      }
    } catch (e) {
      _showError('Failed to get current location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // MAP MARKERS AND UI
  void _addCurrentLocationMarker() {
    _markers.removeWhere((m) => m.markerId.value == 'current_location');
    
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(
            title: '📍 Your Location',
            snippet: 'Pickup point',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
      
      // Add search radius circle
      _circles.clear();
      _circles.add(
        Circle(
          circleId: const CircleId('search_radius'),
          center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          radius: _searchRadius * 1000, // Convert km to meters
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }
    
    setState(() {});
  }

  // DATA LOADING
  Future<void> _searchNearbyUsersAndDrivers() async {
    if (_currentPosition == null) return;
    
    try {
      final results = await Future.wait([
        _userService.getNearbyUsers(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _searchRadius,
        ),
        _userService.getNearbyDrivers(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _searchRadius,
        ),
      ]);
      
      setState(() {
        _nearbyUsers = results[0] as List<UserModel>;
        _nearbyDrivers = results[1] as List<DriverModel>;
      });
      
      _addNearbyMarkersToMap();
      
    } catch (e) {
      debugPrint('Error searching nearby users/drivers: $e');
    }
  }

  void _addNearbyMarkersToMap() {
    // Remove existing nearby markers
    _markers.removeWhere((m) => 
        m.markerId.value.startsWith('user_') || 
        m.markerId.value.startsWith('driver_'));
    
    // Add nearby users
    for (var user in _nearbyUsers) {
      if (user.currentLat != null && user.currentLng != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('user_${user.uid}'),
            position: LatLng(user.currentLat!, user.currentLng!),
            infoWindow: InfoWindow(
              title: '👤 ${user.name}',
              snippet: 'Potential ride partner',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }
    
    // Add nearby drivers
    for (var driver in _nearbyDrivers) {
      if (driver.currentLat != null && driver.currentLng != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('driver_${driver.uid}'),
            position: LatLng(driver.currentLat!, driver.currentLng!),
            infoWindow: InfoWindow(
              title: '🚗 ${driver.name}',
              snippet: 'Available driver - ${driver.vehicleInfo}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onTap: () => _showDriverDetails(driver),
          ),
        );
      }
    }
    
    setState(() {});
  }

  // SEARCH FUNCTIONALITY
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final locations = await _locationService.getAutocompleteSuggestions(query);
      if (locations.isNotEmpty) {
        _showLocationPicker(locations);
      } else {
        _showError('No locations found for "$query"');
      }
    } catch (e) {
      _showError('Search failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLocationPicker(List<LocationModel> locations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
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
              const SizedBox(height: 16),
              const Text(
                'Select Destination',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text(location.name),
                      subtitle: Text(
                        location.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: location.distance > 0
                          ? Text('${(location.distance / 1000).toStringAsFixed(1)} km')
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _selectDestination(location);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDestination(LocationModel location) async {
    setState(() {
      _destinationLocation = location;
      _destinationController.text = location.name;
    });
    
    // Add destination marker
    _markers.removeWhere((m) => m.markerId.value == 'destination');
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(location.latitude, location.longitude),
        infoWindow: InfoWindow(
          title: '🎯 ${location.name}',
          snippet: 'Destination',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    
    await _calculateRoute();
    _updateMapBounds();
  }

  // ROUTE CALCULATION
  Future<void> _calculateRoute() async {
    if (_currentPosition == null || _destinationLocation == null) return;
    
    try {
      final directions = await _locationService.getDirections(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _destinationLocation!.latitude,
        _destinationLocation!.longitude,
      );
      
      setState(() {
        _estimatedDistance = (directions['distance'] as int).toDouble() / 1000; // Convert to km
        _routeDuration = directions['duration_text'] as String;
        _estimatedPrice = _calculatePrice();
      });
      
      // Draw route polyline
      _drawRoute(directions['polyline'] as String);
      
    } catch (e) {
      _showError('Failed to calculate route: $e');
    }
  }

  void _drawRoute(String encodedPolyline) {
    final points = PolylineHelper.decodePolyline(encodedPolyline);
    
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF3498db),
        width: 4,
        patterns: [],
      ),
    );
    
    setState(() {});
  }

  void _updateMapBounds() {
    if (_mapController == null || _currentPosition == null || _destinationLocation == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_currentPosition!.latitude, _destinationLocation!.latitude),
        math.min(_currentPosition!.longitude, _destinationLocation!.longitude),
      ),
      northeast: LatLng(
        math.max(_currentPosition!.latitude, _destinationLocation!.latitude),
        math.max(_currentPosition!.longitude, _destinationLocation!.longitude),
      ),
    );
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // PRICING CALCULATION
  double _calculatePrice() {
    if (_estimatedDistance == null) return 0.0;
    
    const double basePrice = 50.0;
    const double sharedAloneDiscount = 0.35;
    const double sharedWithOthersDiscount = 0.20;
    
    double finalPrice = basePrice;
    
    // Apply ride type discount
    switch (_selectedRideType) {
      case RideType.private:
        if (_requiredSeats > 1) {
          finalPrice = basePrice * _requiredSeats;
        }
        break;
      case RideType.shared:
        if (_nearbyUsers.isEmpty) {
          // Shared alone - 35% discount
          finalPrice = basePrice * (1 - sharedAloneDiscount);
        } else {
          // Shared with others - 20% discount
          finalPrice = basePrice * (1 - sharedWithOthersDiscount);
        }
        break;
      case RideType.pool:
        finalPrice = basePrice * 0.7; // 30% discount for pool
        break;
    }
    
    // Add distance-based pricing
    if (_estimatedDistance! > 10) {
      finalPrice += (_estimatedDistance! - 10) * 5; // R5 per km after 10km
    }
    
    return finalPrice;
  }

  // DIALOG METHODS
  void _showDriverDetails(DriverModel driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Driver: ${driver.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle: ${driver.vehicleInfo}'),
            Text('Rating: ${driver.rating.toStringAsFixed(1)}⭐'),
            Text('Total Rides: ${driver.totalRides}'),
            if (driver.distanceFromUser != null)
              Text('Distance: ${(driver.distanceFromUser! / 1000).toStringAsFixed(1)} km'),
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
              _requestRideWithDriver(driver);
            },
            child: const Text('Select Driver'),
          ),
        ],
      ),
    );
  }

  // RIDE MANAGEMENT
  Future<void> _requestRideWithDriver(DriverModel driver) async {
    if (_destinationLocation == null) {
      _showError('Please select a destination first');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _rideService.requestRideWithDriver(
        pickupLocation: _pickupLocation!,
        destination: _destinationLocation!,
        rideType: _selectedRideType,
        requiredSeats: _requiredSeats,
        preferredDriverId: driver.uid,
        estimatedPrice: _estimatedPrice!,
      );
      
      _showSuccess('Ride requested successfully! Driver ${driver.name} has been notified.');
      
      // Navigate back to main screen
      Navigator.pop(context);
      
    } catch (e) {
      _showError('Failed to request ride: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRide() async {
    if (_destinationLocation == null) {
      _showError('Please select a destination first');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Find optimal driver based on distance and availability
      DriverModel? selectedDriver;
      if (_nearbyDrivers.isNotEmpty) {
        _nearbyDrivers.sort((a, b) => 
          (a.distanceFromUser ?? double.infinity).compareTo(
            b.distanceFromUser ?? double.infinity
          )
        );
        selectedDriver = _nearbyDrivers.first;
      }
      
      await _rideService.requestRide(
        pickupLocation: _pickupLocation!,
        destination: _destinationLocation!,
        rideType: _selectedRideType,
        maxPassengers: _requiredSeats,
        routeFlexibility: 'moderate',
        preferredDriverId: selectedDriver?.uid,
        estimatedPrice: _estimatedPrice!,
      );
      
      _showSuccess(
        'Ride requested successfully! ${selectedDriver != null 
          ? 'Driver ${selectedDriver.name} has been notified.' 
          : 'Finding a driver...'}'
      );
      
      // Navigate back to main screen
      Navigator.pop(context);
      
    } catch (e) {
      _showError('Failed to request ride: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // UTILITY METHODS
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // UI BUILD METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Ride'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationInputs(),
          if (_destinationLocation != null) _buildRideOptions(),
          _buildMap(),
          if (_destinationLocation != null) _buildRequestButton(),
        ],
      ),
    );
  }

  Widget _buildLocationInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Pickup location (read-only)
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
              hintText: _pickupLocation?.address ?? 'Getting location...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Destination search
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              hintText: 'Where to?',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchLocation(_destinationController.text),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: _searchLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildRideOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Ride type selection
          Row(
            children: [
              const Text('Ride Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: SegmentedButton<RideType>(
                  segments: const [
                    ButtonSegment(value: RideType.shared, label: Text('Shared')),
                    ButtonSegment(value: RideType.private, label: Text('Private')),
                    ButtonSegment(value: RideType.pool, label: Text('Pool')),
                  ],
                  selected: {_selectedRideType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedRideType = selection.first;
                      _estimatedPrice = _calculatePrice();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Seat and radius controls
          Row(
            children: [
              const Text('Seats: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _requiredSeats,
                items: [1, 2, 3, 4].map((seats) => 
                  DropdownMenuItem(value: seats, child: Text(seats.toString()))
                ).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _requiredSeats = value;
                      _estimatedPrice = _calculatePrice();
                    });
                  }
                },
              ),
              const Spacer(),
              
              // Search radius
              Text('Search Radius: ${_searchRadius.toInt()}km'),
              Slider(
                value: _searchRadius,
                min: 1,
                max: 15,
                divisions: 14,
                onChanged: (value) {
                  setState(() => _searchRadius = value);
                  _addCurrentLocationMarker();
                  _searchNearbyUsersAndDrivers();
                },
              ),
            ],
          ),
          
          // Trip details
          if (_estimatedDistance != null) _buildTripDetails(),
        ],
      ),
    );
  }

  Widget _buildTripDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Distance: ${_estimatedDistance!.toStringAsFixed(1)} km'),
                if (_routeDuration != null) Text('Time: $_routeDuration'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nearby drivers: ${_nearbyDrivers.length}'),
                Text('Nearby users: ${_nearbyUsers.length}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated Price:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'R${_estimatedPrice?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27ae60),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Expanded(
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
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              onTap: (LatLng latLng) {
                // Optional: Allow manual destination selection by tapping
              },
            ),
    );
  }

  Widget _buildRequestButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _requestRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF27ae60),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Request Ride - R${_estimatedPrice?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }
}