#!/usr/bin/env node
/**
 * whatsapp-bridge.js — WhatsApp Bridge via Baileys
 *
 * Node.js bridge that connects to WhatsApp via @whiskeysockets/baileys,
 * normalizes messages to adapter-message.schema.json, and exposes a
 * local HTTP API for send-whatsapp.sh to call.
 *
 * Architecture:
 *   WhatsApp (Baileys) <--> this bridge <--> channel-inbox/ (for inbound)
 *                                        <--> HTTP /send    (for outbound)
 *
 * HTTP API:
 *   POST /send       — {to, text, image_url?} → send message
 *   GET  /health     — {connected, phone, uptime_s}
 *   GET  /qr         — QR code as text (first login only)
 *
 * Environment:
 *   CRM_AGENT_NAME              — Agent name (default: prisma)
 *   CRM_INSTANCE_ID             — Instance (default: default)
 *   CRM_ROOT                    — State root (~/.claude-remote/{instance})
 *   WHATSAPP_BRIDGE_PORT        — HTTP port (default: 8445)
 *   WHATSAPP_ALLOWED_NUMBERS    — Comma-separated allowed phone numbers
 *
 * Reference: OpenClaw extensions/whatsapp/ (auth-store.ts, login.ts)
 * Story 114.18 Phase 3
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Lazy-load Baileys (installed as dependency)
let makeWASocket, useMultiFileAuthState, DisconnectReason, Boom, downloadMediaMessage;

try {
    const baileys = require('@whiskeysockets/baileys');
    makeWASocket = baileys.default || baileys.makeWASocket;
    useMultiFileAuthState = baileys.useMultiFileAuthState;
    DisconnectReason = baileys.DisconnectReason;
    downloadMediaMessage = baileys.downloadMediaMessage;
} catch (e) {
    console.error('ERROR: @whiskeysockets/baileys not installed.');
    console.error('Install with: npm install @whiskeysockets/baileys');
    process.exit(1);
}

try {
    Boom = require('@hapi/boom').Boom;
} catch {
    // Boom is optional — we can check statusCode directly
    Boom = null;
}

// --- Configuration ---
const AGENT_NAME = process.env.CRM_AGENT_NAME || 'prisma';
const INSTANCE_ID = process.env.CRM_INSTANCE_ID || 'default';
const CRM_ROOT = process.env.CRM_ROOT || path.join(require('os').homedir(), '.claude-remote', INSTANCE_ID);
const BRIDGE_PORT = parseInt(process.env.WHATSAPP_BRIDGE_PORT || '8445', 10);
const ALLOWED_NUMBERS = (process.env.WHATSAPP_ALLOWED_NUMBERS || '')
    .split(',')
    .map(n => n.trim())
    .filter(Boolean);

const AUTH_DIR = path.join(CRM_ROOT, 'state', AGENT_NAME, 'whatsapp-auth');
const INBOX_DIR = path.join(CRM_ROOT, 'channel-inbox', AGENT_NAME);
const LOG_DIR = path.join(CRM_ROOT, 'logs', AGENT_NAME);
const LOG_FILE = path.join(LOG_DIR, 'whatsapp-bridge.log');
const MEDIA_DIR = '/tmp/prisma-media';

// Ensure directories exist
[AUTH_DIR, INBOX_DIR, LOG_DIR, MEDIA_DIR].forEach(d => fs.mkdirSync(d, { recursive: true }));

// --- Logging ---
function log(msg) {
    const ts = new Date().toISOString().replace(/\.\d+Z/, 'Z');
    const line = `${ts} [whatsapp-bridge/${AGENT_NAME}] ${msg}\n`;
    fs.appendFileSync(LOG_FILE, line);
    process.stdout.write(line);
}

// --- State ---
let sock = null;
let qrCode = null;
let connected = false;
let phoneNumber = '';
const startTime = Date.now();

// Markdown → WhatsApp format conversion (OpenClaw pattern: send.ts)
// WhatsApp uses *bold*, _italic_, ~strikethrough~ instead of Markdown
function convertMarkdownToWhatsApp(text) {
    return text
        // **bold** or __bold__ → *bold*
        .replace(/\*\*(.+?)\*\*/g, '*$1*')
        .replace(/__(.+?)__/g, '*$1*')
        // ~~strike~~ → ~strike~
        .replace(/~~(.+?)~~/g, '~$1~');
    // Note: `code` and ```blocks``` are the same in WhatsApp
}

