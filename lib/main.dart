import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:voteguard/firebase_options.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';
import 'package:voteguard/features/auth/ui/login_screen.dart';
import 'package:voteguard/features/dashboard/ui/dashboard_screen.dart';
import 'package:voteguard/features/observer/ui/observer_dashboard_screen.dart';
import 'package:voteguard/services/auth_service.dart';
import 'package:voteguard/services/ai_service.dart';
import 'package:voteguard/data/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => AppDatabase()),
        RepositoryProvider(
          create: (context) => AIService(
            apiKey: 'AIzaSyB2SXvs5KgrAYG1ng2SyRmALwZeL0I20cY',
          ),
        ),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(
          authService: context.read<AuthService>(),
        ),
        child: const VoteGuardApp(),
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
        if (settings.name == '/observer/dashboard') {
          final electionId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => ObserverDashboardScreen(electionId: electionId),
          );
        }
        return null;
      },
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            return const DashboardScreen();
          } else if (state.status == AuthStatus.authenticating) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
