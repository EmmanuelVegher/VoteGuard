import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userProfile;

  const ProfileScreen({super.key, required this.userProfile});

  Widget _buildField(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
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
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
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
        Text(title, style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(width: 30, height: 2, color: const Color(0xFFE2E8F0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = userProfile['profilePictureUrl'] != null;

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
          'OBSERVER PROFILE',
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
            image: AssetImage('assets/images/election_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              // Profile Header
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: hasImg ? NetworkImage(userProfile['profilePictureUrl'].toString()) : null,
                  child: !hasImg ? const Icon(LucideIcons.user, size: 40, color: Colors.white) : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userProfile['name'] ?? 'Unknown Observer',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  userProfile['role'] ?? 'OBSERVER',
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('CONTACT INFORMATION'),
                    const SizedBox(height: 20),
                    _buildField('EMAIL ADDRESS', userProfile['email'] ?? '', icon: LucideIcons.mail),
                    const SizedBox(height: 16),
                    _buildField('PHONE NUMBER', userProfile['phone'] ?? '', icon: LucideIcons.phone),
                    
                    const SizedBox(height: 32),
                    _buildSectionTitle('LOCATION & ASSIGNMENT'),
                    const SizedBox(height: 20),
                    _buildField('STATE', userProfile['state'] ?? userProfile['assignedState'] ?? '', icon: LucideIcons.map),
                    const SizedBox(height: 16),
                    _buildField('LGA', userProfile['lga'] ?? userProfile['assignedLga'] ?? '', icon: LucideIcons.mapPin),
                    const SizedBox(height: 16),
                    _buildField('WARD', userProfile['ward'] ?? userProfile['assignedWard'] ?? '', icon: LucideIcons.navigation),
                    const SizedBox(height: 16),
                    _buildField('POLLING UNIT', userProfile['pollingUnit'] ?? userProfile['assignedPollingUnit'] ?? '', icon: LucideIcons.building),
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
