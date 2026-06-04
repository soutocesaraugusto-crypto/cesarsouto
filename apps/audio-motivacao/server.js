"use strict";

/**
 * OMNI — App de Hipnose Coletiva Motivacional
 * Tema -> roteiro no estilo da Rafa (Claude) -> áudio com a voz dela (Voxtral).
 * App simples com job assíncrono + polling.
 */

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

// Carrega o .env raiz (MISTRAL/GROQ/etc) e depois o local (ANTHROPIC/PORT, com precedência).
const rootEnv = path.join(__dirname, "..", "..", ".env");
const envPath = path.join(__dirname, ".env");
if (fs.existsSync(rootEnv)) require("dotenv").config({ path: rootEnv });
if (fs.existsSync(envPath)) require("dotenv").config({ path: envPath, override: true });

const express = require("express");
const { gerarRoteiro, DURACAO } = require("./lib/script-generator");
const { sintetizar, listVoices } = require("./lib/tts");
const { getStatus, upsertEnv, saveUserVoice, validarChave, TONS } = require("./lib/setup-status");

const PORT = parseInt(process.env.PORT || "7791", 10);
const BIND = "127.0.0.1";
const JOBS_DIR = path.join(__dirname, "data", "jobs");
fs.mkdirSync(JOBS_DIR, { recursive: true });

const app = express();
app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));

const jobs = new Map(); // id -> job

function saveJob(job) {
  jobs.set(job.id, job);
  try { fs.writeFileSync(path.join(JOBS_DIR, `${job.id}.json`), JSON.stringify(job, null, 2)); } catch (e) {}
}

function publicJob(job) {
  return {
    id: job.id, status: job.status, tema: job.tema, duracao: job.duracao, voz: job.voz,
    progresso: job.progresso, erro: job.erro,
    audioUrl: job.status === "pronto" ? `audio/${job.id}.mp3` : null,
    roteiroUrl: job.status === "pronto" ? `roteiro/${job.id}.txt` : null,
    criadoEm: job.criadoEm,
  };
}

async function processar(job) {
  try {
    job.status = "roteiro"; saveJob(job);
    const segments = await gerarRoteiro(job.tema, job.duracao);

    const roteiroTxt = segments.map((s) => s.texto).join("\n\n");
    fs.writeFileSync(path.join(JOBS_DIR, `${job.id}.txt`), roteiroTxt);

    job.status = "sintetizando";
    job.progresso = { i: 0, total: segments.length };
    saveJob(job);

    const outFile = path.join(JOBS_DIR, `${job.id}.mp3`);
    await sintetizar(segments, outFile, (p) => {
      job.progresso = { i: p.i, total: p.total };
      saveJob(job);
    }, job.voz);

    job.status = "pronto"; saveJob(job);
  } catch (err) {
    job.status = "erro";
    job.erro = err.message;
    saveJob(job);
  }
}

app.post("/api/generate", (req, res) => {
  const { tema, duracao, voz } = req.body || {};
  if (!tema || !tema.trim()) return res.status(400).json({ erro: "Informe um tema." });
  const st = getStatus();
  if (!st.ready) {
    const faltam = [];
    if (!st.ffmpeg) faltam.push("ffmpeg (rode o instalador de novo)");
    if (!st.mistral) faltam.push("chave da Mistral");
    if (!st.roteiro.ok) faltam.push("chave de roteiro (Google/OpenRouter/Anthropic)");
    if (!st.voice.ok) faltam.push("gravar sua voz (" + st.voice.faltando.join(", ") + ")");
    return res.status(412).json({ erro: "Configuração incompleta: falta " + faltam.join(", ") + ".", setup: true });
  }
  const dur = DURACAO[duracao] ? duracao : "media";
  const vozIds = listVoices().map((v) => v.id);
  const vozId = vozIds.includes(voz) ? voz : vozIds[0];

  const job = {
    id: crypto.randomBytes(6).toString("hex"),
    tema: tema.trim().slice(0, 300),
    duracao: dur,
    voz: vozId,
    status: "fila",
    progresso: null,
    erro: null,
    criadoEm: new Date().toISOString(),
  };
  saveJob(job);
  setImmediate(() => processar(job));
  res.json({ id: job.id });
});

