"use strict";

/**
 * Diagnóstico de ambiente + leitura/escrita do .env local + voz do usuário.
 * Usado pela tela de onboarding: diz o que falta (ffmpeg, chaves, voz),
 * grava as chaves que a pessoa cola e salva as amostras de voz que ela grava,
 * tudo sem ela precisar editar arquivo nenhum.
 */

const fs = require("fs");
const os = require("os");
const path = require("path");
const https = require("https");
const crypto = require("crypto");
const { spawnSync, execFileSync } = require("child_process");

const APP_ROOT = path.join(__dirname, "..");
const ENV_FILE = path.join(APP_ROOT, ".env");
const VOICES_FILE = path.join(APP_ROOT, "data", "voices.json");
const VOICES_DIR = path.join(APP_ROOT, "data", "voices");

// Tons usados pelo roteiro (batem com fixed-blocks.js / script-generator).
const TONS = ["hipnose", "normal", "motivacional"];
// Id fixo da voz do dono do app (o aluno). Rótulo é o nome que ele digita.
const USER_VOICE_ID = "minha-voz";

const _resolveRel = (p) => (p && !path.isAbsolute(p) ? path.join(APP_ROOT, p) : p);

// Chaves que o onboarding gerencia. label/link aparecem na UI.
const KEYS = {
  MISTRAL_API_KEY: { rotulo: "Mistral (voz)", link: "https://console.mistral.ai/api-keys" },
  GOOGLE_AI_STUDIO_API_KEY: { rotulo: "Google AI Studio (roteiro)", link: "https://aistudio.google.com/apikey" },
  OPENROUTER_API_KEY: { rotulo: "OpenRouter (roteiro)", link: "https://openrouter.ai/keys" },
  ANTHROPIC_API_KEY: { rotulo: "Anthropic (roteiro)", link: "https://console.anthropic.com/settings/keys" },
};

// ── Detecção de binários ────────────────────────────────────────────────────

let _ffmpegCache = null;
function ffmpegOk() {
  if (_ffmpegCache !== null) return _ffmpegCache;
  try {
    const r = spawnSync("ffmpeg", ["-version"], { stdio: "ignore" });
    _ffmpegCache = r.status === 0;
  } catch (e) {
    _ffmpegCache = false;
  }
  return _ffmpegCache;
}

// Claude CLI logado por assinatura também serve como provider de roteiro (grátis).
function claudeCliOk() {
  try {
    const r = spawnSync("claude", ["--version"], { stdio: "ignore" });
    return r.status === 0;
  } catch (e) {
    return false;
  }
}

// ── Validação de chaves (chamada real, leve, à API de cada provedor) ──────────

function httpsGetStatus(hostname, reqPath, headers) {
  return new Promise((resolve) => {
    const req = https.request(
      { hostname, path: reqPath, method: "GET", headers, timeout: 12000 },
      (res) => { res.on("data", () => {}); res.on("end", () => resolve(res.statusCode || 0)); }
    );
    req.on("error", () => resolve(0));
    req.on("timeout", () => { req.destroy(); resolve(0); });
    req.end();
  });
}

/**
 * Testa se uma chave funciona de verdade. Retorna { ok, motivo }.
 * motivo: "ok" | "invalida" | "rede" (erro de conexão/timeout, não dá pra afirmar).
 */
async function validarChave(nome, valor) {
  const v = (valor || "").trim();
  if (!v) return { ok: false, motivo: "invalida" };
  let status = 0;
  if (nome === "MISTRAL_API_KEY") {
    status = await httpsGetStatus("api.mistral.ai", "/v1/models", { Authorization: `Bearer ${v}` });
  } else if (nome === "GOOGLE_AI_STUDIO_API_KEY") {
    status = await httpsGetStatus("generativelanguage.googleapis.com", `/v1beta/models?key=${encodeURIComponent(v)}`, {});
  } else if (nome === "OPENROUTER_API_KEY") {
    status = await httpsGetStatus("openrouter.ai", "/api/v1/key", { Authorization: `Bearer ${v}` });
  } else if (nome === "ANTHROPIC_API_KEY") {
    status = await httpsGetStatus("api.anthropic.com", "/v1/models", { "x-api-key": v, "anthropic-version": "2023-06-01" });
  } else {
    return { ok: false, motivo: "invalida" };
  }
  if (status === 200) return { ok: true, motivo: "ok" };
  if (status === 0) return { ok: false, motivo: "rede" }; // não conseguiu testar (offline?)
  return { ok: false, motivo: "invalida" }; // 401/403/400 etc.
}

