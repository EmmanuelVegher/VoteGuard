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
  Map<String, dynamic>? _conflictData;
  bool _proceedAnyway = false;

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

      // An account is strictly considered enrolled ONLY if it actually possesses a valid profile picture
      if (!hasPicture) {
        await _storage.delete(key: 'isFaceEnrolled_${widget.userId}');
        await _storage.delete(key: 'profilePictureUrl_${widget.userId}');
        await _storage.delete(key: 'local_profile_image_path_${widget.userId}');

        // If Firestore still has stale isFaceEnrolled: true, reset it to false
        if (data?['isFaceEnrolled'] == true) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .set({'isFaceEnrolled': false}, SetOptions(merge: true))
              .catchError((_) {});
        }
        return GateStatus.notEnrolled;
      }

      // Self-healing: ensure isFaceEnrolled is true in Firestore if user has a profile picture
      if (data?['isFaceEnrolled'] != true) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({'isFaceEnrolled': true}, SetOptions(merge: true))
            .catchError((_) {});
      }

      // 1. Duplicate check gate commented out for now
      /*
      final auditStatus = data?['faceAuditStatus'] as String?;
      final hasConflict = data?['hasBiometricConflict'] == true;
      if (auditStatus == 'FLAGGED_DUPLICATE' || hasConflict) {
        _conflictData = data;
        return GateStatus.flaggedDuplicate;
      }
      */

      await _storage.write(key: 'isFaceEnrolled_${widget.userId}', value: 'true');
      await _storage.write(key: 'profilePictureUrl_${widget.userId}', value: profileUrl);
      return GateStatus.verified;
    } catch (e) {
      debugPrint("Biometric check error: $e");
      final cached = await _storage.read(key: 'isFaceEnrolled_${widget.userId}');
      final cachedUrl = await _storage.read(key: 'profilePictureUrl_${widget.userId}');
      return (cached == 'true' && (cachedUrl != null && cachedUrl.trim().isNotEmpty))
          ? GateStatus.verified
          : GateStatus.notEnrolled;
    }
  }

  Widget _buildDuplicateWarningScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Biometric Advisory",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 58,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Potential Duplicate Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Our biometric integrity system detected that this facial portrait has a similarity match with an existing registered election observer account.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),

              // Conflicting account details card
              if (_conflictData != null) ...[
                Builder(builder: (context) {
                  final matchedName = (_conflictData!['duplicateOfName'] ?? _conflictData!['conflictAccountName'] ?? 'Enrolled Observer').toString();
                  final matchedEmail = (_conflictData!['duplicateOfEmail'] ?? _conflictData!['conflictAccountEmail'] ?? 'N/A').toString();
                  final matchedRole = (_conflictData!['duplicateOfRole'] ?? _conflictData!['conflictAccountRole'])?.toString();
                  final matchedConf = _conflictData!['duplicateConfidence'] ?? _conflictData!['conflictConfidence'];

                  if (matchedName == 'Enrolled Observer' && matchedEmail == 'N/A') {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.person_pin_rounded, color: Color(0xFFF59E0B), size: 18),
                            SizedBox(width: 8),
                            Text(
                              "POTENTIAL MATCH DETAILS",
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow("Observer Name:", matchedName),
                        const SizedBox(height: 6),
                        _buildDetailRow("Email:", matchedEmail),
                        if (matchedRole != null && matchedRole.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildDetailRow("Role:", matchedRole.toUpperCase()),
                        ],
                        if (matchedConf != null) ...[
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            "Match Confidence:",
                            "${((matchedConf as num) * 100).toStringAsFixed(1)}%",
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              const Text(
                "As an accredited field observer, your access to polling unit checklists, incident reporting, and Form EC8A submission remains fully active. This match has been logged for administrative audit.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),

              // Primary Button: Proceed to Dashboard
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    "PROCEED TO DASHBOARD",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                  onPressed: () {
                    setState(() {
                      _proceedAnyway = true;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Re-verify Selfie button (optional)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: BorderSide(color: const Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    "Re-capture Live Face Photo",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LivenessEnrollmentScreen(isModal: true),
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
              const SizedBox(height: 12),

              // Sign Out option
              TextButton(
                onPressed: () {
                  context.read<AuthBloc>().add(LogoutRequested());
                },
                child: const Text(
                  "Log out of this account",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
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

        if (_proceedAnyway) {
          return widget.targetScreen;
        }

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
