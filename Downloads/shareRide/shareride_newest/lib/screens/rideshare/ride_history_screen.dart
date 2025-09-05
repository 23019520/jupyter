import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();

  // Sample ride history data - replace with your data source
  final List<RideHistory> _completedRides = [
    RideHistory(
      id: '1',
      driverName: 'Sarah Johnson',
      pickupAddress: 'University of Venda',
      destinationAddress: 'Thohoyandou CBD',
      date: DateTime.now().subtract(const Duration(days: 2)),
      price: 25.0,
      status: 'completed',
      rating: 4.5,
      isDriver: false,
    ),
    RideHistory(
      id: '2',
      driverName: 'You',
      pickupAddress: 'Thohoyandou Mall',
      destinationAddress: 'Sibasa',
      date: DateTime.now().subtract(const Duration(days: 5)),
      price: 105.0, // 3 passengers × R35
      status: 'completed',
      rating: 4.8,
      isDriver: true,
    ),
  ];

  final List<RideHistory> _activeRides = [
    RideHistory(
      id: '3',
      driverName: 'Mike Netshiunda',
      pickupAddress: 'University of Venda',
      destinationAddress: 'Louis Trichardt',
      date: DateTime.now().add(const Duration(hours: 2)),
      price: 45.0,
      status: 'confirmed',
      isDriver: false,
    ),
  ];

  final List<RideHistory> _cancelledRides = [
    RideHistory(
      id: '4',
      driverName: 'John Doe',
      pickupAddress: 'Thohoyandou CBD',
      destinationAddress: 'Polokwane',
      date: DateTime.now().subtract(const Duration(days: 1)),
      price: 120.0,
      status: 'cancelled',
      isDriver: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: const Color(0xFF3498db),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRideList(_activeRides, 'active'),
          _buildRideList(_completedRides, 'completed'),
          _buildRideList(_cancelledRides, 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildRideList(List<RideHistory> rides, String type) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(type),
              size: 64,
              color: Theme.of(context).inputDecorationTheme.hintStyle?.color,
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(type),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubMessage(type),
              style: Theme.of(context).inputDecorationTheme.hintStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        return _buildRideCard(rides[index]);
      },
    );
  }

  Widget _buildRideCard(RideHistory ride) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(ride.status);
    final isUpcoming = ride.date.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showRideDetails(ride),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with driver info and status
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: ride.isDriver ? const Color(0xFF2ecc71) : const Color(0xFF3498db),
                    child: Icon(
                      ride.isDriver ? Icons.drive_eta : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.isDriver ? 'You (Driver)' : ride.driverName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          _formatDate(ride.date),
                          style: theme.inputDecorationTheme.hintStyle?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Route info
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2ecc71),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 24,
                        color: theme.inputDecorationTheme.hintStyle?.color?.withOpacity(0.3),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFe74c3c),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupAddress,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          ride.destinationAddress,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Price and rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'R${ride.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2ecc71),
                    ),
                  ),
                  if (ride.rating != null && ride.status == 'completed')
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFf39c12),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ride.rating!.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                ],
              ),
              
              // Action buttons for active rides
              if (ride.status == 'confirmed') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelRide(ride),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _contactDriver(ride),
                        child: const Text('Contact'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF2ecc71);
      case 'confirmed':
        return const Color(0xFF3498db);
      case 'cancelled':
        return const Color(0xFFe74c3c);
      default:
        return Colors.grey;
    }
  }

  IconData _getEmptyIcon(String type) {
    switch (type) {
      case 'active':
        return Icons.directions_car_outlined;
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.history;
    }
  }

  String _getEmptyMessage(String type) {
    switch (type) {
      case 'active':
        return 'No Active Rides';
      case 'completed':
        return 'No Completed Rides';
      case 'cancelled':
        return 'No Cancelled Rides';
      default:
        return 'No Rides';
    }
  }

  String _getEmptySubMessage(String type) {
    switch (type) {
      case 'active':
        return 'You don\'t have any active rides.\nRequest a ride to get started!';
      case 'completed':
        return 'Your completed rides will appear here.\nStart sharing rides to build your history!';
      case 'cancelled':
        return 'Your cancelled rides will appear here.';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      return 'Tomorrow at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == -1) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference > 0) {
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showRideDetails(RideHistory ride) {
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
                
                // Trip details header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(ride.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        ride.status == 'completed' ? Icons.check_circle : 
                        ride.status == 'confirmed' ? Icons.schedule :
                        Icons.cancel,
                        color: _getStatusColor(ride.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(ride.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDate(ride.date),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Driver info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: ride.isDriver ? const Color(0xFF2ecc71) : const Color(0xFF3498db),
                      child: Icon(
                        ride.isDriver ? Icons.drive_eta : Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ride.isDriver ? 'You (Driver)' : ride.driverName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            ride.isDriver ? 'You drove this trip' : 'Driver',
                            style: Theme.of(context).inputDecorationTheme.hintStyle,
                          ),
                        ],
                      ),
                    ),
                    if (ride.rating != null && ride.status == 'completed')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf39c12).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFf39c12),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ride.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFFf39c12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Route details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2ecc71),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup',
                                  style: Theme.of(context).inputDecorationTheme.hintStyle,
                                ),
                                Text(
                                  ride.pickupAddress,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
                        width: 2,
                        height: 32,
                        color: Theme.of(context).inputDecorationTheme.hintStyle?.color?.withOpacity(0.3),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFe74c3c),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Destination',
                                  style: Theme.of(context).inputDecorationTheme.hintStyle,
                                ),
                                Text(
                                  ride.destinationAddress,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Price info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ride.isDriver ? 'Total Earned' : 'Amount Paid',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'R${ride.price.toStringAsFixed(0)}',
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
                
                // Action buttons based on status
                if (ride.status == 'confirmed') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelRide(ride);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text(
                            'Cancel Ride',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _contactDriver(ride);
                          },
                          child: const Text('Contact Driver'),
                        ),
                      ),
                    ],
                  ),
                ] else if (ride.status == 'completed' && !ride.isDriver && ride.rating == null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _rateRide(ride);
                      },
                      icon: const Icon(Icons.star),
                      label: const Text('Rate This Ride'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cancelRide(RideHistory ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: Text('Are you sure you want to cancel your ride with ${ride.driverName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ride cancelled successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
  }

  void _contactDriver(RideHistory ride) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact ${ride.driverName}'),
        content: const Text('Choose how you would like to contact the driver:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call feature coming soon!')),
              );
            },
            child: const Text('Call'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message feature coming soon!')),
              );
            },
            child: const Text('Message'),
          ),
        ],
      ),
    );
  }

  void _rateRide(RideHistory ride) {
    double rating = 5.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rate ${ride.driverName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How was your ride experience?'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        rating = index + 1.0;
                      });
                    },
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFf39c12),
                      size: 32,
                    ),
                  );
                }),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Thank you for rating ${ride.driverName}!'),
                  backgroundColor: const Color(0xFF2ecc71),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

// Data model for ride history
class RideHistory {
  final String id;
  final String driverName;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime date;
  final double price;
  final String status;
  final double? rating;
  final bool isDriver;

  RideHistory({
    required this.id,
    required this.driverName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.date,
    required this.price,
    required this.status,
    this.rating,
    required this.isDriver,
  });
}