// Rate limiter: 200ms between sends
let lastSendTime = 0;
async function rateLimitedSend(jid, content) {
    const now = Date.now();
    const elapsed = now - lastSendTime;
    if (elapsed < 200) {
        await new Promise(r => setTimeout(r, 200 - elapsed));
    }
    lastSendTime = Date.now();

    // Send "composing" presence before message (OpenClaw pattern: sendMessageWhatsApp)
    try {
        await sock.presenceSubscribe(jid);
        await sock.sendPresenceUpdate('composing', jid);
    } catch {}

    const result = await sock.sendMessage(jid, content);

    // Clear composing state
    try {
        await sock.sendPresenceUpdate('paused', jid);
    } catch {}

    return result;
}

// --- Write to channel-inbox ---
function writeToInbox(normalized) {
    const ts = Date.now();
    const rand = Math.random().toString(36).substring(2, 10);
    const filename = `${ts}-whatsapp-${rand}.json`;
    const tmpFile = path.join(INBOX_DIR, `.tmp-${rand}`);
    const finalFile = path.join(INBOX_DIR, filename);

    try {
        fs.writeFileSync(tmpFile, JSON.stringify(normalized), { mode: 0o600 });
        fs.renameSync(tmpFile, finalFile);
        log(`Wrote inbox: ${filename}`);
    } catch (e) {
        log(`ERROR writing inbox: ${e.message}`);
        // Fallback: direct write
        try { fs.writeFileSync(finalFile, JSON.stringify(normalized)); } catch {}
    }
}

// --- WhatsApp JID helpers ---
function normalizeJid(number) {
    // Remove non-digits, ensure @s.whatsapp.net suffix
    const clean = number.replace(/[^0-9]/g, '');
    return clean.includes('@') ? clean : `${clean}@s.whatsapp.net`;
}

function extractNumber(jid) {
    return (jid || '').split('@')[0];
}

