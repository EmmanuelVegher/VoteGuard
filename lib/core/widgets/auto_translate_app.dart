import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:voteguard/services/language_service.dart';

/// Wrap any widget in [NoTranslate] to prevent its text from being auto-translated
/// (e.g., language selector names, user IDs, proper nouns).
class NoTranslate extends StatelessWidget {
  static const Object marker = Object();
  final Widget child;

  const NoTranslate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: marker,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

/// Whole-application offline-first text translator for Flutter.
/// Walks active [RenderParagraph] nodes in the render tree right after every frame
/// when a non-English language is active, so network fluctuations / setState rebuilds
/// NEVER flash text back to English.
/// - Strictly relies on the in-code offline dictionary + any dynamic translations
///   already cached locally (e.g. Firestore checklist questions).
/// - Protects all icon fonts (Lucide, Material, Cupertino) from style modification.
/// - Switching back to English cleanly restores every paragraph to exact English.
class AutoTranslateApp extends StatefulWidget {
  final Widget child;

  const AutoTranslateApp({super.key, required this.child});

  @override
  State<AutoTranslateApp> createState() => _AutoTranslateAppState();
}

class _AutoTranslateAppState extends State<AutoTranslateApp> {
  final Expando<InlineSpan> _originalSpans = Expando<InlineSpan>('vg_orig_span');
  final Expando<InlineSpan> _appliedSpans = Expando<InlineSpan>('vg_applied_span');
  final Expando<AppLanguage> _appliedLang = Expando<AppLanguage>('vg_applied_lang');
  final Expando<int> _appliedCacheVer = Expando<int>('vg_applied_cache_ver');

  // Matches extended Latin / Nigerian hooked & dotted letters + combining diacritics ONLY.
  // Never matches Private Use Area icon codepoints or emojis.
  static final RegExp _nigerianExtendedChars =
      RegExp(r'[\u00C0-\u02AF\u0300-\u036F\u1E00-\u1EFF]');
  static final RegExp _privateUseArea = RegExp(r'[\uE000-\uF8FF]');

  LanguageService? _langService;
  bool _persistentCallbackRegistered = false;
  bool _isScanning = false;
  bool _needsEnglishRestore = false;

  @override
  void initState() {
    super.initState();
    _registerFrameCallback();
  }

