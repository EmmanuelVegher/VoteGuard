import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:voteguard/firebase_options.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';
import 'package:voteguard/features/auth/ui/login_screen.dart';
import 'package:voteguard/features/dashboard/ui/dashboard_screen.dart';
import 'package:voteguard/features/observer/ui/observer_dashboard_screen.dart';
import 'package:voteguard/features/observer/ui/election_gallery_screen.dart';
import 'package:voteguard/features/admin/ui/situation_room_screen.dart';
import 'package:voteguard/services/auth_service.dart';
import 'package:voteguard/services/ai_service.dart';
import 'package:voteguard/data/local/app_database.dart';
import 'package:voteguard/services/notification_service.dart';
import 'package:voteguard/features/splash/ui/splash_screen.dart';
import 'package:voteguard/features/results/ui/public_results_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize push notification system
  await NotificationService().init();

  final aiService = AIService();
  
  // Dynamic API Key Sync from Firestore
  FirebaseFirestore.instance
      .collection('settings')
      .doc('system_settings')
      .snapshots()
      .listen((doc) {
    if (doc.exists) {
      try {
        final valueStr = doc.data()?['value'] as String?;
        if (valueStr != null) {
          final valueJson = jsonDecode(valueStr);
          
          // 1. Sync API Key
          final key = valueJson['ai']?['gemini_api_key'] ?? valueJson['gemini_api_key'];
          if (key != null && key.toString().isNotEmpty) {
            aiService.setApiKey(key.toString());
          }

          // 2. Sync Selected OCR Model
          final modelId = valueJson['ai']?['ocrModel'];
          if (modelId != null && modelId.toString().isNotEmpty) {
            aiService.setPrimaryModel(modelId.toString());
            debugPrint('AI Service: Config Updated (Model: $modelId)');
          }
        }
      } catch (e) {
        debugPrint('AI Service: Error parsing dynamic config: $e');
      }
    }
  });
  
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => AppDatabase()),
      ],
      child: ChangeNotifierProvider.value(
        value: aiService,
        child: BlocProvider(
          create: (context) => AuthBloc(
            authService: context.read<AuthService>(),
          ),
          child: const VoteGuardApp(),
        ),
      ),
    ),
  );
}

class VoteGuardApp extends StatelessWidget {
  const VoteGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoteGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        if (settings.name == '/observer/dashboard') {
          final electionId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => ObserverDashboardScreen(electionId: electionId),
          );
        }
        if (settings.name == '/public-results') {
          return MaterialPageRoute(builder: (context) => const PublicResultsScreen());
        }
        return null;
      },
      home: const SplashScreen(),
    );
  }
}
