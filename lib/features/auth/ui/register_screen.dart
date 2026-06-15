import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voteguard/services/geo_service.dart';
import 'package:voteguard/models/geo_models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _geoService = GeoService();
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _termsAgreed = false;
  bool _isLoading = false;

  List<GeoItem> _states = [];
  List<GeoItem> _lgas = [];
  List<GeoItem> _wards = [];
  List<PollingUnit> _units = [];
  List<PollingUnit> _filteredUnits = [];

  GeoItem? _selectedState;
  GeoItem? _selectedLga;
  GeoItem? _selectedWard;
  PollingUnit? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadStates();
    _phoneController.addListener(_formatPhoneNumber);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_formatPhoneNumber);
    super.dispose();
  }

  void _formatPhoneNumber() {
    String text = _phoneController.text;
    if (text.startsWith('0')) {
      String newText = '234${text.substring(1)}';
      _phoneController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  bool _isLoadingWards = false;
  bool _isLoadingUnits = false;

  Future<void> _loadStates() async {
    try {
      final states = await _geoService.getStates();
      if (mounted) setState(() => _states = states);
    } catch (e) {
      debugPrint("States Fetch Error: $e");
    }
  }

  Future<void> _onStateChanged(GeoItem? state) async {
    setState(() {
      _selectedState = state;
      _selectedLga = null;
      _selectedWard = null;
      _selectedUnit = null;
      _lgas = [];
      _wards = [];
      _units = [];
    });
    if (state != null) {
      try {
        final lgas = await _geoService.getLGAs(state.name);
        if (mounted) setState(() => _lgas = lgas);
      } catch (e) { debugPrint("LGA Fetch Error: $e"); }
    }
  }

  Future<void> _onLgaChanged(GeoItem? lga) async {
    setState(() {
      _selectedLga = lga;
      _selectedWard = null;
      _selectedUnit = null;
      _wards = [];
      _units = [];
      _isLoadingWards = true;
    });
    if (lga != null && _selectedState != null) {
      try {
        final stateName = _selectedState?.name;
        if (stateName == null) return;
        final wards = await _geoService.getWards(stateName, lga.name);
        if (mounted) {
          setState(() {
            _wards = wards;
            _isLoadingWards = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingWards = false);
      }
    }
  }

  Future<void> _onWardChanged(GeoItem? ward) async {
    setState(() {
      _selectedWard = ward;
      _selectedUnit = null;
      _units = [];
      _filteredUnits = [];
    });
    if (ward != null && _selectedState != null && _selectedLga != null) {
      _fetchPollingUnits(ward);
    }
  }

  Future<void> _fetchPollingUnits(GeoItem ward) async {
    setState(() => _isLoadingUnits = true);
    try {
      final stateName = _selectedState?.name;
      final lgaName = _selectedLga?.name;
      if (stateName == null || lgaName == null) return;
      final units = await _geoService.getPollingUnits(stateName, lgaName, ward.name);
      if (mounted) {
        setState(() {
          _units = units;
          _filteredUnits = units;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUnits = false);
    }
  }

  void _showPollingUnitSearch() {
    if (_selectedWard == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Search Polling Unit', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Type to filter units...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  onChanged: (value) {
                    setModalState(() {
                      _filteredUnits = _units
                          .where((u) => u.name.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _filteredUnits.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final unit = _filteredUnits[index];
                    return ListTile(
                      title: Text(unit.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      subtitle: Text('ID: ${unit.pollingUnitId}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                      onTap: () {
                        setState(() => _selectedUnit = unit);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms of Service', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTermsSection('1. Mission Statement', 'VoteGuard is dedicated to ensuring the integrity and transparency of the democratic process. By accessing this platform, you commit to providing accurate, unbiased, and real-time reports of election activities at your assigned location.'),
                _buildTermsSection('2. Observer Conduct', 'As a verified VoteGuard observer, you agree to the following code of conduct:\n\n• Maintain absolute neutrality and non-partisanship at all times.\n• Report only witnessed events and verified results.\n• Respect the authority of election officials and law enforcement.\n• Do not interfere with the voting process or attempt to influence voters.'),
                _buildTermsSection('3. Data Privacy & Security', 'All data submitted—including images of EC8A forms and incident reports—are encrypted and handled with the highest security standards. Your personal identification is used strictly for verification and security auditing. We do not share your contact information with third-party political entities or commercial organizations.'),
                _buildTermsSection('4. Disciplinary Protocol', 'Submission of fraudulent data, intentional misrepresentation of results, or engaging in partisanship will result in immediate termination of platform access. Such actions may be reported to relevant legal authorities for further investigation into election malpractice.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _termsAgreed = true);
              Navigator.pop(context);
            },
            child: const Text('I UNDERSTAND', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5)),
        ],
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate() || !_termsAgreed) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.isNotEmpty 
          ? _emailController.text 
          : "${_phoneController.text.replaceAll(RegExp(r'\D'), '')}@voteguard.com";
      
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'id': uid,
        'name': "${_firstNameController.text} ${_lastNameController.text}",
        'email': email,
        'phone': _phoneController.text,
        'role': 'OBSERVER',
        'state': _selectedState?.name,
        'stateId': _selectedState?.id,
        'lga': _selectedLga?.name,
        'lgaId': _selectedLga?.id,
        'ward': _selectedWard?.name,
        'wardId': _selectedWard?.id,
        'pollingUnit': _selectedUnit?.name,
        'pollingUnitId': _selectedUnit?.id,
        'assignedState': _selectedState?.name,
        'assignedLga': _selectedLga?.name,
        'assignedWard': _selectedWard?.name,
        'assignedPollingUnit': _selectedUnit?.name,
        'status': 'ACTIVE',
        'termsAgreed': true,
        'termsAgreedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/election_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset('assets/images/voteguard_logo.png', height: 50),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                      children: [
                        const TextSpan(text: 'Create '),
                        TextSpan(text: 'Account', style: TextStyle(color: const Color(0xFF991B1B))),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text('JOIN THE OBSERVATION NETWORK', style: TextStyle(color: Color(0xFF64748B), fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
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
                        _buildSectionTitle('PERSONAL INFORMATION'),
                        const SizedBox(height: 20),
                        _buildField('FIRST NAME', _firstNameController, 'John', validator: (v) => v!.isEmpty ? 'First name required' : null),
                        const SizedBox(height: 16),
                        _buildField('LAST NAME', _lastNameController, 'Doe', validator: (v) => v!.isEmpty ? 'Last name required' : null),
                        const SizedBox(height: 16),
                        _buildField('EMAIL ADDRESS', _emailController, 'john.doe@example.com', icon: LucideIcons.mail, validator: (v) => v!.isEmpty ? 'Email required' : null),
                        const SizedBox(height: 16),
                        _buildField('PHONE NUMBER', _phoneController, '0801 234 5678', icon: LucideIcons.phone, validator: (v) => v!.isEmpty ? 'Phone required' : null),
                        
                        const SizedBox(height: 32),
                        _buildSectionTitle('ACCOUNT & SECURITY'),
                        const SizedBox(height: 20),
                        _buildField('ROLE', TextEditingController(), 'Observer', icon: LucideIcons.shield, readOnly: true),
                        const SizedBox(height: 16),
                        _buildField(
                          'PASSWORD', 
                          _passwordController, 
                          '••••••••', 
                          icon: LucideIcons.lock, 
                          obscureText: !_isPasswordVisible,
                          validator: (v) => v!.length < 6 ? 'Password too short (min 6 chars)' : null,
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: const Color(0xFF64748B)),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          'CONFIRM PASSWORD', 
                          _confirmPasswordController, 
                          '••••••••', 
                          icon: LucideIcons.lock, 
                          obscureText: !_isConfirmPasswordVisible,
                          validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                          suffixIcon: IconButton(
                            icon: Icon(_isConfirmPasswordVisible ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: const Color(0xFF64748B)),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        _buildSectionTitle('LOCATION DETAILS (OPTIONAL)'),
                        const SizedBox(height: 20),
                        
                        _buildDropdown('STATE', 'Select State', _states, _selectedState, _onStateChanged),
                        const SizedBox(height: 16),
                        _buildDropdown('LGA', 'Select LGA', _lgas, _selectedLga, _onLgaChanged),
                        const SizedBox(height: 16),
                        _buildDropdown('WARD', 'Select Ward', _wards, _selectedWard, _onWardChanged),
                        const SizedBox(height: 16),
                        
                        // Searchable Polling Unit Selector
                        _buildSearchableSelector('POLLING UNIT', _selectedUnit?.name ?? 'Select Unit', _showPollingUnitSearch),
                        
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 24, width: 24,
                              child: Checkbox(
                                value: _termsAgreed,
                                onChanged: (v) => setState(() => _termsAgreed = v ?? false),
                                activeColor: const Color(0xFF991B1B),
                                side: const BorderSide(color: Color(0xFF991B1B), width: 1.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _showTermsDialog,
                                child: const Text.rich(
                                  TextSpan(
                                    text: 'I HAVE READ AND AGREE TO THE ',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(text: 'Terms of Service', style: TextStyle(color: Color(0xFF991B1B), decoration: TextDecoration.underline)),
                                      TextSpan(text: ' AND OBSERVATION PROTOCOLS'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_termsAgreed && !_isLoading) ? _handleRegistration : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF991B1B),
                              disabledBackgroundColor: const Color(0xFF991B1B).withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.userPlus, size: 20),
                                    SizedBox(width: 10),
                                    Text('COMPLETE REGISTRATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(LucideIcons.arrowLeft, size: 16),
                            label: const Text('BACK TO LOGIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'PROPRIETARY SYSTEM OF VOTEGUARD.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildField(String label, TextEditingController controller, String hint, {IconData? icon, bool obscureText = false, bool readOnly = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          validator: validator ?? ((v) => (v == null || v.isEmpty) && !readOnly ? 'Required' : null),
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            suffixIcon: suffixIcon,
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String hint, List<GeoItem> items, GeoItem? selected, Function(GeoItem?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<GeoItem>(
          value: selected,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 12)),
          )).toList(),
          onChanged: (v) => onChanged(v),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildSearchableSelector(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: value.contains('Select') ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(LucideIcons.search, size: 18, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
