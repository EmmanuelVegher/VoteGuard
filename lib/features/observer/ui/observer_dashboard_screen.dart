import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:voteguard/models/election_model.dart';
import 'package:voteguard/services/ai_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';

class ObserverDashboardScreen extends StatefulWidget {
  final String electionId;
  const ObserverDashboardScreen({super.key, required this.electionId});

  @override
  State<ObserverDashboardScreen> createState() => _ObserverDashboardScreenState();
}

class _ObserverDashboardScreenState extends State<ObserverDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Election? _election;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadElection();
  }

  Future<void> _loadElection() async {
    final doc = await _firestore.collection('elections').doc(widget.electionId).get();
    if (doc.exists && mounted) {
      setState(() {
        _election = Election.fromFirestore(doc.data()!, doc.id);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF065F46))));
    if (_election == null) return const Scaffold(body: Center(child: Text('Election not found')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_election!.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text('OBSERVER DASHBOARD', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 1)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false, // Forces all tabs to fit on screen
          labelPadding: const EdgeInsets.symmetric(horizontal: 2), // Minimizes padding for small screens
          labelColor: const Color(0xFF065F46),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF065F46),
          labelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'DASHBOARD'),
            Tab(text: 'CHECKLIST'),
            Tab(text: 'INCIDENTS'),
            Tab(text: 'RESULTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(electionId: widget.electionId, tabController: _tabController),
          _ChecklistTab(electionId: widget.electionId),
          _IncidentsTab(electionId: widget.electionId),
          _EC8AResultsTab(electionId: widget.electionId),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showChatOverlay,
        backgroundColor: const Color(0xFF0F172A),
        child: const Icon(LucideIcons.messageSquare, color: Colors.white),
      ),
    );
  }

  void _showChatOverlay() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Group Chat...'), duration: Duration(milliseconds: 500)));

    // Fetch user profile for state and name
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data() ?? {};
    final state = data['assignedState']?.toString().toLowerCase() ?? 'national';
    final groupId = 'group_state_$state';
    final fullName = data['fullName'] ?? 'Observer';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatWidget(
        groupId: groupId,
        userId: user.uid,
        userName: fullName,
        role: data['role'] ?? 'OBSERVER',
      ),
    );
  }
}

// --- TAB 1: DASHBOARD ---
class _DashboardTab extends StatelessWidget {
  final String electionId;
  final TabController tabController;

  const _DashboardTab({required this.electionId, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('users').doc(user?.uid).snapshots(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data?.data() as Map<String, dynamic>?;
        
        return StreamBuilder<List<int>>(
          stream: Rx.combineLatest3(
            firestore.collection('observer_checklists').where('electionId', isEqualTo: electionId).where('observerId', isEqualTo: user?.uid).snapshots(),
            firestore.collection('incident_reports').where('electionId', isEqualTo: electionId).where('observerId', isEqualTo: user?.uid).snapshots(),
            firestore.collection('election_results').where('electionId', isEqualTo: electionId).where('submittedBy', isEqualTo: user?.uid).snapshots(),
            (check, inc, res) => [check.docs.length, inc.docs.length, res.docs.length]
          ),
          builder: (context, statsSnapshot) {
            final stats = statsSnapshot.data ?? [0, 0, 0];
            
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _buildCommandHeader(profile),
                const SizedBox(height: 24),
                _buildStatGrid(context, stats, profile),
                const SizedBox(height: 24),
                _buildAnalyticsSection(),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildSupportSection(),
                const SizedBox(height: 32),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildCommandHeader(Map<String, dynamic>? profile) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(100)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('SYSTEM LIVE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF065F46), letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Spacer(),
              Text(DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Command Center', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBadge('2024 PRESIDENTIAL ELECTION', const Color(0xFFF1F5F9), const Color(0xFF475569)),
              const SizedBox(width: 8),
              _buildBadge('#VG-8829-LIVE', const Color(0xFFECFDF5), const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
              children: [
                const TextSpan(text: 'Welcome back, '),
                TextSpan(text: user?.displayName ?? profile?['fullName'] ?? 'Observer', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                const TextSpan(text: '. Deployment verified for '),
                TextSpan(text: '${profile?['assignedState'] ?? 'FCT'} / ${profile?['assignedLga'] ?? 'Abuja'}.', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text, 
        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textCol),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context, List<int> stats, Map<String, dynamic>? profile) {
    final checklist = stats[0];
    final incidents = stats[1];
    final results = stats[2];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Checklists', checklist.toString(), LucideIcons.fileCheck, const Color(0xFF10B981))),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Incidents', incidents.toString(), LucideIcons.triangleAlert, const Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricCard('PU RESULTS', results.toString(), 'VALIDATED & UPLOADED', LucideIcons.trendingUp, const Color(0xFF10B981), 'ACTIVE SUBMISSION')),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('LIVE INCIDENTS', incidents.toString(), 'REQUIRING REVIEW', LucideIcons.triangleAlert, const Color(0xFFEF4444), 'CRISIS CONTROL')),
          ],
        ),
        const SizedBox(height: 16),
        _buildLocationCard(profile),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, IconData icon, Color color, String badge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Flexible(child: _buildBadge(badge, color.withOpacity(0.1), color)),
            ],
          ),
          const SizedBox(height: 16),
          Text(val, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          Text(title, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.outfit(fontSize: 8, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic>? profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mapPin, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEPLOYMENT INTELLIGENCE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
                    Text(profile?['assignedLga'] ?? 'Area Council', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                    Text(profile?['assignedState'] ?? 'State/FCT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              _buildBadge('SECURED', const Color(0xFFECFDF5), const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                _buildLocationRow('WARD', profile?['assignedWard'] ?? 'N/A'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                _buildLocationRow('POLLING UNIT', profile?['assignedPollingUnit'] ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 120, width: double.infinity,
              color: const Color(0xFFF8FAFC),
              child: const Icon(LucideIcons.map, size: 40, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
        const SizedBox(width: 16),
        Flexible(child: Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    return Row(
      children: [
        Expanded(child: _buildDonutChart()),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildPulseChart()),
      ],
    );
  }

  Widget _buildDonutChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIVITY MIX', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
          const Spacer(),
          SizedBox(
            height: 100,
            child: PieChart(PieChartData(sections: [
              PieChartSectionData(color: const Color(0xFF10B981), value: 40, radius: 20, showTitle: false),
              PieChartSectionData(color: const Color(0xFFEF4444), value: 20, radius: 20, showTitle: false),
              PieChartSectionData(color: const Color(0xFF0F172A), value: 40, radius: 20, showTitle: false),
            ], centerSpaceRadius: 30)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPulseChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('OPERATIONAL PULSE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Flexible(child: _buildBadge('LIVE TRACKING', const Color(0xFFF1F5F9), const Color(0xFF64748B))),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 100,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF10B981).withOpacity(0.1)),
                  spots: [
                    const FlSpot(0, 3), 
                    const FlSpot(2.6, 2), 
                    const FlSpot(4.9, 5), 
                    const FlSpot(6.8, 3.1), 
                    const FlSpot(8, 4)
                  ],
                )
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK ACTIONS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          _buildActionItem('PROCESS CHECKLIST', LucideIcons.squareCheck, const Color(0xFF10B981), () => tabController.animateTo(1)),
          _buildActionItem('LOG INCIDENT', LucideIcons.triangleAlert, const Color(0xFFEF4444), () => tabController.animateTo(2)),
          _buildActionItem('RESULT ENTRY', LucideIcons.trendingUp, const Color(0xFF0F172A), () => tabController.animateTo(3)),
        ],
      ),
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color col, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: col, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 14)),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
            const Spacer(),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(32)),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle), child: const Icon(LucideIcons.phone, color: Colors.white, size: 24)),
          const SizedBox(height: 20),
          Text('Security & Support', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('DIRECT ENCRYPTED UPLINK TO THE NATIONAL COMMAND CENTER.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), height: 1.5)),
          const SizedBox(height: 24),
          Text('INITIATE VOICE CALL', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 1)),
        ],
      ),
    );
  }
}

// --- PLACEHOLDER TABS (To be implemented in next phases) ---
class _ChecklistTab extends StatefulWidget {
  final String electionId;
  const _ChecklistTab({required this.electionId});

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> with AutomaticKeepAliveClientMixin {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  List<dynamic> _questions = [];
  Map<String, dynamic>? _userProfile;
  bool _isFinalized = false;
  bool _hasSavedDraft = false;
  final Set<String> _editableFields = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      _userProfile = profile.data();

      // Step 1: Get the election to find its templateId
      final electionDoc = await FirebaseFirestore.instance.collection('elections').doc(widget.electionId).get();
      String? templateId = electionDoc.data()?['checklistTemplateId'];

      // Step 2: Fallback to the latest template if not specified in the election
      if (templateId == null) {
        final latestTemplate = await FirebaseFirestore.instance.collection('checklist_templates')
            .orderBy('updatedAt', descending: true).limit(1).get();
        if (latestTemplate.docs.isNotEmpty) {
          templateId = latestTemplate.docs.first.id;
        }
      }

      // Step 3: Fetch questions from the sub-collection
      if (templateId != null) {
        final qDocs = await FirebaseFirestore.instance.collection('checklist_templates')
            .doc(templateId).collection('questions').orderBy('order').get();
        _questions = qDocs.docs.map((d) => d.data()).toList();
      }

      final pu = _userProfile?['assignedPollingUnit'] ?? 'unknown_pu';
      final primaryId = '${user?.uid}_${widget.electionId}';
      final secondaryId = '${widget.electionId}_${user?.uid}_$pu';
      
      // Step 4: Load draft/submission
      var draft = await FirebaseFirestore.instance.collection('observer_checklists')
          .doc(primaryId).get();
      
      // Fallback for different ID formats
      if (!draft.exists) {
        draft = await FirebaseFirestore.instance.collection('observer_checklists')
            .doc(secondaryId).get();
      }
      
      final docId = draft.exists ? draft.id : primaryId;

      if (mounted) {
        setState(() {
          if (draft.exists) {
            final data = draft.data()!;
            _answers.addAll(Map<String, dynamic>.from(data['answers'] ?? {}));
            _isFinalized = data['status'] == 'submitted';
            _hasSavedDraft = data['status'] == 'draft';
            
            // Initialize controllers with saved data
            _answers.forEach((key, value) {
              if (!_controllers.containsKey(key)) {
                _controllers[key] = TextEditingController(text: value?.toString());
              } else {
                _controllers[key]!.text = value?.toString() ?? '';
              }
            });
          }
          
          // Intelligent Auto-fill Logic
          for (var q in _questions) {
            final text = (q['text'] ?? '').toString().toLowerCase();
            final qId = q['id'];
            if (_answers[qId] == null) {
              String? autoValue;
              if (text.contains('name')) autoValue = _userProfile?['fullName'];
              if (text.contains('phone')) autoValue = _userProfile?['phone'];
              if (text.contains('lga')) autoValue = _userProfile?['assignedLga'];
              if (text.contains('ward')) autoValue = _userProfile?['assignedWard'];
              if (text.contains('polling unit')) autoValue = _userProfile?['assignedPollingUnit'];
              
              if (autoValue != null) {
                _answers[qId] = autoValue;
                if (!_controllers.containsKey(qId)) {
                  _controllers[qId] = TextEditingController(text: autoValue);
                } else {
                  _controllers[qId]!.text = autoValue;
                }
              }
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Checklist load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Access Denied: Checklist templates require admin authorization.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ));
        }
      }
    }
  }