app.get("/api/job/:id", (req, res) => {
  const job = jobs.get(req.params.id);
  if (!job) return res.status(404).json({ erro: "Job não encontrado." });
  res.json(publicJob(job));
});

app.get("/audio/:id.mp3", (req, res) => {
  const f = path.join(JOBS_DIR, `${req.params.id}.mp3`);
  if (!fs.existsSync(f)) return res.status(404).send("não encontrado");
  res.type("audio/mpeg").sendFile(f);
});

app.get("/roteiro/:id.txt", (req, res) => {
  const f = path.join(JOBS_DIR, `${req.params.id}.txt`);
  if (!fs.existsSync(f)) return res.status(404).send("não encontrado");
  res.type("text/plain; charset=utf-8").sendFile(f);
});

app.get("/api/voices", (_req, res) => res.json({ vozes: listVoices() }));

// ── Onboarding: diagnóstico do ambiente e gravação das chaves ────────────────
app.get("/api/setup/status", (_req, res) => {
  try { res.json(getStatus()); }
  catch (e) { res.status(500).json({ erro: e.message }); }
});

app.post("/api/setup/save", async (req, res) => {
  const b = req.body || {};
  const candidatas = {};
  // Aceita só as chaves conhecidas; ignora o resto.
  for (const k of ["MISTRAL_API_KEY", "GOOGLE_AI_STUDIO_API_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_API_KEY"]) {
    if (typeof b[k] === "string" && b[k].trim()) candidatas[k] = b[k].trim();
  }
  if (Object.keys(candidatas).length === 0) {
    return res.status(400).json({ erro: "Nenhuma chave informada." });
  }
  // Testa cada chave de verdade antes de gravar. Só grava as válidas.
  const validas = {};
  const invalidas = []; // chave inválida (rejeitada pela API)
  const semRede = [];   // não deu pra testar (offline)
  for (const [k, v] of Object.entries(candidatas)) {
    const r = await validarChave(k, v);
    if (r.ok) validas[k] = v;
    else if (r.motivo === "rede") semRede.push(k);
    else invalidas.push(k);
  }
  try {
    if (Object.keys(validas).length) upsertEnv(validas);
  } catch (e) {
    return res.status(500).json({ erro: "Não foi possível salvar: " + e.message });
  }
  if (invalidas.length || semRede.length) {
    return res.status(422).json({ erro: "Algumas chaves não passaram no teste.", invalidas, semRede, status: getStatus() });
  }
  res.json({ ok: true, status: getStatus() });
});

// Recebe uma amostra de voz (corpo binário) para um tom. ?tom=hipnose&nome=Fulano
app.post("/api/setup/voice", express.raw({ type: "*/*", limit: "40mb" }), (req, res) => {
  const tom = String(req.query.tom || "");
  const nome = req.query.nome ? String(req.query.nome) : "";
  if (!TONS.includes(tom)) return res.status(400).json({ erro: "Tom inválido." });
  if (!req.body || !req.body.length) return res.status(400).json({ erro: "Áudio vazio." });
  try {
    const voice = saveUserVoice(req.body, tom, nome);
    res.json({ ok: true, voice, status: getStatus() });
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.get("/api/health", (_req, res) => res.json({ ok: true, port: PORT }));

// Recuperação no boot: recarrega jobs persistidos e marca como "erro" qualquer um
// que ficou em andamento (órfão de um reinício do servidor), evitando spinner infinito.
function recuperarJobs() {
  let recuperados = 0, orfaos = 0;
  for (const f of fs.readdirSync(JOBS_DIR).filter((x) => x.endsWith(".json"))) {
    try {
      const job = JSON.parse(fs.readFileSync(path.join(JOBS_DIR, f), "utf8"));
      if (["fila", "roteiro", "sintetizando"].includes(job.status)) {
        job.status = "erro";
        job.erro = "Geração interrompida (reinício do servidor). Gere novamente.";
        fs.writeFileSync(path.join(JOBS_DIR, f), JSON.stringify(job, null, 2));
        orfaos++;
      }
      jobs.set(job.id, job);
      recuperados++;
    } catch (e) {}
  }
  if (recuperados) console.log(`📂  ${recuperados} jobs recarregados (${orfaos} órfãos → erro)`);
}

recuperarJobs();
app.listen(PORT, BIND, () => {
  console.log(`🌀  Audio Motivação rodando em http://${BIND}:${PORT}`);
});
