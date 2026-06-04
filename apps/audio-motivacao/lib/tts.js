"use strict";

/**
 * Síntese de voz via Voxtral (Mistral) com clonagem da voz do Michael.
 * Reaproveita a lógica comprovada do scripts/voxtral-tts-multi.js, com duas adições:
 *   - cache de PCM dos blocos fixos (indução/aprofundamento/emersão são idênticos sempre)
 *   - callback de progresso por segmento (para o job assíncrono do webapp)
 *
 * Áudio interno: float32 LE, 24000 Hz, mono.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const https = require("https");
const { execFileSync, spawnSync } = require("child_process");
const { gerarFundoPCM, VOLUME_FUNDO } = require("./background-audio");

const APP_ROOT = path.join(__dirname, "..");
// Config de voz LOCAL do app (Rafa). Não usa o voxtral-voices.json compartilhado (Michael).
const VOICES_FILE = path.join(APP_ROOT, "data", "voices.json");
const CACHE_DIR = path.join(APP_ROOT, "cache");
const MODEL = process.env.VOXTRAL_MODEL || "voxtral-mini-tts-2603";

fs.mkdirSync(CACHE_DIR, { recursive: true });

const _resolvePath = (p) => (p && !path.isAbsolute(p) ? path.join(APP_ROOT, p) : p);

// Lê o config multi-voz e resolve os caminhos relativos de cada perfil.
function loadConfig() {
  let cfg;
  try { cfg = JSON.parse(fs.readFileSync(VOICES_FILE, "utf8")); }
  catch (e) { return { default: null, vozes: {} }; }
  for (const v of Object.values(cfg.vozes || {})) {
    for (const k of Object.keys(v.perfis || {})) v.perfis[k] = _resolvePath(v.perfis[k]);
    if (v.fallback) v.fallback = _resolvePath(v.fallback);
  }
  return cfg;
}

// Retorna o objeto da voz escolhida (com fallback pra default).
function getVoz(cfg, voz) {
  const vozes = cfg.vozes || {};
  return vozes[voz] || vozes[cfg.default] || Object.values(vozes)[0] || { perfis: {}, fallback: null };
}

// Lista de vozes disponíveis para a UI: [{ id, rotulo }]
function listVoices() {
  const cfg = loadConfig();
  return Object.entries(cfg.vozes || {}).map(([id, v]) => ({ id, rotulo: v.rotulo || id }));
}

function resolveVoice(voz, tone) {
  const p = voz.perfis || {};
  if (p[tone] && fs.existsSync(p[tone])) return p[tone];
  if (voz.fallback && fs.existsSync(voz.fallback)) return voz.fallback;
  const any = Object.values(p).find((v) => v && fs.existsSync(v));
  return any || null;
}

// Re-encoda a referência de voz (qualidade máxima, evita artefatos). Cacheado por arquivo.
const _refCache = new Map();
function freshEncodeVoice(voiceFile) {
  const stat = fs.statSync(voiceFile);
  const key = `${voiceFile}:${stat.mtimeMs}`;
  if (_refCache.has(key)) return _refCache.get(key);
  const tmpWav = path.join(os.tmpdir(), `vox-ref-${Date.now()}.wav`);
  const tmpOgg = path.join(os.tmpdir(), `vox-ref-${Date.now()}.ogg`);
  try {
    execFileSync("ffmpeg", ["-i", voiceFile, "-ar", "24000", "-ac", "1", "-y", tmpWav], { stdio: "ignore" });
    execFileSync("ffmpeg", ["-i", tmpWav, "-c:a", "libopus", "-b:a", "128k", "-y", tmpOgg], { stdio: "ignore" });
    const buf = fs.readFileSync(tmpOgg);
    _refCache.set(key, buf);
    return buf;
  } finally {
    try { fs.unlinkSync(tmpWav); } catch (e) {}
    try { fs.unlinkSync(tmpOgg); } catch (e) {}
  }
}

function httpsPost(hostname, reqPath, headers, bodyBuffer) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname, path: reqPath, method: "POST", headers: { ...headers, "Content-Length": bodyBuffer.length } },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
      }
    );
    req.on("error", reject);
    req.write(bodyBuffer);
    req.end();
  });
}

async function generateSegmentPCM(text, voiceFile, apiKey) {
  const voiceBuffer = freshEncodeVoice(voiceFile);
  const body = Buffer.from(JSON.stringify({
    model: MODEL,
    input: text,
    response_format: "pcm",
    ref_audio: voiceBuffer.toString("base64"),
  }));
  const res = await httpsPost("api.mistral.ai", "/v1/audio/speech",
    { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" }, body);
  if (res.status !== 200) throw new Error(`Voxtral ${res.status}: ${res.body.toString().slice(0, 300)}`);
  const ct = res.headers?.["content-type"] || "";
  if (ct.includes("application/json")) {
    const j = JSON.parse(res.body.toString());
    const b64 = j.audio || j.audio_data || j.data || j.output;
    if (!b64) throw new Error(`Campo de áudio ausente. Chaves: ${Object.keys(j).join(", ")}`);
    return Buffer.from(b64, "base64");
  }
  return res.body;
}

function cacheKey(text, voiceFile) {
  return crypto.createHash("sha1").update(`${MODEL}|${voiceFile}|${text}`).digest("hex");
}

// Sintetiza um segmento, usando cache em disco quando fixed=true.
async function synthSegment(seg, voiceFile, apiKey) {
  if (seg.fixed) {
    const cf = path.join(CACHE_DIR, cacheKey(seg.texto, voiceFile) + ".pcm");
    if (fs.existsSync(cf)) return { pcm: fs.readFileSync(cf), cached: true };
    const pcm = await generateSegmentPCM(seg.texto, voiceFile, apiKey);
    fs.writeFileSync(cf, pcm);
    return { pcm, cached: false };
  }
  const pcm = await generateSegmentPCM(seg.texto, voiceFile, apiKey);
  return { pcm, cached: false };
}

function calcRMS(pcm) {
  const s = new Float32Array(pcm.buffer, pcm.byteOffset, pcm.length / 4);
  let sum = 0;
  for (let i = 0; i < s.length; i++) sum += s[i] * s[i];
  return Math.sqrt(sum / s.length);
}

function normalizePCM(pcm, targetRMS) {
  const s = new Float32Array(pcm.buffer, pcm.byteOffset, pcm.length / 4);
  const rms = calcRMS(pcm);
  if (rms === 0) return pcm;
  const scale = targetRMS / rms;
  const out = Buffer.alloc(pcm.length);
  for (let i = 0; i < s.length; i++) out.writeFloatLE(Math.max(-1, Math.min(1, s[i] * scale)), i * 4);
  return out;
}

// Silêncio em PCM float32 mono 24kHz
function silencePCM(seconds) {
  return Buffer.alloc(Math.round(24000 * seconds) * 4);
}

function pcmToMp3(pcm, outputFile, fundoFile = null, volFundo = 0.6) {
  if (!fundoFile) {
    const r = spawnSync("ffmpeg",
      ["-f", "f32le", "-ar", "24000", "-ac", "1", "-i", "pipe:0", "-q:a", "2", "-y", outputFile],
      { input: pcm, stdio: ["pipe", "ignore", "pipe"], maxBuffer: 1024 * 1024 * 512 });
    if (r.status !== 0) throw new Error(`ffmpeg PCM->MP3 falhou: ${r.stderr?.toString().slice(-300)}`);
    return;
  }

  // Escreve voz mono em arquivo temporário para mixagem
  const voiceTmp = path.join(os.tmpdir(), `voice-${Date.now()}.pcm`);
  try {
    fs.writeFileSync(voiceTmp, pcm);
    const voiceDurSec = pcm.length / 4 / 24000;

    const r = spawnSync("ffmpeg", [
      "-f", "f32le", "-ar", "24000", "-ac", "1", "-i", voiceTmp,
      "-f", "f32le", "-ar", "24000", "-ac", "2", "-i", fundoFile,
      "-filter_complex",
      `[0:a]pan=stereo|c0=c0|c1=c0,volume=0.90[v];` +
      `[1:a]volume=${volFundo},atrim=duration=${voiceDurSec}[bg];` +
      `[v][bg]amix=inputs=2:normalize=0[out]`,
      "-map", "[out]",
      "-q:a", "2", "-y", outputFile,
    ], { stdio: ["ignore", "ignore", "pipe"], maxBuffer: 1024 * 1024 * 512 });

    if (r.status !== 0) throw new Error(`ffmpeg mix falhou: ${r.stderr?.toString().slice(-300)}`);
  } finally {
    try { fs.unlinkSync(voiceTmp); } catch (e) {}
  }
}

/**
 * Sintetiza o roteiro completo em um MP3 com a voz escolhida.
 * @param {Array<{tom,texto,fixed}>} segments
 * @param {string} outputFile
 * @param {(p:{i:number,total:number,tom:string,cached:boolean})=>void} onProgress
 * @param {string} [voz] id da voz (ex: "rafa" | "michael"); cai pro default se omitido
 */
