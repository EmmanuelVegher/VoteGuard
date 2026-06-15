import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voteguard/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────

enum QuestionType { checkbox, yesNo }

class ChecklistItem {
  final int number;
  final String title;
  final String category;
  final QuestionType type;

  /// For checkbox items: null = unanswered, true = checked.
  /// For yesNo items:   null = unanswered, true = Yes, false = No.
  bool? answer;

  /// If non-null, this item is only shown when the referenced question
  /// has the given answer.
  final int? showIfQuestionNumber;
  final bool? showIfAnswer;

  ChecklistItem({
    required this.number,
    required this.title,
    required this.category,
    this.type = QuestionType.checkbox,
    this.answer,
    this.showIfQuestionNumber,
    this.showIfAnswer,
  });

  bool get isAnswered => answer != null;
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class VerificationChecklistScreen extends StatefulWidget {
  const VerificationChecklistScreen({super.key});

  @override
  State<VerificationChecklistScreen> createState() =>
      _VerificationChecklistScreenState();
}

class _VerificationChecklistScreenState
    extends State<VerificationChecklistScreen> {
  late final List<ChecklistItem> _allItems;

  @override
  void initState() {
    super.initState();
    _allItems = _buildItems();
  }

  List<ChecklistItem> _buildItems() => [
        ChecklistItem(number: 1,  title: 'Polling Unit opened on time (8:30 AM)',            category: 'Opening'),
        ChecklistItem(number: 2,  title: 'INEC officials present at opening',                 category: 'Opening'),
        ChecklistItem(number: 3,  title: 'Empty ballot box demonstrated to agents',           category: 'Opening'),
        ChecklistItem(number: 4,  title: 'BVAS machine functional and zeroed',                category: 'Technical'),
        ChecklistItem(number: 5,  title: 'Security personnel present at PU',                  category: 'Security'),
        ChecklistItem(number: 6,  title: 'Voter privacy guaranteed (booth placement)',         category: 'Setup'),
        ChecklistItem(number: 7,  title: 'Party agents present at opening',                   category: 'Audit'),
        ChecklistItem(number: 8,  title: 'Voter register available and accessible',            category: 'Setup'),
        ChecklistItem(number: 9,  title: 'Adequate lighting in polling unit',                 category: 'Setup'),
        ChecklistItem(number: 10, title: 'Ballot papers available in sufficient quantity',     category: 'Materials'),
        ChecklistItem(number: 11, title: 'Result sheets (Form EC8A) available',               category: 'Materials'),
        ChecklistItem(number: 12, title: 'Stamp/ink pads available',                          category: 'Materials'),
        ChecklistItem(number: 13, title: 'Voters queuing in an orderly manner',               category: 'Process'),
        ChecklistItem(number: 14, title: 'BVAS used for all voter accreditation',             category: 'Technical'),
        ChecklistItem(number: 15, title: 'No voter intimidation observed',                    category: 'Security'),
        ChecklistItem(number: 16, title: 'No campaigning within 300 m of PU',                category: 'Compliance'),
        ChecklistItem(number: 17, title: 'Thumb printing done in secrecy',                   category: 'Process'),
        ChecklistItem(number: 18, title: 'Ballot box sealed properly before voting began',    category: 'Process'),
        ChecklistItem(number: 19, title: 'Rejected ballots accounted for',                   category: 'Counting'),
        ChecklistItem(number: 20, title: 'Valid votes counted publicly',                     category: 'Counting'),
        ChecklistItem(number: 21, title: 'Agents allowed to observe counting',               category: 'Audit'),
        ChecklistItem(number: 22, title: 'Form EC8A filled correctly',                       category: 'Documentation'),
        ChecklistItem(number: 23, title: 'Results announced publicly at PU',                 category: 'Transparency'),
        ChecklistItem(number: 24, title: 'All agents signed Form EC8A',                      category: 'Documentation'),
        ChecklistItem(number: 25, title: 'Results posted at polling unit',                   category: 'Transparency'),
        ChecklistItem(number: 26, title: 'BVAS transmission of results completed',           category: 'Technical'),
        ChecklistItem(number: 27, title: 'No over-voting detected',                          category: 'Compliance'),
        ChecklistItem(number: 28, title: 'No ballot box stuffing observed',                  category: 'Security'),
        ChecklistItem(number: 29, title: 'Presiding officer available throughout',           category: 'Compliance'),
        ChecklistItem(number: 30, title: 'Polling closed at official time (2:30 PM)',        category: 'Closing'),
        ChecklistItem(number: 31, title: 'Unused ballots counted and documented',            category: 'Closing'),
        ChecklistItem(number: 32, title: 'All materials packed and sealed',                  category: 'Closing'),
        ChecklistItem(number: 33, title: 'Observers allowed access throughout',              category: 'Audit'),
        ChecklistItem(number: 34, title: 'No technical failures affected voting',            category: 'Technical'),
        ChecklistItem(number: 35, title: 'Voter turnout recorded',                           category: 'Documentation'),
        ChecklistItem(number: 36, title: 'Any incidents reported to INEC',                  category: 'Incidents'),
        ChecklistItem(number: 37, title: 'Security adequate throughout voting period',       category: 'Security'),

        // ── Conditional pivot question ──────────────────────────────────────
        ChecklistItem(
          number: 38,
          title: 'Was voting disrupted at any point?',
          category: 'Incidents',
          type: QuestionType.yesNo,
        ),

        // Q39 – only shown when Q38 = Yes
        ChecklistItem(
          number: 39,
          title: 'Nature of disruption documented and reported',
          category: 'Incidents',
          showIfQuestionNumber: 38,
          showIfAnswer: true,
        ),

        // Q40 – only shown when Q38 = No
        ChecklistItem(
          number: 40,
          title: 'Peaceful conduct confirmed throughout the exercise',
          category: 'Compliance',
          showIfQuestionNumber: 38,
          showIfAnswer: false,
        ),
      ];

  // ── helpers ───────────────────────────────────────────────────────────────

  bool _isVisible(ChecklistItem item) {
    if (item.showIfQuestionNumber == null) return true;
    final pivot = _allItems.firstWhere(
      (i) => i.number == item.showIfQuestionNumber,
    );
    return pivot.answer == item.showIfAnswer;
  }

  List<ChecklistItem> get _visibleItems =>
      _allItems.where(_isVisible).toList();

  int get _answeredCount =>
      _visibleItems.where((i) => i.isAnswered).length;

  double get _progress {
    final visible = _visibleItems.length;
    if (visible == 0) return 0;
    return _answeredCount / visible;
  }

  bool get _allDone =>
      _visibleItems.isNotEmpty &&
      _visibleItems.every((i) => i.isAnswered);

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PU Audit Checklist',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressHeader(visible),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: visible.length,
              itemBuilder: (context, index) =>
                  _buildItem(visible[index]),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── progress header ───────────────────────────────────────────────────────

  Widget _buildProgressHeader(List<ChecklistItem> visible) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                '$_answeredCount / ${visible.length}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: AppColors.background,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── item builder ──────────────────────────────────────────────────────────

  Widget _buildItem(ChecklistItem item) {
    final isConditional = item.showIfQuestionNumber != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isAnswered
              ? AppColors.accent.withOpacity(0.35)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number badge + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _numberBadge(item.number, isConditional),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: item.isAnswered
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: (item.type == QuestionType.checkbox &&
                                  item.answer == true)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkbox answer
                if (item.type == QuestionType.checkbox)
                  Checkbox(
                    value: item.answer == true,
                    activeColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    onChanged: (val) {
                      setState(() => item.answer = val);
                    },
                  ),
              ],
            ),

            // Yes / No buttons for yesNo type
            if (item.type == QuestionType.yesNo) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _yesNoButton(
                    label: 'Yes',
                    selected: item.answer == true,
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      setState(() {
                        item.answer = true;
                        // Reset Q39 & Q40 answers when pivot changes
                        _resetConditionals(item.number);
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  _yesNoButton(
                    label: 'No',
                    selected: item.answer == false,
                    color: const Color(0xFFE53935),
                    onTap: () {
                      setState(() {
                        item.answer = false;
                        _resetConditionals(item.number);
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resetConditionals(int pivotNumber) {
    for (final item in _allItems) {
      if (item.showIfQuestionNumber == pivotNumber) {
        item.answer = null;
      }
    }
  }

  Widget _numberBadge(int number, bool isConditional) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isConditional
            ? AppColors.accent.withOpacity(0.15)
            : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isConditional ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _yesNoButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppColors.textSecondary.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: selected ? color : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ElevatedButton(
        onPressed: _allDone ? () => Navigator.pop(context) : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          'Complete Verification',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _allDone ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
