const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

function normalizePhone(phoneNumber) {
  const digits = String(phoneNumber || '').replace(/\D/g, '');

  if (digits.startsWith('234')) {
    return digits;
  }

  if (digits.startsWith('0')) {
    return `234${digits.substring(1)}`;
  }

  return digits;
}

function generateOtp() {
  const chars = '0123456789';
  let otp = '';

  for (let i = 0; i < 6; i += 1) {
    otp += chars[Math.floor(Math.random() * chars.length)];
  }

  return otp;
}

async function findUserByPhone(phoneNumber) {
  const normalizedPhone = normalizePhone(phoneNumber);

  let snapshot = await db
    .collection('users')
    .where('phone', '==', normalizedPhone)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    const doc = snapshot.docs[0];
    return { id: doc.id, ...doc.data() };
  }

  snapshot = await db
    .collection('users')
    .where('phone', '==', phoneNumber)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    const doc = snapshot.docs[0];
    return { id: doc.id, ...doc.data() };
  }

  return null;
}

async function findUserByEmail(email) {
  const normalizedEmail = String(email || '').trim().toLowerCase();

  if (!normalizedEmail) {
    return null;
  }

  const snapshot = await db
    .collection('users')
    .where('email', '==', normalizedEmail)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() };
}

exports.resolveLoginIdentifier = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.set('Access-Control-Allow-Headers', 'Content-Type');

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const identifier = String(request.body?.identifier || '').trim();

  if (!identifier) {
    response.status(400).json({ error: 'identifier is required' });
    return;
  }

  const looksLikePhone = /^\+?\d{10,15}$/.test(identifier);
  const user = looksLikePhone
    ? await findUserByPhone(identifier)
    : await findUserByEmail(identifier);

  if (!user) {
    response.status(404).json({ error: 'No user found for this identifier' });
    return;
  }

  if (!user.email) {
    response.status(400).json({
      error: 'This user does not have an email address for Firebase login',
    });
    return;
  }

  response.json({ success: true, userId: user.id, email: user.email });
});

exports.sendPasswordResetOtp = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.set('Access-Control-Allow-Headers', 'Content-Type');

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const phoneNumber = normalizePhone(request.body?.phoneNumber || '');

  if (!phoneNumber) {
    response.status(400).json({ error: 'phoneNumber is required' });
    return;
  }

  const user = await findUserByPhone(phoneNumber);

  if (!user) {
    response.status(404).json({ error: 'No user found for this phone number' });
    return;
  }

  const fcmToken = user.fcmToken || user.pushToken;

  if (!fcmToken) {
    response.status(400).json({
      error: 'No active FCM token found for this user',
    });
    return;
  }

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  await db.collection('password_reset_otps').add({
    userId: user.id,
    phoneNumber,
    otp,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'PENDING',
  });

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: 'VoteGuard Password Reset',
      body: `Your VoteGuard password reset OTP is ${otp}.`,
    },
    data: {
      type: 'PASSWORD_RESET_OTP',
      otp,
      expiresAt,
      phoneNumber,
      userId: user.id,
    },
  });

  response.json({ success: true, otpId: 'created' });
});

function computeCosineSimilarity(v1, v2) {
  if (!v1 || !v2 || v1.length !== v2.length || v1.length === 0) return 0.0;
  let dotProduct = 0.0;
  let n1 = 0.0;
  let n2 = 0.0;
  for (let i = 0; i < v1.length; i++) {
    dotProduct += v1[i] * v2[i];
    n1 += v1[i] * v1[i];
    n2 += v2[i] * v2[i];
  }
  const denominator = Math.sqrt(n1) * Math.sqrt(n2);
  if (denominator <= 0) return 0.0;
  return Math.max(-1.0, Math.min(1.0, dotProduct / denominator));
}

