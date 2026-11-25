import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:voteguard/services/language_service.dart';

class ReviewService {
  static const String _playStorePackageId = 'org.caritasnigeria.voteguard';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _keyReviewCompleted = 'vg_review_completed';
  static const String _keyLastPromptedMs = 'vg_review_last_prompted_ms';
  static const String _keySessionCount = 'vg_review_session_count';

  /// Minimum sessions before showing an automatic session-based prompt on the Gallery screen.
  static const int _minSessionsBeforePrompt = 3;

  /// Cooldown duration after user taps "Remind Me Later" (7 days).
  static const Duration _remindLaterCooldown = Duration(days: 7);

  static bool _isDialogShowing = false;
  static bool _sessionRecordedThisLaunch = false;

  /// Opens the VoteGuard Google Play Store listing directly.
  static Future<void> openPlayStoreListing() async {
    try {
      await _storage.write(key: _keyReviewCompleted, value: 'true');
    } catch (_) {}

    final marketUri =
        Uri.parse('market://details?id=$_playStorePackageId');
    final webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_playStorePackageId');

    try {
      final launchedMarket = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedMarket) return;
    } catch (_) {}

    try {
      await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('ReviewService: Could not launch Play Store URL: $e');
    }
  }

  /// Checks whether the user is eligible for an automatic review prompt.
  static Future<bool> _canPromptAutomatically() async {
    try {
      final completed = await _storage.read(key: _keyReviewCompleted);
      if (completed == 'true') return false;

      final lastPromptedStr = await _storage.read(key: _keyLastPromptedMs);
      if (lastPromptedStr != null) {
        final lastMs = int.tryParse(lastPromptedStr);
        if (lastMs != null) {
          final elapsed = DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
          if (elapsed < _remindLaterCooldown) {
            return false;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records an app session on the Gallery screen and prompts if threshold is reached.
  static Future<void> recordAppSessionAndMaybePrompt(
      BuildContext context) async {
    try {
      int count = 0;
      final existing = await _storage.read(key: _keySessionCount);
      if (existing != null) {
        count = int.tryParse(existing) ?? 0;
      }
      if (!_sessionRecordedThisLaunch) {
        _sessionRecordedThisLaunch = true;
        count += 1;
        await _storage.write(key: _keySessionCount, value: count.toString());
      }

      if (count < _minSessionsBeforePrompt) return;
      if (!await _canPromptAutomatically()) return;

      await Future.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
      await showReviewDialog(context);
    } catch (e) {
      debugPrint('ReviewService session check error: $e');
    }
  }

  /// Called right after a successful final Checklist, Incident Report, or EC8A Result submission.
  static Future<void> recordSubmissionAndMaybePrompt(
      BuildContext context) async {
    try {
      if (!await _canPromptAutomatically()) return;

      await Future.delayed(const Duration(milliseconds: 1400));
      if (!context.mounted) return;
      await showReviewDialog(context);
    } catch (e) {
      debugPrint('ReviewService submission check error: $e');
    }
  }

  /// Displays the Google Play Store review prompt dialog.
  static Future<void> showReviewDialog(BuildContext context,
      {bool force = false}) async {
    if (_isDialogShowing) return;
    if (!force && !await _canPromptAutomatically()) return;

    _isDialogShowing = true;
    int selectedStars = 5;

    try {
      await _storage.write(
        key: _keyLastPromptedMs,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.star,
                        color: Color(0xFF059669),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      ctx.tr('Enjoying VoteGuard?'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ctx.tr(
                          'Your review on the Google Play Store helps us improve election observation across Nigeria.'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starNum = index + 1;
                        final isSelected = starNum <= selectedStars;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedStars = starNum);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isSelected
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFCBD5E1),
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await openPlayStoreListing();
                        },
                        icon: const Icon(
                          LucideIcons.externalLink,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          ctx.tr('RATE ON PLAY STORE'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: () async {
                              try {
                                await _storage.write(
                                  key: _keyLastPromptedMs,
                                  value: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                );
                              } catch (_) {}
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Text(
                              ctx.tr('REMIND ME LATER'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: TextButton(
                            onPressed: () async {
                              try {
                                await _storage.write(
                                    key: _keyReviewCompleted, value: 'true');
                              } catch (_) {}
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Text(
                              ctx.tr('NO, THANKS'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _isDialogShowing = false;
  }
}
