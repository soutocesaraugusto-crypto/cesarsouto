"use strict";

/**
 * Gerador do MIOLO do roteiro (blocos 4–6: visualização + sugestões + mantra)
 * no estilo do Michael, via Claude (Anthropic). Os blocos fixos vêm de fixed-blocks.js.
 *
 * Retorna o roteiro completo já segmentado por tom:
 *   [{ tom, texto, fixed }]
 */

const https = require("https");
const os = require("os");
const { spawn } = require("child_process");
const { INTRO, APROFUNDAMENTO, PONTE, EMERSAO, FECHAMENTO } = require("./fixed-blocks");

// Provider chain (em ordem). Cada um é tentado; se falhar (sem saldo/erro), cai para o próximo.
// Override: HIPNOSE_PROVIDER = openrouter | gemini | anthropic
const MODEL = process.env.HIPNOSE_MODEL || "auto";

// Alvo de palavras do miolo por duração (fixos somam ~300 palavras / ~2 min)
const DURACAO = {
  curta:    { palavras: 230,  rotulo: "curta (~3 min)" },
  media:    { palavras: 620,  rotulo: "média (~6 min)" },
  completa: { palavras: 1150, rotulo: "completa (~10 min)" },
  longa:    { palavras: 1900, rotulo: "longa (~15 min)" },
  extensa:  { palavras: 2600, rotulo: "extensa (~20 min)" },
  profunda: { palavras: 4000, rotulo: "profunda (~30 min)" },
};

const SYSTEM_MOTIVACIONAL = `Você é uma hipnoterapeuta especialista escrevendo o MIOLO de um áudio de autohipnose motivacional em português do Brasil. Você recebe um TEMA e escreve apenas os blocos centrais (visualização + sugestões + mantra) — a indução, o aprofundamento e a emersão já existem e NÃO devem ser escritos por você.

ESTILO OBRIGATÓRIO:
- 2ª pessoa do singular ("você"), tempo presente, sempre afirmativo. Nunca use frases no negativo.
- Marcadores frequentes: "Muito bem", "Ótimo".
- Loops recursivos: "quanto mais X, mais Y".
- Empilhamento: "sentindo ótimo, sentindo incrível, sentindo extraordinário".
- Frases curtas, ritmadas, hipnóticas. Repetição para ênfase.
- Audiência GENÉRICA: sem jargão interno, sem nomes próprios.

ESTRUTURA DO MIOLO:
1. VISUALIZAÇÃO (tom: hipnose): comece SEMPRE com "Eu quero que você imagine agora que você está numa sala..." e construa um cenário coerente com o tema.
2. SUGESTÕES (tom: motivacional): sugestões diretas, convicção, impacto.
3. MANTRA (tom: motivacional): afirmação curta em 1ª pessoa para a pessoa repetir na mente.

SAÍDA: responda APENAS um JSON válido (sem markdown), array de segmentos:
[{ "tom": "hipnose", "texto": "..." }, { "tom": "motivacional", "texto": "..." }]
Use só os tons "hipnose" e "motivacional". Agrupe frases do mesmo tom num único segmento.`;

const SYSTEM_TRATAMENTO = `Você é uma hipnoterapeuta clínica especialista em reprogramação mental escrevendo o MIOLO de um áudio de hipnoterapia para tratamento em português do Brasil. Você recebe um TEMA DE TRATAMENTO e escreve apenas os blocos centrais — a indução, o aprofundamento e a emersão já existem e NÃO devem ser escritos por você.

ESTILO OBRIGATÓRIO:
- 2ª pessoa do singular ("você"), tempo presente, sempre afirmativo. Nunca use negativas.
- Tom: calmo, profundo, seguro, acolhedor — nunca energético ou animado.
- Linguagem clínica hipnoterápica: ressignificação, dissociação, âncora, novo padrão de crença.
- Frases longas, hipnóticas, com ritmo de indução profunda.
- Foco em transformação de padrão, não em motivação superficial.

ESTRUTURA DO MIOLO (tratamento):
1. RESSIGNIFICAÇÃO (tom: hipnose): inicie com "Quero que você perceba que em algum lugar dentro de você..." — trabalhe o padrão que precisa ser transformado, usando dissociação e perspectiva de observador interno.
2. TRABALHO TERAPÊUTICO (tom: hipnose): instalação do novo padrão — sugestões diretas de transformação profunda de crença e comportamento.
3. ÂNCORA (tom: normal): uma âncora de ativação — um gesto ou palavra-gatilho que o cliente pode usar fora da sessão para acessar esse estado de transformação.

SAÍDA: responda APENAS um JSON válido (sem markdown), array de segmentos:
[{ "tom": "hipnose", "texto": "..." }, { "tom": "normal", "texto": "..." }]
Use só os tons "hipnose" e "normal". Agrupe frases do mesmo tom num único segmento.`;

