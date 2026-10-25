import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';
import 'package:voteguard/features/auth/ui/login_screen.dart';
import 'package:voteguard/features/auth/ui/liveness_enrollment_screen.dart';
import 'package:voteguard/features/observer/ui/election_gallery_screen.dart';
import 'package:voteguard/features/admin/ui/situation_room_screen.dart';

class DashboardRedirect extends StatelessWidget {
  const DashboardRedirect({super.key});

  static Widget getTargetScreen(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    
    if (authState.status != AuthStatus.authenticated) {
      return const LoginScreen();
    }

    final user = authState.user;
    if (user == null) {
      return const LoginScreen();
    }

    final role = authState.role?.toUpperCase();
    const observerRoles = [
      'OBSERVER',
      'ADMIN',
      'SUPER_ADMIN',
      'DIOCESAN_DIRECTOR',
      'DIOCESAN_PROJECT_MANAGER',
      'DIOCESAN_COORDINATOR',
      'PROVINCIAL_DIRECTOR',
      'PROVINCIAL_PROJECT_MANAGER',
      'PROVINCIAL_SECRETARY',
      'BISHOP',
      'ARCH-BISHOP',
      'ARCH_BISHOP'
    ];
    
    final targetDashboard = (role != null && observerRoles.contains(role))
        ? const ElectionGalleryScreen()
        : const SituationRoomScreen();

    // Wrap with Biometric Liveness Gate
    return BiometricEnrollmentGate(
      userId: user.uid,
      targetScreen: targetDashboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return getTargetScreen(context);
  }
}

enum GateStatus {
  loading,
  notEnrolled,
  flaggedDuplicate,
  verified,
}

class BiometricEnrollmentGate extends StatefulWidget {
  final String userId;
  final Widget targetScreen;

  const BiometricEnrollmentGate({
    super.key,
    required this.userId,
    required this.targetScreen,
  });

  @override
  State<BiometricEnrollmentGate> createState() => _BiometricEnrollmentGateState();
}

class _BiometricEnrollmentGateState extends State<BiometricEnrollmentGate> {
  static const _storage = FlutterSecureStorage();
  late Future<GateStatus> _gateCheck;

  @override
  void initState() {
    super.initState();
    _gateCheck = _checkEnrollmentAndAudit();
  }

  Future<GateStatus> _checkEnrollmentAndAudit() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final data = doc.data();
      final profileUrl = (data?['profilePictureUrl'] ?? data?['profileImageUrl']) as String?;
      final hasPicture = profileUrl != null && profileUrl.trim().isNotEmpty;
      final isEnrolled = data?['isFaceEnrolled'] == true && hasPicture;

      if (!isEnrolled) {
        await _storage.delete(key: 'isFaceEnrolled_${widget.userId}');
        return GateStatus.notEnrolled;
      }

      // Check Biometric Deduplication Audit Flag
      final auditStatus = data?['faceAuditStatus'] as String?;
      if (auditStatus == 'FLAGGED_DUPLICATE') {
        return GateStatus.flaggedDuplicate;
      }

      await _storage.write(key: 'isFaceEnrolled_${widget.userId}', value: 'true');
      return GateStatus.verified;
    } catch (e) {
      debugPrint("Biometric check error: $e");
      final cached = await _storage.read(key: 'isFaceEnrolled_${widget.userId}');
      return cached == 'true' ? GateStatus.verified : GateStatus.notEnrolled;
    }
  }

  Widget _buildDuplicateWarningScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Biometric Security Alert",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Biometric Duplicate Detected",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Our biometric integrity system has detected that this facial portrait matches an already enrolled election observer.\n\nUnder election observation accreditation standards, each field observer is restricted to a single verified account to protect checklist credibility and Form EC8A chain of custody.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Re-verify Selfie button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    "Re-capture Live Face Photo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LivenessEnrollmentScreen(isModal: true),
                      ),
                    );
                    if (updated == true) {
                      setState(() {
                        _gateCheck = _checkEnrollmentAndAudit();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Sign Out option
              TextButton(
                onPressed: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                child: const Text(
                  "Log out of this account",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GateStatus>(
      future: _gateCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF020617),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)),
            ),
          );
        }

        final status = snapshot.data ?? GateStatus.notEnrolled;

        switch (status) {
          case GateStatus.flaggedDuplicate:
            return _buildDuplicateWarningScreen(context);
          case GateStatus.notEnrolled:
            return const LivenessEnrollmentScreen();
          case GateStatus.verified:
            return widget.targetScreen;
          case GateStatus.loading:
            return const Scaffold(
              backgroundColor: Color(0xFF020617),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              ),
            );
        }
      },
    );
  }
}