// --- Baileys Connection ---
async function startConnection() {
    const { state, saveCreds: rawSaveCreds } = await useMultiFileAuthState(AUTH_DIR);

    // OpenClaw pattern: backup creds before saving new ones (auth-store.ts)
    const saveCreds = async () => {
        const credsPath = path.join(AUTH_DIR, 'creds.json');
        const backupPath = path.join(AUTH_DIR, 'creds.json.bak');
        try {
            if (fs.existsSync(credsPath)) {
                fs.copyFileSync(credsPath, backupPath);
            }
        } catch {}
        await rawSaveCreds();
    };

    sock = makeWASocket({
        auth: state,
        printQRInTerminal: true,
        // Suppress verbose logging
        logger: {
            info: () => {},
            warn: (msg) => log(`WARN: ${typeof msg === 'string' ? msg : JSON.stringify(msg)}`),
            error: (msg) => log(`ERROR: ${typeof msg === 'string' ? msg : JSON.stringify(msg)}`),
            debug: () => {},
            trace: () => {},
            child: () => ({ info: () => {}, warn: () => {}, error: () => {}, debug: () => {}, trace: () => {} }),
        },
    });

    // Save credentials on update
    sock.ev.on('creds.update', saveCreds);

    // Connection state
    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
            qrCode = qr;
            log('QR code generated — scan with WhatsApp to login');
            // Try to notify via Telegram if available
            try {
                const sendTg = path.join(__dirname, '../../core/bus/send-telegram.sh');
                if (fs.existsSync(sendTg)) {
                    execSync(`bash "${sendTg}" "${process.env.CHAT_ID || ''}" "WhatsApp QR ready. Open bridge at http://localhost:${BRIDGE_PORT}/qr"`, { timeout: 10000 });
                }
            } catch {}
        }

        if (connection === 'close') {
            connected = false;
            const statusCode = lastDisconnect?.error?.output?.statusCode;

            // OpenClaw pattern: handle specific status codes
            if (statusCode === 401 || statusCode === DisconnectReason.loggedOut) {
                // Logged out — clear auth cache and require re-login
                log('Logged out (401) — clearing auth cache for re-login');
                try {
                    const credsPath = path.join(AUTH_DIR, 'creds.json');
                    if (fs.existsSync(credsPath)) fs.unlinkSync(credsPath);
                } catch {}
                setTimeout(startConnection, 5000);
            } else if (statusCode === 515) {
                // Restart required (OpenClaw: login.ts handles this)
                log('Restart required (515), reconnecting immediately...');
                setTimeout(startConnection, 1000);
            } else if (statusCode !== DisconnectReason.loggedOut) {
                log(`Connection closed (code ${statusCode}), reconnecting...`);
                setTimeout(startConnection, 3000);
            } else {
                log('Logged out — delete auth folder and restart to re-login');
            }
        } else if (connection === 'open') {
            connected = true;
            qrCode = null;
            phoneNumber = extractNumber(sock.user?.id || '');
            log(`Connected as ${phoneNumber}`);
        }
    });

    // Incoming messages
    sock.ev.on('messages.upsert', async ({ messages: msgs, type }) => {
        if (type !== 'notify') return;

        for (const msg of msgs) {
            // Skip own messages
            if (msg.key.fromMe) continue;

            const sender = extractNumber(msg.key.remoteJid);

            // Filter by allowed numbers
            if (ALLOWED_NUMBERS.length > 0 && !ALLOWED_NUMBERS.includes(sender)) {
                log(`Rejected message from ${sender} (not in allowed list)`);
                continue;
            }

            const pushName = msg.pushName || sender;
            const text = msg.message?.conversation
                || msg.message?.extendedTextMessage?.text
                || msg.message?.imageMessage?.caption
                || msg.message?.documentMessage?.caption
                || msg.message?.videoMessage?.caption
                || msg.message?.buttonsResponseMessage?.selectedButtonId
                || msg.message?.listResponseMessage?.singleSelectReply?.selectedRowId
                || '';

            let msgType = 'message';
            const mediaObj = {};
            let needsDownload = false;

            if (msg.message?.imageMessage) {
                msgType = 'photo';
                mediaObj.type = 'photo';
                mediaObj.caption = msg.message.imageMessage.caption || '';
                mediaObj.mime_type = msg.message.imageMessage.mimetype || 'image/jpeg';
                mediaObj.ext = 'jpg';
                needsDownload = true;
            } else if (msg.message?.documentMessage) {
                msgType = 'document';
                mediaObj.type = 'document';
                mediaObj.caption = msg.message.documentMessage.caption || '';
                mediaObj.mime_type = msg.message.documentMessage.mimetype || 'application/octet-stream';
                mediaObj.filename = msg.message.documentMessage.fileName || 'document';
                mediaObj.ext = path.extname(mediaObj.filename).slice(1) || 'bin';
                needsDownload = true;
            } else if (msg.message?.videoMessage) {
                msgType = 'video';
                mediaObj.type = 'video';
                mediaObj.caption = msg.message.videoMessage.caption || '';
                mediaObj.mime_type = msg.message.videoMessage.mimetype || 'video/mp4';
                mediaObj.ext = 'mp4';
                needsDownload = true;
            } else if (msg.message?.audioMessage) {
                msgType = 'audio';
                mediaObj.type = 'audio';
                mediaObj.mime_type = msg.message.audioMessage.mimetype || 'audio/ogg';
                mediaObj.ext = msg.message.audioMessage.ptt ? 'ogg' : 'mp3';
                needsDownload = true;
            } else if (msg.message?.buttonsResponseMessage || msg.message?.listResponseMessage) {
                msgType = 'callback';
            }

            // Download and persist media to disk
            if (needsDownload && downloadMediaMessage) {
                try {
                    const buffer = await downloadMediaMessage(msg, 'buffer', {});
                    const basename = mediaObj.filename
                        ? `${Date.now()}-${mediaObj.filename}`
                        : `${Date.now()}-${Math.random().toString(36).slice(2)}.${mediaObj.ext}`;
                    const localPath = path.join(MEDIA_DIR, basename);
                    fs.writeFileSync(localPath, buffer);
                    mediaObj.local_path = localPath;
                    log(`Media saved: ${localPath} (${buffer.length} bytes)`);
                } catch (e) {
                    log(`Media download failed: ${e.message}`);
                }
            }

            const normalized = {
                _source: 'whatsapp',
                _type: msgType,
                _timestamp: new Date().toISOString().replace(/\.\d+Z/, 'Z'),
                _message_id: msg.key.id || '',
                platform: 'whatsapp',
                chat_id: sender,
                from: pushName,
                user_id: sender,
                text: text,
            };

            if (Object.keys(mediaObj).length > 0) {
                normalized.media = mediaObj;
            }

            // Check for button reply (permission response)
            const buttonReply = msg.message?.buttonsResponseMessage?.selectedButtonId;
            if (buttonReply) {
                normalized.callback_data = buttonReply;
            }

            writeToInbox(normalized);
            log(`Message from ${pushName} (${sender}): ${text.substring(0, 80)}`);

            // Mark as read
            try {
                await sock.readMessages([msg.key]);
            } catch {}
        }
    });
}

