-- =====================================================
--  Script para criar keys de teste no Firestore
--
--  USO:
--   1) Instale Node.js
--   2) npm install firebase-admin
--   3) Baixe a service account key do Firebase Console
--   4) Rode: node create-license.js LH-TEST-TEST-TEST monthly
-- =====================================================

const admin = require("firebase-admin");

// Caminho pra service account key (baixe no Firebase Console)
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createLicense(key, plan, days) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  await db.collection("licenses").doc(key).set({
    key,
    plan,
    status: "active",
    createdAt: now,
    expiresAt,
    hwid: "",
    discordId: "",
    email: "",
    lastCheck: null,
  });

  console.log(`✓ Key criada: ${key}`);
  console.log(`  Plano: ${plan}`);
  console.log(`  Expira em: ${expiresAt.toISOString()}`);
}

// Planos
const PLANS = {
  weekly: 7,
  monthly: 30,
  annual: 365,
  premium: 365,
};

// Args
const key = process.argv[2] || "LH-TEST-TEST-TEST";
const plan = process.argv[3] || "monthly";
const days = PLANS[plan] || 30;

createLicense(key, plan, days)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Erro:", err);
    process.exit(1);
  });