  double get _completionProgress {
    if (_questions.isEmpty) return 0;
    int visibleCount = 0;
    int answeredCount = 0;
    for (var q in _questions) {
      if (!_isQuestionVisible(q)) continue;
      visibleCount++;
      if (_answers[q['id']] != null && _answers[q['id']].toString().isNotEmpty) answeredCount++;
    }
    return visibleCount == 0 ? 0 : answeredCount / visibleCount;
  }

  bool _isQuestionVisible(Map<String, dynamic> q) {
    // COMMISSION MEMBERS RULE
    if ((q['text'] ?? '').toString().contains('present?') && q['id'] != 'commission_present') {
       // This is a sub-question example
    }
    
    // Technical Spec Rules
    if ((q['text'] ?? '').toString().toLowerCase().contains('how many of them') && 
        (q['text'] ?? '').toString().toLowerCase().contains('members')) {
      final parent = _questions.firstWhere((item) => (item['text'] ?? '').toString().toLowerCase().contains('commission members present?'), orElse: () => null);
      if (parent != null && _answers[parent['id']] != 'yes') return false;
    }

    if ((q['text'] ?? '').toString().toLowerCase().contains('refuse to sign')) {
      final parent = _questions.firstWhere((item) => (item['text'] ?? '').toString().toLowerCase().contains('party agents present sign'), orElse: () => null);
      if (parent != null && _answers[parent['id']] != 'no') return false;
    }

    return true;
  }

  Future<void> _save(bool isFinal) async {
    if (isFinal) {
      for (var q in _questions) {
        if (_isQuestionVisible(q) && q['required'] == true && q['type'] != 'media') {
          if (_answers[q['id']] == null || _answers[q['id']].toString().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all required questions before submitting.'), backgroundColor: Colors.orange));
            return;
          }
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'state': _userProfile?['assignedState'],
        'lga': _userProfile?['assignedLga'],
        'ward': _userProfile?['assignedWard'],
        'pollingUnit': _userProfile?['assignedPollingUnit'],
        'answers': _answers,
        'status': isFinal ? 'submitted' : 'draft',
        'timestamp': FieldValue.serverTimestamp(),
      };

      final pu = _userProfile?['assignedPollingUnit'] ?? 'unknown_pu';
      // Use the ID format confirmed in Firestore: observerId_electionId
      final docId = '${user?.uid}_${widget.electionId}';

      await FirebaseFirestore.instance.collection('observer_checklists')
          .doc(docId).set(payload, SetOptions(merge: true));

      // Audit Log
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'action': isFinal ? 'CHECKLIST_SUBMIT' : 'CHECKLIST_SAVE_DRAFT',
        'resource': 'checklist',
        'details': {
          'electionId': widget.electionId,
          'pollingUnit': pu,
          'answeredCount': _answers.length,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          _isFinalized = isFinal;
          _hasSavedDraft = !isFinal;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFinal ? 'Checklist Finalized Successfully!' : 'Progress Saved as Draft'),
          backgroundColor: const Color(0xFF065F46),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _discardDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = '${user?.uid}_${widget.electionId}';

    await FirebaseFirestore.instance.collection('observer_checklists')
        .doc(docId).delete();
    setState(() {
      _answers.clear();
      _controllers.values.forEach((c) => c.clear());
      _hasSavedDraft = false;
      _loadData(); // Reload to re-apply auto-fill
    });
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF065F46)));