// --- HTTP Server for send-whatsapp.sh ---
const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${BRIDGE_PORT}`);

    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');

    if (req.method === 'GET' && url.pathname === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            connected,
            phone: phoneNumber,
            uptime_s: Math.floor((Date.now() - startTime) / 1000),
            auth_exists: fs.existsSync(path.join(AUTH_DIR, 'creds.json')),
        }));
        return;
    }

    if (req.method === 'GET' && url.pathname === '/qr') {
        if (qrCode) {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(qrCode);
        } else if (connected) {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(`Already connected as ${phoneNumber}`);
        } else {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('No QR code available. Wait for connection...');
        }
        return;
    }

    if (req.method === 'POST' && url.pathname === '/send') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', async () => {
            try {
                const data = JSON.parse(body);
                const { to, text, image_url } = data;

                if (!to || (!text && !image_url)) {
                    res.writeHead(400, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'Missing "to" and "text" or "image_url"' }));
                    return;
                }

                if (!connected) {
                    res.writeHead(503, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'WhatsApp not connected' }));
                    return;
                }

                const jid = normalizeJid(to);

                if (image_url) {
                    await rateLimitedSend(jid, {
                        image: { url: image_url },
                        caption: convertMarkdownToWhatsApp(text || ''),
                    });
                } else if (data.buttons) {
                    // Interactive buttons for permission requests
                    await rateLimitedSend(jid, {
                        text: text,
                        buttons: data.buttons,
                        headerType: 1,
                    });
                } else {
                    await rateLimitedSend(jid, { text: convertMarkdownToWhatsApp(text) });
                }

                log(`Sent to ${to}: ${(text || '[image]').substring(0, 80)}`);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ ok: true, to, sent: true }));
            } catch (e) {
                log(`Send error: ${e.message}`);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: e.message }));
            }
        });
        return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
});

// --- Start ---
log(`Starting WhatsApp bridge on port ${BRIDGE_PORT}`);
log(`Auth dir: ${AUTH_DIR}`);
log(`Inbox dir: ${INBOX_DIR}`);
if (ALLOWED_NUMBERS.length > 0) {
    log(`Allowed numbers: ${ALLOWED_NUMBERS.join(', ')}`);
}

server.listen(BRIDGE_PORT, '127.0.0.1', () => {
    log(`HTTP server listening on http://127.0.0.1:${BRIDGE_PORT}`);
    console.log(`WhatsApp bridge: http://127.0.0.1:${BRIDGE_PORT}`);
    console.log(`  POST /send    — send messages`);
    console.log(`  GET  /health  — connection status`);
    console.log(`  GET  /qr      — QR code for login`);
    startConnection();
});