async function sintetizar(segments, outputFile, onProgress, voz, opcoesFundo = {}) {
  const apiKey = process.env.MISTRAL_API_KEY;
  if (!apiKey) throw new Error("MISTRAL_API_KEY não encontrada no ambiente");
  const vozObj = getVoz(loadConfig(), voz);

  const pcmBuffers = [];
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    const voiceFile = resolveVoice(vozObj, seg.tom);
    if (!voiceFile) throw new Error(`Sem referência de voz para o tom "${seg.tom}".`);
    const { pcm, cached } = await synthSegment(seg, voiceFile, apiKey);
    pcmBuffers.push(pcm);
    if (onProgress) onProgress({ i: i + 1, total: segments.length, tom: seg.tom, cached });
  }

  // Normaliza volume entre segmentos e intercala respiros curtos entre blocos.
  const targetRMS = pcmBuffers.map(calcRMS).reduce((a, b) => a + b, 0) / pcmBuffers.length;
  const gap = silencePCM(0.6);
  const parts = [];
  for (let i = 0; i < pcmBuffers.length; i++) {
    parts.push(normalizePCM(pcmBuffers[i], targetRMS));
    if (i < pcmBuffers.length - 1) parts.push(gap);
  }
  const voicePCM = Buffer.concat(parts);

  // Gera e mixa fundo se solicitado
  const { fundo, binaural, volumeFundo } = opcoesFundo;
  let fundoFile = null;
  if (fundo && fundo !== "silencio") {
    const durationSec = voicePCM.length / 4 / 24000;
    console.log(`[tts] gerando fundo: ${fundo} (${binaural || "theta"}) para ${Math.round(durationSec)}s`);
    fundoFile = gerarFundoPCM(fundo, binaural || "theta", durationSec);
  }

  const volNum = VOLUME_FUNDO[volumeFundo] ?? VOLUME_FUNDO.medio;
  try {
    pcmToMp3(voicePCM, outputFile, fundoFile, volNum);
  } finally {
    if (fundoFile) { try { fs.unlinkSync(fundoFile); } catch (e) {} }
  }
  return outputFile;
}

module.exports = { sintetizar, listVoices, loadConfig };
