import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:voteguard/models/election_model.dart';
import 'package:voteguard/services/time_service.dart';
import 'package:voteguard/services/export_service.dart';
import 'package:voteguard/features/auth/ui/login_screen.dart';
import 'package:voteguard/features/profile/ui/profile_screen.dart';
import 'package:voteguard/services/geo_service.dart';
import 'package:voteguard/services/auth_service.dart';
import 'package:voteguard/services/sync_service.dart';
import 'package:voteguard/data/local/app_database.dart' as db;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ElectionGalleryScreen extends StatefulWidget {
  const ElectionGalleryScreen({super.key});

  @override
  State<ElectionGalleryScreen> createState() => _ElectionGalleryScreenState();
}

class _ElectionGalleryScreenState extends State<ElectionGalleryScreen>
    with SingleTickerProviderStateMixin {
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
  String? _userSenatorialDistrict;
  String? _lastFetchedState;
  String? _lastFetchedLga;

  // Notifications State
  final _secureStorage = const FlutterSecureStorage();
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readNotificationIds = {};

  // Connectivity State
  bool _isOnline = true;
  Timer? _connectivityTimer;

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
    _checkConnectivity();
    _startConnectivityTimer();
    _updateTime();
    _loadStates();
    _fetchElections();
    _listenForElectionUpdates();
    _loadReadNotifications();
    _listenNotifications();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _electionsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReadNotifications() async {
    try {
      final data = await _secureStorage.read(key: 'read_notification_ids');
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        if (mounted) {
          setState(() {
            _readNotificationIds = decoded.map((e) => e.toString()).toSet();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading read notifications: $e');
    }
  }

  void _listenNotifications() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('push_notifications')
        .where('triggered', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _notifications = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList();
          });
        }
      },
      onError: (e) {
        debugPrint('Notifications listen error (check Firestore rules): $e');
      },
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_readNotificationIds.contains(notificationId)) return;
    setState(() {
      _readNotificationIds.add(notificationId);
    });
    try {
      await _secureStorage.write(
        key: 'read_notification_ids',
        value: jsonEncode(_readNotificationIds.toList()),
      );
    } catch (e) {
      debugPrint('Error saving read notifications: $e');
    }
  }

  Future<void> _markAllAsRead(List<String> notificationIds) async {
    setState(() {
      _readNotificationIds.addAll(notificationIds);
    });
    try {
      await _secureStorage.write(
        key: 'read_notification_ids',
        value: jsonEncode(_readNotificationIds.toList()),
      );
    } catch (e) {
      debugPrint('Error saving read notifications: $e');
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  void _showNotificationDetail(Map<String, dynamic> n) {
    final priority = n['priority']?.toString().toLowerCase() ?? 'normal';
    final isUrgent = priority == 'urgent';
    final createdAt = n['createdAt'] as Timestamp?;

    Color iconBgColor = const Color(0xFFECFDF5);
    Color iconColor = const Color(0xFF10B981);
    IconData iconData = LucideIcons.bell;

    if (isUrgent) {
      iconBgColor = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFEF4444);
      iconData = LucideIcons.circleAlert;
    } else if (priority == 'warning') {
      iconBgColor = const Color(0xFFFFFBEB);
      iconColor = const Color(0xFFF59E0B);
      iconData = LucideIcons.info;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                n['title']?.toString() ?? 'Notification',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  DateFormat('MMMM d, yyyy • h:mm a').format(createdAt.toDate()),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  n['body']?.toString() ?? '',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF475569),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'CLOSE',
              style: GoogleFonts.outfit(
                color: const Color(0xFF065F46),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsBottomSheet(List<Map<String, dynamic>> filteredNotifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final unreadCount = filteredNotifications.where((n) => !_readNotificationIds.contains(n['id'])).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            if (unreadCount > 0)
                              Text(
                                '$unreadCount unread',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        if (unreadCount > 0)
                          TextButton.icon(
                            icon: const Icon(LucideIcons.checkCheck, size: 16, color: Color(0xFF065F46)),
                            label: Text(
                              'Mark all as read',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF065F46),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              final unreadIds = filteredNotifications
                                  .where((n) => !_readNotificationIds.contains(n['id']))
                                  .map((n) => n['id'] as String)
                                  .toList();
                              await _markAllAsRead(unreadIds);
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: filteredNotifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.bellOff,
                                    color: Color(0xFF94A3B8),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications yet',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'We\'ll notify you when updates are available.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filteredNotifications.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final n = filteredNotifications[index];
                              final isRead = _readNotificationIds.contains(n['id']);
                              final priority = n['priority']?.toString().toLowerCase() ?? 'normal';
                              final isUrgent = priority == 'urgent';
                              final createdAt = n['createdAt'] as Timestamp?;
                              
                              Color leftBorderColor = const Color(0xFF10B981);
                              Color iconBgColor = const Color(0xFFECFDF5);
                              Color iconColor = const Color(0xFF10B981);
                              IconData iconData = LucideIcons.bell;

                              if (isUrgent) {
                                leftBorderColor = const Color(0xFFEF4444);
                                iconBgColor = const Color(0xFFFEF2F2);
                                iconColor = const Color(0xFFEF4444);
                                iconData = LucideIcons.circleAlert;
                              } else if (priority == 'warning') {
                                leftBorderColor = const Color(0xFFF59E0B);
                                iconBgColor = const Color(0xFFFFFBEB);
                                iconColor = const Color(0xFFF59E0B);
                                iconData = LucideIcons.info;
                              }

                              return InkWell(
                                onTap: () {
                                  _markAsRead(n['id']);
                                  setModalState(() {});
                                  setState(() {});
                                  _showNotificationDetail(n);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.white : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0).withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            width: 5,
                                            color: leftBorderColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: iconBgColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(iconData, color: iconColor, size: 18),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                n['title']?.toString() ?? 'Notification',
                                                                style: GoogleFonts.outfit(
                                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                                  fontSize: 14,
                                                                  color: const Color(0xFF1E293B),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              _formatTime(createdAt),
                                                              style: GoogleFonts.outfit(
                                                                fontSize: 11,
                                                                color: const Color(0xFF94A3B8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          n['body']?.toString() ?? '',
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 13,
                                                            color: const Color(0xFF64748B),
                                                            height: 1.3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 14, left: 6),
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF10B981),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startConnectivityTimer() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final isNowOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != isNowOnline) {
        setState(() => _isOnline = isNowOnline);
      }
    } catch (_) {
      if (mounted && _isOnline) {
        setState(() => _isOnline = false);
      }
    }
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
      await _updateTime(); // Ensure we have the latest time for filtering
      final snapshot =
          await FirebaseFirestore.instance.collection('elections').get();
      final fetched = snapshot.docs
          .map((d) => Election.fromFirestore(d.data(), d.id))
          .toList();

      // Background Sync to Local DB
      final syncService = SyncService(context.read<db.AppDatabase>());
      syncService.syncAllData(); // Trigger full sync (parties + elections)

      if (mounted) {
        setState(() {
          _elections = fetched;
          _isLoadingElections = false;
        });
      }
    } catch (e) {
      debugPrint(
          "ElectionGallery: Network fetch failed, falling back to local storage: $e");
      final localElections =
          await context.read<db.AppDatabase>().getAllLocalElections();

      if (mounted) {
        setState(() {
          _elections = localElections.map<Election>((le) {
            Map<String, dynamic> metadata = {};
            if (le.metadataJson != null) {
              try {
                metadata = jsonDecode(le.metadataJson!);
              } catch (_) {}
            }
            return Election(
              id: le.id,
              name: le.name,
              type: le.type,
              startDate: le.startDate,
              endDate: le.endDate,
              status: le.status,
              states: (metadata['state'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              lgas: (metadata['lga'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              wards: (metadata['ward'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              senatorialDistricts:
                  (metadata['senatorialDistricts'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
              primaryParty: metadata['primaryParty']?.toString(),
              primaryElectionType: metadata['primaryElectionType']?.toString(),
              aspirants: (metadata['aspirants'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e))
                      .toList() ??
                  [],
            );
          }).toList();
          _isLoadingElections = false;
        });
      }
    }
  }

  void _listenForElectionUpdates() {
    _electionsSubscription = FirebaseFirestore.instance
        .collection('elections')
        .snapshots()
        .listen((snapshot) {
      if (_isFirstSnapshot) {
        _isFirstSnapshot = false;
        return;
      }
      if (snapshot.docChanges.isNotEmpty) {
        if (mounted) {
          _fetchElections(); // Automatically fetch the latest data
        }
      }
    });
  }

  Future<void> _fetchUserSenatorialDistrict(String state, String lga) async {
    if (state.isEmpty || lga.isEmpty) return;
    try {
      // 1. Query flexible state & name
      final q = await FirebaseFirestore.instance
          .collection('lgas')
          .where('state', isEqualTo: state)
          .where('name', isEqualTo: lga)
          .get();
      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final district = data['senatorialDistrict']?.toString() ??
            data['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
          return;
        }
      }

      // 2. Secondary fallback direct document ID lookup
      final docId = '${state}_$lga';
      final docSnap =
          await FirebaseFirestore.instance.collection('lgas').doc(docId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        final district = data?['senatorialDistrict']?.toString() ??
            data?['senatorial_district']?.toString();
        if (district != null && mounted) {
          setState(() {
            _userSenatorialDistrict = district;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user senatorial district: $e");
    }
  }

  Stream<DocumentSnapshot> get _userStream {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid ?? 'none')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, userSnapshot) {
          final userProfile =
              userSnapshot.data?.data() as Map<String, dynamic>?;

          if (userProfile != null) {
            final state = userProfile['assignedState']?.toString() ??
                userProfile['state']?.toString() ??
                '';
            final lga = userProfile['assignedLga']?.toString() ??
                userProfile['lga']?.toString() ??
                '';
            if (state.isNotEmpty &&
                lga.isNotEmpty &&
                (state != _lastFetchedState || lga != _lastFetchedLga)) {
              _lastFetchedState = state;
              _lastFetchedLga = lga;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchUserSenatorialDistrict(state, lga);
              });
            }
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: RefreshIndicator(
              onRefresh: _fetchElections,
              color: const Color(0xFF065F46),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildAppBar(userProfile),
                  // Dynamic Connectivity Status Banner
                  SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isOnline
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOnline ? LucideIcons.wifi : LucideIcons.wifiOff,
                            color: _isOnline
                                ? const Color(0xFF059669)
                                : const Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isOnline
                                  ? 'NETWORK STABLE'
                                  : 'OFFLINE MODE (LOCAL DATABASE READY)',
                              style: GoogleFonts.outfit(
                                color: _isOnline
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF991B1B),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Removed manual refresh banner widget
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
        });
  }

  Widget _buildAppBar(Map<String, dynamic>? profile) {
    final hasImg = profile?['profilePictureUrl'] != null;
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.logOut, color: Color(0xFF1E293B)),
        onPressed: () => _showLogoutConfirmation(),
      ),
      title: Text(
        'ELECTION GALLERY',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1E293B),
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        Builder(
          builder: (context) {
            // Filter notifications for this user based on their role from profile
            final userRole = profile?['role']?.toString() ?? '';
            final filteredNotifications = _notifications.where((n) {
              final targetRoles = (n['targetRoles'] as List<dynamic>?) ?? [];
              // Show if targetRoles is empty (broadcast) or includes the user's role
              return targetRoles.isEmpty ||
                  targetRoles.any((r) => r.toString() == userRole);
            }).toList();
            // Sort newest first
            filteredNotifications.sort((a, b) {
              final aTs = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTs = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bTs.compareTo(aTs);
            });
            final unreadCount = filteredNotifications
                .where((n) => !_readNotificationIds.contains(n['id']))
                .length;

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.bell,
                      size: 22, color: Color(0xFF1E293B)),
                  onPressed: () => _showNotificationsBottomSheet(filteredNotifications),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: unreadCount > 9 ? 18 : 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 8),
          child: GestureDetector(
            onTap: () {
              if (profile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userProfile: profile),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1E293B),
              child: hasImg
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: profile!['profilePictureUrl'].toString(),
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white70),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                            LucideIcons.user,
                            size: 16,
                            color: Colors.white),
                      ),
                    )
                  : const Icon(LucideIcons.user, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout Confirmation',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        content: Text('Are you sure you want to log out of VoteGuard?',
            style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('LOGOUT',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCenterHeader(Map<String, dynamic>? profile) {
    final rawRole = profile?['role']?.toString() ?? '';
    final role = rawRole.toLowerCase();
    final isDiocesan = ['diocesan_director', 'diocesan_project_manager', 'diocesan_coordinator'].contains(role);
    final isProvincial = ['provincial_director', 'provincial_project_manager', 'provincial_secretary'].contains(role);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20), // Reduced from 32
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(32), // Reduced from 40
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10)),
                child: const Icon(LucideIcons.layoutGrid,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OBSERVER COMMAND CENTER',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                    const SizedBox(height: 2),
                    Text('ROLE: ${(profile?['role']?.toString() ?? 'OBSERVER').toUpperCase()}',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF6EE7B7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    if (isDiocesan && profile?['assignedDiocese'] != null) ...[
                      const SizedBox(height: 2),
                      Text('DIOCESE: ${profile!['assignedDiocese'].toString().toUpperCase()}',
                          style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ],
                    if (isProvincial && profile?['assignedProvince'] != null) ...[
                      const SizedBox(height: 2),
                      Text('PROVINCE: ${profile!['assignedProvince'].toString().toUpperCase()}',
                          style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
              _isEditingAssignment
                  ? 'Update your Polling Location'
                  : 'Choose an Election to\nStart Observing',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  letterSpacing: -0.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mapPin,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'SELECT YOUR POLLING UNIT',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                        onPressed: () {
                          if (_isEditingAssignment) {
                            setState(() => _isEditingAssignment = false);
                          } else {
                            setState(() => _isEditingAssignment = true);
                            if (_states.isEmpty) _loadStates();
                          }
                        },
                        child: Text(_isEditingAssignment ? 'CANCEL' : 'CHANGE UNIT',
                            style: GoogleFonts.outfit(
                                color: _isEditingAssignment ? Colors.white70 : const Color(0xFF6EE7B7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold))),
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
                      _buildAssignmentItem(
                          'STATE', profile?['assignedState'] ?? 'N/A'),
                      _buildAssignmentItem(
                          'LGA', profile?['assignedLga'] ?? 'N/A'),
                      _buildAssignmentItem(
                          'WARD', profile?['assignedWard'] ?? 'N/A'),
                      _buildAssignmentItem('POLLING UNIT',
                          profile?['assignedPollingUnit'] ?? 'N/A'),
                      if (isDiocesan)
                        _buildAssignmentItem('DIOCESE',
                            profile?['assignedDiocese'] ?? 'N/A'),
                      if (isProvincial)
                        _buildAssignmentItem('PROVINCE',
                            profile?['assignedProvince'] ?? 'N/A'),
                    ],
                  ),
                ] else ...[
                  if (_states.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                              color: Colors.white70),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _loadStates,
                              child: Text('RETRY LOADING',
                                  style: GoogleFonts.outfit(
                                      color: const Color(0xFF6EE7B7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                    )
                  else
                    _buildGeoDropdown('Select State', _states, _selectedState,
                        (v) async {
                      setState(() {
                        _selectedState = v;
                        _selectedLga = null;
                        _selectedWard = null;
                        _selectedPU = null;
                      });
                      final lgas = await _geoService.getLGAs(v!);
                      setState(() => _lgas = lgas.map((e) => e.name).toList());
                    }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select LGA', _lgas, _selectedLga,
                      (v) async {
                    setState(() {
                      _selectedLga = v;
                      _selectedWard = null;
                      _selectedPU = null;
                    });
                    final wards =
                        await _geoService.getWards(_selectedState!, v!);
                    setState(() => _wards = wards.map((e) => e.name).toList());
                  }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select Ward', _wards, _selectedWard,
                      (v) async {
                    setState(() {
                      _selectedWard = v;
                      _selectedPU = null;
                    });
                    final pus = await _geoService.getPollingUnits(
                        _selectedState!, _selectedLga!, v!);
                    setState(() => _pus = pus.map((e) => e.name).toList());
                  }),
                  const SizedBox(height: 12),
                  _buildGeoDropdown('Select Polling Unit', _pus, _selectedPU,
                      (v) => setState(() => _selectedPU = v)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAssignment,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE LOCATION',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(LucideIcons.circleCheck,
                        color: Color(0xFF6EE7B7), size: 14),
                    const SizedBox(width: 8),
                    Text('LOCATION VERIFIED',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF6EE7B7),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1))
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeoDropdown(String hint, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    // Deduplicate items to prevent duplicate DropdownMenuItem values crash
    final uniqueItems = items.toSet().toList();

    // Ensure the current value is strictly present in the deduplicated items list
    final String? safeValue =
        (value != null && uniqueItems.contains(value)) ? value : null;

    debugPrint(
        "Dropdown: $hint has ${uniqueItems.length} unique items. Current value: $value, Safe value: $safeValue");
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: Text(hint,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          isExpanded: true,
          dropdownColor: const Color(0xFF064E3B),
          icon: const Icon(LucideIcons.chevronDown,
              color: Colors.white70, size: 16),
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          items: uniqueItems
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    if (_selectedState == null ||
        _selectedLga == null ||
        _selectedWard == null ||
        _selectedPU == null) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
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
        Text(label,
            style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.5),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value.toString().toUpperCase(),
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildYourElectionsTitle() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('YOUR ELECTIONS',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                  letterSpacing: 0.5)),
          const Icon(LucideIcons.listFilter, size: 18, color: Color(0xFF64748B))
        ]));
  }

  Widget _buildTabsHeader() {
    return SliverPersistentHeader(
        pinned: true,
        delegate: _SliverAppBarDelegate(TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: const Color(0xFF065F46),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF065F46),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
            tabs: const [
              Tab(text: 'ACTIVE'),
              Tab(text: 'UPCOMING'),
              Tab(text: 'COMPLETED')
            ])));
  }

  Widget _buildElectionsList(Map<String, dynamic>? profile) {
    if (_isLoadingElections)
      return const SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF065F46))));
    final filtered =
        _getFilteredElections(_elections, _activeTabIndex, profile);
    if (filtered.isEmpty)
      return SliverFillRemaining(
          child: Center(
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
            Icon(LucideIcons.calendar, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No elections found.',
                style: TextStyle(color: Colors.grey[500]))
          ]))));
    return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                (context, index) => _buildGalleryCard(filtered[index], profile,
                    isCompleted: _activeTabIndex == 2),
                childCount: filtered.length)));
  }

  List<Election> _getFilteredElections(
      List<Election> all, int tabIndex, Map<String, dynamic>? profile) {
    final now = _currentWAT;
    final observerState = profile?['assignedState']?.toString();
    final observerLga = profile?['assignedLga']?.toString();
    final observerWard = profile?['assignedWard']?.toString();

    return all.where((e) {
      if (e.startDate == null) return false;

      bool isVisible = false;
      bool matchGeographic(List<String> targets, String? value) {
        if (value == null || value.trim().isEmpty) return false;
        final normalizedValue = value.trim().toUpperCase();
        return targets.any((t) {
          final normalizedTarget = t.trim().toUpperCase();
          return normalizedTarget == normalizedValue ||
              normalizedTarget.contains(normalizedValue);
        });
      }

      final rawType = e.type.toUpperCase();

      if (rawType == 'PRESIDENTIAL') {
        isVisible = true;
      } else if (rawType == 'GOVERNORSHIP') {
        isVisible = matchGeographic(e.states, observerState);
      } else if (rawType == 'SENATORIAL') {
        if (_userSenatorialDistrict == null) {
          isVisible = false;
        } else {
          isVisible =
              matchGeographic(e.senatorialDistricts, _userSenatorialDistrict);
        }
      } else if (rawType == 'HOUSE_OF_REPRESENTATIVES' ||
          rawType == 'LOCAL_GOVERNMENT') {
        isVisible = matchGeographic(e.lgas, observerLga);
      } else if (rawType == 'STATE_HOUSE_OF_ASSEMBLY') {
        if (e.wards.isNotEmpty) {
          isVisible = matchGeographic(e.wards, observerWard);
        } else {
          isVisible = matchGeographic(e.lgas, observerLga);
        }
      } else if (rawType == 'COUNCILLOR') {
        isVisible = matchGeographic(e.wards, observerWard);
      } else if (rawType == 'PARTY_PRIMARIES') {
        if (e.wards.isNotEmpty) {
          isVisible = matchGeographic(e.wards, observerWard);
        } else if (e.lgas.isNotEmpty) {
          isVisible = matchGeographic(e.lgas, observerLga);
        } else if (e.states.isNotEmpty) {
          isVisible = matchGeographic(e.states, observerState);
        } else {
          isVisible = true;
        }
      } else {
        // Fallback for any other type
        if (rawType.contains('PRESIDENTIAL') || rawType.contains('GENERAL')) {
          isVisible = true;
        } else if (rawType.contains('GOVERNOR')) {
          isVisible = matchGeographic(e.states, observerState);
        } else if (rawType.contains('SENATE') ||
            rawType.contains('SENATORIAL')) {
          isVisible = _userSenatorialDistrict != null &&
              matchGeographic(e.senatorialDistricts, _userSenatorialDistrict);
        } else if (rawType.contains('REPRESENTATIVE') ||
            rawType.contains('REPS') ||
            rawType.contains('LGA') ||
            rawType.contains('LOCAL GOVERNMENT')) {
          isVisible = matchGeographic(e.lgas, observerLga);
        } else if (rawType.contains('STATE ASSEMBLY') ||
            rawType.contains('HOUSE OF ASSEMBLY') ||
            rawType.contains('STATE HOUSE')) {
          if (e.wards.isNotEmpty) {
            isVisible = matchGeographic(e.wards, observerWard);
          } else {
            isVisible = matchGeographic(e.lgas, observerLga);
          }
        } else if (rawType.contains('COUNCILLOR')) {
          isVisible = matchGeographic(e.wards, observerWard);
        } else {
          // Defensive fallback
          if (e.wards.isNotEmpty) {
            isVisible = matchGeographic(e.wards, observerWard);
          } else if (e.lgas.isNotEmpty) {
            isVisible = matchGeographic(e.lgas, observerLga);
          } else if (e.states.isNotEmpty) {
            isVisible = matchGeographic(e.states, observerState);
          } else {
            isVisible = true;
          }
        }
      }

      if (!isVisible) return false;

      final start = e.startDate!;
      final end = e.endDate ?? start;

      // If time is not specified (midnight), treat end date as inclusive of that entire day
      final effectiveEnd = (end.hour == 0 && end.minute == 0)
          ? end.add(const Duration(days: 1))
          : end;

      if (tabIndex == 0) {
        // ACTIVE: current time is within the [startDate, effectiveEnd) window
        return !now.isBefore(start) && now.isBefore(effectiveEnd);
      }

      if (tabIndex == 1) {
        // UPCOMING: startDate is in the future
        return now.isBefore(start);
      }

      // COMPLETED: effectiveEnd has passed.
      // Elections stay in this tab forever for historical access/downloads.
      return !now.isBefore(effectiveEnd);
    }).toList();
  }

  String formatElectionDate(DateTime? dt) {
    if (dt == null) return 'TBA';
    final datePart = DateFormat('MMM d, yyyy').format(dt);
    final timePart = DateFormat('h:mm a').format(dt);
    return '$datePart • $timePart';
  }

  Widget _buildGalleryCard(Election election, Map<String, dynamic>? profile,
      {bool isCompleted = false}) {
    final statusLabel = _activeTabIndex == 0
        ? 'ACTIVE ELECTION'
        : (_activeTabIndex == 1 ? 'UPCOMING ELECTION' : 'COMPLETED ELECTION');
    final statusBgColor = _activeTabIndex == 0
        ? const Color(0xFFECFDF5)
        : (_activeTabIndex == 1
            ? const Color(0xFFF0F9FF)
            : const Color(0xFFF8FAFC));
    final statusTextColor = _activeTabIndex == 0
        ? const Color(0xFF047857)
        : (_activeTabIndex == 1
            ? const Color(0xFF0284C7)
            : const Color(0xFF64748B));

    final String startDateText = formatElectionDate(election.startDate);
    final String endDateText =
        formatElectionDate(election.endDate ?? election.startDate);

    return _buildElectionStatsWrapper(election, profile, (stats) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered Top Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                LucideIcons.briefcase,
                size: 36,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.outfit(
                  color: statusTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Election Title
            Text(
              election.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Location Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    (profile?['assignedPollingUnit']?.toString() ??
                            'ARAE FI/ (V.I.O) F.C.D.A. OFFICE')
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Start Datetime Item
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.calendar,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START DATETIME',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      startDateText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End Datetime Item
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.clock,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'END DATETIME',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      endDateText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Action Button Row
            Row(
              children: [
                // Download button (Only visible on Completed tab card)
                if (_activeTabIndex == 2) ...[
                  GestureDetector(
                    onTap: () => _showReportArchive(election, stats, profile),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(LucideIcons.download,
                          size: 20, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                Expanded(
                  child: _buildActionButton(election, stats, profile),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton(Election election, Map<String, dynamic> stats,
      Map<String, dynamic>? profile) {
    if (_activeTabIndex == 1) {
      // Upcoming tab: locked to prevent accessing forms
      return SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    const Icon(LucideIcons.lock, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 12),
                    Text('Election Upcoming',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            fontSize: 18)),
                  ],
                ),
                content: Text(
                  'This election has not started yet. You will be able to access the observation forms and report details starting on ${formatElectionDate(election.startDate)}.',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B), fontSize: 14),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF064E3B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('OK',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF94A3B8).withOpacity(0.2),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LOCKED UNTIL START',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.lock, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      );
    }

    if (_activeTabIndex == 2) {
      // Completed tab: check grace period
      final ref = election.endDate ?? election.startDate;
      final withinGrace =
          ref == null || _currentWAT.difference(ref).inHours < 48;

      if (!withinGrace) {
        // Locked
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.lock, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Text(
                'REPORTING CLOSED',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      }
    }

    // Active tab or within grace Completed tab
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(
          context,
          '/observer/dashboard',
          arguments: election.id,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF064E3B),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'VIEW DETAILS',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildChipBadge(String label, Color bg, Color text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: text,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1)));
  Widget _buildInlineInfo(IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFF10B981)),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label.toUpperCase(),
                style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis))
      ]);
  Widget _buildStatusChip(String label, bool active) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.check,
            size: 10,
            color: active ? const Color(0xFF10B981) : Colors.grey[300]),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: GoogleFonts.outfit(
                    color: active ? const Color(0xFF065F46) : Colors.grey[400],
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis))
      ]));

  Widget _buildIconInfo(IconData icon, String label) => Row(children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontWeight: FontWeight.w600))
      ]);

  Widget _buildElectionStatsWrapper(
      Election election,
      Map<String, dynamic>? profile,
      Widget Function(Map<String, dynamic>) builder) {
    final user = FirebaseAuth.instance.currentUser;
    final state = profile?['assignedState'] ?? '';
    final lga = profile?['assignedLga'] ?? '';
    final ward = profile?['assignedWard'] ?? '';
    final pu = profile?['assignedPollingUnit'] ?? '';

    if (state.isEmpty || lga.isEmpty || ward.isEmpty || pu.isEmpty) {
      return builder({'checklist': false, 'incidents': 0, 'result': false});
    }

    final puKey = '${state}_${lga}_${ward}_$pu'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final docId = '${election.id}_$puKey';

    return StreamBuilder<List<dynamic>>(
        stream: Rx.combineLatest3(
            FirebaseFirestore.instance
                .collection('observer_checklists')
                .where('electionId', isEqualTo: election.id)
                .where('observerId', isEqualTo: user?.uid)
                .snapshots(),
            FirebaseFirestore.instance
                .collection('incident_reports')
                .where('electionId', isEqualTo: election.id)
                .where('observerId', isEqualTo: user?.uid)
                .snapshots(),
            FirebaseFirestore.instance
                .collection('election_results')
                .doc(docId)
                .snapshots(), (check, inc, resSnap) {
          bool hasSubmittedResult = false;
          if (resSnap.exists && resSnap.data() != null) {
            final data = resSnap.data()!;
            final submissionsList = data['submissions'] as List<dynamic>? ?? [];
            hasSubmittedResult = submissionsList.any(
                (s) => s['submittedBy'] == user?.uid && s['status'] == 'final');
          }
          return [check.docs.length, inc.docs.length, hasSubmittedResult];
        }),
        builder: (context, snapshot) {
          final data = snapshot.data ?? [0, 0, false];
          return builder({
            'checklist': data[0] > 0,
            'incidents': data[1],
            'result': data[2]
          });
        });
  }

  void _showReportArchive(Election election, Map<String, dynamic> stats,
      Map<String, dynamic>? profile) {
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
                    .limit(1)
                    .get();
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
                    await ExportService()
                        .exportIncidentReport(election, incidents);
                  } else {
                    await ExportService()
                        .exportIncidentExcel(election, incidents);
                  }
                }
              } else if (type == 'result_pdf' || type == 'result_excel') {
                final state = profile?['assignedState'] ?? '';
                final lga = profile?['assignedLga'] ?? '';
                final ward = profile?['assignedWard'] ?? '';
                final pu = profile?['assignedPollingUnit'] ?? '';
                final puKey = '${state}_${lga}_${ward}_$pu'
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                    .replaceAll(RegExp(r'^_+|_+$'), '');
                final docId = '${election.id}_$puKey';

                final snap = await FirebaseFirestore.instance
                    .collection('election_results')
                    .doc(docId)
                    .get();
                if (snap.exists && snap.data() != null) {
                  final data = snap.data()!;
                  final submissionsList =
                      data['submissions'] as List<dynamic>? ?? [];
                  final sub = submissionsList.firstWhere(
                    (s) => s['submittedBy'] == user?.uid,
                    orElse: () => null,
                  );
                  if (sub != null) {
                    await ExportService().exportResultReport(
                        election, Map<String, dynamic>.from(sub));
                  }
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Colors.red),
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
                            Text('Report Archive',
                                style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Text('Download your submitted election data.',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(LucideIcons.x,
                            size: 22, color: Color(0xFF64748B)),
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
                    child: Text('CLOSE ARCHIVE',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF64748B),
                            letterSpacing: 1)),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isReady
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 20,
                      color: isReady
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Text(isReady ? 'Ready for archive' : 'Not yet submitted',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isReady
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
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

  Widget _buildExportBtn(
      {required String label,
      required IconData icon,
      required bool isLoading,
      required bool isDisabled,
      VoidCallback? onTap}) {
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
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF10B981)))
            else
              Icon(icon,
                  size: 16,
                  color: isDisabled
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF1E293B)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDisabled
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: label == 'ACTIVE'
              ? const Color(0xFFECFDF5)
              : (label == 'UPCOMING'
                  ? const Color(0xFFF0F9FF)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: label == 'ACTIVE'
                  ? const Color(0xFF065F46)
                  : (label == 'UPCOMING'
                      ? const Color(0xFF0369A1)
                      : const Color(0xFF64748B)),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)));
  Widget _buildMiniBadge(String label, Color color, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold))
      ]));
  Widget _buildCompletedTag(String label, bool done) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: done ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: done ? const Color(0xFF065F46) : Colors.grey)));
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: _tabBar);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class Rx {
  static Stream<T> combineLatest3<A, B, C, T>(
      Stream<A> a, Stream<B> b, Stream<C> c, T Function(A, B, C) combiner) {
    late StreamController<T> controller;
    A? lastA;
    B? lastB;
    C? lastC;
    bool hasA = false, hasB = false, hasC = false;
    void update() {
      if (hasA && hasB && hasC)
        controller.add(combiner(lastA as A, lastB as B, lastC as C));
    }

    controller = StreamController<T>(onListen: () {
      a.listen((v) {
        lastA = v;
        hasA = true;
        update();
      });
      b.listen((v) {
        lastB = v;
        hasB = true;
        update();
      });
      c.listen((v) {
        lastC = v;
        hasC = true;
        update();
      });
    });
    return controller.stream;
  }
}
