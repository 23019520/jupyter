import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../rideshare/ride_history_screen.dart';
import 'profile_settings_screen.dart';
import 'help_support_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.black, // Add background color for consistency
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: const Color(0xFF9b59b6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF3498db),
                    child: Text(
                      (user?.email?.substring(0, 1).toUpperCase()) ?? 'U',
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
                          user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: Colors.grey[400],
                          ),
                        ),
                        if (!authService.isEmailVerified)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Email not verified',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu Items
          _buildMenuItem(
            context,
            icon: Icons.history,
            title: 'Ride History',
            subtitle: 'View your past rides',
            onTap: () {
              _navigateToScreen(context, const RideHistoryScreen());
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.person,
            title: 'Profile Settings',
            subtitle: 'Manage your account',
            onTap: () {
              _navigateToScreen(context, const ProfileSettingsScreen());
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.payment,
            title: 'Payment Methods',
            subtitle: 'Manage payment options',
            onTap: () {
              _navigateToPaymentMethods(context);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help and contact us',
            onTap: () {
              _navigateToScreen(context, const HelpSupportScreen());
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.info,
            title: 'About',
            subtitle: 'App version and info',
            onTap: () {
              _showAboutDialog(context);
            },
          ),
          
          // Email Verification (if needed)
          if (!authService.isEmailVerified)
            _buildMenuItem(
              context,
              icon: Icons.mark_email_unread,
              title: 'Verify Email',
              subtitle: 'Verify your email address',
              iconColor: Colors.orange,
              onTap: () {
                _handleEmailVerification(context, authService);
              },
            ),
          
          const SizedBox(height: 32),

          // Sign Out Button
          Card(
            color: Colors.red.withOpacity(0.1),
            child: ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () => _handleSignOut(context, authService),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? const Color(0xFF3498db)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios, 
          size: 16, 
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  // Navigation helper methods
  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).catchError((error) {
      // Handle navigation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigation error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _navigateToPaymentMethods(BuildContext context) {
    // For now, show coming soon message
    // Replace with actual navigation when PaymentMethodsScreen is ready
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment methods coming soon!'),
        backgroundColor: Color(0xFF3498db),
      ),
    );
    
    // TODO: Uncomment when PaymentMethodsScreen is implemented
    // _navigateToScreen(context, const PaymentMethodsScreen());
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'University Ride Share',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.local_taxi,
        size: 48,
        color: Color(0xFF3498db),
      ),
      children: const [
        Text('A ride-sharing app for university students to share rides and save money.'),
        SizedBox(height: 16),
        Text('Features:'),
        Text('• Share rides with fellow students'),
        Text('• Split costs and save money'),
        Text('• Safe and verified drivers'),
        Text('• Real-time tracking'),
        Text('• 24/7 support'),
      ],
    );
  }

  Future<void> _handleEmailVerification(BuildContext context, AuthService authService) async {
    try {
      await authService.sendEmailVerification();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Check your inbox.'),
            backgroundColor: Color(0xFF27ae60),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut(BuildContext context, AuthService authService) async {
    try {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

      if (shouldSignOut == true) {
        // Show loading indicator
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Signing out...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        await authService.signOut();
        
        // Navigate to login screen and clear the stack
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login', // Make sure this route exists in your main.dart
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}