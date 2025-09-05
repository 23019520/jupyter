import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _messageController = TextEditingController();
  final _subjectController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  
  final List<FAQItem> _faqItems = [
    FAQItem(
      question: "How do I book a ride?",
      answer: "To book a ride:\n1. Open the app and ensure location services are enabled\n2. Enter your pickup location and destination\n3. Select your preferred ride type\n4. Review the fare estimate and confirm your booking\n5. Wait for a driver to accept your request",
    ),
    FAQItem(
      question: "How do I cancel a ride?",
      answer: "You can cancel a ride by:\n1. Going to your active ride screen\n2. Tapping the 'Cancel Ride' button\n3. Selecting a cancellation reason\n4. Confirming the cancellation\n\nNote: Cancellation fees may apply depending on the timing.",
    ),
    FAQItem(
      question: "How is the fare calculated?",
      answer: "Fare calculation includes:\n• Base fare\n• Distance traveled\n• Time taken\n• Ride type multiplier\n• Current demand (surge pricing when applicable)\n• Any applicable taxes and fees",
    ),
    FAQItem(
      question: "What payment methods are accepted?",
      answer: "We accept:\n• Credit and debit cards\n• Mobile payments (Apple Pay, Google Pay)\n• Digital wallets\n• University student credits (where applicable)\n• Cash (in select areas)",
    ),
    FAQItem(
      question: "How do I become a driver?",
      answer: "To become a driver:\n1. Meet the minimum age requirement (21+)\n2. Have a valid driver's license\n3. Vehicle inspection and registration\n4. Background check\n5. Complete driver training\n6. Download the driver app and get approved",
    ),
    FAQItem(
      question: "What if I left something in the vehicle?",
      answer: "If you left an item:\n1. Go to 'Ride History' in the app\n2. Select the relevant trip\n3. Tap 'Report Lost Item'\n4. Describe the item and provide contact details\n5. We'll help connect you with the driver\n\nAlternatively, you can contact support directly.",
    ),
    FAQItem(
      question: "How do I report a safety concern?",
      answer: "For safety concerns:\n• Use the emergency button in the app during a ride\n• Contact us immediately through the support chat\n• Call our 24/7 safety hotline: 0800-SAFETY\n• Report through the 'Safety' section in your profile\n\nYour safety is our top priority.",
    ),
    FAQItem(
      question: "Why was I charged a different amount?",
      answer: "Price differences can occur due to:\n• Route changes during the trip\n• Traffic delays increasing time\n• Surge pricing during high demand\n• Tolls or additional stops\n• Cancellation or no-show fees\n\nCheck your trip details for a breakdown of charges.",
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Help & Support'),
          backgroundColor: const Color(0xFF9b59b6),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.help), text: 'FAQ'),
              Tab(icon: Icon(Icons.chat), text: 'Contact'),
              Tab(icon: Icon(Icons.info), text: 'Emergency'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFAQTab(),
            _buildContactTab(),
            _buildEmergencyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faqItems.length,
      itemBuilder: (context, index) {
        final faq = _faqItems[index];
        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              faq.question,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: const Color(0xFF3498db),
            collapsedIconColor: Colors.grey,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  faq.answer,
                  style: TextStyle(
                    color: Colors.grey[300],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Contact Options
          const Text(
            'Quick Contact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickContactCard(
                  icon: Icons.phone,
                  title: 'Call Us',
                  subtitle: '+27 123 456 7890',
                  color: const Color(0xFF27ae60),
                  onTap: () => _makePhoneCall('+27123456789'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickContactCard(
                  icon: Icons.email,
                  title: 'Email Us',
                  subtitle: 'support@rideshare.co.za',
                  color: const Color(0xFF3498db),
                  onTap: () => _sendEmail(),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickContactCard(
                  icon: Icons.chat,
                  title: 'Live Chat',
                  subtitle: 'Chat with support',
                  color: const Color(0xFFf39c12),
                  onTap: () => _startLiveChat(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickContactCard(
                  icon: Icons.schedule,
                  title: 'Hours',
                  subtitle: '24/7 Available',
                  color: const Color(0xFF9b59b6),
                  onTap: () => _showHoursInfo(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Contact Form
          const Text(
            'Send us a message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _subjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: const Icon(Icons.subject, color: Color(0xFF3498db)),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF3498db)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        prefixIcon: const Icon(Icons.message, color: Color(0xFF3498db)),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF3498db)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter your message';
                        }
                        if (value!.trim().length < 10) {
                          return 'Message must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitMessage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27ae60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Send Message',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Social Media Links
          const Text(
            'Connect with us',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                icon: Icons.facebook,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () => _openSocialMedia('https://facebook.com/rideshare'),
              ),
              _buildSocialButton(
                icon: Icons.alternate_email,
                label: 'Twitter',
                color: const Color(0xFF1DA1F2),
                onTap: () => _openSocialMedia('https://twitter.com/rideshare'),
              ),
              _buildSocialButton(
                icon: Icons.camera_alt,
                label: 'Instagram',
                color: const Color(0xFFE4405F),
                onTap: () => _openSocialMedia('https://instagram.com/rideshare'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 32),
                SizedBox(height: 8),
                Text(
                  'Emergency Services',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'For immediate emergencies, contact local emergency services first',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Emergency Contacts
          const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),

          _buildEmergencyContactCard(
            icon: Icons.local_police,
            title: 'Police',
            number: '10111',
            description: 'South African Police Service',
            color: Colors.blue,
          ),
          
          _buildEmergencyContactCard(
            icon: Icons.local_hospital,
            title: 'Medical Emergency',
            number: '10177',
            description: 'Emergency Medical Services',
            color: Colors.red,
          ),
          
          _buildEmergencyContactCard(
            icon: Icons.security,
            title: 'Ride Safety Hotline',
            number: '0800-SAFETY',
            description: '24/7 Ride safety support',
            color: const Color(0xFF9b59b6),
          ),

          const SizedBox(height: 32),

          // Safety Features
          const Text(
            'Safety Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),

          _buildSafetyFeatureCard(
            icon: Icons.share_location,
            title: 'Share Trip',
            description: 'Share your real-time location with trusted contacts during rides',
            onTap: () => _showFeatureInfo('Share Trip'),
          ),

          _buildSafetyFeatureCard(
            icon: Icons.emergency,
            title: 'Emergency Button',
            description: 'Quick access to emergency services and automatic location sharing',
            onTap: () => _showFeatureInfo('Emergency Button'),
          ),

          _buildSafetyFeatureCard(
            icon: Icons.verified_user,
            title: 'Driver Verification',
            description: 'All drivers undergo background checks and vehicle inspections',
            onTap: () => _showFeatureInfo('Driver Verification'),
          ),

          _buildSafetyFeatureCard(
            icon: Icons.gps_fixed,
            title: 'GPS Tracking',
            description: 'Real-time GPS tracking for all rides with route monitoring',
            onTap: () => _showFeatureInfo('GPS Tracking'),
          ),

          const SizedBox(height: 32),

          // Safety Tips
          const Text(
            'Safety Tips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498db),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Before your ride:',
                    style: TextStyle(
                      color: Color(0xFF27ae60),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Verify the driver and vehicle details\n• Check the license plate number\n• Share your trip with someone you trust',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'During your ride:',
                    style: TextStyle(
                      color: Color(0xFFf39c12),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Wear your seatbelt\n• Follow the route on the app\n• Trust your instincts\n• Keep emergency contacts handy',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.grey[900],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContactCard({
    required IconData icon,
    required String title,
    required String number,
    required String description,
    required Color color,
  }) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              description,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _makePhoneCall(number),
          icon: const Icon(Icons.phone, color: Color(0xFF27ae60)),
        ),
      ),
    );
  }

  Widget _buildSafetyFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF3498db)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: const Icon(Icons.info_outline, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // Action methods
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Could not launch phone dialer');
    }
  }

  Future<void> _sendEmail() async {
    final uri = Uri.parse('mailto:support@rideshare.co.za?subject=Support Request');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Could not launch email client');
    }
  }

  void _startLiveChat() {
    _showSnackBar('Live chat feature coming soon!');
    // TODO: Implement live chat functionality
  }

  void _showHoursInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Support Hours',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone Support:',
              style: TextStyle(color: Color(0xFF3498db), fontWeight: FontWeight.bold),
            ),
            Text('24/7 Available', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            Text(
              'Live Chat:',
              style: TextStyle(color: Color(0xFF3498db), fontWeight: FontWeight.bold),
            ),
            Text('Mon-Sun: 6:00 AM - 11:00 PM', style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            Text(
              'Email Response:',
              style: TextStyle(color: Color(0xFF3498db), fontWeight: FontWeight.bold),
            ),
            Text('Within 24 hours', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('support_messages').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _subjectController.clear();
      _messageController.clear();
      
      _showSnackBar('Message sent successfully! We\'ll get back to you soon.');
    } catch (e) {
      _showSnackBar('Failed to send message. Please try again.');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openSocialMedia(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open social media link');
    }
  }

  void _showFeatureInfo(String feature) {
    String info;
    switch (feature) {
      case 'Share Trip':
        info = 'Share your live location and trip details with up to 5 trusted contacts. They can track your journey in real-time and receive notifications when you arrive safely.';
        break;
      case 'Emergency Button':
        info = 'Press and hold the emergency button for 3 seconds to automatically contact emergency services and alert your emergency contacts with your location.';
        break;
      case 'Driver Verification':
        info = 'All drivers undergo comprehensive background checks, vehicle inspections, and identity verification before being approved to drive on our platform.';
        break;
      case 'GPS Tracking':
        info = 'Every ride is tracked with GPS technology. We monitor routes for safety and can quickly locate you in case of emergency.';
        break;
      default:
        info = 'Feature information not available.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          feature,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          info,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3498db),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}