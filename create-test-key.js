// =====================================================
//  Script pra criar key de teste no Firestore
//  Rode: node create-test-key.js
// =====================================================

const https = require("https");

const API_KEY = "AIzaSyAubOqbL3_pNU9F3tCDVboN_9MCwitjXCQ";
const PROJECT_ID = "legithub-20dd6";

// Key de teste
const TEST_KEY = {
  key: "LH-TEST-TEST-TEST",
  plan: "monthly",
  status: "active",
  createdAt: new Date().toISOString(),
  expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
  hwid: "",
  discordId: "",
  email: "teste@legithub.com",
  lastCheck: null,
};

// Firestore REST API
const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/licenses?key=${API_KEY}`;

const body = JSON.stringify({
  fields: {
    key: { stringValue: TEST_KEY.key },
    plan: { stringValue: TEST_KEY.plan },
    status: { stringValue: TEST_KEY.status },
    createdAt: { timestampValue: TEST_KEY.createdAt },
    expiresAt: { timestampValue: TEST_KEY.expiresAt },
    hwid: { stringValue: TEST_KEY.hwid },
    discordId: { stringValue: TEST_KEY.discordId },
    email: { stringValue: TEST_KEY.email },
    lastCheck: { nullValue: null },
  },
});

const options = {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
  },
};

console.log("Criando key de teste...");

const req = https.request(url, options, (res) => {
  let data = "";
  res.on("data", (chunk) => (data += chunk));
  res.on("end", () => {
    if (res.statusCode === 200 || res.statusCode === 201) {
      console.log("✓ Key criada com sucesso!");
      console.log(`  Key: ${TEST_KEY.key}`);
      console.log(`  Plano: ${TEST_KEY.plan}`);
      console.log(`  Expira em: ${TEST_KEY.expiresAt}`);
    } else {
      console.error("✗ Erro:", res.statusCode, data);
    }
  });
});

req.on("error", (err) => {
  console.error("Erro de conexão:", err.message);
});

req.write(body);
req.end();