    final grouped = <String, List<dynamic>>{};
    for (var q in _questions) {
      final section = q['section'] ?? 'General';
      if (!grouped.containsKey(section)) grouped[section] = [];
      grouped[section]!.add(q);
    }

    return Column(
      children: [
        if (_isFinalized)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CHECKLIST FINALIZED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                      const SizedBox(height: 2),
                      Text('All responses are now locked for synchronization.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _buildProgressHUD(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: grouped.entries.map((entry) => _buildSection(entry.key, entry.value)).toList(),
          ),
        ),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildProgressHUD() {
    final progress = _completionProgress;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              strokeWidth: 6,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('COMPLETION TRACKER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1)),
              Text('${(progress * 100).toInt()}% Questions Answered', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> questions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Text(title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1)),
        const SizedBox(height: 16),
        ...questions.map((q) => _isQuestionVisible(q) ? _buildQuestionCard(q) : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final id = q['id'];
    final isAnswered = _answers[id] != null && _answers[id].toString().isNotEmpty;
    final text = (q['text'] ?? '').toString();
    final isLocationField = text.toLowerCase().contains('lga') || text.toLowerCase().contains('ward') || text.toLowerCase().contains('polling unit');
    final isEditable = _editableFields.contains(id) || !isLocationField;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isAnswered ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))),
              if (text.toLowerCase().contains('name') || text.toLowerCase().contains('phone'))
                IconButton(
                  icon: Icon(_editableFields.contains(id) ? LucideIcons.check : LucideIcons.pencil, size: 14, color: const Color(0xFF64748B)),
                  onPressed: _isFinalized ? null : () => setState(() {
                    if (_editableFields.contains(id)) _editableFields.remove(id);
                    else _editableFields.add(id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput(q, isEditable && !_isFinalized),
        ],
      ),
    );
  }

  Widget _buildInput(Map<String, dynamic> q, bool enabled) {
    final type = q['type'] ?? 'text';
    final id = q['id'];

    if (type == 'yes_no') {
      return Row(
        children: [
          _buildChoiceChip(id, 'YES', 'yes', enabled),
          const SizedBox(width: 12),
          _buildChoiceChip(id, 'NO', 'no', enabled),
        ],
      );
    }

    if (type == 'media') {
      final url = _answers[id]?.toString() ?? '';
      final hasUrl = url.isNotEmpty;
      
      // Determine media type
      String mediaType = 'photo';
      if (hasUrl) {
        final lowerUrl = url.toLowerCase();
        if (lowerUrl.contains('.mp4') || lowerUrl.contains('.mov') || lowerUrl.contains('.avi')) mediaType = 'video';
        else if (lowerUrl.contains('.mp3') || lowerUrl.contains('.wav') || lowerUrl.contains('.m4a') || lowerUrl.contains('.aac')) mediaType = 'audio';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUrl)
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaType == 'video'
                  ? VideoPlayerWidget(url: url)
                  : mediaType == 'audio'
                    ? AudioPlayerWidget(url: url)
                    : GestureDetector(
                        onTap: () => _showFullScreenImage(url),
                        child: CachedNetworkImage(
                          imageUrl: url, 
                          fit: BoxFit.cover, 
                          placeholder: (c,u) => const Center(child: CircularProgressIndicator()),
                        ),
                      ),
              ),
            ),
          InkWell(
            onTap: !enabled ? null : () => _showChecklistSourcePicker(id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(hasUrl ? LucideIcons.refreshCw : LucideIcons.camera, size: 16, color: const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(hasUrl ? 'REPLACE MEDIA' : 'ADD PHOTO/VIDEO', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_controllers.containsKey(id)) {
      _controllers[id] = TextEditingController(text: _answers[id]?.toString());
    }

    return TextField(
      enabled: enabled,
      controller: _controllers[id],
      style: GoogleFonts.outfit(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Enter response...',
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      onChanged: (v) => _answers[id] = v,
    );
  }

  Widget _buildChoiceChip(String id, String label, String value, bool enabled) {
    final selected = _answers[id] == value;
    final isNo = value.toLowerCase() == 'no';
    final activeColor = isNo ? const Color(0xFFEF4444) : const Color(0xFF065F46);

    return Expanded(
      child: InkWell(
        onTap: !enabled ? null : () => setState(() => _answers[id] = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFF64748B))),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_isFinalized) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _submitting ? null : () => _save(false), child: Text('SAVE PROGRESS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton(onPressed: _submitting ? null : () => _save(true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46)), child: Text('FINAL SUBMIT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)))),
            ],
          ),
          if (_hasSavedDraft)
            TextButton(
              onPressed: _submitting ? null : _discardDraft,
              child: Text('DISCARD DRAFT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChecklistSourcePicker(String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('ATTACH EVIDENCE', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Select evidence from your device', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildChecklistPickerOption(
              icon: LucideIcons.camera, 
              title: 'TAKE SNAPSHOT',
              subtitle: 'Capture evidence now',
              onTap: () {
                Navigator.pop(ctx);
                _handleChecklistMedia(id, ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildChecklistPickerOption(
              icon: LucideIcons.image, 
              title: 'PICK FROM GALLERY',
              subtitle: 'Upload existing file',
              onTap: () {
                Navigator.pop(ctx);
                _handleChecklistMedia(id, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistPickerOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChecklistMedia(String id, ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 70);
    if (img != null) {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading evidence...'), duration: Duration(seconds: 2)));
      
      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseStorage.instance.ref().child('checklist_media/${user?.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(img.path));
      final url = await ref.getDownloadURL();
      setState(() => _answers[id] = url);
    }
  }
}

class _IncidentsTab extends StatefulWidget {
  final String electionId;
  const _IncidentsTab({required this.electionId});

  @override
  State<_IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<_IncidentsTab> {
  final _descriptionController = TextEditingController();
  String? _selectedType;
  final List<Map<String, dynamic>> _media = [];
  bool _submitting = false;
  bool _savingDraft = false;
  double _uploadProgress = 0;
  Position? _currentPosition;
  Map<String, dynamic>? _userProfile;
  final String _deviceId = 'OBS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  Timer? _clockTimer;

  final List<Map<String, String>> _types = [
    {'id': 'ballot_snatching', 'label': 'Ballot Snatching'},
    {'id': 'violence', 'label': 'Violence or Threat'},
    {'id': 'underage_voting', 'label': 'Underage Voting'},
    {'id': 'vote_buying', 'label': 'Vote Buying'},
    {'id': 'equipment_failure', 'label': 'Equipment Failure'},
    {'id': 'no_materials', 'label': 'Insufficient Materials'},
    {'id': 'late_start', 'label': 'Late Commencement'},
    {'id': 'other', 'label': 'Other Incident'},
  ];

  @override
  void initState() {
    super.initState();
    _initData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      _userProfile = profile.data();
      _currentPosition = await _determinePosition();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _pickMedia(String type, {ImageSource source = ImageSource.camera}) async {
    if (type == 'audio') {
      // For audio, we use FilePicker. 
      // If source is 'camera' (Live), we try to use the system recorder if available via FilePicker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _media.add({'type': type, 'file': File(result.files.single.path!)}));
      }
      return;
    }

    final picker = ImagePicker();
    XFile? file;
    if (type == 'photo') {
      file = await picker.pickImage(source: source, imageQuality: 70);
    } else if (type == 'video') {
      file = await picker.pickVideo(source: source);
    }

    if (file != null) {
      setState(() => _media.add({'type': type, 'file': File(file!.path)}));
    }
  }

  void _showSourcePicker(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('SELECT SOURCE', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Choose how you want to attach ${type.toUpperCase()}', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildPickerOption(
              icon: type == 'audio' ? LucideIcons.mic : LucideIcons.camera, 
              title: type == 'audio' ? 'RECORD LIVE' : 'LIVE ${type == 'photo' ? 'SNAPSHOT' : 'RECORDING'}',
              subtitle: type == 'audio' ? 'Capture audio now' : 'Use your device camera',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(type, source: ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildPickerOption(
              icon: type == 'audio' ? LucideIcons.mic : LucideIcons.image, 
              title: type == 'audio' ? 'UPLOAD FILE' : 'UPLOAD FROM GALLERY',
              subtitle: type == 'audio' ? 'Select from storage' : 'Pick from your photo library',
              onTap: () {
                Navigator.pop(ctx);
                _pickMedia(type, source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedType == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a type and provide a description.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _submitting = true;
      _uploadProgress = 0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final List<Map<String, String>> mediaItems = [];

      for (int i = 0; i < _media.length; i++) {
        final item = _media[i];
        final type = item['type'] as String;
        final file = item['file'] as File;
        
        final ref = FirebaseStorage.instance.ref().child('incidents/${user?.uid}/${DateTime.now().millisecondsSinceEpoch}_$i');
        final uploadTask = ref.putFile(file);
        
        uploadTask.snapshotEvents.listen((event) {
          final p = (event.bytesTransferred / event.totalBytes) / _media.length;
          setState(() => _uploadProgress = (i / _media.length) + p);
        });

        await uploadTask;
        final url = await ref.getDownloadURL();
        mediaItems.add({'url': url, 'type': type});
      }

      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'submittedBy': user?.uid,
        'incidentType': _selectedType,
        'description': _descriptionController.text,
        'mediaItems': mediaItems,
        'mediaUrls': mediaItems.map((e) => e['url']).toList(), // for backward compatibility
        'state': _userProfile?['assignedState'],
        'lga': _userProfile?['assignedLga'],
        'ward': _userProfile?['assignedWard'],
        'pollingUnit': _userProfile?['assignedPollingUnit'],
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'deviceId': _deviceId,
        'status': 'reported',
        'isSynced': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('incident_reports').add(payload);

      // Clean up draft if it exists
      await FirebaseFirestore.instance.collection('incident_reports')
          .doc('${widget.electionId}_${user?.uid}_draft').delete();

      if (mounted) {
        _descriptionController.clear();
        setState(() {
          _selectedType = null;
          _media.clear();
          _uploadProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident report submitted successfully!'), backgroundColor: Color(0xFF10B981)));
        DefaultTabController.maybeOf(context)?.animateTo(0);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _savingDraft = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final payload = {
        'electionId': widget.electionId,
        'observerId': user?.uid,
        'incidentType': _selectedType,
        'description': _descriptionController.text,
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('incident_reports')
          .doc('${widget.electionId}_${user?.uid}_draft').set(payload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved successfully'), backgroundColor: Color(0xFF065F46)));
      }
    } catch (e) {
      debugPrint('Save draft error: $e');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        _buildIssueDetailsCard(),
        const SizedBox(height: 24),
        _buildEvidenceCard(),
        const SizedBox(height: 24),
        _buildReportDetailsCard(),
        const SizedBox(height: 24),
        _buildGuidelinesCard(),
        const SizedBox(height: 32),
        _buildSubmitActions(),
        const SizedBox(height: 48),
        _buildRecentSubmissions(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report an Issue', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('Reporting for 2026 Presidential Election', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
                  Text('CONNECTED', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIssueDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.activity, 'ISSUE DETAILS', 'INCIDENT INFORMATION'),
          const SizedBox(height: 32),
          Text('TYPE OF ISSUE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            dropdownColor: Colors.white,
            icon: const Icon(LucideIcons.chevronDown, size: 16, color: Color(0xFF64748B)),
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: _inputDecoration('Select an option'),
            items: _types.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['label']!, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)))).toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 24),
          Text('POLLING UNIT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(child: Text(_userProfile?['assignedPollingUnit'] ?? 'LOCATING POLLING UNIT...', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))),
                const Icon(LucideIcons.mapPin, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('DESCRIBE WHAT HAPPENED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 6,
            style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: Colors.black),
            decoration: _inputDecoration('Provide a detailed description of the incident. Include what happened, who was involved, and when it occurred...'),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.camera, 'PHOTOS & VIDEO', 'OPTIONAL EVIDENCE'),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildEvidenceTile('TAKE PHOTO', 'PHOTOS/STILLS', LucideIcons.camera, () => _showSourcePicker('photo')),
              const SizedBox(width: 12),
              _buildEvidenceTile('RECORD VIDEO', 'HD VIDEO', LucideIcons.video, () => _showSourcePicker('video')),
            ],
          ),
          const SizedBox(height: 12),
          _buildEvidenceTile('RECORD AUDIO', 'VOICE/SOUND', LucideIcons.mic, () => _showSourcePicker('audio'), isFullWidth: true),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _media.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 100, height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        image: _media[i]['type'] == 'photo' ? DecorationImage(image: FileImage(_media[i]['file']), fit: BoxFit.cover) : null
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_media[i]['type'] != 'photo') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(
                                _media[i]['type'] == 'video' ? LucideIcons.video : LucideIcons.mic, 
                                color: const Color(0xFF10B981), 
                                size: 24
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _media[i]['type'].toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _media.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(6), 
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), 
                          child: const Icon(LucideIcons.x, size: 14, color: Colors.red)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceTile(String title, String sub, IconData icon, VoidCallback onTap, {bool isFullWidth = false}) {
    final content = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0F172A), size: 28),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );

    return isFullWidth ? content : Expanded(child: content);
  }

  Widget _buildReportDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('REPORT DETAILS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 32),
          _buildDetailRow('TIME', DateFormat('HH:mm:ss').format(DateTime.now()), LucideIcons.clock),
          _buildDetailRow('LATITUDE', '${_currentPosition?.latitude.toStringAsFixed(4) ?? '0.0000'}° N', LucideIcons.mapPin),
          _buildDetailRow('LONGITUDE', '${_currentPosition?.longitude.toStringAsFixed(4) ?? '0.0000'}° E', LucideIcons.mapPin),
          _buildDetailRow('DEVICE ID', _deviceId, LucideIcons.smartphone),
          const SizedBox(height: 24),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
            child: const Center(child: Icon(LucideIcons.map, size: 40, color: Color(0xFFCBD5E1))),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? labelColor, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: labelColor ?? const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: valueColor ?? const Color(0xFF0F172A))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.shieldCheck, 'GUIDELINES', ''),
          const SizedBox(height: 24),
          _buildGuidelineItem('ONLY REPORT WHAT YOU PERSONALLY SAW.'),
          _buildGuidelineItem('MAKE SURE YOUR GPS IS TURNED ON.'),
          _buildGuidelineItem('YOUR SAFETY IS MORE IMPORTANT THAN REPORTING.'),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 10, color: Color(0xFF10B981))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildSubmitActions() {
    return Column(
      children: [
        if (_submitting) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UPLOADING REPORT...', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
                    Text('${(_uploadProgress * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFFECFDF5),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_submitting || _savingDraft) ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.send, size: 16, color: Colors.white),
                const SizedBox(width: 12),
                Text('SUBMIT REPORT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (_submitting || _savingDraft) ? null : _handleSaveDraft,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              side: const BorderSide(color: Color(0xFFF1F5F9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.save, size: 16, color: Color(0xFF065F46)),
                const SizedBox(width: 12),
                Text('SAVE DRAFT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF065F46), letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSubmissions() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(LucideIcons.fileText, 'RECENT SUBMISSIONS', 'HISTORY FOR THIS ELECTION'),
        const SizedBox(height: 24),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('incident_reports')
              .where('electionId', isEqualTo: widget.electionId)
              .where('observerId', isEqualTo: user?.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)), child: Center(child: Text('No reports submitted yet', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)))));
            
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final date = d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : (d['timestamp'] != null ? (d['timestamp'] as Timestamp).toDate() : DateTime.now());
                return GestureDetector(
                  onTap: () => _showIncidentDetails(docs[i].id, d),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.triangleAlert, size: 16, color: Colors.orange)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(d['incidentType']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'INCIDENT', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                                  const Spacer(),
                                  _buildStatusBadge(d['status'] ?? 'reported'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd/MM/yyyy, HH:mm:ss').format(date), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final isDraft = status.toLowerCase() == 'draft';
    final color = isDraft ? Colors.orange : const Color(0xFF10B981);
    final bgColor = isDraft ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
      ),
    );
  }

  void _showIncidentDetails(String docId, Map<String, dynamic> data) {
    final date = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : (data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now());
    final List<dynamic> mediaItems = data['mediaItems'] ?? [];
    final List<String> mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.arrowLeft)),
                    const SizedBox(width: 16),
                    Expanded(child: Text('INCIDENT REPORT', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black))),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (confirmCtx) => AlertDialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            title: Text('Delete Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                            content: Text('Are you sure you want to delete this incident report? This action cannot be undone.', style: GoogleFonts.outfit(color: Colors.black)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(confirmCtx),
                                child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(confirmCtx);
                                  await FirebaseFirestore.instance.collection('incident_reports').doc(docId).delete();
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted'), backgroundColor: Colors.red));
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: Text('DELETE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.trash2, color: Colors.red),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 300,
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                        child: (mediaItems.isEmpty && mediaUrls.isEmpty)
                          ? const Center(child: Icon(LucideIcons.image, color: Colors.white24, size: 48))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mediaItems.isNotEmpty ? mediaItems.length : mediaUrls.length,
                              itemBuilder: (c, i) {
                                final url = mediaItems.isNotEmpty ? mediaItems[i]['url'] : mediaUrls[i];
                                String type = mediaItems.isNotEmpty ? mediaItems[i]['type'] : 'photo';
                                
                                // Enhanced type detection for backward compatibility with older reports
                                if (type == 'photo') {
                                  final lowerUrl = url.toLowerCase();
                                  if (lowerUrl.contains('.mp4') || lowerUrl.contains('.mov') || lowerUrl.contains('.avi')) {
                                    type = 'video';
                                  } else if (lowerUrl.contains('.mp3') || lowerUrl.contains('.wav') || lowerUrl.contains('.m4a') || lowerUrl.contains('.aac')) {
                                    type = 'audio';
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.85,
                                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24), 
                                      child: type == 'video' 
                                        ? VideoPlayerWidget(url: url)
                                        : type == 'audio'
                                          ? AudioPlayerWidget(url: url)
                                          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['incidentType']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'INCIDENT', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                            const SizedBox(height: 8),
                            Text(DateFormat('EEEE, MMMM d, yyyy - HH:mm:ss').format(date), style: GoogleFonts.outfit(fontSize: 14, color: Colors.black)),
                            const SizedBox(height: 32),
                            Text('DESCRIPTION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1)),
                            const SizedBox(height: 12),
                            Text(data['description'] ?? '', style: GoogleFonts.outfit(fontSize: 14, height: 1.5, color: Colors.black)),
                            const SizedBox(height: 32),
                            Text('LOCATION DETAILS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1)),
                            const SizedBox(height: 12),
                            _buildDetailRow('POLLING UNIT', data['pollingUnit'] ?? '', LucideIcons.mapPin, labelColor: Colors.black, valueColor: Colors.black),
                            _buildDetailRow('WARD', data['ward'] ?? '', LucideIcons.map, labelColor: Colors.black, valueColor: Colors.black),
                            _buildDetailRow('LGA / STATE', '${data['lga']} / ${data['state']}', LucideIcons.map, labelColor: Colors.black, valueColor: Colors.black),
                            _buildDetailRow('COORDINATES', '${data['latitude']}°, ${data['longitude']}°', LucideIcons.navigation, labelColor: Colors.black, valueColor: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              if (sub.isNotEmpty) Text(sub, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(20),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textCol, letterSpacing: 0.5)),
    );
  }
}

class _EC8AResultsTab extends StatefulWidget {
  final String electionId;
  const _EC8AResultsTab({required this.electionId});

  @override
  State<_EC8AResultsTab> createState() => _EC8AResultsTabState();
}

class _EC8AResultsTabState extends State<_EC8AResultsTab> {
  final Map<String, int> _partyVotes = {};
  final Map<String, int> _stats = {
    'votersInRegister': 0,
    'accreditedVoters': 0,
    'ballotsIssued': 0,
    'unusedBallots': 0,
    'spoiledBallots': 0,
    'rejectedBallots': 0,
  };
  
  List<DocumentSnapshot> _parties = [];
  bool _loading = true;
  bool _scanning = false;
  bool _submitting = false;
  bool _isFinal = false;
  Map<String, dynamic>? _userProfile;
  File? _evidenceFile;
  String? _evidenceUrl;
  bool _isPrecisionView = true; 
  DateTime? _lastScanTime;
  int? _expectedYear;
  String? _expectedType;
  final Map<String, TextEditingController> _partyControllers = {};
  final Map<String, TextEditingController> _statControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var c in _partyControllers.values) {
      c.dispose();
    }
    for (var c in _statControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _sanitizeId(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
  }

  void _updateControllers() {
    _partyVotes.forEach((k, v) {
      if (_partyControllers.containsKey(k)) {
        _partyControllers[k]!.text = v == 0 ? '' : v.toString();
      }
    });
    _stats.forEach((k, v) {
      if (_statControllers.containsKey(k)) {
        _statControllers[k]!.text = v == 0 ? '' : v.toString();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profileSnap = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      _userProfile = profileSnap.data();
      
      final parties = await FirebaseFirestore.instance.collection('parties').orderBy('abbreviation').get();
      final electionDoc = await FirebaseFirestore.instance.collection('elections').doc(widget.electionId).get();
      
      final state = _userProfile?['assignedState'] ?? '';
      final lga = _userProfile?['assignedLga'] ?? '';
      final ward = _userProfile?['assignedWard'] ?? '';
      final pu = _userProfile?['assignedPollingUnit'] ?? '';
      
      final puKey = _sanitizeId('${state}_${lga}_${ward}_$pu');
      final webDocId = '${widget.electionId}_$puKey';
      final mobileDocId = '${widget.electionId}_${user?.uid}';

      // Load Results
      var existing = await FirebaseFirestore.instance.collection('election_results')
          .doc(mobileDocId).get();
      if (!existing.exists) {
        existing = await FirebaseFirestore.instance.collection('election_results')
            .doc(webDocId).get();
        if (existing.exists) debugPrint('📱 Found web-formatted results: $webDocId');
      }
          
      // Load Statistics
      var existingStats = await FirebaseFirestore.instance.collection('election_statistics')
          .doc(mobileDocId).get();
      if (!existingStats.exists) {
        existingStats = await FirebaseFirestore.instance.collection('election_statistics')
            .doc('${webDocId}_stats').get();
        if (existingStats.exists) debugPrint('📱 Found web-formatted statistics');
      }

      if (mounted) {
        setState(() {
          _userProfile = profileSnap.data();
          _parties = parties.docs;
          if (electionDoc.exists && electionDoc.data()?['startDate'] != null) {
            _expectedYear = (electionDoc.data()!['startDate'] as Timestamp).toDate().year;
            _expectedType = electionDoc.data()?['type']?.toString().toUpperCase();
          }
          
          // Initialize controllers
          for (var doc in _parties) {
            final data = doc.data() as Map<String, dynamic>;
            final abb = data['abbreviation'] as String;
            if (!_partyControllers.containsKey(abb)) {
              _partyControllers[abb] = TextEditingController();
            }
          }
          _stats.keys.forEach((key) {
            if (!_statControllers.containsKey(key)) {
              _statControllers[key] = TextEditingController();
            }
          });

          // Hydrate Party Votes Draft Data
          if (existing.exists && existing.data() != null) {
            final data = existing.data()!;
            final votes = data['partyVotes'] as Map<String, dynamic>? ?? {};
            votes.forEach((k, v) => _partyVotes[k] = v as int);
            _isFinal = data['status'] == 'final';
            _evidenceUrl = data['evidenceUrl'] as String?;
          }
          
          // Hydrate EC8A Statistics Draft Data
          if (existingStats.exists && existingStats.data() != null) {
            final data = existingStats.data()!;
            _stats.keys.forEach((key) {
              if (data.containsKey(key)) {
                _stats[key] = int.tryParse(data[key].toString()) ?? 0;
              }
            });
          }
          
          _loading = false;
          _updateControllers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalValidVotes => _partyVotes.values.fold(0, (sum, v) => sum + v);
  int get _totalUsedBallots => (_stats['ballotsIssued'] ?? 0) - (_stats['unusedBallots'] ?? 0);

  List<String> get _validationErrors {
    List<String> errors = [];
    if (_totalValidVotes > (_stats['votersInRegister'] ?? 0)) errors.add('OVER-VOTING: Total votes exceed registered voters.');
    if ((_stats['accreditedVoters'] ?? 0) > (_stats['votersInRegister'] ?? 0)) errors.add('ACCREDITATION ERROR: Accredited exceeds registered.');
    final totalBallotsCounted = (_stats['unusedBallots'] ?? 0) + (_stats['spoiledBallots'] ?? 0) + (_stats['rejectedBallots'] ?? 0);
    if (totalBallotsCounted > (_stats['ballotsIssued'] ?? 0)) errors.add('BALLOT MISMATCH: Counted ballots exceed issued.');
    return errors;
  }

  Future<void> _handleOCR(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img == null) return;

    if (_lastScanTime != null) {
      final diff = DateTime.now().difference(_lastScanTime!).inSeconds;
      if (diff < 65) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rate Limit: Please wait ${65 - diff}s before scanning again.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    setState(() {
      _evidenceFile = File(img.path);
    });
    
    // Ask for pre-scan validation before automatically running the OCR
    _showPreScanValidation();
  }

  void _showPreScanValidation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Quality & Integrity Check', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before we automatically read the numbers, please confirm the following:',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.calendarCheck, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(child: Text('This EC8A form is strictly for the ${_expectedYear ?? 'assigned'} ${_expectedType ?? ''} Election.', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.scanLine, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(child: Text('All four borders of the document are visible, well-lit, and in focus.', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _evidenceFile = null;
              });
            },
            child: Text('RETAKE IMAGE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runOCR();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('I CONFIRM, PROCEED', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runOCR() async {
    if (_evidenceFile == null) return;
    
    setState(() => _scanning = true);
    _lastScanTime = DateTime.now();

    try {
      final aiService = context.read<AIService>();
      Map<String, dynamic>? result;
      bool usedFallback = false;

      try {
        result = await aiService.processEC8A(_evidenceFile!);
      } catch (geminiError) {
        debugPrint("Gemini failed, falling back to ML Kit: $geminiError");
        usedFallback = true;
        List<String> abbs = _parties.map((d) => (d.data() as Map<String, dynamic>)['abbreviation'] as String).toList();
        result = await aiService.processEC8ALocal(_evidenceFile!, abbs);
      }
      
      if (result != null && mounted) {
        int? detectedYear = int.tryParse(result['electionYear']?.toString() ?? '');
        if (detectedYear != null && _expectedYear != null && detectedYear != _expectedYear && detectedYear > 1900) {
          // Clear the image to force re-upload
          setState(() {
            _evidenceFile = null;
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Election Year Mismatch!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                ],
              ),
              content: Text(
                'Data Extraction Aborted.\n\nThe AI detected the year $detectedYear on this result sheet, but you are assigned to observe the $_expectedYear election.\n\nPlease upload the correct EC8A image for the actual election.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('UPLOAD CORRECT FORM', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
          return; // Abort extraction entirely
        }

        String? detectedType = result['electionType']?.toString().toUpperCase();
        if (detectedType != null && _expectedType != null && detectedType != _expectedType && detectedType.isNotEmpty) {
          // Clear the image to force re-upload
          setState(() {
            _evidenceFile = null;
          });
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Election Type Mismatch!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                ],
              ),
              content: Text(
                'Data Extraction Aborted.\n\nThe AI detected this is a $detectedType election result sheet, but you are assigned to observe the $_expectedType election.\n\nPlease upload the correct EC8A image for the actual election type.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('UPLOAD CORRECT FORM', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
          return; // Abort extraction entirely
        }

        // Proceed to map data since year and type matches (or wasn't detected)
        setState(() {
          // Map party votes
          _parties.forEach((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final key = data['abbreviation'] as String;
            if (result!.containsKey(key)) {
              _partyVotes[key] = int.tryParse(result![key].toString()) ?? 0;
            }
          });
          // Map stats
          _stats.keys.forEach((key) {
            if (result!.containsKey(key)) {
              _stats[key] = int.tryParse(result![key].toString()) ?? 0;
            }
          });
          _updateControllers();
        });

        if (usedFallback) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline Scan Complete (Best Effort)'), backgroundColor: Colors.orange));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EC8A Sheet Scanned Successfully!'), backgroundColor: Color(0xFF10B981)));
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(LucideIcons.check, color: Colors.black),
                const SizedBox(width: 8),
                Text('Scan Complete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              ],
            ),
            content: Text(
              'The EC8A data has been extracted.\n\nPlease carefully cross-check the populated numbers with your original EC8A image to ensure 100% accuracy before you submit.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Verify Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(LucideIcons.triangleAlert, color: Colors.red),
                const SizedBox(width: 8),
                Text('Scanning Error', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.outfit(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _attemptSubmit(bool isFinal) {
    if (_evidenceFile != null || _evidenceUrl != null) {
      showDialog(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Data Accuracy', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
          content: Text(
            'You have an EC8A image attached. Are you absolutely sure the numbers you have entered match the numbers on the physical EC8A form?',
            style: GoogleFonts.outfit(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmCtx),
              child: Text('REVIEW', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(confirmCtx);
                _submit(isFinal);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('PROCEED', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _submit(isFinal);
    }
  }

  Future<void> _submit(bool isFinal) async {
    if (isFinal && _validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_validationErrors.first), backgroundColor: Colors.red));
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? evidenceUrl;
      
      if (_evidenceFile != null) {
        final ref = FirebaseStorage.instance.ref().child('results/${widget.electionId}/${user?.uid}.jpg');
        await ref.putFile(_evidenceFile!);
        evidenceUrl = await ref.getDownloadURL();
      }

      // 1. Data Preparation (Both Modes)
      final pollingUnitInfo = {
        'state': _userProfile?['assignedState'],
        'lga': _userProfile?['assignedLga'],
        'ward': _userProfile?['assignedWard'],
        'pollingUnit': _userProfile?['assignedPollingUnit'],
      };

      final payload1 = {
        'electionId': widget.electionId,
        'pollingUnitInfo': pollingUnitInfo,
        'partyVotes': _partyVotes,
        if (evidenceUrl != null) 'evidenceUrl': evidenceUrl,
        'status': isFinal ? 'final' : 'draft',
        if (isFinal) 'submittedBy': user?.uid,
        if (isFinal) 'submittedByName': _userProfile?['fullName'],
        if (isFinal) 'submittedAt': FieldValue.serverTimestamp(),
        if (!isFinal) 'updatedBy': user?.uid,
        if (!isFinal) 'updatedAt': FieldValue.serverTimestamp(),
      };

      final payload2 = {
        'electionId': widget.electionId,
        'pollingUnitInfo': pollingUnitInfo,
        'status': isFinal ? 'final' : 'draft',
        ..._stats,
        'totalValidVotes': _totalValidVotes,
        'totalUsedBallots': _totalUsedBallots,
      };

      // Write 1: election_results
      await FirebaseFirestore.instance.collection('election_results').doc('${widget.electionId}_${user?.uid}').set(payload1, SetOptions(merge: true));

      // Write 2: election_statistics
      await FirebaseFirestore.instance.collection('election_statistics').doc('${widget.electionId}_${user?.uid}').set(payload2, SetOptions(merge: true));

      if (mounted) {
        if (isFinal) {
          // 3. Final Submission Post-Action
          setState(() => _isFinal = true); // _isFinal acts as the isSubmitted boolean
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Results Submitted and Locked'), backgroundColor: Color(0xFF10B981)));
          // Navigate back to Observer Command Center Dashboard
          DefaultTabController.maybeOf(context)?.animateTo(0);
        } else {
          // 2. Save Progress Post-Action
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft Saved'), backgroundColor: Color(0xFF3B82F6)));
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF065F46)));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHeader(),
        if (_validationErrors.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildValidationBanner(),
        ],
        const SizedBox(height: 32),
        _buildResultsGridCard(),
        const SizedBox(height: 24),
        _buildEvidenceSidebarCard(),
        const SizedBox(height: 24),
        _buildStatsSidebarCard(),
        const SizedBox(height: 32),
        _buildProgressFooter(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Submit Results', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
              const SizedBox(height: 4),
              Text('Enter results for 2026 Presidential Election', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _buildStatusBadge('LIVE CONNECTION', const Color(0xFFECFDF5), const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: textCol, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildValidationBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert, color: Color(0xFFB91C1C), size: 18),
              const SizedBox(width: 10),
              Text('VALIDATION ERRORS DETECTED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFFB91C1C), letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ..._validationErrors.map((err) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFB91C1C), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(err, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7F1D1D)))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildResultsGridCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.chartBar, 'Election Results', ''),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleItem('CONDENSED', !_isPrecisionView, () => setState(() => _isPrecisionView = false)),
                _buildToggleItem('PRECISION VIEW', _isPrecisionView, () => setState(() => _isPrecisionView = true)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_isPrecisionView)
            _buildPrecisionHeader()
          else
            const SizedBox.shrink(),
          if (_isPrecisionView)
            _buildPrecisionList()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: _parties.length,
              itemBuilder: (context, i) => _buildPartyEntryCard(_parties[i].data() as Map<String, dynamic>),
            ),
        ],
      ),
    );
  }

  Widget _buildPrecisionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text('PARTY LOGO', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 0.5))),
          const SizedBox(width: 24),
          Expanded(child: Text('PARTY NAME', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 0.5))),
          SizedBox(width: 80, child: Text('TOTAL VOTES', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 0.5), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildPrecisionList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _parties.length,
      separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, i) => _buildPartyEntryRow(_parties[i].data() as Map<String, dynamic>),
    );
  }

  Widget _buildPartyEntryRow(Map<String, dynamic> party) {
    final abb = party['abbreviation'] ?? '';
    final name = party['name'] ?? '';
    final logoUrl = party['logoUrl'];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _buildSmartLogo(logoUrl, abb, 48, fontSize: 16),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(abb, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF0F172A), fontWeight: FontWeight.w900)),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                    Text('OFFICIAL PARTY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: TextField(
              enabled: !_isFinal,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _partyVotes[abb] = int.tryParse(v) ?? 0),
              controller: _partyControllers[abb],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8))),
      ),
    );
  }

  Widget _buildPartyEntryCard(Map<String, dynamic> party) {
    final abb = party['abbreviation'] ?? '';
    final name = party['name'] ?? '';
    final logoUrl = party['logoUrl'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          _buildSmartLogo(logoUrl, abb, 24, fontSize: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(abb, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: TextField(
              enabled: !_isFinal,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _partyVotes[abb] = int.tryParse(v) ?? 0),
              controller: _partyControllers[abb],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildCardHeader(LucideIcons.fileImage, 'RESULT SHEET (EC8A)', '')),
              if (_evidenceFile != null || _evidenceUrl != null)
                IconButton(
                  onPressed: () => _showFullImage(),
                  icon: const Icon(LucideIcons.maximize2, size: 14, color: Color(0xFF10B981)),
                )
              else
                const Icon(LucideIcons.maximize2, size: 14, color: Color(0xFFCBD5E1)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              image: _evidenceFile != null 
                ? DecorationImage(
                    image: FileImage(_evidenceFile!), 
                    fit: BoxFit.cover,
                    colorFilter: _scanning ? ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken) : null,
                  ) 
                : (_evidenceUrl != null ? DecorationImage(image: CachedNetworkImageProvider(_evidenceUrl!), fit: BoxFit.cover) : null),
            ),
            child: _scanning
              ? Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 0.99),
                    duration: const Duration(seconds: 12),
                    builder: (context, value, _) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: value, 
                                strokeWidth: 6, 
                                color: const Color(0xFF10B981), 
                                backgroundColor: const Color(0xFFECFDF5)
                              ),
                            ),
                            Text(
                              '${(value * 100).toInt()}%', 
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF065F46))
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : (_evidenceFile == null && _evidenceUrl == null)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.image, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      Text('No result sheet uploaded yet.\nUpload the EC8A form to automatically read the numbers.', 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : null,
          ),
          const SizedBox(height: 24),
          if (_evidenceFile == null && _evidenceUrl == null && !_isFinal)
            Row(
              children: [
                Expanded(child: _buildActionButton('CAPTURE SHEET', LucideIcons.camera, () => _showResultsSourcePicker())),
                const SizedBox(width: 12),
                Expanded(child: _buildActionButton('GALLERY', LucideIcons.image, () => _handleOCR(ImageSource.gallery))),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildActionButton('CHANGE IMAGE', LucideIcons.refreshCw, () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        backgroundColor: Colors.white,
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Change Image Source', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                                const SizedBox(height: 16),
                                ListTile(
                                  leading: const Icon(LucideIcons.camera, color: Colors.black),
                                  title: Text('Camera Snapshot', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _handleOCR(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(LucideIcons.image, color: Colors.black),
                                  title: Text('Upload from Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _handleOCR(ImageSource.gallery);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF10B981)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _scanning ? null : () => _runOCR(),
                          icon: _scanning 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.scan, size: 16, color: Colors.white),
                          label: Text('AUTO-FILL NUMBERS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showFullImage() {
    if (_evidenceFile == null && _evidenceUrl == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _evidenceFile != null 
                  ? Image.file(_evidenceFile!) 
                  : CachedNetworkImage(imageUrl: _evidenceUrl!),
              ),
            ),
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.black, size: 24),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isFinal ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStatsSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(LucideIcons.calculator, 'VOTER STATISTICS (EC8A)', ''),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildCompactStatInput('VOTERS IN REGISTER', 'votersInRegister'),
              const SizedBox(width: 12),
              _buildCompactStatInput('ACCREDITED VOTERS', 'accreditedVoters'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCompactStatInput('BALLOTS ISSUED', 'ballotsIssued'),
              const SizedBox(width: 12),
              _buildCompactStatInput('UNUSED BALLOTS', 'unusedBallots'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCompactStatInput('SPOILED BALLOTS', 'spoiledBallots'),
              const SizedBox(width: 12),
              _buildCompactStatInput('REJECTED BALLOTS', 'rejectedBallots'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL VALID VOTES', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
                  Text(_totalValidVotes.toString(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL USED BALLOTS', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8))),
                  Text(_totalUsedBallots.toString(), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatInput(String label, String key) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          TextField(
            enabled: !_isFinal,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
            onChanged: (v) => setState(() => _stats[key] = int.tryParse(v) ?? 0),
            controller: _statControllers[key],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _buildStepIndicator('1', 'ACCREDITATION', 'VERIFIED', true)),
              _buildStepDivider(),
              Flexible(child: _buildStepIndicator('2', 'RESULT ENTRY', 'ACTIVE', false, isCurrent: true)),
              _buildStepDivider(),
              Flexible(child: _buildStepIndicator('3', 'FINAL REVIEW', 'PENDING', false)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isFinal ? null : () => _attemptSubmit(false),
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: Text('SAVE PROGRESS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 24), side: const BorderSide(color: Color(0xFFF1F5F9)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isFinal ? null : () => _attemptSubmit(true),
                    icon: const Icon(LucideIcons.send, size: 16, color: Colors.white),
                    label: Text('FINAL SUBMISSION', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String num, String title, String sub, bool verified, {bool isCurrent = false}) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: verified ? const Color(0xFFECFDF5) : (isCurrent ? const Color(0xFF10B981) : const Color(0xFFF1F5F9)),
            shape: BoxShape.circle,
            border: verified ? Border.all(color: const Color(0xFF10B981)) : null,
          ),
          child: Center(
            child: verified 
              ? const Icon(LucideIcons.check, size: 14, color: Color(0xFF10B981))
              : Text(num, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: isCurrent ? Colors.white : const Color(0xFF94A3B8))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              Text(sub, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: verified ? const Color(0xFF10B981) : const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Container(width: 20, height: 1, color: const Color(0xFFF1F5F9));
  }

  void _showResultsSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('RESULTS EVIDENCE', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('Attach the EC8A result sheet', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 32),
            _buildResultsPickerOption(
              icon: LucideIcons.camera, 
              title: 'TAKE SNAPSHOT',
              subtitle: 'Scan official document now',
              onTap: () {
                Navigator.pop(ctx);
                _handleOCR(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _buildResultsPickerOption(
              icon: LucideIcons.image, 
              title: 'PICK FROM GALLERY',
              subtitle: 'Upload from device storage',
              onTap: () {
                Navigator.pop(ctx);
                _handleOCR(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPickerOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle), child: Icon(icon, size: 16, color: const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
              if (sub.isNotEmpty) Text(sub, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartLogo(String? url, String abb, double size, {double fontSize = 14}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildFallbackLogo(abb, size, fontSize),
              errorWidget: (context, url, error) => _buildFallbackLogo(abb, size, fontSize),
            )
          : _buildFallbackLogo(abb, size, fontSize),
      ),
    );
  }

  Widget _buildFallbackLogo(String abb, double size, double fontSize) {
    return Center(
      child: Text(
        abb.isNotEmpty ? abb[0] : '?',
        style: GoogleFonts.outfit(fontSize: fontSize, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      debugPrint('Initializing video player for: ${widget.url}');
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      
      await _videoPlayerController!.initialize();
      
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Video playback error',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        },
      );
      
      setState(() {});
    } catch (e) {
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              'Unable to load video',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
        ? Chewie(controller: _chewieController!)
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Buffering...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged.listen((s) => setState(() => _isPlaying = s == PlayerState.playing));
    await _audioPlayer.setSourceUrl(widget.url);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(LucideIcons.mic, color: Color(0xFF10B981), size: 32),
          ),
          const SizedBox(height: 12),
          Text('AUDIO RECORDING', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFF10B981),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.white,
            ),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: GoogleFonts.outfit(fontSize: 9, color: Colors.white54)),
                Text(_formatDuration(_duration), style: GoogleFonts.outfit(fontSize: 9, color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IconButton(
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.url));
              }
            },
            iconSize: 48,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class _ChatWidget extends StatefulWidget {
  final String groupId;
  final String userId;
  final String userName;
  final String role;

  const _ChatWidget({
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.role,
  });

  @override
  State<_ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<_ChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.users, size: 20, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GROUP CHAT', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                      Text(widget.groupId.replaceAll('_', ' ').toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_messages')
                  .where('groupId', isEqualTo: widget.groupId)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderId'] == widget.userId;
                    final sender = d['sender'] as Map<String, dynamic>? ?? {};
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text('${sender['firstName']} ${sender['lastName']}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                            if (!isMe) const SizedBox(height: 4),
                            Text(d['content'] ?? '', style: GoogleFonts.outfit(fontSize: 13, color: isMe ? Colors.white : const Color(0xFF0F172A), height: 1.4)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    
    final names = widget.userName.split(' ');
    final firstName = names.isNotEmpty ? names[0] : 'Observer';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

    await FirebaseFirestore.instance.collection('chat_messages').add({
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
      'groupId': widget.groupId,
      'isRead': false,
      'senderId': widget.userId,
      'sender': {
        'firstName': firstName,
        'lastName': lastName,
        'role': widget.role,
        'senderId': widget.userId,
      },
    });
  }
}
