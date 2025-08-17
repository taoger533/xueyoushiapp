/**
 * 自动审核规则（可随时修改/扩展）
 * - 规范化文本：去零宽/全角转半角/去分隔符，拦截“花式写法”
 * - 长度校验：MIN_LEN / MAX_LEN
 * - 禁止词：bannedKeywords（可继续补充）
 * - 联系方式/外链：手机号/座机/邮箱/疑似ID/关键词、网址/域名
 */

const MIN_LEN = 10;
const MAX_LEN = 300;

// —— 较全面的禁止词（按需继续增补）——
const bannedKeywords = [
  // 违法/违规
  '违法','非法','暴力','恐怖','极端','毒品','赌博','博彩','色情','黄赌毒','枪支','弹药','爆炸物','军火','走私','诈骗','洗钱',
  // 政治敏感（示例）
  '反动','推翻政府','恐怖组织','分裂国家','台独','港独','疆独',
  // 低俗辱骂
  '傻逼','垃圾','畜生','狗东西','滚蛋','妈的','sb','操你','fuck','shit',
  // 广告/推广
  '代理','代购','批发','促销','低价出售','清仓','发票','办证','出售答案','刷单','兼职','赚钱','返利','推广','营销号',
  // 联系方式引导
  '加微信','加qq','加vx','加v信','vx联系','v信联系','联系我','加我好友','私人号','小号','微商','工作室',
  // 其他容易触发问题
  '彩票','赌球','下注','黑客','外挂','破解','vpn',
];

// 零宽字符与常见分隔符（用来拼接手机号/微信的“花式”写法）
const ZERO_WIDTH = /[\u200B-\u200D\uFEFF]/g;
const FULLWIDTH_START = 0xFF01, FULLWIDTH_END = 0xFF5E;
function toHalfWidth(str) {
  return str.replace(/[\uFF01-\uFF5E]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
            .replace(/\u3000/g, ' ');
}

// 把 “v x”、“1-3-5-xxxx-xxxx”、“w w w . 域 名 . c o m” 这类拆分写法规范化
function normalizeForDetect(s) {
  if (!s) return '';
  let t = String(s);
  t = t.replace(ZERO_WIDTH, '');         // 去零宽
  t = toHalfWidth(t);                     // 全角转半角
  // 去掉常见分隔符（保留中文，删除空格/点/横线/下划线/斜杠等）
  t = t.replace(/[\s._\-\\/|•·•，。；；、,]/g, '');
  return t.toLowerCase();
}

const patterns = {
  // 大陆手机号（简单版）
  mobile: /\b1[3-9]\d{9}\b/g,
  // 座机（区号-号码 或 纯数字7~12位，宽松）
  landline: /\b(?:\d{3,4}-\d{7,8}|\d{7,12})\b/g,
  // 邮箱
  email: /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}\b/g,
  // URL（http/https、www、或裸域名）
  url: /\b(?:https?:\/\/|www\.)[^\s]+|\b[a-zA-Z0-9-]+\.(?:com|cn|net|org|edu|gov|top|xyz|io|co|me|cc|site|shop)(?:\/[^\s]*)?\b/gi,
  // 可能的“ID样式”（常见微信/QQ/自定义ID）
  idLike: /\b[a-zA-Z][a-zA-Z0-9_-]{4,}\b/g,
  // 关键词提示（微信/QQ/联系等）
  contactKW: /(微信|vx|v信|加我|联系我|qq|扣扣|电话|手机号|手机|微信号|微商|工作室)/gi,
};

// 在原文与“规范化文本”上双重检测
function detectContactAndLinks(text = '') {
  const raw = String(text);
  const norm = normalizeForDetect(text);

  const urlsRaw = raw.match(patterns.url) || [];
  const urlsNorm = norm.match(patterns.url) || [];

  const contactRaw = [
    ...(raw.match(patterns.mobile) || []),
    ...(raw.match(patterns.landline) || []),
    ...(raw.match(patterns.email) || []),
    ...(raw.match(patterns.idLike) || []),
  ];
  const contactNorm = [
    ...(norm.match(patterns.mobile) || []),
    ...(norm.match(patterns.landline) || []),
    ...(norm.match(patterns.email) || []),
    ...(norm.match(patterns.idLike) || []),
  ];

  const kwRaw = raw.match(patterns.contactKW) || [];
  const kwNorm = norm.match(patterns.contactKW) || [];

  const uniq = arr => Array.from(new Set(arr.filter(Boolean)));

  return {
    urls: uniq([...urlsRaw, ...urlsNorm]),
    contact: uniq([...contactRaw, ...contactNorm]),
    keywords: uniq([...kwRaw, ...kwNorm]),
  };
}

/**
 * 审核主函数
 * @param {string} content
 * @returns {{
 *  status:'approved'|'rejected',
 *  message:string,
 *  flags:{ empty:boolean, tooShort:boolean, tooLong:boolean, containsBanned:boolean, containsContact:boolean, containsUrl:boolean },
 *  hits:{ banned:string[], contact:string[], urls:string[], keywords:string[] }
 * }}
 */
function reviewContent(content) {
  const text = (content ?? '').toString().trim();

  const result = {
    status: 'approved',
    message: '审核通过',
    flags: {
      empty: false,
      tooShort: false,
      tooLong: false,
      containsBanned: false,
      containsContact: false,
      containsUrl: false,
    },
    hits: {
      banned: [],
      contact: [],
      urls: [],
      keywords: [],
    },
  };

  if (!text) {
    result.status = 'rejected';
    result.message = '详细情况不能为空';
    result.flags.empty = true;
    return result;
  }

  if (text.length < MIN_LEN) {
    result.status = 'rejected';
    result.message = `详细情况过短，至少 ${MIN_LEN} 个字`;
    result.flags.tooShort = true;
    return result;
  }
  if (text.length > MAX_LEN) {
    result.status = 'rejected';
    result.message = `详细情况过长，最多允许 ${MAX_LEN} 个字`;
    result.flags.tooLong = true;
    return result;
  }

  // 禁止词（对原文匹配即可；如需更严可对 normalize 后再匹配一次）
  const bannedHit = bannedKeywords.filter(k => text.includes(k));
  if (bannedHit.length > 0) {
    result.status = 'rejected';
    result.message = `内容包含禁止词汇：${bannedHit[0]}`;
    result.flags.containsBanned = true;
    result.hits.banned = Array.from(new Set(bannedHit));
    return result;
  }

  // 联系方式/链接检测（原文 + 规范化文本）
  const contactRes = detectContactAndLinks(text);

  if (contactRes.urls.length > 0) {
    result.status = 'rejected';
    result.message = '不得包含网址或外部链接';
    result.flags.containsUrl = true;
    result.hits.urls = contactRes.urls;
    result.hits.keywords = contactRes.keywords;
    return result;
  }

  if (contactRes.contact.length > 0 || contactRes.keywords.length > 0) {
    result.status = 'rejected';
    result.message = '不得在详细情况中留联系方式（手机号/微信/QQ/邮箱等）';
    result.flags.containsContact = true;
    result.hits.contact = contactRes.contact;
    result.hits.keywords = contactRes.keywords;
    return result;
  }

  return result;
}

module.exports = {
  reviewContent,
  detectContactAndLinks,
  bannedKeywords,
  MIN_LEN,
  MAX_LEN,
  normalizeForDetect,
};
