const admin = require('firebase-admin');

// Initialize Firebase Admin with ADC (Application Default Credentials)
admin.initializeApp({
  projectId: 'naijaobserve'
});

const db = admin.firestore();

async function run() {
  try {
    console.log('Fetching parties...');
    const snapshot = await db.collection('parties').get();
    if (snapshot.empty) {
      console.log('No parties found.');
      return;
    }
    snapshot.forEach(doc => {
      console.log(doc.id, '=>', JSON.stringify(doc.data(), null, 2));
    });
  } catch (error) {
    console.error('Error fetching parties:', error);
  }
}

run();
