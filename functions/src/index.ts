import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// ============================================================
//  validateKey — Chamado pelo launcher pra validar a key
// ============================================================
export const validateKey = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ valid: false, error: "Method not allowed" });
    return;
  }

  const { key, hwid } = req.body;

  if (!key || typeof key !== "string") {
    res.status(400).json({ valid: false, error: "Key obrigatória" });
    return;
  }

  try {
    const doc = await db.collection("licenses").doc(key).get();

    if (!doc.exists) {
      res.status(200).json({ valid: false, error: "Key não encontrada" });
      return;
    }

    const license = doc.data()!;

    if (license.status === "revoked") {
      res.status(200).json({ valid: false, error: "Key revogada" });
      return;
    }

    if (license.status === "expired") {
      res.status(200).json({ valid: false, error: "Key expirada" });
      return;
    }

    const now = new Date();
    if (license.expiresAt && new Date(license.expiresAt.toDate()) < now) {
      await db.collection("licenses").doc(key).update({ status: "expired" });
      res.status(200).json({ valid: false, error: "Key expirada" });
      return;
    }

    // HWID check
    if (license.hwid && hwid && license.hwid !== hwid) {
      res.status(200).json({
        valid: false,
        error: "Key associada a outro dispositivo",
      });
      return;
    }

    // Primeira vez: salva o HWID
    if (!license.hwid && hwid) {
      await db.collection("licenses").doc(key).update({ hwid });
    }

    // Atualiza último check
    await db.collection("licenses").doc(key).update({ lastCheck: now });

    res.status(200).json({
      valid: true,
      plan: license.plan || "weekly",
      expiresAt: license.expiresAt
        ? license.expiresAt.toDate().toISOString()
        : null,
    });
  } catch (err) {
    console.error("validateKey error:", err);
    res.status(500).json({ valid: false, error: "Erro interno" });
  }
});

// ============================================================
//  createLicense — Chamado pelo webhook do Kirvano
//  POST com secret pra autenticar
// ============================================================
export const createLicense = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  // Autenticação via secret
  const secret = req.headers["x-webhook-secret"];
  const EXPECTED_SECRET = functions.config().webhook?.secret || "CHANGE_ME";

  if (secret !== EXPECTED_SECRET) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { key, plan, discordId, email } = req.body;

  if (!key || !plan) {
    res.status(400).json({ error: "key e plan obrigatórios" });
    return;
  }

  // Duração do plano em dias
  const PLAN_DAYS: Record<string, number> = {
    weekly: 7,
    monthly: 30,
    annual: 365,
    premium: 365,
  };

  const days = PLAN_DAYS[plan];
  if (!days) {
    res.status(400).json({ error: "Plan inválido" });
    return;
  }

  try {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

    await db.collection("licenses").doc(key).set({
      key,
      plan,
      status: "active",
      createdAt: now,
      expiresAt,
      hwid: "",
      discordId: discordId || "",
      email: email || "",
      lastCheck: null,
    });

    console.log(`License created: ${key} (${plan}) for ${email || discordId}`);
    res.status(200).json({ success: true, key, plan, expiresAt });
  } catch (err) {
    console.error("createLicense error:", err);
    res.status(500).json({ error: "Erro interno" });
  }
});

// ============================================================
//  revokeLicense — Pra desativar uma key
// ============================================================
export const revokeLicense = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const secret = req.headers["x-webhook-secret"];
  const EXPECTED_SECRET = functions.config().webhook?.secret || "CHANGE_ME";

  if (secret !== EXPECTED_SECRET) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { key } = req.body;

  if (!key) {
    res.status(400).json({ error: "key obrigatória" });
    return;
  }

  try {
    await db.collection("licenses").doc(key).update({ status: "revoked" });
    res.status(200).json({ success: true });
  } catch (err) {
    console.error("revokeLicense error:", err);
    res.status(500).json({ error: "Erro interno" });
  }
});
