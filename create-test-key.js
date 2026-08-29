// =====================================================
//  Cria key de teste no Firestore (via service account)
//  Requer service-account-key.json na raiz (gitignored)
//  Rode: node create-test-key.js [LH-XXXX-XXXX-XXXX]
// =====================================================

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const saPath = path.resolve(__dirname, "service-account-key.json");
if (!fs.existsSync(saPath)) {
  console.error("service-account-key.json nao encontrado na raiz (gitignored).");
  process.exit(1);
}
const sa = JSON.parse(fs.readFileSync(saPath, "utf8"));
const PROJECT_ID = sa.project_id;

const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
const segment = () =>
  Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");

const KEY = process.argv[2] || `LH-TEST-${segment()}-${segment()}`;
const PLAN = process.argv[3] || "monthly";
const DAYS = Number(process.argv[4] || 30);

function b64url(obj) {
  return Buffer.from(JSON.stringify(obj)).toString("base64url");
}

async function getToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const toSign = `${b64url(header)}.${b64url(payload)}`;
  const sig = crypto
    .createSign("RSA-SHA256")
    .update(toSign)
    .sign(sa.private_key, "base64url");
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${toSign}.${sig}`,
    }).toString(),
  });
  const data = await resp.json();
  if (!data.access_token) throw new Error(`token: ${data.error_description || resp.status}`);
  return data.access_token;
}

function toFields(data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null) fields[k] = { nullValue: null };
    else if (typeof v === "string") fields[k] = { stringValue: v };
    else if (typeof v === "boolean") fields[k] = { booleanValue: v };
    else if (typeof v === "number")
      fields[k] = Number.isInteger(v) ? { integerValue: v } : { doubleValue: v };
  }
  return fields;
}

(async () => {
  const token = await getToken();
  const now = new Date();
  const exp = new Date(now.getTime() + DAYS * 24 * 60 * 60 * 1000);
  const data = {
    key: KEY,
    plan: PLAN,
    status: "active",
    createdAt: now.toISOString(),
    expiresAt: exp.toISOString(),
    hwid: "",
    discordId: "",
    email: "",
    lastCheck: null,
  };
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/licenses/${encodeURIComponent(KEY)}`;
  const resp = await fetch(url, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ fields: toFields(data) }),
  });
  if (!resp.ok) {
    const t = await resp.text();
    console.error("Erro:", resp.status, t.slice(0, 300));
    process.exit(1);
  }
  console.log("Key criada com sucesso!");
  console.log("  Key:", KEY);
  console.log("  Plano:", PLAN);
  console.log("  Expira em:", exp.toISOString());
})().catch((e) => {
  console.error("Erro:", e.message);
  process.exit(1);
});