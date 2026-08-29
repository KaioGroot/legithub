import luaparse from "luaparse";
import { readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

const ROOT = resolve(import.meta.dirname, "..");

const COMPOUND = {
  "+=": "+",
  "-=": "-",
  "*=": "*",
  "/=": "/",
  "%=": "%",
  "^=": "^",
  "..=": "..",
};

// Converte sintaxe exclusiva do Luau para Lua 5.4 (so para checagem de sintaxe):
//   x += 1  ->  x = x + 1
function luauToLua5(src) {
  src = src.replace(/\r\n/g, "\n");
  const lines = src.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const m = line.match(/^(.*?)([%\w_.]+)\s*(\+=|-=|\*=|\/=|%=|\^=|\.\.=)(.*)$/);
    if (m && COMPOUND[m[3]]) {
      const [, pre, id, op, rest] = m;
      lines[i] = `${pre}${id} = ${id} ${COMPOUND[op]}${rest}`;
    }
  }
  return lines.join("\n");
}

function walk(dir, out = []) {
  for (const file of readdirSync(dir, { withFileTypes: true })) {
    if (file.name === "node_modules" || file.name === ".git") continue;
    const p = join(dir, file.name);
    if (file.isDirectory()) walk(p, out);
    else if (file.name.endsWith(".lua")) out.push(p);
  }
  return out;
}

const targets = process.argv.slice(2);
const files = targets.length ? targets : walk(ROOT);

let failed = false;
for (const file of files) {
  let src;
  try {
    src = readFileSync(file, "utf8");
  } catch (e) {
    console.error(`[ERRO] nao foi possivel ler ${file}`);
    failed = true;
    continue;
  }
  try {
    luaparse.parse(luauToLua5(src), { luaVersion: "5.2", comments: false, scope: false });
    console.log(`  [OK] ${file}`);
  } catch (e) {
    failed = true;
    console.error(`  [FALHA] ${file}`);
    console.error(`    ${e.message}`);
    if (e.lineNumber) console.error(`    (linha ${e.lineNumber})`);
  }
}

if (failed) {
  console.error("\nValidacao falhou. Corrija antes de publicar.");
  process.exit(1);
} else {
  console.log(`\nTudo ok (${files.length} arquivo(s)).`);
}