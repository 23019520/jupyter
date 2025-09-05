import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationHelperScreen extends StatefulWidget {
  const LocationHelperScreen({super.key});

  @override
  State<LocationHelperScreen> createState() => _LocationHelperScreenState();
}

class _LocationHelperScreenState extends State<LocationHelperScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _currentAddress = 'Getting location...';
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String _debugInfo = '';

  // Sample ride requests - replace with your data source
  final List<RideRequest> _rideRequests = [
    RideRequest(
      id: '1',
      userId: 'user1',
      userName: 'Sarah Johnson',
      pickup: const LatLng(-23.8954, 29.4488), // Thohoyandou area
      destination: const LatLng(-23.8800, 29.4600),
      pickupAddress: 'University of Venda',
      destinationAddress: 'Thohoyandou CBD',
      departureTime: DateTime.now().add(const Duration(hours: 2)),
      availableSeats: 3,
      pricePerSeat: 25.0,
      status: 'active',
    ),
    RideRequest(
      id: '2',
      userId: 'user2',
      userName: 'Mike Netshiunda',
      pickup: const LatLng(-23.8850, 29.4550),
      destination: const LatLng(-23.9100, 29.4400),
      pickupAddress: 'Thohoyandou Mall',
      destinationAddress: 'Sibasa',
      departureTime: DateTime.now().add(const Duration(hours: 4)),
      availableSeats: 2,
      pricePerSeat: 35.0,
      status: 'active',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugInfo = 'Starting location request...';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentAddress = 'Location services are disabled';
          _errorMessage = 'Please enable location services in your device settings';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _debugInfo = 'Location services enabled. Checking permissions...';
      });

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = 'Location permissions denied';
            _errorMessage = 'Location permissions are required to show your location';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentAddress = 'Location permissions permanently denied';
          _errorMessage = 'Please enable location permissions in app settings';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _debugInfo = 'Permissions granted. Getting current position...';
      });

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      setState(() {
        _debugInfo = 'Position obtained: ${position.latitude}, ${position.longitude}';
      });

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        String address = 'Unknown location';
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
              .replaceAll(RegExp(r'^,\s*|,\s*$'), '') // Remove leading/trailing commas
              .replaceAll(RegExp(r',\s*,'), ','); // Remove double commas
          
          if (address.isEmpty || address == ', , ') {
            address = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
        }

        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _isLoading = false;
          _debugInfo = 'Location and address obtained successfully';
        });

        // Animate camera to current location if map is initialized
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              15.0,
            ),
          );
        }

        _addMarkersForRides();
      } catch (geocodingError) {
        // If geocoding fails, still show the location with coordinates
        String address = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        
        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _isLoading = false;
          _debugInfo = 'Location obtained, geocoding failed: $geocodingError';
        });

        _addMarkersForRides();
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Error getting location';
        _errorMessage = 'Failed to get location: $e';
        _isLoading = false;
        _debugInfo = 'Error: $e';
      });
    }
  }

  void _addMarkersForRides() {
    _markers.clear();
    
    // Add current location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: _currentAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add ride request markers
    for (RideRequest ride in _rideRequests) {
      _markers.add(
        Marker(
          markerId: MarkerId('pickup_${ride.id}'),
          position: ride.pickup,
          infoWindow: InfoWindow(
            title: 'Pickup: ${ride.pickupAddress}',
            snippet: '${ride.userName} - R${ride.pricePerSeat} per seat',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showRideDetails(ride),
        ),
      );

      _markers.add(
        Marker(
          markerId: MarkerId('destination_${ride.id}'),
          position: ride.destination,
          infoWindow: InfoWindow(
            title: 'Destination: ${ride.destinationAddress}',
            snippet: ride.userName,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Add polyline between pickup and destination
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route_${ride.id}'),
          points: [ride.pickup, ride.destination],
          color: const Color(0xFF3498db),
          width: 3,
        ),
      );
    }

    setState(() {});
  }

  void _showRideDetails(RideRequest ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
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
                
                // Driver info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF3498db),
                      child: Text(
                        ride.userName.substring(0, 1).toUpperCase(),
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
                            ride.userName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Driver',
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
                        color: const Color(0xFF2ecc71).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${ride.availableSeats} seats',
                        style: const TextStyle(
                          color: Color(0xFF2ecc71),
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
                  subtitle: ride.pickupAddress,
                  color: const Color(0xFF2ecc71),
                ),
                const SizedBox(height: 16),
                _buildTripDetail(
                  icon: Icons.location_on,
                  title: 'Destination',
                  subtitle: ride.destinationAddress,
                  color: const Color(0xFFe74c3c),
                ),
                const SizedBox(height: 16),
                _buildTripDetail(
                  icon: Icons.access_time,
                  title: 'Departure',
                  subtitle: _formatDateTime(ride.departureTime),
                  color: const Color(0xFF3498db),
                ),
                const SizedBox(height: 24),
                
                // Price
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Price per seat',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'R${ride.pricePerSeat.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2ecc71),
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
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message feature coming soon!')),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _requestRide(ride);
                        },
                        icon: const Icon(Icons.directions_car),
                        label: const Text('Request Ride'),
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
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _requestRide(RideRequest ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Ride'),
        content: Text('Request a ride with ${ride.userName}?\n\nPickup: ${ride.pickupAddress}\nDestination: ${ride.destinationAddress}\nPrice: R${ride.pricePerSeat}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ride request sent to ${ride.userName}!'),
                  backgroundColor: const Color(0xFF2ecc71),
                ),
              );
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Rides'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          // Debug info button
          if (_debugInfo.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: SingleChildScrollView(
                      child: Text(_debugInfo),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            )
          : Column(
              children: [
                // Location info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.my_location : Icons.location_off,
                            color: _currentPosition != null ? const Color(0xFF3498db) : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Location',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _currentAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(color: Colors.red, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Map or fallback
                Expanded(
                  child: _currentPosition != null
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            zoom: 12,
                          ),
                          markers: _markers,
                          polylines: _polylines,
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onTap: (LatLng latLng) {
                            print('Map tapped at: ${latLng.latitude}, ${latLng.longitude}');
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Unable to load map',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage.isNotEmpty ? _errorMessage : 'Location not available',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateRideDialog();
        },
        backgroundColor: const Color(0xFF3498db),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateRideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Ride'),
        content: const Text('Create ride functionality will be implemented here with a proper form for pickup, destination, time, and price.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create ride feature coming soon!'),
                  backgroundColor: Color(0xFF3498db),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// Data model for ride requests
class RideRequest {
  final String id;
  final String userId;
  final String userName;
  final LatLng pickup;
  final LatLng destination;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final String status;

  RideRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.pickup,
    required this.destination,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.status,
  });
}