const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const router = express.Router();

const LEGAL_DIR = path.join(__dirname, '..', 'public', 'legal');

const META = {
  version: 'V1.0',
  effectiveDate: '2025-08-20',
  lang: 'zh-CN',
  subject: '吴江松陵镇学友师教育咨询工作室（个体工商户）',
};

const TERMS_PATH = path.join(LEGAL_DIR, 'terms.html');
const PRIVACY_PATH = path.join(LEGAL_DIR, 'privacy.html');
const CONSENT_LOG = path.join(LEGAL_DIR, 'consents.log');

function readDocInfo(filePath) {
  const html = fs.readFileSync(filePath, 'utf8');
  const hash = 'sha256:' + crypto.createHash('sha256').update(html, 'utf8').digest('hex');
  return { html, hash };
}

router.get('/docs', (req, res) => {
  const type = String(req.query.type || '').toLowerCase();
  if (!['terms', 'privacy'].includes(type)) {
    return res.status(400).json({ error: 'type 必须为 terms 或 privacy' });
  }
  const file = type === 'terms' ? TERMS_PATH : PRIVACY_PATH;
  if (!fs.existsSync(file)) {
    return res.status(503).json({ error: 'legal docs not ready' });
  }
  const { html, hash } = readDocInfo(file);
  res.json({
    type,
    version: META.version,
    effectiveDate: META.effectiveDate,
    lang: META.lang,
    subject: META.subject,
    contentHtml: html,
    contentHash: hash,
  });
});

router.get('/latest', (_req, res) => {
  if (!fs.existsSync(TERMS_PATH) || !fs.existsSync(PRIVACY_PATH)) {
    return res.status(503).json({ error: 'legal docs not ready' });
  }
  const t = readDocInfo(TERMS_PATH);
  const p = readDocInfo(PRIVACY_PATH);
  res.json({
    version: META.version,
    effectiveDate: META.effectiveDate,
    lang: META.lang,
    subject: META.subject,
    terms: { type: 'terms', contentHash: t.hash, version: META.version },
    privacy: { type: 'privacy', contentHash: p.hash, version: META.version },
  });
});

router.post('/consents', (req, res) => {
  const { userId, type, version, contentHash, consentAt } = req.body || {};
  if (!userId || !type || !version || !contentHash) {
    return res.status(400).json({ error: '缺少字段' });
  }
  if (!['terms', 'privacy'].includes(String(type).toLowerCase())) {
    return res.status(400).json({ error: 'type 必须为 terms 或 privacy' });
  }
  const ip = (req.headers['x-forwarded-for'] || '').toString().split(',')[0].trim() || req.socket.remoteAddress || '';
  const ua = req.headers['user-agent'] || '';
  const now = new Date().toISOString();
  const line =
    JSON.stringify({
      userId,
      type,
      version,
      contentHash,
      consentAt: consentAt || now,
      ip,
      ua,
      serverAt: now,
    }) + '\n';
  try {
    fs.appendFileSync(CONSENT_LOG, line, 'utf8');
  } catch (_) {}
  res.json({ ok: true });
});

module.exports = router;
