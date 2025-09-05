// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AuthService _authService = AuthService();

  String? _fcmToken;
  bool _isInitialized = false;

  // Getters
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  // Initialize notification service
  Future<void> initialize() async {
    try {
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      await _setupMessageHandlers();
      _isInitialized = true;
      
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
      rethrow;
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  // Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notification permission');
      
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');
      
      // Save token to user profile if authenticated
      if (_authService.currentUser != null) {
        await _saveFCMTokenToUser();
      }
    } else {
      debugPrint('❌ User declined notification permission');
    }

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      debugPrint('🔄 FCM Token refreshed: $token');
      
      if (_authService.currentUser != null) {
        await _saveFCMTokenToUser();
      }
    });
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle messages when app is terminated
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel rideUpdatesChannel = AndroidNotificationChannel(
      'ride_updates',
      'Ride Updates',
      description: 'Notifications about your rides',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const AndroidNotificationChannel driverArrivalChannel = AndroidNotificationChannel(
      'driver_arrival',
      'Driver Arrival',
      description: 'Notifications when your driver arrives',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('driver_arrival'),
    );

    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general',
      'General Notifications',
      description: 'General app notifications',
      importance: Importance.defaultImportance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(rideUpdatesChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(driverArrivalChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    
    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  // Handle messages when app is opened
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 App opened from notification: ${message.messageId}');
    
    // Handle navigation based on notification type
    final notificationType = message.data['type'];
    final rideId = message.data['rideId'];
    
    switch (notificationType) {
      case 'ride_request':
        _navigateToRideDetails(rideId);
        break;
      case 'driver_arrival':
        _navigateToActiveRide(rideId);
        break;
      case 'ride_status_update':
        _navigateToRideHistory();
        break;
      default:
        _navigateToHome();
        break;
    }
  }

  // Handle local notification taps
  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    
    if (response.payload != null) {
      final Map<String, dynamic> payload = 
          Map<String, dynamic>.from(response.payload as Map? ?? {});
      
      final notificationType = payload['type'];
      final rideId = payload['rideId'];
      
      switch (notificationType) {
        case 'ride_request':
          _navigateToRideDetails(rideId);
          break;
        case 'driver_arrival':
          _navigateToActiveRide(rideId);
          break;
        case 'ride_status_update':
          _navigateToRideHistory();
          break;
        default:
          _navigateToHome();
          break;
      }
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      final channelId = _getChannelId(data['type']);
      
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: _getImportance(channelId),
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF3498db),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: data.toString(),
      );
    }
  }

  // Get notification channel ID based on type
  String _getChannelId(String? type) {
    switch (type) {
      case 'ride_request':
      case 'ride_status_update':
        return 'ride_updates';
      case 'driver_arrival':
        return 'driver_arrival';
      default:
        return 'general';
    }
  }

  // Get channel name
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'ride_updates':
        return 'Ride Updates';
      case 'driver_arrival':
        return 'Driver Arrival';
      default:
        return 'General Notifications';
    }
  }

  // Get channel description
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'ride_updates':
        return 'Notifications about your rides';
      case 'driver_arrival':
        return 'Notifications when your driver arrives';
      default:
        return 'General app notifications';
    }
  }

  // Get importance level
  Importance _getImportance(String channelId) {
    switch (channelId) {
      case 'driver_arrival':
        return Importance.max;
      case 'ride_updates':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }

  // Send ride request notification
  Future<void> sendRideRequestNotification({
    required String driverToken,
    required String passengerName,
    required String pickupLocation,
    required String destination,
    required String rideId,
  }) async {
    try {
      await _sendNotificationToToken(
        token: driverToken,
        title: '🚗 New Ride Request',
        body: '$passengerName wants to join your ride from $pickupLocation to $destination',
        data: {
          'type': 'ride_request',
          'rideId': rideId,
          'passengerName': passengerName,
          'pickupLocation': pickupLocation,
          'destination': destination,
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending ride request notification: $e');
    }
  }

  // Send driver arrival notification
  Future<void> sendDriverArrivalNotification({
    required String passengerToken,
    required String driverName,
    required String pickupLocation,
    required String rideId,
  }) async {
    try {
      await _sendNotificationToToken(
        token: passengerToken,
        title: '🚘 Your Driver Has Arrived!',
        body: '$driverName is waiting for you at $pickupLocation',
        data: {
          'type': 'driver_arrival',
          'rideId': rideId,
          'driverName': driverName,
          'pickupLocation': pickupLocation,
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending driver arrival notification: $e');
    }
  }

  // Send ride status update notification
  Future<void> sendRideStatusUpdateNotification({
    required String userToken,
    required String title,
    required String message,
    required String rideId,
    required String status,
  }) async {
    try {
      await _sendNotificationToToken(
        token: userToken,
        title: title,
        body: message,
        data: {
          'type': 'ride_status_update',
          'rideId': rideId,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending ride status update notification: $e');
    }
  }

  // Generic method to send notification to specific token
  Future<void> _sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // Note: This would typically be handled by your backend server
    // For now, this is a placeholder method
    // In production, you'd make an API call to your backend
    // which would use the Firebase Admin SDK to send the notification
    
    debugPrint('🔔 Would send notification to token: $token');
    debugPrint('📧 Title: $title');
    debugPrint('📝 Body: $body');
    debugPrint('🗂️ Data: $data');
    
    // TODO: Implement actual notification sending via your backend API
    throw UnimplementedError(
      'Notification sending must be implemented on the backend using Firebase Admin SDK'
    );
  }

  // Save FCM token to user profile
  Future<void> _saveFCMTokenToUser() async {
    // TODO: Implement saving FCM token to Firestore user document
    // This will be implemented when you create the user service
    debugPrint('💾 Would save FCM token to user profile: $_fcmToken');
  }

  // Navigation helpers
  void _navigateToRideDetails(String? rideId) {
    // TODO: Implement navigation to ride details screen
    debugPrint('🧭 Would navigate to ride details: $rideId');
  }

  void _navigateToActiveRide(String? rideId) {
    // TODO: Implement navigation to active ride screen
    debugPrint('🧭 Would navigate to active ride: $rideId');
  }

  void _navigateToRideHistory() {
    // TODO: Implement navigation to ride history screen
    debugPrint('🧭 Would navigate to ride history');
  }

  void _navigateToHome() {
    // TODO: Implement navigation to home screen
    debugPrint('🧭 Would navigate to home');
  }

  // Request notification permissions (call this when user first opens the app)
  Future<bool> requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Also request local notification permissions on iOS
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          await _localNotifications
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              );
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  // Show a local notification manually (for testing or immediate feedback)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String channelId = 'general',
    Map<String, dynamic>? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: _getImportance(channelId),
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF3498db),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformDetails,
        payload: payload?.toString(),
      );
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Clear specific notification
  Future<void> clearNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Dispose resources
  void dispose() {
    // Clean up any resources if needed
    debugPrint('🧹 NotificationService disposed');
  }
}