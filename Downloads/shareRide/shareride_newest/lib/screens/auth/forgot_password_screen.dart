import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _emailSent = false;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60; // 1 minute cooldown
    });
    
    // Countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _cooldownSeconds--;
        });
        return _cooldownSeconds > 0;
      }
      return false;
    });
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    
    // Clear any previous errors
    authProvider.clearError();
    
    print('🔄 Attempting to send password reset to: $email');
    
    final success = await authProvider.resetPassword(email);

    if (mounted) {
      if (success) {
        setState(() {
          _emailSent = true;
        });
        
        _startCooldown();
        
        print('✅ Password reset email sent successfully to: $email');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Password reset email sent! 📧', 
                         style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Check your inbox: $email', 
                     style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                const Text('Don\'t forget to check your spam folder!', 
                          style: TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        print('❌ Failed to send password reset email: ${authProvider.error}');
        
        String errorMessage = authProvider.error ?? 'Failed to send reset email';
        
        // Provide more helpful error messages
        if (errorMessage.toLowerCase().contains('user-not-found')) {
          errorMessage = 'No account found with this email address. Please check your email or create a new account.';
        } else if (errorMessage.toLowerCase().contains('invalid-email')) {
          errorMessage = 'Please enter a valid email address.';
        } else if (errorMessage.toLowerCase().contains('too-many-requests')) {
          errorMessage = 'Too many attempts. Please wait a few minutes before trying again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Failed to send reset email', 
                         style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(errorMessage, style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 
                               MediaQuery.of(context).padding.top - 
                               kToolbarHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Icon and Title
                        const Icon(
                          Icons.lock_reset,
                          size: 64,
                          color: Color(0xFF3498db),
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Forgot Password?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          _emailSent
                              ? 'We\'ve sent a password reset link to your email address. Please check your inbox (and spam folder) and follow the instructions.'
                              : 'Don\'t worry! Enter your email address and we\'ll send you a link to reset your password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Email Field
                        if (!_emailSent) ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            validator: Validators.email,
                            onFieldSubmitted: (_) => _sendPasswordResetEmail(),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email address',
                              prefixIcon: Icon(Icons.email_outlined),
                              helperText: 'We\'ll send a reset link to this email',
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Send Reset Email Button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: (authProvider.isLoading || _cooldownSeconds > 0) 
                                  ? null 
                                  : _sendPasswordResetEmail,
                              icon: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(_cooldownSeconds > 0 ? Icons.timer : Icons.send),
                              label: Text(
                                authProvider.isLoading
                                    ? 'Sending...'
                                    : _cooldownSeconds > 0
                                        ? 'Wait $_cooldownSeconds seconds'
                                        : 'Send Reset Email',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          if (_cooldownSeconds > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Please wait $_cooldownSeconds seconds before requesting another email',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                        
                        // Success State
                        if (_emailSent) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Email Sent!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Check your email: ${_emailController.text}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'The link will expire in 1 hour',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Send to Different Email Button
                          OutlinedButton(
                            onPressed: (authProvider.isLoading || _cooldownSeconds > 0) ? null : () {
                              setState(() {
                                _emailSent = false;
                              });
                              authProvider.clearError();
                            },
                            child: Text(
                              _cooldownSeconds > 0 
                                  ? 'Try different email in $_cooldownSeconds s'
                                  : 'Send to Different Email',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        
                        // Back to Login Button
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Help Text
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color?.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.help_outline,
                                color: Color(0xFF3498db),
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Having trouble? Make sure to check your spam folder. The reset link expires in 1 hour. If you still need help, contact our support team.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}