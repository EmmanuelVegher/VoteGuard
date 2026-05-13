import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voteguard/core/theme/app_theme.dart';

class VerificationChecklistScreen extends StatefulWidget {
  const VerificationChecklistScreen({super.key});

  @override
  State<VerificationChecklistScreen> createState() => _VerificationChecklistScreenState();
}

class _VerificationChecklistScreenState extends State<VerificationChecklistScreen> {
  final List<ChecklistItem> _items = [
    ChecklistItem(title: 'Polling Unit Opened on Time (8:30 AM)', category: 'Opening'),
    ChecklistItem(title: 'Presence of INEC Officials', category: 'Opening'),
    ChecklistItem(title: 'Empty Ballot Box Demonstrated', category: 'Opening'),
    ChecklistItem(title: 'BVAS Machine Functional & Zeroed', category: 'Technical'),
    ChecklistItem(title: 'Presence of Security Personnel', category: 'Security'),
    ChecklistItem(title: 'Voter Privacy Guaranteed (Booth Placement)', category: 'Setup'),
    ChecklistItem(title: 'Party Agents Present', category: 'Audit'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PU Audit Checklist'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildChecklistItem(item, index);
              },
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    int completedCount = _items.where((item) => item.isCompleted).length;
    double progress = completedCount / _items.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              Text(
                '$completedCount / ${_items.length}',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isCompleted ? AppColors.accent.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          item.category,
          style: TextStyle(color: AppColors.accent.withOpacity(0.7), fontSize: 12),
        ),
        trailing: Checkbox(
          value: item.isCompleted,
          activeColor: AppColors.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: (val) {
            setState(() {
              _items[index].isCompleted = val!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    bool allDone = _items.every((item) => item.isCompleted);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton(
        onPressed: allDone ? () => Navigator.pop(context) : null,
        child: const Text('Complete Verification'),
      ),
    );
  }
}

class ChecklistItem {
  final String title;
  final String category;
  bool isCompleted;

  ChecklistItem({
    required this.title,
    required this.category,
    this.isCompleted = false,
  });
}
