import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _activeTabIndex = 0; // 0: Overview & Impact, 1: Team & Credits (Module Explorer commented out)
  bool _isLoading = true;

  // Search & Filter state for Tab 2 (Commented out)
  // String _moduleSearchQuery = '';
  // String _selectedCategory = 'All';

  // Live Stats from Firebase
  String _jurisdictions = '36 + FCT';
  // String _activeObservers = '50'; // Commented out
  String _pollingUnits = '176,846';
  // String _submissionsScanned = '15'; // Commented out

  // Dynamic Config with robust defaults mirroring web
  Map<String, dynamic> _config = {
    'header': {
      'title': 'VoteGuard Workspace Portal',
      'description':
          'A secure multi-tier platform driving real-time election observation, field telemetry, incident tracking, and analytical verification workflows in one unified environment.',
      'badges': [
        'AUTOMATIC RESULTS VERIFICATION',
        'DYNAMIC INCIDENT MAPPING',
        'OFFLINE-FIRST CAPTURE',
        'MULTI-TIER CONSENSUS',
      ],
      'version': 'V8.0.0',
    },
    'stats': {
      'statesCovered': '36 + FCT',
      'activeObservers': '50',
      'verifiedPollingUnits': '176,846',
      'totalValidVotes': '15',
    },
    'overview': {
      'purpose':
          'VoteGuard is a custom-built election observation and data intelligence platform designed to track, verify, and archive polling unit data (Checklist, Incident Report, Election Results) in real-time, empowering coordination teams with clean, verified telemetry.',
      'evolution':
          'VoteGuard was first launched in 2023 as the Caritas/JDPC ElectionApp, a localized digital platform aimed at enhancing electoral observation by coordinating field observers and citizen participation. Conceived as a practical solution for collecting and transmitting information from polling units, the platform initially focused on basic reporting, communication, and incident documentation through an Excel spreadsheet. This enabled observers to capture developments in real-time and contribute to greater transparency throughout the electoral process. As the Nigerian political landscape grew more complex, the platform went through a significant technological and operational transformation, from a simple reporting tool into a comprehensive election-observation system capable of supporting large-scale observation missions and political analysis based on pre-election activities like party primaries. Legacy reporting mechanisms were replaced with a modern, high-performance frontend and backend architecture designed to improve reliability, scalability, and user experience. These enhancements strengthened the platform\'s capacity for data collection, validation, analysis, and visualization, enabling stakeholders to access timely and actionable information. VoteGuard now supports real-time election tracking, faster incident reporting, observer deployment management, and enhanced situational awareness across multiple locations. By reducing reporting delays and improving data integrity, the platform has become an important tool for promoting transparency, accountability, credibility, integrity, and public confidence in electoral processes. It also fosters broader collaboration among election observers, civil society organisations, and other political and democratic stakeholders.',
    },
    'focusAreas': [
      {
        'title': 'DATA INTEGRITY',
        'description':
            'Ensuring every results sheet (Form EC8A) uploaded by field observers is verified against INEC IReV Results and cross-checked for any difference.',
        'icon': 'shieldCheck',
      },
      {
        'title': 'FIELD COORDINATION',
        'description':
            'Enabling regional, state, LGA, and ward coordinators to manage assigned observers and track questionnaire compliance.',
        'icon': 'users',
      },
      {
        'title': 'SITUATION ROOM MAP',
        'description':
            'Dynamic mapping of polling station coordinates, color-coded by submission status and security alerts.',
        'icon': 'mapPin',
      },
      {
        'title': 'PUBLIC TRANSPARENCY',
        'description':
            'Read-only public results portal displaying live vote shares and reporting progress to the general public.',
        'icon': 'globe',
      },
      {
        'title': 'COMMUNICATIONS',
        'description':
            'Hierarchical secure messaging channels between field observers and regional command centers.',
        'icon': 'messageSquare',
      },
      {
        'title': 'QUANTITATIVE ANALYTICS',
        'description':
            'Consolidated statistical reporting and checklist questionnaire trends across all jurisdictions.',
        'icon': 'barChart3',
      },
    ],
    'modules': [
      {
        'title': 'User & Observer Management',
        'category': 'Admin & Security',
        'description':
            'Manage profiles, roles, and geographical boundaries for observers and coordinators.',
      },
      {
        'title': 'Situation Room Map',
        'category': 'Operations & Fleet',
        'description':
            'Real-time interactive map plotting observer submissions and urgent incidents.',
      },
      {
        'title': 'Live Election Dashboard',
        'category': 'Operations & Fleet',
        'description':
            'Live charts and tables comparing party vote tallies as they stream from the field.',
      },
      {
        'title': 'Result Dispute Queue',
        'category': 'Admin & Security',
        'description':
            'Administrative portal to review and resolve results sheets with discrepancies.',
      },
      {
        'title': 'Announcements Broadcast',
        'category': 'Collaboration & Projects',
        'description':
            'Publish and target official bulletins and notices to observers in specific states.',
      },
      {
        'title': 'Audit Logs Registry',
        'category': 'Admin & Security',
        'description':
            'Tamper-proof event logs recording every configuration modification and approval.',
      },
      {
        'title': 'Offline-First Form Sync',
        'category': 'Operations & Fleet',
        'description':
            'Edge storage and background queue syncing for zero-connectivity polling unit reporting.',
      },
      {
        'title': 'Biometric Observer Deduplication',
        'category': 'Admin & Security',
        'description':
            'Facial embeddings and liveness verification preventing duplicate registrations.',
      },
    ],
    'team': [
      {
        'name': 'Rev. Fr. Zacharia Nyantiso',
        'role': 'Executive Sponsor / Director',
        'quote':
            'Our mission is to establish a secure, reliable, and transparent record of electoral telemetry that preserves truth and fosters trust across the nation.',
        'description':
            'Oversees the strategic direction and partnerships of the VoteGuard program, ensuring alignment with institutional objectives.',
      },
      {
        'name': 'Tega Okoh',
        'role': 'Technical Program Manager',
        'quote':
            'Building a system that operates seamlessly under low-connectivity constraints requires a deep commitment to edge-first database design and optimization.',
        'description':
            'Coordinates between regional representatives and development teams to ensure software deployment matches field requirements.',
      },
      {
        'name': 'Emmanuel Vegher',
        'role': 'Technical Lead & Engineering Lead',
        'quote':
            'Scaling database query performance for thousands of simultaneous writes during peak election hours requires tight, indexed database design and caching.',
        'description':
            'Architected the distributed data layers, real-time sync pipelines, and edge-first telemetry systems.',
      },
    ],
    'links': {
      'workspace': 'https://voteguard.com.ng',
      'glass': 'https://voteguard.com.ng/live-results',
      'website': 'https://csn.org',
    },
    'footer': {
      'address':
          'CATHOLIC SECRETARIAT OF NIGERIA, PLOT 459 CADASTRAL ZONE B2, DURUMI, ABUJA, NIGERIA',
      'email': 'INFO@CSN.ORG',
      'phone': '+234 9 0000 0000',
      'supportHelpdesk': 'EMMANUEL VEGHER — TECHNICAL LEAD',
      'supportHelpdeskEmail': 'support@voteguard.com.ng',
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchFirebaseLiveRecords();
  }

  Future<void> _fetchFirebaseLiveRecords() async {
    try {
      // 1. Fetch about_page_config from Firestore settings collection if accessible
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('about_page_config')
            .get();

        if (settingsDoc.exists && settingsDoc.data() != null) {
          final data = settingsDoc.data()!;
          Map<String, dynamic>? parsed;
          if (data.containsKey('value')) {
            final rawVal = data['value'];
            if (rawVal is String) {
              try {
                parsed = jsonDecode(rawVal) as Map<String, dynamic>;
              } catch (_) {}
            } else if (rawVal is Map<String, dynamic>) {
              parsed = rawVal;
            }
          } else {
            parsed = data;
          }

          if (parsed != null && mounted) {
            setState(() {
              _config = {
                ..._config,
                ...parsed!,
              };
            });
          }
        }
      } catch (settingsErr) {
        debugPrint('AboutScreen: Note - settingsDoc query skipped or unreadable: $settingsErr');
      }

      /*
      // Check if user is logged in before querying authenticated collections
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 2. Query Live Observers Count (users where role == 'OBSERVER')
        try {
          final observerCountSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'OBSERVER')
              .count()
              .get();
          if (observerCountSnap.count != null && observerCountSnap.count! > 0) {
            _activeObservers = '${observerCountSnap.count}';
          }
        } catch (_) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'OBSERVER')
                .limit(500)
                .get();
            if (snap.docs.isNotEmpty) {
              _activeObservers = '${snap.docs.length}';
            }
          } catch (_) {}
        }

        // 3. Query Live Results Count (election_results)
        try {
          final resultsCountSnap = await FirebaseFirestore.instance
              .collection('election_results')
              .count()
              .get();
          if (resultsCountSnap.count != null && resultsCountSnap.count! > 0) {
            _submissionsScanned = '${resultsCountSnap.count}';
          }
        } catch (_) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('election_results')
                .limit(500)
                .get();
            if (snap.docs.isNotEmpty) {
              _submissionsScanned = '${snap.docs.length}';
            }
          } catch (_) {}
        }
      }
      */

      // Check stats override in config
      if (_config['stats'] != null) {
        final stats = _config['stats'] as Map<String, dynamic>;
        if (stats['statesCovered'] != null) {
          _jurisdictions = stats['statesCovered'].toString();
        }
        /*
        if (stats['activeObservers'] != null && currentUser == null) {
          _activeObservers = stats['activeObservers'].toString();
        }
        */
        if (stats['verifiedPollingUnits'] != null) {
          _pollingUnits = stats['verifiedPollingUnits'].toString();
        }
        /*
        if (stats['totalValidVotes'] != null && currentUser == null) {
          _submissionsScanned = stats['totalValidVotes'].toString();
        }
        */
      }
    } catch (e) {
      debugPrint('AboutScreen: Note - using default data due to offline/error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchExternalUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;

    final normalized = (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
        ? trimmed
        : 'https://$trimmed';

    try {
      final uri = Uri.parse(normalized);
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $normalized'),
            backgroundColor: const Color(0xFF8B1A1A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to open URL $normalized: $e');
      if (mounted) {
        try {
          final uri = Uri.parse(normalized);
          final fallbackLaunched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (fallbackLaunched) return;
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to launch browser for $normalized'),
            backgroundColor: const Color(0xFF8B1A1A),
          ),
        );
      }
    }
  }

  Future<bool> _launchEmail(String email, {String? subject, String? body}) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) return false;

    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    try {
      final queryParams = <String, String>{};
      if (subject != null && subject.trim().isNotEmpty) {
        queryParams['subject'] = subject.trim();
      }
      if (body != null && body.trim().isNotEmpty) {
        queryParams['body'] = body.trim();
      }

      final uri = Uri(
        scheme: 'mailto',
        path: cleanEmail,
        query: queryParams.isNotEmpty ? encodeQueryParameters(queryParams) : null,
      );

      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      return launched;
    } catch (e) {
      debugPrint('Failed to launch email $cleanEmail: $e');
      return false;
    }
  }

  void _showEmailLeadDialog(String leadName, String leadEmail) {
    final subjectController = TextEditingController(text: 'VoteGuard Technical Assistance');
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.mail, size: 18, color: Color(0xFF8B1A1A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMAIL TECHNICAL LEAD',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    leadName,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(ctx),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Recipient pill with copy button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      'TO:',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        leadEmail,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: leadEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email address copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.copy, size: 13, color: Color(0xFF8B1A1A)),
                            const SizedBox(width: 4),
                            Text(
                              'COPY',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF8B1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'SUBJECT',
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: subjectController,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'MESSAGE',
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: bodyController,
                maxLines: 4,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Describe your technical issue, credential problem, or question...',
                  hintStyle: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(LucideIcons.send, size: 13),
            label: Text(
              'SEND EMAIL',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            onPressed: () async {
              final subject = subjectController.text.trim();
              final body = bodyController.text.trim();
              final ok = await _launchEmail(leadEmail, subject: subject, body: body);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (!ok && mounted) {
                Clipboard.setData(ClipboardData(text: leadEmail));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No email app found on device. Copied $leadEmail to clipboard.'),
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFocusIcon(String iconName) {
    IconData icon;
    switch (iconName) {
      case 'shieldCheck':
      case 'ShieldCheck':
      case 'Shield':
        icon = LucideIcons.shieldCheck;
        break;
      case 'users':
      case 'Users':
        icon = LucideIcons.users;
        break;
      case 'mapPin':
      case 'MapPin':
        icon = LucideIcons.mapPin;
        break;
      case 'globe':
      case 'Globe':
        icon = LucideIcons.globe;
        break;
      case 'messageSquare':
      case 'MessageSquare':
        icon = LucideIcons.messageSquare;
        break;
      case 'barChart3':
      case 'BarChart3':
        icon = LucideIcons.chartColumnIncreasing;
        break;
      default:
        icon = LucideIcons.award;
    }
    return Icon(icon, size: 22, color: const Color(0xFF8B1A1A));
  }

  @override
  Widget build(BuildContext context) {
    /*
    final modules = List<Map<String, dynamic>>.from(_config['modules'] ?? []);
    final categories = ['All', ...{...modules.map((m) => (m['category'] ?? '').toString())}];

    final filteredModules = modules.where((m) {
      final matchesQuery = _moduleSearchQuery.isEmpty ||
          (m['title']?.toString().toLowerCase().contains(_moduleSearchQuery.toLowerCase()) ?? false) ||
          (m['description']?.toString().toLowerCase().contains(_moduleSearchQuery.toLowerCase()) ?? false);
      final matchesCat = _selectedCategory == 'All' || m['category'] == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();
    */

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B1A1A)),
                ),
              // ─── HERO HEADER SECTION ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Shield Logo in Rounded Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/voteguard_logo.png',
                        height: 48,
                        width: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          LucideIcons.shieldCheck,
                          size: 40,
                          color: Color(0xFF8B1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main Title: VOTEGUARD WORKSPACE PORTAL
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          height: 1.2,
                        ),
                        children: [
                          const TextSpan(
                            text: 'VOTE',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                          const TextSpan(
                            text: 'GUARD',
                            style: TextStyle(color: Color(0xFF8B1A1A)),
                          ),
                          const TextSpan(
                            text: ' WORKSPACE PORTAL',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Text(
                        _config['header']?['description'] ??
                            'A secure multi-tier platform driving real-time election observation, field telemetry, incident tracking, and analytical verification workflows in one unified environment.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Badges List (Matching screenshot)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildBadge('AUTOMATIC RESULTS VERIFICATION'),
                        _buildBadge('DYNAMIC INCIDENT MAPPING'),
                        _buildBadge('OFFLINE-FIRST CAPTURE'),
                        _buildBadge('MULTI-TIER CONSENSUS'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B1A1A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'RELEASE - V8.0.0',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── FLOATING STATS COUNTER CARD ──────────────────────────────
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(_jurisdictions, 'JURISDICTIONS'),
                        _buildStatDivider(),
                        /*
                        _buildStatItem(_activeObservers, 'ACTIVE OBSERVERS'),
                        _buildStatDivider(),
                        */
                        _buildStatItem(_pollingUnits, 'POLLING UNITS'),
                        /*
                        _buildStatDivider(),
                        _buildStatItem(_submissionsScanned, 'SUBMISSIONS SCANNED'),
                        */
                      ],
                    ),
                  ),
                ),
              ),

              // ─── SEGMENTED TAB SELECTOR ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(0, 'OVERVIEW & IMPACT'),
                      // _buildTabButton(1, 'MODULE EXPLORER'),
                      _buildTabButton(1, 'TEAM & CREDITS'),
                    ],
                  ),
                ),
              ),

              // ─── TAB CONTENT AREA ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _activeTabIndex == 0
                      ? _buildOverviewTab()
                      /*
                      : _activeTabIndex == 1
                          ? _buildModuleExplorerTab(categories, filteredModules)
                      */
                      : _buildTeamCreditsTab(),
                ),
              ),

              const SizedBox(height: 36),

              // ─── FOOTER BANNER ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                color: const Color(0xFF4A0E0E),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF8B1A1A)),
                              const SizedBox(width: 8),
                              Text(
                                'BACK TO LOGIN',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF8B1A1A),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '© ${DateTime.now().year} VoteGuard. All rights reserved.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
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

  // ─── HELPER: PILL BADGE ──────────────────────────────────────────────────
  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF334155),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ─── HELPER: STAT ITEM ───────────────────────────────────────────────────
  Widget _buildStatItem(String value, String title) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 28,
      width: 1,
      color: const Color(0xFFF1F5F9),
    );
  }

  // ─── HELPER: TAB BUTTON ──────────────────────────────────────────────────
  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B1A1A) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B1A1A).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW & IMPACT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    final focusAreas = List<Map<String, dynamic>>.from(_config['focusAreas'] ?? []);
    final links = _config['links'] as Map<String, dynamic>? ?? {};
    final footer = _config['footer'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: PURPOSE-BUILT PLATFORM
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B1A1A).withValues(alpha: 0.15)),
                ),
                child: const Icon(LucideIcons.shield, size: 20, color: Color(0xFF8B1A1A)),
              ),
              const SizedBox(height: 14),
              Text(
                'PURPOSE-BUILT PLATFORM',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _config['overview']?['purpose'] ?? '',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card 2: EVOLUTIONARY JOURNEY
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
                ),
                child: const Icon(LucideIcons.activity, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 14),
              Text(
                'EVOLUTIONARY JOURNEY',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _config['overview']?['evolution'] ?? '',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ─── OPERATIONAL FOCUS AREAS DIVIDER ──────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OPERATIONAL FOCUS AREAS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'VOTEGUARD SUPPORTS SPECIALIZED MODULES ACROSS THESE PRIMARY FOCUS AREAS',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 18),

        // 6 Focus Area Cards
        ...focusAreas.map((area) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildFocusIcon(area['icon'] ?? ''),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            area['title'] ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            area['description'] ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),

        const SizedBox(height: 24),

        // ─── REFERENCE LINKS ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.zap, size: 16, color: Color(0xFF8B1A1A)),
                  const SizedBox(width: 8),
                  Text(
                    'REFERENCE LINKS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildReferenceLink(
                'ACTIVE WORKSPACE',
                links['workspace'] ?? 'https://voteguard.com.ng',
              ),
              const SizedBox(height: 8),
              _buildReferenceLink(
                'LIVE RESULTS HUB',
                links['glass'] ?? 'https://voteguard.com.ng/live-results',
              ),
              const SizedBox(height: 8),
              _buildReferenceLink(
                'OFFICIAL WEBSITE',
                links['website'] ?? 'https://csn.org',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─── HEADQUARTERS ADDRESS & TECHNICAL ASSISTANCE ───────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 16, color: Color(0xFF8B1A1A)),
                  const SizedBox(width: 8),
                  Text(
                    'HEADQUARTERS ADDRESS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                footer['address'] ??
                    'CATHOLIC SECRETARIAT OF NIGERIA, PLOT 459 CADASTRAL ZONE B2, DURUMI, ABUJA, NIGERIA',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.phone, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(
                    footer['phone'] ?? '+234 9 0000 0000',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.mail, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(
                    footer['email'] ?? 'INFO@CSN.ORG',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Technical Assistance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFEF3C7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text(
                    'TECHNICAL ASSISTANCE',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF92400E),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'For server issues, credential problems, access configuration edits, or hardware permissions, contact our software lead.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CONTACT PERSONNEL',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            footer['supportHelpdesk'] ?? 'EMMANUEL VEGHER — TECHNICAL LEAD',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showEmailLeadDialog(
                          (footer['supportHelpdesk'] ?? 'EMMANUEL VEGHER — TECHNICAL LEAD').toString(),
                          (footer['supportHelpdeskEmail'] ?? footer['email'] ?? 'evegher@ccfng.org').toString(),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.mail, size: 12, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'EMAIL LEAD',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceLink(String label, String url) {
    return InkWell(
      onTap: () => _launchExternalUrl(url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: 0.8,
              ),
            ),
            const Icon(LucideIcons.externalLink, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  /*
  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: MODULE EXPLORER (COMMENTED OUT)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildModuleExplorerTab(List<String> categories, List<Map<String, dynamic>> modules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Filter Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search Input
              TextField(
                onChanged: (val) {
                  setState(() {
                    _moduleSearchQuery = val;
                  });
                },
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search modules (e.g. results, maps, logs, chat...)',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF8B1A1A)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isSel ? Colors.white : const Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Modules List
        if (modules.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text(
              'No modules found matching "$_moduleSearchQuery"',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...modules.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Text(
                              (m['category'] ?? '').toString().toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2563EB),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Icon(LucideIcons.chevronRight, size: 14, color: Color(0xFFCBD5E1)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        m['title'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['description'] ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
  */

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: TEAM & CREDITS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTeamCreditsTab() {
    final team = List<Map<String, dynamic>>.from(_config['team'] ?? []);

    final sponsors = team.where((m) {
      final role = (m['role'] ?? '').toString().toLowerCase();
      return role.contains('sponsor') || role.contains('director');
    }).toList();

    final engineers = team.where((m) {
      final role = (m['role'] ?? '').toString().toLowerCase();
      return !role.contains('sponsor') && !role.contains('director');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── SPONSORSHIP & MANAGEMENT ─────────────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'SPONSORSHIP & MANAGEMENT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
          ],
        ),
        const SizedBox(height: 16),

        ...(sponsors.isNotEmpty ? sponsors : team.take(1)).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildTeamCard(
                name: m['name'] ?? '',
                role: m['role'] ?? '',
                quote: m['quote'] ?? '',
                description: m['description'] ?? '',
                isSponsor: true,
              ),
            )),

        const SizedBox(height: 24),

        // ─── TECHNICAL ENGINEERING ─────────────────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'TECHNICAL ENGINEERING',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFF8B1A1A), thickness: 1.5)),
          ],
        ),
        const SizedBox(height: 16),

        ...(engineers.isNotEmpty ? engineers : team.skip(1)).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildTeamCard(
                name: m['name'] ?? '',
                role: m['role'] ?? '',
                quote: m['quote'] ?? '',
                description: m['description'] ?? '',
                isSponsor: false,
              ),
            )),
      ],
    );
  }

  Widget _buildTeamCard({
    required String name,
    required String role,
    required String quote,
    required String description,
    required bool isSponsor,
  }) {
    final badgeColor = isSponsor ? const Color(0xFF8B1A1A) : const Color(0xFF2563EB);
    final badgeBg = isSponsor ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF);
    final badgeBorder = isSponsor ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(
              role.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: badgeColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
          ),
          if (quote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isSponsor
                        ? const Color(0xFF8B1A1A).withValues(alpha: 0.4)
                        : const Color(0xFF2563EB).withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                '"$quote"',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),
            Text(
              description.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.6,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