function httpsPostJSON(hostname, path, headers, bodyObj) {
  const body = Buffer.from(JSON.stringify(bodyObj));
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname, path, method: "POST", headers: { ...headers, "Content-Length": body.length } },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

// ── Providers de LLM (retornam o texto bruto da resposta) ──────────────────────

// Preferido: usa o CLI do Claude (assinatura já autenticada na máquina) — NÃO gasta créditos de API.
// Roda a partir de /tmp para não carregar o CLAUDE.md do projeto.
function viaClaudeCLI(system, user) {
  const model = process.env.HIPNOSE_CLI_MODEL || "sonnet";
  const args = [
    "-p", user,
    "--system-prompt", system,
    "--model", model,
    "--output-format", "text",
    "--exclude-dynamic-system-prompt-sections",
  ];
  // Remove ANTHROPIC_API_KEY do ambiente do filho: assim o CLI usa o login por ASSINATURA (OAuth),
  // não a chave de API (que está sem saldo). É isso que evita gastar créditos.
  const childEnv = { ...process.env };
  delete childEnv.ANTHROPIC_API_KEY;
  delete childEnv.ANTHROPIC_AUTH_TOKEN;

  return new Promise((resolve, reject) => {
    // stdin ignorado (evita o aviso "no stdin data"); cwd em /tmp p/ não carregar CLAUDE.md do projeto.
    const child = spawn("claude", args, { cwd: os.tmpdir(), env: childEnv, stdio: ["ignore", "pipe", "pipe"] });
    let out = "", errb = "";
    const timeoutMs = parseInt(process.env.HIPNOSE_CLI_TIMEOUT_MS || "75000", 10);
    const killer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (errb += d));
    child.on("error", (e) => { clearTimeout(killer); reject(new Error(`claude CLI: ${e.message}`)); });
    child.on("close", (code) => {
      clearTimeout(killer);
      const t = out.trim();
      if (t) return resolve(t);
      reject(new Error(`claude CLI (code ${code}): ${errb.slice(0, 200) || "vazio"}`));
    });
  });
}

async function viaOpenRouter(system, user) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error("sem OPENROUTER_API_KEY");
  const model = process.env.HIPNOSE_OPENROUTER_MODEL || "anthropic/claude-sonnet-4";
  const res = await httpsPostJSON("openrouter.ai", "/api/v1/chat/completions",
    { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    { model, temperature: 0.8, messages: [{ role: "system", content: system }, { role: "user", content: user }] });
  if (res.status !== 200) throw new Error(`OpenRouter ${res.status}: ${res.body.slice(0, 200)}`);
  const j = JSON.parse(res.body);
  return j.choices?.[0]?.message?.content || "";
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function viaGemini(system, user) {
  const key = process.env.GOOGLE_AI_STUDIO_API_KEY || process.env.GEMINI_API_KEY;
  if (!key) throw new Error("sem GOOGLE_AI_STUDIO_API_KEY");
  const models = process.env.HIPNOSE_GEMINI_MODEL
    ? [process.env.HIPNOSE_GEMINI_MODEL]
    : ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.5-flash-lite", "gemini-flash-latest"];
  let last = "";
  for (const model of models) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const res = await httpsPostJSON("generativelanguage.googleapis.com",
        `/v1beta/models/${model}:generateContent?key=${key}`,
        { "Content-Type": "application/json" },
        { systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: "user", parts: [{ text: user }] }],
          generationConfig: { temperature: 0.8 } });
      if (res.status === 200) {
        const j = JSON.parse(res.body);
        const out = (j.candidates?.[0]?.content?.parts || []).map((p) => p.text || "").join("");
        if (out.trim()) return out;
      }
      last = `${model} ${res.status}: ${res.body.slice(0, 120)}`;
      if (res.status === 503 || res.status === 429) { await sleep(1500); continue; }
      break; // outros erros: pula pro próximo modelo
    }
  }
  throw new Error(`Gemini falhou — ${last}`);
}

async function viaAnthropic(system, user) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("sem ANTHROPIC_API_KEY");
  const model = process.env.HIPNOSE_ANTHROPIC_MODEL || "claude-sonnet-4-6";
  const res = await httpsPostJSON("api.anthropic.com", "/v1/messages",
    { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    { model, max_tokens: 4096, system, messages: [{ role: "user", content: user }] });
  if (res.status !== 200) throw new Error(`Anthropic ${res.status}: ${res.body.slice(0, 200)}`);
  const j = JSON.parse(res.body);
  return (j.content || []).map((b) => b.text || "").join("");
}

const PROVIDERS = { cli: viaClaudeCLI, openrouter: viaOpenRouter, gemini: viaGemini, anthropic: viaAnthropic };

