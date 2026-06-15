import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:voteguard/services/auth_service.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isPhoneLoading = false;
  bool _isEmailLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/election_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.white.withAlpha(153),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.arrowLeft,
                          color: Color(0xFF1E293B)),
                    ),
                  ),
                  Image.asset(
                    'assets/images/voteguard_grey.png',
                    height: 72,
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      children: [
                        const TextSpan(text: 'Password '),
                        TextSpan(
                          text: 'Reset',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF991B1B),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a recovery method and we will send you instructions to reset your VoteGuard password.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DefaultTabController(
                    length: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Column(
                          children: [
                            TabBar(
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: const Color(0xFF991B1B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: Colors.white,
                              unselectedLabelColor: const Color(0xFF64748B),
                              labelStyle: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              tabs: const [
                                Tab(text: 'PHONE'),
                                Tab(text: 'EMAIL'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 340,
                              child: TabBarView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24.0),
                                    child: _buildPhoneResetSection(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24.0),
                                    child: _buildEmailResetSection(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'For security, only users with a VoteGuard profile and active FCM token can receive a phone reset OTP.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B).withAlpha(217),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneResetSection() {
    return _buildResetCard(
      title: 'RESET WITH PHONE NUMBER',
      description: 'Enter the phone number linked to your VoteGuard account.',
      hintText: 'Phone Number',
      controller: _phoneController,
      prefixIcon: LucideIcons.phone,
      isLoading: _isPhoneLoading,
      buttonText: 'SEND RESET OTP',
      onPressed: _resetPasswordByPhone,
      onChanged: _normalizePhoneInput,
    );
  }

  Widget _buildEmailResetSection() {
    return _buildResetCard(
      title: 'RESET WITH EMAIL',
      description: 'Enter the email address linked to your VoteGuard account.',
      hintText: 'Email Address',
      controller: _emailController,
      prefixIcon: LucideIcons.mail,
      isLoading: _isEmailLoading,
      buttonText: 'SEND EMAIL RESET LINK',
      onPressed: _resetPasswordByEmail,
    );
  }

  Widget _buildResetCard({
    required String title,
    required String description,
    required String hintText,
    required TextEditingController controller,
    required IconData prefixIcon,
    required bool isLoading,
    required String buttonText,
    required VoidCallback onPressed,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(prefixIcon, size: 20, color: const Color(0xFF991B1B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            enabled: !isLoading,
            style: const TextStyle(color: Colors.black),
            keyboardType: title.contains('EMAIL')
                ? TextInputType.emailAddress
                : TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon:
                  Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => onPressed(),
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF991B1B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      buttonText,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _normalizePhoneInput(String value) {
    if (value.startsWith('0') && !value.startsWith('234')) {
      final normalized = '234${value.substring(1)}';
      _phoneController.text = normalized;
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: normalized.length),
      );
    }
  }

  AuthService _authService() {
    return context.read<AuthService>();
  }

  Future<void> _resetPasswordByPhone() async {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      _showMessage('Please enter your registered phone number.');
      return;
    }

    setState(() => _isPhoneLoading = true);

    try {
      await _authService().resetPasswordByPhone(phoneNumber);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => _buildSuccessDialog(
          dialogContext,
          'Reset OTP Sent',
          'A password reset OTP has been generated and sent through VoteGuard cloud messaging for $phoneNumber.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => _buildErrorDialog(
          dialogContext,
          'Reset OTP Failed',
          _formatFirebaseError(e),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPhoneLoading = false);
      }
    }
  }

  Future<void> _resetPasswordByEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your registered email address.');
      return;
    }

    setState(() => _isEmailLoading = true);

    try {
      await _authService().resetPasswordByEmail(email);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => _buildSuccessDialog(
          dialogContext,
          'Email Reset Sent',
          'A password reset email has been sent to $email if the address is registered.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => _buildErrorDialog(
          dialogContext,
          'Email Reset Failed',
          _formatFirebaseError(e),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  Widget _buildSuccessDialog(
      BuildContext context, String title, String message) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(LucideIcons.circleCheck, color: Color(0xFF16A34A)),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                fontSize: 20),
          ),
        ],
      ),
      content: Text(message,
          style:
              GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('OK',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildErrorDialog(BuildContext context, String title, String message) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(LucideIcons.circleAlert, color: Color(0xFF991B1B)),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
                fontSize: 20),
          ),
        ],
      ),
      content: Text(message,
          style:
              GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 14)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('OK',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF991B1B),
      ),
    );
  }

  String _formatFirebaseError(Object error) {
    final message = error.toString();

    if (message.contains('invalid-email')) {
      return 'The email address format is invalid.';
    }
    if (message.contains('user-not-found')) {
      return 'No account was found for this email address or phone number.';
    }
    if (message.contains('too-many-requests')) {
      return 'Too many reset attempts. Please try again later.';
    }
    if (message.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (message.contains('missing-fcm-token')) {
      return 'No active FCM token was found for this user. Please open the app with notifications enabled.';
    }
    if (message.contains('No active FCM token found')) {
      return 'No active FCM token was found for this user. Please open the app with notifications enabled.';
    }
    if (message.contains('password-reset-sms-failed')) {
      return 'Failed to send password reset OTP. Please verify the phone number and try again.';
    }

    return 'An error occurred while sending the reset instruction. Please try again.';
  }
}
