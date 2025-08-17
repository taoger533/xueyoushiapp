// my_new_app/backend/routes/teacher.js
const express = require('express');
const router = express.Router();
const Teacher = require('../models/Teacher');
const User = require('../models/User');  // 引入 User 模型
const { reviewContent } = require('../utils/reviewRules'); // 自动审核入口

// 教师头衔映射表
const titleCodeMap = {
  0: ['普通教员'],
  1: ['专业教员'],
  2: ['学霸大学生'],
  3: ['专业教员', '学霸大学生'],
};

// 发布教员信息（首次发布）
router.post('/', async (req, res) => {
  try {
    // 兼容多种“详细情况”字段命名
    const detail =
      req.body.detail ??
      req.body.detailInfo ??
      req.body.description ??
      '';

    // 调用审核规则
    const review = reviewContent(detail);

    // 审核不通过 => 硬拦截
    if (review.status === 'rejected') {
      return res.status(400).json({
        error: review.message,
        flags: review.flags, // 可选：便于排查
        hits: review.hits,   // 可选：便于排查
      });
    }

    // 写回审核结果（模型需包含 reviewStatus 与 reviewMessage 字段）
    const payload = {
      ...req.body,
      reviewStatus: review.status,   // 'approved' | 'rejected'
      reviewMessage: review.message, // 审核提示
    };

    const teacher = new Teacher(payload);
    await teacher.save();

    res.status(201).json({
      message: '教员信息已发布',
      reviewStatus: review.status,
      reviewMessage: review.message,
      id: teacher._id,
    });
  } catch (err) {
    console.error('发布失败:', err);
    res.status(500).json({ error: '发布失败' });
  }
});

// 根据 userId 查询教员信息（用来判断是新建还是更新）
router.get('/user/:userId', async (req, res) => {
  try {
    const teacher = await Teacher.findOne({ userId: req.params.userId });
    if (!teacher) return res.status(404).end();
    res.json(teacher);
  } catch (err) {
    console.error('查询失败:', err);
    res.status(500).json({ error: '查询失败' });
  }
});

// 更新指定 _id 的教员信息
router.put('/:id', async (req, res) => {
  try {
    // 为了在更新时重新跑审核，这里采用“先查再改再存”的方式
    const doc = await Teacher.findById(req.params.id);
    if (!doc) return res.status(404).json({ error: '未找到该教员' });

    // 应用请求体字段
    Object.keys(req.body || {}).forEach((k) => {
      doc[k] = req.body[k];
    });

    // 只要请求里带了“详细情况”相关字段，就重新审核一次
    const hasDetailInBody =
      Object.prototype.hasOwnProperty.call(req.body, 'detail') ||
      Object.prototype.hasOwnProperty.call(req.body, 'detailInfo') ||
      Object.prototype.hasOwnProperty.call(req.body, 'description');

    if (hasDetailInBody) {
      const detailNow =
        doc.detail ??
        doc.detailInfo ??
        doc.description ??
        '';
      const review = reviewContent(detailNow);

      // 审核不通过 => 硬拦截更新
      if (review.status === 'rejected') {
        return res.status(400).json({
          error: review.message,
          flags: review.flags,
          hits: review.hits,
        });
      }

      // 审核通过：更新审核字段
      doc.reviewStatus = review.status;
      doc.reviewMessage = review.message;
    }

    const saved = await doc.save();
    res.json(saved);
  } catch (err) {
    console.error('更新失败:', err);
    res.status(500).json({ error: '更新失败' });
  }
});

/**
 * 获取教员列表（带筛选、会员优先、分页）：
 * 支持 query 参数：
 * - teachMethod: '线上' | '线下' | '全部'（或不传）
 * - province, city：地区（通常仅线下需要）
 * - phase: 学段（'全部' 或 具体：小学/初中/高中）
 * - subject: 科目（'全部' 或 具体：语文/数学/...）
 * - gender: 性别（'全部' | '男' | '女'）
 * - titleFilter: 0/1/2/3；其中 3 同时满足 1 与 2 的查询含义
 * - page, limit: 分页参数（可选）
 *
 * 新增功能：如果 query 中包含 userId，则直接根据 userId 返回该教员详情（数组形式），兼容 `/api/teachers?userId=xxx` 调用。
 */
