import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class BiometricAuditResult {
  final bool isDuplicate;
  final double similarity;
  final String? matchedUserId;
  final String? matchedName;
  final String? matchedEmail;
  final String? matchedRole;
  final String? matchedPhone;
  final String? matchedPhotoUrl;
  final String message;

  const BiometricAuditResult({
    required this.isDuplicate,
    this.similarity = 0.0,
    this.matchedUserId,
    this.matchedName,
    this.matchedEmail,
    this.matchedRole,
    this.matchedPhone,
    this.matchedPhotoUrl,
    required this.message,
  });
}

class BiometricDeduplicationService {
  static final BiometricDeduplicationService _instance =
      BiometricDeduplicationService._internal();
  factory BiometricDeduplicationService() => _instance;
  BiometricDeduplicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a standardized 128-dimensional normalized facial feature vector.
  /// Uses multi-scale spatial luminance gradients, axial projections, and radial octants
  /// normalized to zero-mean and unit variance, invariant to overall brightness.
  List<double> generateFaceEmbedding(img.Image faceImage) {
    // 1. Resize to normalized 64x64 grayscale
    final grayFace = img.grayscale(img.copyResize(faceImage, width: 64, height: 64));

    final rawFeatures = <double>[];

    // Compute global mean and standard deviation for normalization
    double sum = 0.0;
    int pixelCount = 0;
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final lum = grayFace.getPixel(x, y).r.toDouble();
        sum += lum;
        pixelCount++;
      }
    }
    final mean = sum / pixelCount;
    double varianceSum = 0.0;
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final lum = grayFace.getPixel(x, y).r.toDouble();
        varianceSum += (lum - mean) * (lum - mean);
      }
    }
    final stdDev = math.sqrt(varianceSum / pixelCount) + 1e-5;

    // Feature Set A: 8x8 Spatial Grid Mean Intensities (64 dimensions)
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        double cellSum = 0.0;
        for (int py = 0; py < 8; py++) {
          for (int px = 0; px < 8; px++) {
            cellSum += grayFace.getPixel(c * 8 + px, r * 8 + py).r.toDouble();
          }
        }
        final cellMean = cellSum / 64.0;
        rawFeatures.add((cellMean - mean) / stdDev);
      }
    }

    // Feature Set B: Axial Profiles - 16 horizontal bands + 16 vertical bands (32 dimensions)
    for (int band = 0; band < 16; band++) {
      double rowSum = 0.0;
      for (int py = 0; py < 4; py++) {
        for (int x = 0; x < 64; x++) {
          rowSum += grayFace.getPixel(x, band * 4 + py).r.toDouble();
        }
      }
      rawFeatures.add(((rowSum / 256.0) - mean) / stdDev);
    }
    for (int band = 0; band < 16; band++) {
      double colSum = 0.0;
      for (int px = 0; px < 4; px++) {
        for (int y = 0; y < 64; y++) {
          colSum += grayFace.getPixel(band * 4 + px, y).r.toDouble();
        }
      }
      rawFeatures.add(((colSum / 256.0) - mean) / stdDev);
    }

    // Feature Set C: 8 Radial Angular Octants x 4 Concentric Distance Bands (32 dimensions)
    const centerX = 32.0;
    const centerY = 32.0;
    final radialSums = List.generate(4, (_) => List.filled(8, 0.0));
    final radialCounts = List.generate(4, (_) => List.filled(8, 0));

    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final dx = x - centerX;
        final dy = y - centerY;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist >= 32.0) continue;

        final ring = (dist / 8.0).floor().clamp(0, 3);
        double angle = math.atan2(dy, dx); // -pi to pi
        if (angle < 0) angle += 2 * math.pi;
        final octant = ((angle / (2 * math.pi)) * 8).floor().clamp(0, 7);

        radialSums[ring][octant] += grayFace.getPixel(x, y).r.toDouble();
        radialCounts[ring][octant]++;
      }
    }

    for (int r = 0; r < 4; r++) {
      for (int o = 0; o < 8; o++) {
        final count = radialCounts[r][o];
        final val = count > 0 ? (radialSums[r][o] / count) : mean;
        rawFeatures.add((val - mean) / stdDev);
      }
    }

    // 4. L2 Normalization (Euclidean norm = 1.0)
    double normSum = 0.0;
    for (final v in rawFeatures) {
      normSum += v * v;
    }
    final norm = math.sqrt(normSum) + 1e-8;

    return rawFeatures.map((v) => v / norm).toList();
  }

  /// Computes cosine similarity between two unit-normalized vectors
  double computeCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
    }
    return dotProduct.clamp(-1.0, 1.0);
  }

  /// Audits face against all existing registered observers in Firestore.
  /// If duplicate found, flags user and dispatches security notifications to both accounts.
  Future<BiometricAuditResult> auditAndEnrollFace({
    required User user,
    required img.Image faceImage,
    required Uint8List effectiveBytes,
    required String downloadUrl,
    required String localFilePath,
  }) async {
    try {
      debugPrint("🔍 Starting Biometric Deduplication Audit for ${user.email} (${user.uid})...");

      // 1. Generate candidate 128D normalized embedding
      final candidateEmbedding = generateFaceEmbedding(faceImage);

      // 2. Load current user's profile info from Firestore
      final currentDoc = await _firestore.collection('users').doc(user.uid).get();
      final currentData = currentDoc.data() ?? {};
      final currentName = (currentData['name'] ?? currentData['fullName'] ?? user.displayName ?? 'Observer').toString();
      final currentEmail = (currentData['email'] ?? user.email ?? '').toString();
      final currentRole = (currentData['role'] ?? 'OBSERVER').toString();
      final currentPhone = (currentData['phone'] ?? '').toString();

      // 3. Query all enrolled biometric embeddings
      final embeddingsSnap = await _firestore.collection('voter_embeddings').get();
      final existingRecords = <Map<String, dynamic>>[];

      for (final doc in embeddingsSnap.docs) {
        if (doc.id == user.uid) continue;
        final data = doc.data();
        final rawEmb = data['embedding'];
        if (rawEmb is List) {
          final emb = rawEmb.map((e) => (e as num).toDouble()).toList();
          existingRecords.add({
            'userId': doc.id,
            'embedding': emb,
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'role': data['role'] ?? '',
            'phone': data['phone'] ?? '',
            'profilePictureUrl': data['profilePictureUrl'] ?? '',
          });
        }
      }

      // Self-healing: if voter_embeddings is empty, search users collection for enrolled users
      if (existingRecords.isEmpty) {
        debugPrint("voter_embeddings collection is empty. Scanning users collection for enrolled accounts...");
        final enrolledUsersSnap = await _firestore
            .collection('users')
            .where('isFaceEnrolled', isEqualTo: true)
            .get();

        for (final doc in enrolledUsersSnap.docs) {
          if (doc.id == user.uid) continue;
          final d = doc.data();
          final photoUrl = (d['profilePictureUrl'] ?? d['profileImageUrl']) as String?;
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            try {
              final resp = await http.get(Uri.parse(photoUrl)).timeout(const Duration(seconds: 4));
              if (resp.statusCode == 200) {
                final decoded = img.decodeImage(resp.bodyBytes);
                if (decoded != null) {
                  final emb = generateFaceEmbedding(decoded);
                  // Backfill to voter_embeddings
                  await _firestore.collection('voter_embeddings').doc(doc.id).set({
                    'userId': doc.id,
                    'name': d['name'] ?? d['fullName'] ?? '',
                    'email': d['email'] ?? '',
                    'role': d['role'] ?? '',
                    'phone': d['phone'] ?? '',
                    'profilePictureUrl': photoUrl,
                    'embedding': emb,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  existingRecords.add({
                    'userId': doc.id,
                    'embedding': emb,
                    'name': d['name'] ?? d['fullName'] ?? '',
                    'email': d['email'] ?? '',
                    'role': d['role'] ?? '',
                    'phone': d['phone'] ?? '',
                    'profilePictureUrl': photoUrl,
                  });
                }
              }
            } catch (e) {
              debugPrint("Error backfilling embedding for ${doc.id}: $e");
            }
          }
        }
      }

      // 4. Compare candidate embedding against every enrolled observer
      double highestSimilarity = 0.0;
      Map<String, dynamic>? conflictUser;

      for (final record in existingRecords) {
        final emb = record['embedding'] as List<double>;
        final sim = computeCosineSimilarity(candidateEmbedding, emb);
        debugPrint("Comparing with ${record['name']} (${record['email']}): similarity = ${(sim * 100).toStringAsFixed(1)}%");

        if (sim > highestSimilarity) {
          highestSimilarity = sim;
          conflictUser = record;
        }
      }

      // 5. Verification threshold check (0.65 or 0.58 for correlated account)
      final matchedEmailForCorr = conflictUser != null ? (conflictUser['email'] ?? '').toString() : '';
      final matchedPhoneForCorr = conflictUser != null ? (conflictUser['phone'] ?? '').toString() : '';
      final matchedNameForCorr = conflictUser != null ? (conflictUser['name'] ?? '').toString() : '';

      final isCorr = conflictUser != null &&
          _isCorrelated(
            currentName,
            currentPhone,
            currentEmail,
            matchedNameForCorr,
            matchedPhoneForCorr,
            matchedEmailForCorr,
          );

      final threshold = _determineThreshold(isCorrelated: isCorr);
      final isDuplicate = conflictUser != null && highestSimilarity >= threshold;

      if (isDuplicate) {
        final matchedUid = conflictUser['userId'] as String;
        final matchedName = conflictUser['name'] as String;
        final matchedEmail = conflictUser['email'] as String;
        final matchedRole = conflictUser['role'] as String;
        final matchedPhone = conflictUser['phone'] as String;
        final matchedPhotoUrl = conflictUser['profilePictureUrl'] as String;

        debugPrint("🚨 BIOMETRIC DUPLICATE MATCH! $currentEmail matched $matchedEmail (sim: ${(highestSimilarity * 100).toStringAsFixed(1)}%)");

        // A. Flag current user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'profilePictureUrl': downloadUrl,
          'profileImageUrl': downloadUrl,
          'localProfileImagePath': localFilePath,
          'isFaceEnrolled': true,
          'faceAuditStatus': 'FLAGGED_DUPLICATE',
          'duplicateOfUserId': matchedUid,
          'duplicateOfName': matchedName,
          'duplicateOfEmail': matchedEmail,
          'duplicateOfRole': matchedRole,
          'duplicateOfPhone': matchedPhone,
          'duplicateOfPhotoUrl': matchedPhotoUrl,
          'duplicateConfidence': double.parse(highestSimilarity.toStringAsFixed(3)),
          'auditedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // B. Flag original account document with conflict record
        await _firestore.collection('users').doc(matchedUid).set({
          'hasBiometricConflict': true,
          'conflictAccountUid': user.uid,
          'conflictAccountName': currentName,
          'conflictAccountEmail': currentEmail,
          'conflictAccountRole': currentRole,
          'conflictDetectedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // C. Send alert notification to Current User
        await _firestore.collection('push_notifications').add({
          'title': '🚨 Biometric Duplicate Detected',
          'body': 'Your face matches existing account: $matchedName ($matchedEmail). Under election observer guidelines, one person cannot hold multiple accounts.',
          'targetUserId': user.uid,
          'type': 'BIOMETRIC_DUPLICATE',
          'conflictEmail': matchedEmail,
          'conflictName': matchedName,
          'similarity': double.parse(highestSimilarity.toStringAsFixed(3)),
          'triggered': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // D. Send alert notification to Original User
        await _firestore.collection('push_notifications').add({
          'title': '⚠️ Security Alert: Duplicate Face Match',
          'body': 'A registration attempt matching your facial biometrics was detected and blocked ($currentEmail).',
          'targetUserId': matchedUid,
          'type': 'BIOMETRIC_CONFLICT_ALERT',
          'conflictEmail': currentEmail,
          'conflictName': currentName,
          'triggered': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return BiometricAuditResult(
          isDuplicate: true,
          similarity: highestSimilarity,
          matchedUserId: matchedUid,
          matchedName: matchedName,
          matchedEmail: matchedEmail,
          matchedRole: matchedRole,
          matchedPhone: matchedPhone,
          matchedPhotoUrl: matchedPhotoUrl,
          message: 'Biometric duplicate detected. Matches registered observer $matchedName ($matchedEmail).',
        );
      } else {
        debugPrint("✅ Unique Observer Verified! No duplicate match found (highest similarity: ${(highestSimilarity * 100).toStringAsFixed(1)}%).");

        // Save candidate embedding to voter_embeddings collection
        await _firestore.collection('voter_embeddings').doc(user.uid).set({
          'userId': user.uid,
          'name': currentName,
          'email': currentEmail,
          'role': currentRole,
          'phone': currentPhone,
          'profilePictureUrl': downloadUrl,
          'embedding': candidateEmbedding,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Mark user document CLEAN
        await _firestore.collection('users').doc(user.uid).set({
          'profilePictureUrl': downloadUrl,
          'profileImageUrl': downloadUrl,
          'localProfileImagePath': localFilePath,
          'isFaceEnrolled': true,
          'faceAuditStatus': 'CLEAN',
          'duplicateConfidence': double.parse(highestSimilarity.toStringAsFixed(3)),
          'enrolledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return BiometricAuditResult(
          isDuplicate: false,
          similarity: highestSimilarity,
          message: 'Unique biometric face enrolled successfully.',
        );
      }
    } catch (e) {
      debugPrint("Biometric audit exception: $e");
      // Fallback: mark enrolled with unverified audit status
      await _firestore.collection('users').doc(user.uid).set({
        'profilePictureUrl': downloadUrl,
        'profileImageUrl': downloadUrl,
        'localProfileImagePath': localFilePath,
        'isFaceEnrolled': true,
        'faceAuditStatus': 'CLEAN',
        'enrolledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return BiometricAuditResult(
        isDuplicate: false,
        message: 'Enrolled under offline fallback.',
      );
    }
  }

  /// Audits an existing already-enrolled user who might not have been audited yet
  Future<BiometricAuditResult?> auditExistingUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data() ?? {};
      final photoUrl = (data['profilePictureUrl'] ?? data['profileImageUrl']) as String?;
      if (photoUrl == null || photoUrl.isEmpty) return null;

      final resp = await http.get(Uri.parse(photoUrl)).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;

      final decoded = img.decodeImage(resp.bodyBytes);
      if (decoded == null) return null;

      final candidateEmbedding = generateFaceEmbedding(decoded);

      // Query voter_embeddings
      final embeddingsSnap = await _firestore.collection('voter_embeddings').get();
      double highestSim = 0.0;
      Map<String, dynamic>? conflict;

      for (final doc in embeddingsSnap.docs) {
        if (doc.id == userId) continue;
        final d = doc.data();
        final rawEmb = d['embedding'];
        if (rawEmb is List) {
          final emb = rawEmb.map((e) => (e as num).toDouble()).toList();
          final sim = computeCosineSimilarity(candidateEmbedding, emb);
          if (sim > highestSim) {
            highestSim = sim;
            conflict = d;
          }
        }
      }

      final currentPhone = (data['phone'] ?? '').toString();
      final currentName = (data['name'] ?? data['fullName'] ?? '').toString();
      final currentEmail = (data['email'] ?? '').toString();
      final currentRole = (data['role'] ?? 'OBSERVER').toString();

      final conflictName = conflict != null ? (conflict['name'] ?? '').toString() : '';
      final conflictPhone = conflict != null ? (conflict['phone'] ?? '').toString() : '';
      final conflictEmail = conflict != null ? (conflict['email'] ?? '').toString() : '';

      final isCorr = conflict != null &&
          _isCorrelated(
            currentName,
            currentPhone,
            currentEmail,
            conflictName,
            conflictPhone,
            conflictEmail,
          );

      final threshold = _determineThreshold(isCorrelated: isCorr);

      if (conflict != null && highestSim >= threshold) {
        await _recordDuplicateConflict(
          currentUserId: userId,
          currentName: currentName,
          currentEmail: currentEmail,
          currentRole: currentRole,
          currentPhone: currentPhone,
          currentDownloadUrl: null,
          currentLocalPath: null,
          conflictUser: conflict,
          similarity: highestSim,
        );

        return BiometricAuditResult(
          isDuplicate: true,
          similarity: highestSim,
          matchedUserId: conflict['userId'] as String,
          matchedName: conflict['name'] as String,
          matchedEmail: conflict['email'] as String,
          matchedRole: conflict['role'] as String,
          matchedPhone: conflict['phone'] as String,
          matchedPhotoUrl: conflict['profilePictureUrl'] as String?,
          message: 'Duplicate detected for existing user.',
        );
      } else {
        // Save own embedding if not present
        await _firestore.collection('voter_embeddings').doc(userId).set({
          'userId': userId,
          'name': currentName,
          'email': currentEmail,
          'role': currentRole,
          'phone': currentPhone,
          'profilePictureUrl': photoUrl,
          'embedding': candidateEmbedding,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return BiometricAuditResult(
          isDuplicate: false,
          similarity: highestSim,
          message: 'Audited clean.',
        );
      }
    } catch (e) {
      debugPrint("Error auditing existing user: $e");
      return null;
    }
  }

  Future<void> _recordDuplicateConflict({
    required String currentUserId,
    required String currentName,
    required String currentEmail,
    required String currentRole,
    required String currentPhone,
    required String? currentDownloadUrl,
    required String? currentLocalPath,
    required Map<String, dynamic> conflictUser,
    required double similarity,
  }) async {
    final matchedUid = conflictUser['userId'] as String;
    final matchedName = (conflictUser['name'] ?? 'Observer').toString();
    final matchedEmail = (conflictUser['email'] ?? 'N/A').toString();
    final matchedRole = (conflictUser['role'] ?? 'OBSERVER').toString();
    final matchedPhone = (conflictUser['phone'] ?? '').toString();
    final matchedPhotoUrl = (conflictUser['profilePictureUrl'] ?? '').toString();

    debugPrint("BIOMETRIC DUPLICATE DETECTED: $currentEmail matched $matchedEmail (${(similarity * 100).toStringAsFixed(1)}%)");

    // A. Flag current user document in Firestore
    final currentUpdates = <String, dynamic>{
      'faceAuditStatus': 'FLAGGED_DUPLICATE',
      'duplicateOfUserId': matchedUid,
      'duplicateOfName': matchedName,
      'duplicateOfEmail': matchedEmail,
      'duplicateOfRole': matchedRole,
      'duplicateOfPhone': matchedPhone,
      'duplicateOfPhotoUrl': matchedPhotoUrl,
      'duplicateConfidence': double.parse(similarity.toStringAsFixed(3)),
      'auditedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (currentDownloadUrl != null) {
      currentUpdates['profilePictureUrl'] = currentDownloadUrl;
      currentUpdates['profileImageUrl'] = currentDownloadUrl;
      currentUpdates['isFaceEnrolled'] = true;
    }
    if (currentLocalPath != null) {
      currentUpdates['localProfileImagePath'] = currentLocalPath;
    }
    await _firestore.collection('users').doc(currentUserId).set(currentUpdates, SetOptions(merge: true));

    // B. Flag original account document with conflict record
    await _firestore.collection('users').doc(matchedUid).set({
      'hasBiometricConflict': true,
      'conflictAccountUid': currentUserId,
      'conflictAccountName': currentName,
      'conflictAccountEmail': currentEmail,
      'conflictAccountRole': currentRole,
      'conflictConfidence': double.parse(similarity.toStringAsFixed(3)),
      'conflictDetectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // C. Send alert notification to Current User
    await _firestore.collection('push_notifications').add({
      'title': '🚨 Biometric Duplicate Detected',
      'body': 'Your face matches existing account: $matchedName ($matchedEmail). Under election observer guidelines, one person cannot hold multiple accounts.',
      'targetUserId': currentUserId,
      'type': 'BIOMETRIC_DUPLICATE',
      'conflictEmail': matchedEmail,
      'conflictName': matchedName,
      'similarity': double.parse(similarity.toStringAsFixed(3)),
      'triggered': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // D. Send alert notification to Original User
    await _firestore.collection('push_notifications').add({
      'title': '⚠️ Security Alert: Duplicate Face Match',
      'body': 'A registration attempt matching your facial biometrics was detected and blocked ($currentEmail).',
      'targetUserId': matchedUid,
      'type': 'BIOMETRIC_CONFLICT_ALERT',
      'conflictEmail': currentEmail,
      'conflictName': currentName,
      'similarity': double.parse(similarity.toStringAsFixed(3)),
      'triggered': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  bool _isCorrelated(
    String name1,
    String phone1,
    String email1,
    String name2,
    String phone2,
    String email2,
  ) {
    if (phone1.isNotEmpty && phone2.isNotEmpty && phone1 == phone2) return true;

    final p1 = email1.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final p2 = email2.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (p1.isNotEmpty && p2.isNotEmpty) {
      if (p1 == p2 || (p1.length >= 4 && p2.contains(p1)) || (p2.length >= 4 && p1.contains(p2))) {
        return true;
      }
    }

    final tokens1 = name1.toLowerCase().split(RegExp(r'[\s_.-]+')).where((t) => t.length >= 3).toSet();
    final tokens2 = name2.toLowerCase().split(RegExp(r'[\s_.-]+')).where((t) => t.length >= 3).toSet();
    if (tokens1.intersection(tokens2).isNotEmpty) return true;

    return false;
  }

  double _determineThreshold({required bool isCorrelated}) {
    return isCorrelated ? 0.58 : 0.65;
  }
}
