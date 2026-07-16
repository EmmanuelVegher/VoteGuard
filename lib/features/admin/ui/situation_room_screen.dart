import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:voteguard/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voteguard/features/auth/bloc/auth_bloc.dart';

class SituationRoomScreen extends StatefulWidget {
  const SituationRoomScreen({super.key});

  @override
  State<SituationRoomScreen> createState() => _SituationRoomScreenState();
}

class _SituationRoomScreenState extends State<SituationRoomScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGlobalStatusHeader(),
            const SizedBox(height: 32),
            _buildLiveResultsSection(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildNationalMapModule()),
                const SizedBox(width: 24),
                Expanded(child: _buildCrisisControlPanel()),
              ],
            ),
            const SizedBox(height: 32),
            _buildObserverActivityPulse(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final role = context.watch<AuthBloc>().state.role;
    return AppBar(
      backgroundColor: const Color(0xFF020617),
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.shieldCheck, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SITUATION ROOM',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Text(
                    'NATIONAL COMMAND CENTER • ',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: AppColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    (role ?? 'ADMIN').toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: const Color(0xFF10B981),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildLiveIndicator(),
        const SizedBox(width: 16),
        IconButton(icon: const Icon(LucideIcons.settings), onPressed: () {}),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LIVE FEED',
            style: GoogleFonts.outfit(
              color: AppColors.error,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatusHeader() {
    return Row(
      children: [
        _buildStatusMetric('TOTAL VOTES', '12,450,230', LucideIcons.users, AppColors.accent),
        const SizedBox(width: 24),
        _buildStatusMetric('PU REPORTED', '142,030 / 176k', LucideIcons.fileCheck, Colors.green),
        const SizedBox(width: 24),
        _buildStatusMetric('ACTIVE INCIDENTS', '84', LucideIcons.triangleAlert, AppColors.warning),
      ],
    );
  }

  Widget _buildStatusMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveResultsSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE PRESIDENTIAL TALLY',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              _buildBadge('80.5% PROCESSED', Colors.blue),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12);
                        switch (value.toInt()) {
                          case 0: return const Text('APC', style: style);
                          case 1: return const Text('LP', style: style);
                          case 2: return const Text('PDP', style: style);
                          case 3: return const Text('NNPP', style: style);
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 45, Colors.blue),
                  _makeBarGroup(1, 38, Colors.green),
                  _makeBarGroup(2, 12, Colors.red),
                  _makeBarGroup(3, 5, Colors.orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 60,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: color.withOpacity(0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildNationalMapModule() {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GEOGRAPHICAL HOTSPOTS',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Heatmap showing submission velocity by state.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const Expanded(
            child: Center(
              child: Icon(LucideIcons.map, size: 200, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisControlPanel() {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRISIS CONTROL',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.error,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildCrisisItem('Violence reported in Ward 04, Kano', 'High', '14m ago'),
                _buildCrisisItem('Ballot snatching in Alimosho, Lagos', 'Critical', '22m ago'),
                _buildCrisisItem('Late arrival of materials, Rivers', 'Medium', '1h ago'),
                _buildCrisisItem('Technical glitch with Bimodal system', 'Medium', '2h ago'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangle_circular(16),
            ),
            child: const Text('DEPLOY FIELD INTERVENTION'),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisItem(String title, String priority, String time) {
    Color pCol = priority == 'Critical' ? AppColors.error : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: pCol.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(LucideIcons.circleAlert, color: pCol, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('$priority Priority • $time', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObserverActivityPulse() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OBSERVER ACTIVITY PULSE',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.accent.withOpacity(0.1)),
                    spots: [
                      const FlSpot(0, 3), const FlSpot(1, 4), const FlSpot(2, 3.5), const FlSpot(3, 5),
                      const FlSpot(4, 4), const FlSpot(5, 6), const FlSpot(6, 5), const FlSpot(7, 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: col.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: col,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}

// RoundedRectangle_circular fix for ElevatedButton
RoundedRectangleBorder RoundedRectangle_circular(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