router.get('/', async (req, res) => {
  try {
    // 当带有 userId 查询参数时，直接查询单个教员信息并返回数组
    if (req.query.userId) {
      const teacher = await Teacher.findOne({ userId: req.query.userId }).lean();
      if (!teacher) return res.json([]);
      // 查询关联用户信息，组合成前端需要的格式
      const user = await User.findById(req.query.userId).lean();
      const code = Number.isInteger(user?.titleCode) ? user.titleCode : 0;
      const info = {
        ...teacher,
        acceptingStudents: !!user?.acceptingStudents,
        titleCode: code,
        titles: titleCodeMap[code] || [],
        isMember: !!user?.isMember,
      };
      return res.json([info]);
    }

    const {
      teachMethod,   // 线上/线下/全部
      province,
      city,
      phase,         // 小学/初中/高中/全部
      subject,       // 语文/数学/.../全部
      gender,        // 男/女/全部
      titleFilter,   // 0/1/2/3
      page,
      limit,
    } = req.query;

    // 1) 组装 Teacher 基础查询条件
    const query = {};

    // 授课方式：允许 '全部' 的老师同时出现在'线上'或'线下'筛选结果中
    if (teachMethod && teachMethod !== '全部') {
      query.teachMethod = { $in: [teachMethod, '全部'] };
    }

    // 地区：若传递则按 province + city 精确匹配
    if (province && city) {
      query.province = province;
      query.city = city;
    }

    // 性别
    if (gender && gender !== '全部') {
      query.gender = gender;
    }

    // 学段、科目：位于 subjects 数组字段中
    if (phase && phase !== '全部') {
      query['subjects.phase'] = phase;
    }
    if (subject && subject !== '全部') {
      query['subjects.subject'] = subject;
    }

    // 2) 查 Teacher（先不排序，lean 方便合并）
    const teachers = await Teacher.find(query).lean();

    // 3) 查关联 User 的 acceptingStudents、titleCode、isMember
    const userIds = teachers.map(t => t.userId).filter(Boolean);
    const users = await User.find(
      { _id: { $in: userIds } },
      'acceptingStudents titleCode isMember'
    ).lean();

    // 4) 构造 user 映射表
    const userMap = users.reduce((acc, u) => {
      const code = Number.isInteger(u.titleCode) ? u.titleCode : 0;
      acc[u._id.toString()] = {
        acceptingStudents: !!u.acceptingStudents,
        titleCode: code,
        isMember: !!u.isMember,
        titles: titleCodeMap[code] || [],
      };
      return acc;
    }, {});

    // 5) 合并 user 信息
    let merged = teachers.map(t => {
      const key = t.userId ? t.userId.toString() : '';
      const userInfo = userMap[key] ?? {};
      return {
        ...t,
        acceptingStudents: userInfo.acceptingStudents ?? false,
        titleCode: userInfo.titleCode ?? 0,
        titles: userInfo.titles ?? [],
        isMember: userInfo.isMember ?? false,
      };
    });

    // 6) 头衔过滤（titleFilter）：3 视为同时满足 1 与 2
    if (typeof titleFilter !== 'undefined') {
      const tf = parseInt(titleFilter, 10);
      merged = merged.filter((item) => {
        const c = item.titleCode ?? 0;
        if (tf === 3) return c === 3;             // 只要 code==3
        if (tf === 1) return c === 1 || c === 3;  // 专业教员 或 复合
        if (tf === 2) return c === 2 || c === 3;  // 学霸大学生 或 复合
        if (tf === 0) return c === 0;             // 仅普通教员
        return true;
      });
    }

    // 7) 会员优先排序，其次按创建时间倒序
    merged.sort((a, b) => {
      if (a.isMember === b.isMember) {
        const da = a.createdAt ? new Date(a.createdAt) : 0;
        const db = b.createdAt ? new Date(b.createdAt) : 0;
        return db - da;
      }
      return (b.isMember ? 1 : 0) - (a.isMember ? 1 : 0);
    });

    // 8) 分页
    const p = parseInt(page, 10) > 0 ? parseInt(page, 10) : 1;
    const l = parseInt(limit, 10) > 0 ? parseInt(limit, 10) : 20;
    const start = (p - 1) * l;
    const paginated = merged.slice(start, start + l);

    res.json({ total: merged.length, data: paginated });
  } catch (err) {
    console.error('获取教员失败:', err);
    res.status(500).json({ error: '获取教员失败' });
  }
});

module.exports = router;
