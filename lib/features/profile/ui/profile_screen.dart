import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voteguard/features/auth/ui/liveness_enrollment_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const ProfileScreen({super.key, required this.userProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _localFallbackImagePath;

  @override
  void initState() {
    super.initState();
    _checkLocalImage();
  }

  Future<void> _checkLocalImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final localFile = File("${appDir.path}/profile_images/${user.uid}.jpg");
        if (await localFile.exists()) {
          if (mounted) {
            setState(() {
              _localFallbackImagePath = localFile.path;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Local profile image check error: $e");
    }
  }

  Widget _buildField(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(width: 30, height: 2, color: const Color(0xFFE2E8F0)),
      ],
    );
  }

  Widget _buildAvatar(Map<String, dynamic> profile) {
    final explicitLocalPath = profile["localProfileImagePath"]?.toString();
    final effectiveLocalPath = (explicitLocalPath != null && File(explicitLocalPath).existsSync())
        ? explicitLocalPath
        : _localFallbackImagePath;

    final remoteUrl = (profile["profilePictureUrl"] ?? profile["profileImageUrl"])?.toString();

    Widget avatarImage;
    if (effectiveLocalPath != null && File(effectiveLocalPath).existsSync()) {
      avatarImage = Image.file(
        File(effectiveLocalPath),
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        cacheWidth: 300,
        cacheHeight: 300,
      );
    } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      avatarImage = CachedNetworkImage(
        imageUrl: remoteUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        memCacheWidth: 300,
        memCacheHeight: 300,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          LucideIcons.user,
          size: 44,
          color: Colors.white,
        ),
      );
    } else {
      avatarImage = const Icon(
        LucideIcons.user,
        size: 44,
        color: Colors.white,
      );
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: () => _openLivenessModal(),
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0D9488), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF1E293B),
                child: avatarImage,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _openLivenessModal(),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _openLivenessModal() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const LivenessEnrollmentScreen(isModal: true),
      ),
    );
    if (updated == true) {
      _checkLocalImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final liveData = snapshot.data?.data() as Map<String, dynamic>?;
          final mergedProfile = {
            ...widget.userProfile,
            if (liveData != null) ...liveData,
          };
          return _buildScaffold(mergedProfile);
        },
      );
    }

    return _buildScaffold(widget.userProfile);
  }

  Widget _buildScaffold(Map<String, dynamic> userProfile) {
    final isEnrolled = userProfile["isFaceEnrolled"] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "OBSERVER PROFILE",
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/election_bg.png"),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              Center(child: _buildAvatar(userProfile)),
              const SizedBox(height: 14),
              Text(
                userProfile["name"] ?? "Unknown Observer",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userProfile["role"] ?? "OBSERVER",
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnrolled
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEnrolled
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEnrolled ? Icons.verified : Icons.warning_amber_rounded,
                          size: 13,
                          color: isEnrolled
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isEnrolled ? "Face Enrolled" : "No Biometric Photo",
                          style: TextStyle(
                            color: isEnrolled
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.camera_front, size: 16),
                label: Text(
                  isEnrolled ? "Re-verify Face Photo" : "Capture Face Liveness Photo",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openLivenessModal(),
              ),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("CONTACT INFORMATION"),
                    const SizedBox(height: 20),
                    _buildField("EMAIL ADDRESS", userProfile["email"] ?? "",
                        icon: LucideIcons.mail),
                    const SizedBox(height: 16),
                    _buildField("PHONE NUMBER", userProfile["phone"] ?? "",
                        icon: LucideIcons.phone),
                    const SizedBox(height: 32),
                    _buildSectionTitle("LOCATION & ASSIGNMENT"),
                    const SizedBox(height: 20),
                    _buildField(
                      "STATE",
                      userProfile["state"] ?? userProfile["assignedState"] ?? "",
                      icon: LucideIcons.map,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      "LGA",
                      userProfile["lga"] ?? userProfile["assignedLga"] ?? "",
                      icon: LucideIcons.mapPin,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      "WARD",
                      userProfile["ward"] ?? userProfile["assignedWard"] ?? "",
                      icon: LucideIcons.navigation,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      "POLLING UNIT",
                      userProfile["pollingUnit"] ?? userProfile["assignedPollingUnit"] ?? "",
                      icon: LucideIcons.building,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
