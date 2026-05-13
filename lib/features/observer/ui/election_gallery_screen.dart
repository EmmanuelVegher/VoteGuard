import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:voteguard/models/election_model.dart';
import 'package:voteguard/services/time_service.dart';
import 'package:voteguard/services/export_service.dart';
import 'package:voteguard/services/geo_service.dart';

class ElectionGalleryScreen extends StatefulWidget {
  const ElectionGalleryScreen({super.key});

  @override
  State<ElectionGalleryScreen> createState() => _ElectionGalleryScreenState();
}

class _ElectionGalleryScreenState extends State<ElectionGalleryScreen> with SingleTickerProviderStateMixin {
  final _timeService = TimeService();
  final _geoService = GeoService();
  late TabController _tabController;
  int _activeTabIndex = 0;
  DateTime _currentWAT = DateTime.now();
  String? _exportingType;

  // Elections State
  List<Election> _elections = [];
  bool _isLoadingElections = true;
  bool _hasUpdates = false;
  StreamSubscription<QuerySnapshot>? _electionsSubscription;
  bool _isFirstSnapshot = true;

  // Assignment Edit State
  bool _isEditingAssignment = false;
  String? _selectedState;
  String? _selectedLga;
  String? _selectedWard;
  String? _selectedPU;
  List<String> _states = [];
  List<String> _lgas = [];
  List<String> _wards = [];
  List<String> _pus = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted && _tabController.index != _activeTabIndex) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _updateTime();
    _loadStates();
    _fetchElections();
    _listenForElectionUpdates();
  }

  @override
  void dispose() {
    _electionsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    debugPrint("ElectionGallery: Loading states...");
    try {
      final s = await _geoService.getStates();
      debugPrint("ElectionGallery: Loaded ${s.length} states");
      if (mounted) setState(() => _states = s.map((e) => e.name).toList());
    } catch (e) {
      debugPrint("ElectionGallery: Error loading states: $e");
    }
  }

  Future<void> _updateTime() async {
    final time = await _timeService.getWATTime();
    if (mounted) setState(() => _currentWAT = time);
  }

  Future<void> _fetchElections() async {
    if (!mounted) return;
    setState(() {
      _isLoadingElections = true;
      _hasUpdates = false;
    });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('elections').get();
      if (mounted) {
        setState(() {
          _elections = snapshot.docs.map((d) => Election.fromFirestore(d.data(), d.id)).toList();
          _isLoadingElections = false;
        });
      }
    } catch (e) {
      debugPrint("ElectionGallery: Error fetching elections: $e");
      if (mounted) {
        setState(() {
          _isLoadingElections = false;
        });
      }
    }
  }

  void _listenForElectionUpdates() {
    _electionsSubscription = FirebaseFirestore.instance.collection('elections').snapshots().listen((snapshot) {
      if (_isFirstSnapshot) {
        _isFirstSnapshot = false;
        return;
      }
      if (snapshot.docChanges.isNotEmpty) {
        if (mounted) {
          setState(() {
            _hasUpdates = true;
          });
        }
      }
    });
  }

  Stream<DocumentSnapshot> get _userStream {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance.collection('users').doc(user?.uid ?? 'none').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final userProfile = userSnapshot.data?.data() as Map<String, dynamic>?;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: RefreshIndicator(
            onRefresh: _fetchElections,
            color: const Color(0xFF065F46),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildAppBar(userProfile),
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _hasUpdates
                        ? Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.refreshCw, color: Color(0xFF059669), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'New election updates available!',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF065F46),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _fetchElections,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text('REFRESH', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildCommandCenterHeader(userProfile),
                      _buildYourElectionsTitle(),
                    ],
                  ),
                ),
                _buildTabsHeader(),
                _buildElectionsList(userProfile),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildAppBar(Map<String, dynamic>? profile) {
    final hasImg = profile?['profilePictureUrl'] != null;
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      title: Text('ELECTION GALLERY', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
      actions: [
        IconButton(icon: const Icon(LucideIcons.refreshCw, size: 20, color: Color(0xFF1E293B)), onPressed: _fetchElections),
        IconButton(icon: const Icon(LucideIcons.bell, size: 20, color: Color(0xFF1E293B)), onPressed: () {}),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 8),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: hasImg ? NetworkImage(profile!['profilePictureUrl'].toString()) : null,
            backgroundColor: const Color(0xFF1E293B),
            child: !hasImg ? const Icon(LucideIcons.user, size: 16, color: Colors.white) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCommandCenterHeader(Map<String, dynamic>? profile) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20), // Reduced from 32
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(32), // Reduced from 40
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                child: const Icon(LucideIcons.layoutGrid, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
                Expanded(child: Text('OBSERVER COMMAND CENTER', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2))),
            ],
          ),
          const SizedBox(height: 20),
          Text(_isEditingAssignment ? 'Update your Polling Location' : 'Choose an Election to\nStart Monitoring', 
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1, letterSpacing: -0.5)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin, color: Colors.white, size: 16),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text('SELECT YOUR POLLING UNIT', 
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isEditingAssignment)
                      TextButton(onPressed: () {
                        setState(() => _isEditingAssignment = true);
                        if (_states.isEmpty) _loadStates();
                      }, child: Text('CHANGE UNIT', style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)))
                    else
                      TextButton(onPressed: () => setState(() => _isEditingAssignment = false), child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isEditingAssignment) ...[
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 12,
                    children: [
                      _buildAssignmentItem('STATE', profile?['assignedState'] ?? 'N/A'),
                      _buildAssignmentItem('LGA', profile?['assignedLga'] ?? 'N/A'),
                      _buildAssignmentItem('WARD', profile?['assignedWard'] ?? 'N/A'),
                      _buildAssignmentItem('POLLING UNIT', profile?['assignedPollingUnit'] ?? 'N/A'),
                    ],
                  ),
                ] else ...[
                  if (_states.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: Colors.white70),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _loadStates, child: Text('RETRY LOADING', style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    )
                  else
                    _buildGeoDropdown('Select State', _states, _selectedState, (v) async {
                      setState(() { _selectedState = v; _selectedLga = null; _selectedWard = null; _selectedPU = null; });
                      final lgas = await _geoService.getLGAs(v!);
                      setState(() => _lgas = lgas.map((e) => e.name).toList());
                    }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select LGA', _lgas, _selectedLga, (v) async {
                    setState(() { _selectedLga = v; _selectedWard = null; _selectedPU = null; });
                    final wards = await _geoService.getWards(_selectedState!, v!);
                    setState(() => _wards = wards.map((e) => e.name).toList());
                  }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select Ward', _wards, _selectedWard, (v) async {
                    setState(() { _selectedWard = v; _selectedPU = null; });
                    final pus = await _geoService.getPollingUnits(_selectedState!, _selectedLga!, v!);
                    setState(() => _pus = pus.map((e) => e.name).toList());
                  }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select Polling Unit', _pus, _selectedPU, (v) => setState(() => _selectedPU = v)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAssignment,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE LOCATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                //const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(LucideIcons.circleCheck, color: Color(0xFF6EE7B7), size: 14), const SizedBox(width: 8), Text('LOCATION VERIFIED', style: GoogleFonts.outfit(color: const Color(0xFF6EE7B7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoDropdown(String hint, List<String> items, String? value, ValueChanged<String?> onChanged) {
    debugPrint("Dropdown: $hint has ${items.length} items. Current value: $value");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          isExpanded: true,
          dropdownColor: const Color(0xFF064E3B),
          icon: const Icon(LucideIcons.chevronDown, color: Colors.white70, size: 16),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    if (_selectedState == null || _selectedLga == null || _selectedWard == null || _selectedPU == null) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'assignedState': _selectedState,
          'assignedLga': _selectedLga,
          'assignedWard': _selectedWard,
          'assignedPollingUnit': _selectedPU,
        });
        setState(() => _isEditingAssignment = false);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildAssignmentItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value.toString().toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildYourElectionsTitle() {
    return Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('YOUR ELECTIONS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: 0.5)), const Icon(LucideIcons.listFilter, size: 18, color: Color(0xFF64748B))]));
  }

  Widget _buildTabsHeader() {
    return SliverPersistentHeader(
      pinned: true, 
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController, 
          isScrollable: false, 
          labelColor: const Color(0xFF065F46), 
          unselectedLabelColor: const Color(0xFF64748B), 
          indicatorColor: const Color(0xFF065F46), 
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5), 
          tabs: const [
            Tab(text: 'ACTIVE'), 
            Tab(text: 'UPCOMING'), 
            Tab(text: 'COMPLETED')
          ]
        )
      )
    );
  }

  Widget _buildElectionsList(Map<String, dynamic>? profile) {
    if (_isLoadingElections) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF065F46))));
    final filtered = _getFilteredElections(_elections, _activeTabIndex);
    if (filtered.isEmpty) return SliverFillRemaining(child: Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(LucideIcons.calendar, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), Text('No elections found.', style: TextStyle(color: Colors.grey[500]))]))));
    return SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildGalleryCard(filtered[index], profile), childCount: filtered.length)));
  }

  List<Election> _getFilteredElections(List<Election> all, int tabIndex) {
    final today = DateTime(_currentWAT.year, _currentWAT.month, _currentWAT.day);
    if (tabIndex == 0) return all.where((e) => e.startDate != null && DateTime(e.startDate!.year, e.startDate!.month, e.startDate!.day).isAtSameMomentAs(today)).toList();
    if (tabIndex == 1) return all.where((e) => e.startDate != null && DateTime(e.startDate!.year, e.startDate!.month, e.startDate!.day).isAfter(today)).toList();
    return all.where((e) => e.startDate != null && today.difference(DateTime(e.startDate!.year, e.startDate!.month, e.startDate!.day)).inDays > 0).toList();
  }

  Widget _buildGalleryCard(Election election, Map<String, dynamic>? profile) {
    final statusLabel = _activeTabIndex == 0 ? 'ACTIVE' : (_activeTabIndex == 1 ? 'UPCOMING' : 'COMPLETED');
    final statusColor = _activeTabIndex == 0 ? const Color(0xFF10B981) : (_activeTabIndex == 1 ? const Color(0xFF0EA5E9) : const Color(0xFF64748B));

    return _buildElectionStatsWrapper(election, profile, (stats) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24)),
              child: const Icon(LucideIcons.archive, size: 36, color: Color(0xFF1E293B)),
            ),
            const SizedBox(width: 20),

            // All Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badges
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChipBadge('ID: ${election.id.substring(0, 1).toUpperCase()}', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                      _buildChipBadge(statusLabel, statusColor.withOpacity(0.1), statusColor),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Election name
                  Text(election.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.3)),
                  const SizedBox(height: 8),

                  // Location & Date
                  Row(
                    children: [
                      Expanded(child: _buildInlineInfo(LucideIcons.mapPin, profile?['assignedState']?.toString() ?? 'NATIONAL')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInlineInfo(LucideIcons.calendar, election.startDate != null ? DateFormat('MMM d, yyyy').format(election.startDate!) : 'TBA')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action buttons — below the election name
                  Row(
                    children: [
                      // Download button
                      GestureDetector(
                        onTap: () => _showReportArchive(election, stats, profile),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Icon(LucideIcons.download, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Complete Reporting button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/observer/dashboard', arguments: election.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A651),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'COMPLETE REPORTING',
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.externalLink, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip('CHECKLIST', stats['checklist']),
                      _buildStatusChip('INCIDENT REPORT', stats['incidents'] > 0),
                      _buildStatusChip('RESULTS', stats['result']),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildChipBadge(String label, Color bg, Color text) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Text(label, style: GoogleFonts.outfit(color: text, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)));
  Widget _buildInlineInfo(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: const Color(0xFF10B981)), const SizedBox(width: 6), Flexible(child: Text(label.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5), overflow: TextOverflow.ellipsis))]);
  Widget _buildStatusChip(String label, bool active) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.check, size: 10, color: active ? const Color(0xFF10B981) : Colors.grey[300]), const SizedBox(width: 6), Flexible(child: Text(label, style: GoogleFonts.outfit(color: active ? const Color(0xFF065F46) : Colors.grey[400], fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5), overflow: TextOverflow.ellipsis))]));

  Widget _buildIconInfo(IconData icon, String label) => Row(children: [Icon(icon, size: 14, color: Colors.grey[400]), const SizedBox(width: 6), Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600))]);

  Widget _buildElectionStatsWrapper(Election election, Map<String, dynamic>? profile, Widget Function(Map<String, dynamic>) builder) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<int>>(
      stream: Rx.combineLatest3(
        FirebaseFirestore.instance.collection('observer_checklists').where('electionId', isEqualTo: election.id).where('observerId', isEqualTo: user?.uid).snapshots(),
        FirebaseFirestore.instance.collection('incident_reports').where('electionId', isEqualTo: election.id).where('observerId', isEqualTo: user?.uid).snapshots(),
        FirebaseFirestore.instance.collection('election_results').where('electionId', isEqualTo: election.id).where('submittedBy', isEqualTo: user?.uid).where('status', isEqualTo: 'final').snapshots(),
        (check, inc, res) => [check.docs.length, inc.docs.length, res.docs.length]
      ),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [0, 0, 0];
        return builder({'checklist': data[0] > 0, 'incidents': data[1], 'result': data[2] > 0});
      }
    );
  }

  void _showReportArchive(Election election, Map<String, dynamic> stats, Map<String, dynamic>? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          String? localExporting;

          Future<void> handleExport(String type) async {
            setModalState(() => localExporting = type);
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (type == 'checklist_pdf' || type == 'checklist_excel') {
                final snap = await FirebaseFirestore.instance
                    .collection('observer_checklists')
                    .where('electionId', isEqualTo: election.id)
                    .where('observerId', isEqualTo: user?.uid)
                    .limit(1).get();
                if (snap.docs.isNotEmpty) {
                  final data = {...snap.docs.first.data(), ...profile ?? {}};
                  await ExportService().exportChecklistReport(election, data);
                }
              } else if (type == 'incident_pdf' || type == 'incident_excel') {
                final snap = await FirebaseFirestore.instance
                    .collection('incident_reports')
                    .where('electionId', isEqualTo: election.id)
                    .where('observerId', isEqualTo: user?.uid)
                    .get();
                if (snap.docs.isNotEmpty) {
                  final incidents = snap.docs.map((d) => d.data()).toList();
                  if (type == 'incident_pdf') {
                    await ExportService().exportIncidentReport(election, incidents);
                  } else {
                    await ExportService().exportIncidentExcel(election, incidents);
                  }
                }
              } else if (type == 'result_pdf' || type == 'result_excel') {
                final snap = await FirebaseFirestore.instance
                    .collection('election_results')
                    .where('electionId', isEqualTo: election.id)
                    .where('submittedBy', isEqualTo: user?.uid)
                    .limit(1).get();
                if (snap.docs.isNotEmpty) {
                  await ExportService().exportResultReport(election, snap.docs.first.data());
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              setModalState(() => localExporting = null);
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Report Archive', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Text('Download your submitted election data.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x, size: 22, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Archive cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildArchiveCard(
                        ctx: ctx,
                        title: 'CHECKLIST SUMMARY',
                        isReady: stats['checklist'] == true,
                        icon: LucideIcons.circleCheck,
                        localExporting: localExporting,
                        onPdf: () => handleExport('checklist_pdf'),
                        onExcel: () => handleExport('checklist_excel'),
                        pdfKey: 'checklist_pdf',
                        excelKey: 'checklist_excel',
                      ),
                      const SizedBox(height: 16),
                      _buildArchiveCard(
                        ctx: ctx,
                        title: 'INCIDENT REPORTS',
                        isReady: (stats['incidents'] as int? ?? 0) > 0,
                        icon: LucideIcons.circleAlert,
                        localExporting: localExporting,
                        onPdf: () => handleExport('incident_pdf'),
                        onExcel: () => handleExport('incident_excel'),
                        pdfKey: 'incident_pdf',
                        excelKey: 'incident_excel',
                      ),
                      const SizedBox(height: 16),
                      _buildArchiveCard(
                        ctx: ctx,
                        title: 'ELECTION RESULT (EC8A)',
                        isReady: stats['result'] == true,
                        icon: LucideIcons.fileText,
                        localExporting: localExporting,
                        onPdf: () => handleExport('result_pdf'),
                        onExcel: () => handleExport('result_excel'),
                        pdfKey: 'result_pdf',
                        excelKey: 'result_excel',
                      ),
                    ],
                  ),
                ),

                // Close button
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CLOSE ARCHIVE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildArchiveCard({
    required BuildContext ctx,
    required String title,
    required bool isReady,
    required IconData icon,
    required String? localExporting,
    required VoidCallback onPdf,
    required VoidCallback onExcel,
    required String pdfKey,
    required String excelKey,
  }) {
    final pdfLoading = localExporting == pdfKey;
    final excelLoading = localExporting == excelKey;
    final anyLoading = localExporting != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isReady ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: isReady ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(isReady ? 'Ready for archive' : 'Not yet submitted', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: isReady ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // PDF & Excel buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildExportBtn(
                    label: 'PDF',
                    icon: LucideIcons.fileText,
                    isLoading: pdfLoading,
                    isDisabled: anyLoading || !isReady,
                    onTap: isReady && !anyLoading ? onPdf : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildExportBtn(
                    label: 'EXCEL',
                    icon: LucideIcons.layoutGrid,
                    isLoading: excelLoading,
                    isDisabled: anyLoading || !isReady,
                    onTap: isReady && !anyLoading ? onExcel : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportBtn({required String label, required IconData icon, required bool isLoading, required bool isDisabled, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
            else
              Icon(icon, size: 16, color: isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: isDisabled ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: label == 'ACTIVE' ? const Color(0xFFECFDF5) : (label == 'UPCOMING' ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC)), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: label == 'ACTIVE' ? const Color(0xFF065F46) : (label == 'UPCOMING' ? const Color(0xFF0369A1) : const Color(0xFF64748B)), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  Widget _buildMiniBadge(String label, Color color, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))]));
  Widget _buildCompletedTag(String label, bool done) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: done ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: done ? const Color(0xFF065F46) : Colors.grey)));
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class Rx {
  static Stream<T> combineLatest3<A, B, C, T>(Stream<A> a, Stream<B> b, Stream<C> c, T Function(A, B, C) combiner) {
    late StreamController<T> controller;
    A? lastA; B? lastB; C? lastC;
    bool hasA = false, hasB = false, hasC = false;
    void update() { if (hasA && hasB && hasC) controller.add(combiner(lastA as A, lastB as B, lastC as C)); }
    controller = StreamController<T>(onListen: () {
      a.listen((v) { lastA = v; hasA = true; update(); });
      b.listen((v) { lastB = v; hasB = true; update(); });
      c.listen((v) { lastC = v; hasC = true; update(); });
    });
    return controller.stream;
  }
}