  void _registerFrameCallback() {
    if (_persistentCallbackRegistered) return;
    _persistentCallbackRegistered = true;
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (!mounted || _isScanning) return;
      final service = _langService;
      if (service == null) return;
      if (service.currentLanguage == AppLanguage.en && !_needsEnglishRestore) {
        return;
      }
      _scanRenderTree();
      if (service.currentLanguage == AppLanguage.en) {
        _needsEnglishRestore = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<LanguageService>();
    if (_langService != service) {
      _langService?.removeListener(_onLanguageChanged);
      _langService = service;
      _langService?.addListener(_onLanguageChanged);
      _scheduleImmediateFrame();
    }
  }

  void _onLanguageChanged() {
    if (_langService?.currentLanguage == AppLanguage.en) {
      _needsEnglishRestore = true;
    }
    _scheduleImmediateFrame();
  }

  void _scheduleImmediateFrame() {
    if (!mounted) return;
    WidgetsBinding.instance.scheduleFrame();
  }

  void _scanRenderTree() {
    final service = _langService;
    if (service == null) return;
    _isScanning = true;
    final lang = service.currentLanguage;

    try {
      for (final renderView in WidgetsBinding.instance.renderViews) {
        _visitRenderObject(renderView, lang, service, false);
      }
    } finally {
      _isScanning = false;
    }
  }

  void _visitRenderObject(
    RenderObject node,
    AppLanguage lang,
    LanguageService service,
    bool insideNoTranslate,
  ) {
    final skipSubtree = insideNoTranslate ||
        (node is RenderMetaData && identical(node.metaData, NoTranslate.marker));
    if (skipSubtree) return;

    if (node is RenderParagraph) {
      _processParagraph(node, lang, service);
      return;
    }

    node.visitChildren((child) {
      _visitRenderObject(child, lang, service, false);
    });
  }

  bool _isIconSpan(TextSpan span) {
    final family = (span.style?.fontFamily ?? '').toLowerCase();
    if (family.contains('icon') ||
        family.contains('lucide') ||
        family.contains('cupertino') ||
        family.contains('material') ||
        family.contains('packages/')) {
      return true;
    }
    final txt = span.text;
    if (txt != null && _privateUseArea.hasMatch(txt)) {
      return true;
    }
    return false;
  }

  void _processParagraph(
    RenderParagraph paragraph,
    AppLanguage lang,
    LanguageService service,
  ) {
    final currentSpan = paragraph.text;

    if (lang == AppLanguage.en) {
      // Only restore if AutoTranslateApp itself had mutated this paragraph AND Flutter
      // hasn't already rebuilt it with fresh English via context.tr(...)
      final orig = _originalSpans[paragraph];
      final lastApplied = _appliedSpans[paragraph];
      if (orig != null && identical(currentSpan, lastApplied)) {
        paragraph.text = orig;
      }
      _originalSpans[paragraph] = null;
      _appliedSpans[paragraph] = null;
      _appliedLang[paragraph] = null;
      _appliedCacheVer[paragraph] = null;
      return;
    }

    InlineSpan? orig = _originalSpans[paragraph];
    final lastApplied = _appliedSpans[paragraph];
    final lastLang = _appliedLang[paragraph];
    final lastCacheVer = _appliedCacheVer[paragraph];

    // Fast O(1) exit: already translated for this language & cache version -> zero flicker!
    if (identical(currentSpan, lastApplied) &&
        lastLang == lang &&
        lastCacheVer == service.cacheVersion) {
      return;
    }

    if (orig == null) {
      orig = currentSpan;
    } else if (!identical(currentSpan, lastApplied) &&
        !identical(currentSpan, orig)) {
      // Widget rebuilt with a fresh InlineSpan from build() (e.g. context.tr(...) or setState)
      orig = currentSpan;
      _originalSpans[paragraph] = null;
      _appliedSpans[paragraph] = null;
      _appliedCacheVer[paragraph] = null;
    } else if (identical(currentSpan, lastApplied) && lastLang == lang) {
      // Cache version incremented -> re-check if dynamic cache gained a new entry
      final rebuilt = _translateSpan(orig, lang, service);
      _appliedCacheVer[paragraph] = service.cacheVersion;
      if (_spanTextEquals(rebuilt, currentSpan)) {
        return;
      }
      paragraph.text = rebuilt;
      _appliedSpans[paragraph] = rebuilt;
      _appliedLang[paragraph] = lang;
      return;
    }

    final translated = _translateSpan(orig, lang, service);
    final textChanged = !_spanTextEquals(translated, currentSpan);
    final fontChanged = _spanNeedsUnicodeFont(currentSpan);

    if (textChanged || fontChanged) {
      // Only record _originalSpans when AutoTranslateApp actually mutates this paragraph
      _originalSpans[paragraph] = orig;
      paragraph.text = translated;
      _appliedSpans[paragraph] = translated;
      _appliedLang[paragraph] = lang;
      _appliedCacheVer[paragraph] = service.cacheVersion;
    } else {
      // Mark as checked for this language & cache version so we don't re-walk it every frame
      _appliedSpans[paragraph] = currentSpan;
      _appliedLang[paragraph] = lang;
      _appliedCacheVer[paragraph] = service.cacheVersion;
    }
  }

  bool _spanNeedsUnicodeFont(InlineSpan span) {
    if (span is TextSpan) {
      if (_isIconSpan(span)) return false;
      final txt = span.text;
      if (txt != null &&
          _nigerianExtendedChars.hasMatch(txt) &&
          span.style?.fontFamily != 'Roboto') {
        return true;
      }
      if (span.children != null) {
        for (final c in span.children!) {
          if (_spanNeedsUnicodeFont(c)) return true;
        }
      }
    }
    return false;
  }

  InlineSpan _translateSpan(
    InlineSpan span,
    AppLanguage lang,
    LanguageService service,
  ) {
    if (span is TextSpan) {
      if (_isIconSpan(span)) return span;

      String? newText = span.text;
      if (newText != null && newText.trim().isNotEmpty) {
        if (!LanguageService.shouldSkipTranslation(newText)) {
          final translated = service.tr(newText);
          if (translated != newText) {
            newText = translated;
          }
        }
      }

      List<InlineSpan>? newChildren;
      if (span.children != null && span.children!.isNotEmpty) {
        newChildren = span.children!
            .map((c) => _translateSpan(c, lang, service))
            .toList(growable: false);
      }

      // Outfit font lacks glyphs for extended Nigerian characters (ɓ, ɗ, ƙ, ƴ, ə, ẹ, ọ, ṣ, ị, ụ).
      // Only apply Roboto/Noto Sans fallback when extended Latin letters are present (never on icons!).
      TextStyle? resolvedStyle = span.style;
      if (newText != null && _nigerianExtendedChars.hasMatch(newText)) {
        resolvedStyle = (span.style ?? const TextStyle()).copyWith(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans', 'Roboto', 'sans-serif'],
        );
      }

      return TextSpan(
        text: newText,
        children: newChildren,
        style: resolvedStyle,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }
    return span;
  }

  bool _spanTextEquals(InlineSpan a, InlineSpan b) {
    if (identical(a, b)) return true;
    return a.toPlainText() == b.toPlainText();
  }

  @override
  void dispose() {
    _langService?.removeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
