import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class PasswordResetTester {
  static final AuthService _authService = AuthService();

  /// Test password reset functionality with comprehensive validation
  static Future<void> testPasswordReset(String email, BuildContext context) async {
    try {
      print('🔄 Testing password reset for: $email');
      
      // First, check if email is registered
      final isRegistered = await _authService.isEmailRegistered(email);
      if (!isRegistered) {
        throw 'Email is not registered in the system';
      }
      
      print('✓ Email is registered, proceeding with password reset...');
      
      // Send password reset email
      await _authService.resetPassword(email);
      
      print('✅ Password reset email sent successfully!');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Test successful!', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Password reset email sent to $email'),
                const SizedBox(height: 4),
                const Text('Check your email and spam folder.',
                  style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
    } catch (e) {
      print('❌ Password reset test failed: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❌ Test failed', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Error: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Test email verification sending
  static Future<void> testEmailVerification(BuildContext context) async {
    try {
      print('🔄 Testing email verification...');
      
      await _authService.sendEmailVerification();
      
      print('✅ Email verification sent successfully!');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Verification email sent! Check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Email verification test failed: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Verification failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Get detailed email information for testing
  static Future<Map<String, dynamic>> getEmailInfo(String email) async {
    try {
      final isRegistered = await _authService.isEmailRegistered(email);
      final signInMethods = isRegistered 
        ? await _authService.getSignInMethods(email)
        : <String>[];
      
      return {
        'email': email,
        'isRegistered': isRegistered,
        'signInMethods': signInMethods,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'email': email,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Test widget for easy integration in debug builds
  static Widget buildTestWidget() {
    return Builder(
      builder: (context) {
        final emailController = TextEditingController();
        
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🧪 Auth Testing Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Test Email',
                    border: OutlineInputBorder(),
                    hintText: 'Enter email to test',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        final email = emailController.text.trim();
                        if (email.isNotEmpty) {
                          testPasswordReset(email, context);
                        }
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Test Reset'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        testEmailVerification(context);
                      },
                      icon: const Icon(Icons.verified),
                      label: const Text('Test Verification'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final email = emailController.text.trim();
                        if (email.isNotEmpty) {
                          final info = await getEmailInfo(email);
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Email Info'),
                                content: Text(
                                  'Email: ${info['email']}\n'
                                  'Registered: ${info['isRegistered']}\n'
                                  'Sign-in methods: ${info['signInMethods']}\n'
                                  '${info['error'] != null ? 'Error: ${info['error']}' : ''}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('Email Info'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: This panel should only be used in debug builds',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}