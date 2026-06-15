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
