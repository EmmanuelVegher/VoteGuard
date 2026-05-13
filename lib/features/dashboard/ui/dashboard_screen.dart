import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:voteguard/features/results/ui/results_entry_screen.dart';
import 'package:voteguard/features/incidents/ui/incident_report_screen.dart';
import 'package:voteguard/features/checklists/ui/verification_checklist_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Operational Pulse'),
                  const SizedBox(height: 16),
                  _buildPulseStats(),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Live Status'),
                  const SizedBox(height: 16),
                  _buildStatusGrid(context),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, 'Geographical Context'),
                  const SizedBox(height: 16),
                  _buildTelemetryCard(context),
                  const SizedBox(height: 40),
                  _buildEmergencyButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          'Command Center',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.bell),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            backgroundColor: AppColors.surface,
            child: Icon(LucideIcons.user, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPulseStats() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.activity, color: AppColors.accent, size: 32),
            const SizedBox(height: 8),
            Text(
              '85% Submission Velocity',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Real-time data stream active',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatusCard(
          context,
          'Results',
          '24',
          LucideIcons.fileText,
          AppColors.accent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ResultsEntryScreen()),
          ),
        ),
        _buildStatusCard(
          context,
          'Incidents',
          '02',
          LucideIcons.circleAlert,
          AppColors.warning,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
          ),
        ),
        _buildStatusCard(
          context,
          'Checklists',
          '08/10',
          LucideIcons.squareCheck,
          Colors.blue,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerificationChecklistScreen()),
          ),
        ),
        _buildStatusCard(
          context,
          'Sync status',
          'Active',
          LucideIcons.refreshCw,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildTelemetryRow('State', 'Lagos'),
          const Divider(color: AppColors.background),
          _buildTelemetryRow('LGA', 'Alimosho'),
          const Divider(color: AppColors.background),
          _buildTelemetryRow('Ward', 'Egbeda'),
          const Divider(color: AppColors.background),
          _buildTelemetryRow('Polling Unit', '004 - Market Square'),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.phoneCall),
            SizedBox(width: 12),
            Text('Contact Control Center'),
          ],
        ),
      ),
    );
  }
}
