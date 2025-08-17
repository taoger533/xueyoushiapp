// my_new_app/backend/routes/student.js
const express = require('express');
const router = express.Router();
const Student = require('../models/Student');
const User = require('../models/User'); // 引入 User 模型
const { reviewContent } = require('../utils/reviewRules'); // 详细情况自动审核

// 发布学生信息（用于首次发布）
router.post('/', async (req, res) => {
  try {
    // 从请求体中取出“详细情况”字段（兼容多种命名）
    const detail =
      req.body.detail ??
      req.body.detailInfo ??
      req.body.description ??
      '';

    // 调用审核规则
    const review = reviewContent(detail);

    // 审核不通过则直接拒绝写库（硬拦截）
    if (review.status === 'rejected') {
      return res.status(400).json({
        error: review.message,
        flags: review.flags, // 可选：便于排查
        hits: review.hits,   // 可选：便于排查
      });
    }

    // 审核通过：写回审核结果（模型需包含 reviewStatus 与 reviewMessage 字段）
    const payload = {
      ...req.body,
      reviewStatus: review.status, // 'approved' | 'rejected'
      reviewMessage: review.message,
    };

    const student = new Student(payload);
    await student.save();

    res.status(201).json({
      message: '学生信息已发布',
      reviewStatus: review.status,
      reviewMessage: review.message,
      id: student._id,
    });
  } catch (err) {
    console.error('发布失败:', err);
    res.status(500).json({ error: '发布失败' });
  }
});

// 根据 userId 获取学生信息（判断是否已发布过）
router.get('/user/:userId', async (req, res) => {
  try {
    const student = await Student.findOne({ userId: req.params.userId });
    if (!student) return res.status(404).end();
    res.json(student);
  } catch (err) {
    console.error('查询失败:', err);
    res.status(500).json({ error: '查询失败' });
  }
});

// 根据 id 更新学生信息
router.put('/:id', async (req, res) => {
  try {
    // 为了在更新时重新跑审核，这里用“先查再改再存”的方式，便于写入审核结果
    const doc = await Student.findById(req.params.id);
    if (!doc) return res.status(404).json({ error: '未找到该学生信息' });

    // 应用更新字段
    Object.keys(req.body || {}).forEach((k) => {
      doc[k] = req.body[k];
    });

    // 只要传了“详细情况”字段，就重新审核一次
    const hasDetailInBody =
      Object.prototype.hasOwnProperty.call(req.body, 'detail') ||
      Object.prototype.hasOwnProperty.call(req.body, 'detailInfo') ||
      Object.prototype.hasOwnProperty.call(req.body, 'description');

    if (hasDetailInBody) {
      const detail =
        doc.detail ??
        doc.detailInfo ??
        doc.description ??
        '';
      const review = reviewContent(detail);

      // 审核不通过：拒绝更新
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
 * 获取学生列表，并支持筛选和分页：
 * - teachMethod: '线上' | '线下' | '全部'
 * - province, city: 地区（仅在线下模式传入）
 * - phase: 学段（小学/初中/高中/全部）
 * - subject: 科目（语文/数学/.../全部）
 * - gender: 学生性别（男/女/全部）
 * 返回时仅包括公开学生（isPublic=true），会员优先排列。
 *
 * 新增功能：如果 query 中包含 userId，则直接根据 userId 返回该学生信息（数组形式），兼容
 * `/api/students?userId=xxx` 的调用。
 */
router.get('/', async (req, res) => {
  try {
    // 如果携带 userId，则查询单个学生信息并返回数组。
    // 这里兼容多种字段命名，因为学生信息可能使用 userId、user_id 或 publisherId 来存储用户ID。
    if (req.query.userId) {
      const userId = req.query.userId;
      const stu = await Student.findOne({
        $or: [
          { userId: userId },
          { user_id: userId },
          { publisherId: userId },
        ],
      });
      if (!stu) return res.json([]);
      return res.json([stu]);
    }

    const {
      teachMethod,
      province,
      city,
      phase,
      subject,
      gender,
      page,
      limit,
    } = req.query;

    const query = { isPublic: true };

    // 授课方式：允许学生“偏好”为“全部”的也被命中
    if (teachMethod && teachMethod !== '全部') {
      query.teachMethod = { $in: [teachMethod, '全部'] };
    }

    // 地区（仅当传入省市时过滤；通常线下模式使用）
    if (province && city) {
      query.province = province;
      query.city = city;
    }

    // 学段与科目（数组字段示例：subjects: [{phase, subject}]）
    if (phase && phase !== '全部') {
      query['subjects.phase'] = phase;
    }
    if (subject && subject !== '全部') {
      query['subjects.subject'] = subject;
    }

    if (gender && gender !== '全部') {
      query.gender = gender;
    }

    // 先按创建时间倒序取出（lean 以便后续处理更轻量）
    const students = await Student.find(query).sort({ createdAt: -1 }).lean();

    // 取出关联 userIds 查询会员状态
    const userIds = students.map(s => s.userId).filter(Boolean);
    const users = await User.find(
      { _id: { $in: userIds } },
      'isMember'
    ).lean();

    const userMap = users.reduce((acc, u) => {
      acc[u._id.toString()] = !!u.isMember;
      return acc;
    }, {});

    // 合并会员信息
    let merged = students.map(s => {
      const key = s.userId ? s.userId.toString() : '';
      return { ...s, isMember: userMap[key] ?? false };
    });

    // 会员优先 + 创建时间倒序（保持稳定排序）
    merged.sort((a, b) => {
      if (a.isMember !== b.isMember) {
        return (b.isMember ? 1 : 0) - (a.isMember ? 1 : 0);
      }
      // 二级：createdAt 倒序
      const ta = new Date(a.createdAt || 0).getTime();
      const tb = new Date(b.createdAt || 0).getTime();
      return tb - ta;
    });

    // 分页
    const p = parseInt(page, 10) || 1;
    const l = parseInt(limit, 10) || 20;
    const start = (p - 1) * l;
    const paginated = merged.slice(start, start + l);

    res.json({ total: merged.length, data: paginated });
  } catch (err) {
    console.error('获取失败:', err);
    res.status(500).json({ error: '获取失败' });
  }
});

module.exports = router;
