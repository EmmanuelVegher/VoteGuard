import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';
import 'package:voteguard/features/dashboard/ui/dashboard_screen.dart';
import 'package:voteguard/features/auth/ui/register_screen.dart';
import 'package:voteguard/features/observer/ui/election_gallery_screen.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:voteguard/data/local/app_database.dart' as db;
import 'package:voteguard/services/sync_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:voteguard/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image with Overlay
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/election_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.white.withOpacity(0.6), // More visible background
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Title
                    Image.asset(
                      'assets/images/voteguard_logo.png',
                      height: 80,
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        children: [
                          const TextSpan(text: 'VoteGuard '),
                          TextSpan(
                            text: 'Portal',
                            style: TextStyle(color: const Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'ELECTION PORTAL FOR VOTEGUARD',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel('EMAIL / PHONE NUMBER'),
                          TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Email/Phone Number',
                              prefixIcon: const Icon(LucideIcons.logIn, size: 20, color: Color(0xFF64748B)),
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInputLabel('PASSWORD'),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                child: const Text(
                                  'PASSWORD RESET',
                                  style: TextStyle(color: Color(0xFF991B1B), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: '••••••••••••',
                              prefixIcon: const Icon(LucideIcons.lock, size: 20, color: Color(0xFF64748B)),
                              fillColor: const Color(0xFFF8FAFC),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                                  size: 18,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) {
                                    setState(() => _rememberMe = v ?? false);
                                  },
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'REMEMBER THIS DEVICE',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Login Button
                          BlocConsumer<AuthBloc, AuthState>(
                            listener: (context, state) {
                              if (state.status == AuthStatus.authenticated) {
                                if (_rememberMe) {
                                  context.read<AuthService>().saveCredentials(_emailController.text, _passwordController.text);
                                } else {
                                  context.read<AuthService>().clearCredentials();
                                }

                                // Trigger background sync of metadata (parties, checklists, elections)
                                try {
                                  final syncService = SyncService(context.read<db.AppDatabase>());
                                  syncService.syncAllData().catchError((e) => debugPrint('Background sync failed: $e'));
                                } catch (e) {
                                  debugPrint('Failed to start sync: $e');
                                }

                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ElectionGalleryScreen()),
                                  (route) => false,
                                );
                              }
                              if (state.status == AuthStatus.failure) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    title: Row(
                                      children: [
                                        const Icon(LucideIcons.circleAlert, color: Color(0xFF991B1B)),
                                        const SizedBox(width: 12),
                                        Text('Login Failed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontSize: 20)),
                                      ],
                                    ),
                                    content: Text(
                                      state.errorMessage ?? 'An unknown error occurred during authentication. Please check your credentials and try again.',
                                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF991B1B),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: Text('OK', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            builder: (context, state) {
                              final isLoading = state.status == AuthStatus.authenticating;
                              return ElevatedButton(
                                onPressed: isLoading ? null : () {
                                  context.read<AuthBloc>().add(LoginRequested(
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                  ));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF991B1B), // Dark Red
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                child: isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(LucideIcons.shield, size: 18),
                                        SizedBox(width: 8),
                                        Text('LOGIN'),
                                      ],
                                    ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'OR SECURE ACCESS',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Biometric Button
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
                                final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
                                
                                if (!canAuthenticate) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics not supported on this device', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF991B1B)));
                                  }
                                  return;
                                }

                                final bool didAuthenticate = await _localAuth.authenticate(
                                  localizedReason: 'Authenticate to access VoteGuard Portal',
                                  options: const AuthenticationOptions(biometricOnly: true),
                                );

                                if (didAuthenticate && mounted) {
                                  final credentials = await context.read<AuthService>().getStoredCredentials();
                                  if (credentials != null) {
                                    context.read<AuthBloc>().add(LoginRequested(
                                      email: credentials['email']!,
                                      password: credentials['password']!,
                                    ));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved credentials. Please login manually and check "Remember this device".', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF991B1B)));
                                  }
                                }
                              } catch (e) {
                                debugPrint('Biometric Error: $e');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 45),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.fingerprintPattern, size: 18, color: Color(0xFF1E293B)),
                                SizedBox(width: 8),
                                Text('LOGIN WITH BIOMETRICS', style: TextStyle(color: Color(0xFF1E293B), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
                          /*
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'NEW TO VOTEGUARD?',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Create Account Button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.userPlus, size: 18, color: Color(0xFF991B1B)),
                                  SizedBox(width: 8),
                                  Text('CREATE NEW ACCOUNT', style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          */
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text(
                      'PUBLIC MONITORING DASHBOARD',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    // Public Results Hub
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.activity, color: Color(0xFF991B1B), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PUBLIC RESULTS HUB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                Text('LIVE RESULTS & SITUATION ROOM', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Text(
                      'PROPRIETARY SYSTEM OF IDPC GENERAL ELECTIONS MONITORING. ALL TELEMETRY IS RECORDED FOR NATIONAL SECURITY PURPOSES UNDER FEDERAL PROTOCOL.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: const Color(0xFF64748B).withOpacity(0.8), fontSize: 7, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