async function chamarLLM(system, user) {
  const forced = process.env.HIPNOSE_PROVIDER;
  const ordem = forced ? [forced] : ["cli", "gemini", "openrouter", "anthropic"];
  const erros = [];
  for (const nome of ordem) {
    const fn = PROVIDERS[nome];
    if (!fn) continue;
    try {
      const out = await fn(system, user);
      if (out && out.trim()) return { texto: out, provider: nome };
    } catch (e) { erros.push(`${nome}: ${e.message}`); }
  }
  throw new Error(`Todos os providers falharam — ${erros.join(" | ")}`);
}

async function gerarMiolo(tema, duracao, modo, nomeCliente = "", doresCliente = "") {
  const cfg = DURACAO[duracao] || DURACAO.media;
  const system = modo === "tratamento" ? SYSTEM_TRATAMENTO : SYSTEM_MOTIVACIONAL;

  const instrucaoInicio = modo === "tratamento"
    ? `Lembre: comece a ressignificação com "Quero que você perceba que em algum lugar dentro de você...".`
    : `Lembre: comece a visualização com "Eu quero que você imagine agora que você está numa sala...".`;

  const linhasContexto = [];
  if (modo === "tratamento") {
    linhasContexto.push(`TEMA DE TRATAMENTO: ${tema}`);
    if (nomeCliente) linhasContexto.push(`NOME DO CLIENTE: ${nomeCliente}`);
    if (doresCliente) linhasContexto.push(`DORES E CONTEXTO ESPECÍFICO:\n${doresCliente}`);
  } else {
    linhasContexto.push(`TEMA: ${tema}`);
    if (nomeCliente) linhasContexto.push(`NOME DO OUVINTE: ${nomeCliente}`);
  }

  const instrucaoNome = nomeCliente
    ? `Use o nome "${nomeCliente}" naturalmente ao longo do áudio (ex.: "${nomeCliente}, quero que você perceba..."). Não use o nome em excesso — de 3 a 5 vezes ao longo do roteiro. `
    : "";

  const instrucaoDores = (modo === "tratamento" && doresCliente)
    ? `Personalize o trabalho terapêutico especificamente para as dores listadas — vá além do tema geral e trate o que o cliente descreveu. `
    : "";

  const userMsg =
    linhasContexto.join("\n") + "\n\n" +
    instrucaoNome +
    instrucaoDores +
    `Escreva o miolo com aproximadamente ${cfg.palavras} palavras no total ` +
    `(versão ${cfg.rotulo}). ${instrucaoInicio} ` +
    `Responda só o JSON.`;

  const { texto, provider } = await chamarLLM(system, userMsg);
  if (process.env.NODE_ENV !== "production") console.log(`[script-generator] provider=${provider} modo=${modo} cliente=${nomeCliente || "-"}`);
  const match = texto.match(/\[[\s\S]*\]/);
  if (!match) throw new Error(`LLM não retornou JSON válido:\n${texto.slice(0, 400)}`);

  const segs = JSON.parse(match[0]);
  if (!Array.isArray(segs) || segs.length === 0) throw new Error("Miolo vazio");
  return segs
    .filter((s) => s && s.texto && s.texto.trim())
    .map((s) => ({
      tom: ["hipnose", "motivacional", "normal"].includes(s.tom) ? s.tom : "hipnose",
      texto: s.texto.trim(),
    }));
}

/**
 * Monta o roteiro completo (fixos + miolo) já segmentado por tom.
 * @param {string} tema
 * @param {string} duracao
 * @param {"motivacional"|"tratamento"|"proprio"} [modo]
 * @param {string} [roteiroCustom] — texto livre quando modo="proprio"
 * @returns {Promise<Array<{tom,texto,fixed}>>}
 */
async function gerarRoteiro(tema, duracao, modo = "motivacional", roteiroCustom = "", nomeCliente = "", doresCliente = "") {
  const fixo = (b) => ({ ...b, fixed: true });
  const dyn  = (s) => ({ ...s, fixed: false });

  if (modo === "proprio") {
    if (!roteiroCustom || !roteiroCustom.trim()) throw new Error("Roteiro próprio vazio.");
    // Substitui placeholder [NOME] pelo nome real do cliente, se informado
    const texto = nomeCliente
      ? roteiroCustom.trim().replace(/\[NOME\]/gi, nomeCliente)
      : roteiroCustom.trim();
    return [
      fixo(INTRO),
      dyn({ tom: "normal", texto }),
      fixo(EMERSAO),
    ];
  }

  const miolo = await gerarMiolo(tema, duracao, modo, nomeCliente, doresCliente);
  return [
    fixo(INTRO),
    fixo(APROFUNDAMENTO),
    fixo(PONTE),
    ...miolo.map(dyn),
    fixo(EMERSAO),
  ];
}

module.exports = { gerarRoteiro, gerarMiolo, DURACAO, MODEL };
