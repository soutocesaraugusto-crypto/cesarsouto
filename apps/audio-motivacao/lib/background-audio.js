"use strict";

/**
 * Geração de áudio de fundo: binaural, natureza (pink noise) e drone relaxante.
 * Usa FFmpeg para geração eficiente — sem carregar buffers gigantes em RAM.
 * Retorna caminho de arquivo PCM temporário (float32 LE, 24kHz, stereo).
 */

const { spawnSync } = require("child_process");
const path = require("path");
const os = require("os");

const SR = 24000;

const BINAURAL_CFG = {
  delta: { beat: 2,  carrier: 100, label: "Delta · 2 Hz · sono profundo" },
  theta: { beat: 6,  carrier: 200, label: "Theta · 6 Hz · meditação" },
  alpha: { beat: 10, carrier: 200, label: "Alpha · 10 Hz · relaxamento" },
};

const VOLUME_FUNDO = {
  suave:   0.35,
  medio:   0.60,
  intenso: 0.88,
};

function ffmpegGerar(args, label) {
  const r = spawnSync("ffmpeg", args, { stdio: ["ignore", "ignore", "pipe"] });
  if (r.status !== 0) {
    console.error(`[background] ${label} falhou:`, r.stderr?.toString().slice(-300));
    return false;
  }
  return true;
}

/**
 * Gera binaural puro: dois senoidais com frequências levemente diferentes em cada canal.
 * Requer fones de ouvido para funcionar como binaural verdadeiro.
 */
function gerarBinaural(binauralTipo, durationSec, outFile) {
  const cfg = BINAURAL_CFG[binauralTipo] || BINAURAL_CFG.theta;
  const leftFreq  = cfg.carrier - cfg.beat / 2;
  const rightFreq = cfg.carrier + cfg.beat / 2;
  const dur = Math.ceil(durationSec) + 2;

  return ffmpegGerar([
    "-f", "lavfi", "-i", `sine=frequency=${leftFreq}:sample_rate=${SR}:duration=${dur}`,
    "-f", "lavfi", "-i", `sine=frequency=${rightFreq}:sample_rate=${SR}:duration=${dur}`,
    "-filter_complex",
    `[0:a]volume=0.12,afade=t=in:d=5,afade=t=out:st=${durationSec - 5}:d=5[L];` +
    `[1:a]volume=0.12,afade=t=in:d=5,afade=t=out:st=${durationSec - 5}:d=5[R];` +
    `[L][R]amerge=inputs=2[out]`,
    "-map", "[out]",
    "-f", "f32le", "-ar", String(SR), "-ac", "2", "-y", outFile,
  ], "binaural");
}

/**
 * Gera pink noise (soa como chuva suave / natureza).
 */
function gerarNatureza(durationSec, outFile) {
  const dur = Math.ceil(durationSec) + 2;

  return ffmpegGerar([
    "-f", "lavfi", "-i", `anoisesrc=d=${dur}:color=pink:amplitude=0.07:r=${SR}`,
    "-filter_complex",
    `[0:a]afade=t=in:d=4,afade=t=out:st=${durationSec - 4}:d=4,pan=stereo|c0=c0|c1=c0[out]`,
    "-map", "[out]",
    "-f", "f32le", "-ar", String(SR), "-ac", "2", "-y", outFile,
  ], "natureza");
}

/**
 * Gera drone relaxante com frequências solfeggio + binaural embutido.
 * Frequências base: 174 Hz (fundação) e 285 Hz (cura) — com desvio binaural entre canais.
 */
function gerarRelaxante(binauralTipo, durationSec, outFile) {
  const cfg = BINAURAL_CFG[binauralTipo] || BINAURAL_CFG.theta;
  const beat = cfg.beat;
  const dur = Math.ceil(durationSec) + 2;

  // Duas camadas: 174 Hz e 285 Hz — cada uma com desvio binaural L/R
  const f1L = 174 - beat / 2, f1R = 174 + beat / 2;
  const f2L = 285 - beat / 2, f2R = 285 + beat / 2;
  const fadeOut = Math.max(0, durationSec - 8);

  return ffmpegGerar([
    "-f", "lavfi", "-i", `sine=frequency=${f1L}:sample_rate=${SR}:duration=${dur}`,
    "-f", "lavfi", "-i", `sine=frequency=${f1R}:sample_rate=${SR}:duration=${dur}`,
    "-f", "lavfi", "-i", `sine=frequency=${f2L}:sample_rate=${SR}:duration=${dur}`,
    "-f", "lavfi", "-i", `sine=frequency=${f2R}:sample_rate=${SR}:duration=${dur}`,
    "-filter_complex",
    `[0:a]volume=0.10[a0];[2:a]volume=0.06[a2];` +
    `[a0][a2]amix=inputs=2:normalize=0,afade=t=in:d=8,afade=t=out:st=${fadeOut}:d=8[L];` +
    `[1:a]volume=0.10[a1];[3:a]volume=0.06[a3];` +
    `[a1][a3]amix=inputs=2:normalize=0,afade=t=in:d=8,afade=t=out:st=${fadeOut}:d=8[R];` +
    `[L][R]amerge=inputs=2[out]`,
    "-map", "[out]",
    "-f", "f32le", "-ar", String(SR), "-ac", "2", "-y", outFile,
  ], "relaxante");
}

/**
 * Gera o arquivo PCM de fundo conforme o tipo escolhido.
 * @returns {string|null} caminho do arquivo PCM ou null (silencio)
 */
function gerarFundoPCM(tipo, binauralTipo, durationSec) {
  if (!tipo || tipo === "silencio") return null;

  const outFile = path.join(os.tmpdir(), `bg-${Date.now()}-${tipo}.pcm`);
  let ok = false;

  if (tipo === "binaural")   ok = gerarBinaural(binauralTipo, durationSec, outFile);
  else if (tipo === "natureza")  ok = gerarNatureza(durationSec, outFile);
  else if (tipo === "relaxante") ok = gerarRelaxante(binauralTipo, durationSec, outFile);

  return ok ? outFile : null;
}

module.exports = { gerarFundoPCM, BINAURAL_CFG, VOLUME_FUNDO };