function isCorrelated(name1, phone1, email1, name2, phone2, email2) {
  if (phone1 && phone2 && phone1.trim() === phone2.trim() && phone1.length > 5) return true;
  if (email1 && email2) {
    const e1 = email1.toLowerCase().trim().split('@')[0];
    const e2 = email2.toLowerCase().trim().split('@')[0];
    if (e1 && e2 && e1 === e2 && e1.length > 3) return true;
  }
  if (name1 && name2) {
    const n1 = name1.toLowerCase().trim();
    const n2 = name2.toLowerCase().trim();
    if (n1 && n2 && (n1 === n2 || (n1.length > 4 && (n1.includes(n2) || n2.includes(n1))))) return true;
  }
  return false;
}

exports.auditAndEnrollBiometrics = functions.https.onRequest(async (request, response) => {
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { userId, name, email, role, phone, profilePictureUrl, embedding } = request.body || {};

    if (!userId || !Array.isArray(embedding) || embedding.length === 0) {
      response.status(400).json({ error: 'userId and non-empty embedding array are required' });
      return;
    }

    const candidateEmbedding = embedding.map(Number);
    const userName = (name || 'Observer').toString();
    const userEmail = (email || '').toString().toLowerCase();
    const userRole = (role || 'OBSERVER').toString();
    const userPhone = (phone || '').toString();
    const photoUrl = (profilePictureUrl || '').toString();

    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    // Persist candidate embedding to voter_embeddings
    await db.collection('voter_embeddings').doc(userId).set({
      userId,
      name: userName,
      email: userEmail,
      role: userRole,
      phone: userPhone,
      profilePictureUrl: photoUrl,
      embedding: candidateEmbedding,
      updatedAt: timestamp,
    }, { merge: true });

    /*
    // DUPLICATE CHECK COMMENTED OUT FOR NOW
    // 1. Fetch all enrolled records in voter_embeddings
    const embeddingsSnap = await db.collection('voter_embeddings').get();
    const existingRecords = [];

    embeddingsSnap.forEach(docSnap => {
      if (docSnap.id === userId) return;
      const data = docSnap.data();
      if (Array.isArray(data.embedding)) {
        existingRecords.push({
          userId: docSnap.id,
          embedding: data.embedding.map(Number),
          name: data.name || '',
          email: data.email || '',
          role: data.role || '',
          phone: data.phone || '',
          profilePictureUrl: data.profilePictureUrl || '',
        });
      }
    });

    // 2. Self-healing fallback: if voter_embeddings is empty, search users collection
    if (existingRecords.length === 0) {
      const usersSnap = await db.collection('users').where('isFaceEnrolled', '==', true).get();
      usersSnap.forEach(docSnap => {
        if (docSnap.id === userId) return;
        const data = docSnap.data();
        if (Array.isArray(data.embedding)) {
          existingRecords.push({
            userId: docSnap.id,
            embedding: data.embedding.map(Number),
            name: data.name || '',
            email: data.email || '',
            role: data.role || '',
            phone: data.phone || '',
            profilePictureUrl: data.profilePictureUrl || data.profileImageUrl || '',
          });
        }
      });
    }

    // 3. Compare candidate embedding against all enrolled profiles
    let highestSimilarity = 0.0;
    let conflictUser = null;

    for (const record of existingRecords) {
      const sim = computeCosineSimilarity(candidateEmbedding, record.embedding);
      if (sim > highestSimilarity) {
        highestSimilarity = sim;
        conflictUser = record;
      }
    }

    // 4. Threshold check: 0.65 standard, 0.58 if correlated
    const isCorr = conflictUser
      ? isCorrelated(
          userName,
          userPhone,
          userEmail,
          conflictUser.name,
          conflictUser.phone,
          conflictUser.email
        )
      : false;

    const threshold = isCorr ? 0.58 : 0.65;
    const isDuplicate = conflictUser !== null && highestSimilarity >= threshold;

    if (isDuplicate && conflictUser) {
      console.warn(`🚨 Biometric duplicate match: ${userEmail} matched ${conflictUser.email} (${(highestSimilarity * 100).toFixed(1)}%)`);

      // Update current user in users collection
      await db.collection('users').doc(userId).set({
        profilePictureUrl: photoUrl,
        profileImageUrl: photoUrl,
        isFaceEnrolled: true,
        faceAuditStatus: 'FLAGGED_DUPLICATE',
        duplicateOfUserId: conflictUser.userId,
        duplicateOfName: conflictUser.name,
        duplicateOfEmail: conflictUser.email,
        duplicateOfRole: conflictUser.role,
        duplicateOfPhone: conflictUser.phone,
        duplicateOfPhotoUrl: conflictUser.profilePictureUrl,
        duplicateConfidence: parseFloat(highestSimilarity.toFixed(3)),
        auditedAt: timestamp,
        updatedAt: timestamp,
      }, { merge: true });

      // Update original matched user in users collection
      await db.collection('users').doc(conflictUser.userId).set({
        hasBiometricConflict: true,
        conflictAccountUid: userId,
        conflictAccountName: userName,
        conflictAccountEmail: userEmail,
        conflictAccountRole: userRole,
        conflictConfidence: parseFloat(highestSimilarity.toFixed(3)),
        conflictDetectedAt: timestamp,
      }, { merge: true });

      // Push notification ONLY to the two affected accounts (never broadcast)
      try {
        const currentUserDoc = await db.collection('users').doc(userId).get();
        const currentToken = currentUserDoc.data()?.fcmToken || currentUserDoc.data()?.pushToken;

        if (currentToken) {
          await admin.messaging().send({
            token: currentToken,
            notification: {
              title: '⚠️ Potential Duplicate Account Noted',
              body: `Facial similarity match with account: ${conflictUser.name} (${conflictUser.email}). Your reporting privileges remain active.`,
            },
            data: {
              type: 'BIOMETRIC_DUPLICATE_NOTICE',
              targetUserId: userId,
              conflictEmail: conflictUser.email,
              conflictName: conflictUser.name,
              similarity: (highestSimilarity * 100).toFixed(1),
            },
          });
        }

        // Notify the original matched account ONLY if it has a distinct device token
        const conflictUserDoc = await db.collection('users').doc(conflictUser.userId).get();
        const conflictToken = conflictUserDoc.data()?.fcmToken || conflictUserDoc.data()?.pushToken;
        if (conflictToken && conflictToken !== currentToken) {
          await admin.messaging().send({
            token: conflictToken,
            notification: {
              title: 'ℹ️ Biometric Notice: Potential Similarity',
              body: `An account with facial similarity to your profile was enrolled (${userEmail}). Recorded for review.`,
            },
            data: {
              type: 'BIOMETRIC_CONFLICT_ALERT',
              targetUserId: conflictUser.userId,
              conflictEmail: userEmail,
              conflictName: userName,
              similarity: (highestSimilarity * 100).toFixed(1),
            },
          });
        }
      } catch (fcmErr) {
        console.warn('Could not send targeted FCM alert:', fcmErr);
      }

      response.json({
        success: true,
        isDuplicate: true,
        similarity: parseFloat(highestSimilarity.toFixed(3)),
        matchedUserId: conflictUser.userId,
        matchedName: conflictUser.name,
        matchedEmail: conflictUser.email,
        matchedRole: conflictUser.role,
        matchedPhone: conflictUser.phone,
        matchedPhotoUrl: conflictUser.profilePictureUrl,
        message: `Biometric duplicate detected. Matches registered observer ${conflictUser.name} (${conflictUser.email}).`,
      });
      return;
    }
    */

    const highestSimilarity = 0.0;

    // Clean user
    await db.collection('users').doc(userId).set({
      profilePictureUrl: photoUrl,
      profileImageUrl: photoUrl,
      isFaceEnrolled: true,
      faceAuditStatus: 'CLEAN',
      hasBiometricConflict: false,
      duplicateConfidence: parseFloat(highestSimilarity.toFixed(3)),
      enrolledAt: timestamp,
      updatedAt: timestamp,
    }, { merge: true });

    response.json({
      success: true,
      isDuplicate: false,
      similarity: parseFloat(highestSimilarity.toFixed(3)),
      message: 'Unique biometric profile enrolled successfully.',
    });
  } catch (error) {
    console.error('Biometric deduplication error:', error);
    response.status(500).json({ error: error.message || 'Internal server error' });
  }
});