// ── .env: leitura e escrita preservando o que já existe ───────────────────────

function readEnvFile() {
  const out = {};
  if (!fs.existsSync(ENV_FILE)) return out;
  for (const raw of fs.readFileSync(ENV_FILE, "utf8").split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const k = line.slice(0, eq).trim();
    let v = line.slice(eq + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    out[k] = v;
  }
  return out;
}

// Valor efetivo de uma chave: process.env tem precedência, depois o .env em disco.
function effectiveKey(name) {
  const v = process.env[name];
  if (v && v.trim()) return v.trim();
  const fromFile = readEnvFile()[name];
  return fromFile && fromFile.trim() ? fromFile.trim() : "";
}

function sanitizeValue(v) {
  return String(v == null ? "" : v).replace(/[\r\n]+/g, " ").trim();
}

/**
 * Atualiza/insere chaves no .env preservando linhas existentes e comentários.
 * Também aplica em process.env para valer sem reiniciar o servidor.
 */
function upsertEnv(updates) {
  let lines = [];
  if (fs.existsSync(ENV_FILE)) lines = fs.readFileSync(ENV_FILE, "utf8").split(/\r?\n/);

  for (const [key, rawVal] of Object.entries(updates)) {
    const val = sanitizeValue(rawVal);
    if (!val) continue; // não apaga chave existente com valor vazio
    const re = new RegExp(`^\\s*${key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*=`);
    const idx = lines.findIndex((l) => re.test(l));
    const newLine = `${key}=${val}`;
    if (idx >= 0) lines[idx] = newLine;
    else lines.push(newLine);
    process.env[key] = val;
  }

  while (lines.length && lines[lines.length - 1].trim() === "") lines.pop();
  fs.writeFileSync(ENV_FILE, lines.join("\n") + "\n", "utf8");
}

// ── Voz do usuário ────────────────────────────────────────────────────────────

function readVoices() {
  try { return JSON.parse(fs.readFileSync(VOICES_FILE, "utf8")); }
  catch (e) { return { default: null, vozes: {} }; }
}

function writeVoices(cfg) {
  fs.writeFileSync(VOICES_FILE, JSON.stringify(cfg, null, 2) + "\n", "utf8");
}

/**
 * Status da voz para a UI.
 * - Se o app não exige voz do usuário (requireUserVoice ausente/false), está OK
 *   (é o caso do app OMNI, que já vem com Rafa/Michael).
 * - Se exige, só fica OK quando os 3 tons foram gravados.
 */
function getVoiceStatus() {
  const cfg = readVoices();
  const required = !!cfg.requireUserVoice;
  if (!required) return { ok: true, required: false, gravados: [], faltando: [], tons: TONS, rotulo: null };

  const id = cfg.userVoice || USER_VOICE_ID;
  const voz = (cfg.vozes && cfg.vozes[id]) || { perfis: {} };
  const perfis = voz.perfis || {};
  const gravados = TONS.filter((t) => perfis[t] && fs.existsSync(_resolveRel(perfis[t])));
  const faltando = TONS.filter((t) => !gravados.includes(t));
  return { ok: faltando.length === 0, required: true, gravados, faltando, tons: TONS, rotulo: voz.rotulo || null };
}

/**
 * Salva uma amostra de voz (buffer de áudio em qualquer formato que o ffmpeg leia)
 * para um tom, convertendo para OGG/Opus 24kHz mono, e atualiza o voices.json.
 * @param {Buffer} buffer  bytes do áudio (webm/mp3/m4a/wav…)
 * @param {string} tom     "hipnose" | "normal" | "motivacional"
 * @param {string} [nome]  rótulo da voz (nome do aluno)
 * @returns {object} status de voz atualizado
 */
function saveUserVoice(buffer, tom, nome) {
  if (!TONS.includes(tom)) throw new Error(`Tom inválido: ${tom}`);
  if (!buffer || !buffer.length) throw new Error("Áudio vazio.");
  if (!ffmpegOk()) throw new Error("ffmpeg não disponível para converter o áudio.");

  fs.mkdirSync(VOICES_DIR, { recursive: true });
  const tmpIn = path.join(os.tmpdir(), `voz-${crypto.randomBytes(4).toString("hex")}.bin`);
  const relOut = path.join("data", "voices", `${USER_VOICE_ID}-${tom}.ogg`);
  const absOut = path.join(APP_ROOT, relOut);

  fs.writeFileSync(tmpIn, buffer);
  try {
    execFileSync("ffmpeg", ["-i", tmpIn, "-ar", "24000", "-ac", "1", "-c:a", "libopus", "-b:a", "128k", "-y", absOut], { stdio: "ignore" });
  } catch (e) {
    throw new Error("Não foi possível processar o áudio. Tente gravar de novo.");
  } finally {
    try { fs.unlinkSync(tmpIn); } catch (e) {}
  }

  // Atualiza o voices.json: cria/atualiza a voz do usuário e a torna padrão.
  const cfg = readVoices();
  cfg.vozes = cfg.vozes || {};
  const voz = cfg.vozes[USER_VOICE_ID] || { rotulo: "", perfis: {} };
  if (nome && nome.trim()) voz.rotulo = nome.trim().slice(0, 60);
  if (!voz.rotulo) voz.rotulo = "Minha voz";
  voz.perfis = voz.perfis || {};
  voz.perfis[tom] = relOut.replace(/\\/g, "/");
  // fallback = primeiro tom disponível (preferindo hipnose)
  voz.fallback = voz.perfis.hipnose || voz.perfis.normal || voz.perfis.motivacional || voz.fallback || null;
  cfg.vozes[USER_VOICE_ID] = voz;
  cfg.default = USER_VOICE_ID;
  cfg.userVoice = USER_VOICE_ID;
  writeVoices(cfg);

  return getVoiceStatus();
}

// ── Status agregado para a UI ─────────────────────────────────────────────────

function getStatus() {
  const mistral = !!effectiveKey("MISTRAL_API_KEY");
  const gemini = !!(effectiveKey("GOOGLE_AI_STUDIO_API_KEY") || effectiveKey("GEMINI_API_KEY"));
  const openrouter = !!effectiveKey("OPENROUTER_API_KEY");
  const anthropic = !!effectiveKey("ANTHROPIC_API_KEY");
  const cli = claudeCliOk();
  const ffmpeg = ffmpegOk();
  const voice = getVoiceStatus();

  // No app do aluno (requireUserVoice), o CLI NÃO conta como garantia de roteiro:
  // ele é imprevisível na máquina de cada um, então exigimos uma chave validada.
  // No app OMNI, o CLI (assinatura) continua valendo.
  const roteiroOk = gemini || openrouter || anthropic || (!voice.required && cli);
  const ready = ffmpeg && mistral && roteiroOk && voice.ok;

  return {
    ready,
    ffmpeg,
    node: process.version,
    mistral,
    roteiro: { ok: roteiroOk, gemini, openrouter, anthropic, cli },
    voice,
  };
}

module.exports = {
  getStatus, upsertEnv, readEnvFile, effectiveKey, ffmpegOk, validarChave,
  getVoiceStatus, saveUserVoice, TONS, KEYS, ENV_FILE,
};
