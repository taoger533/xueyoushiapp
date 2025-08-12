const express = require('express');
const router = express.Router();
const Student = require('../models/Student');
const User = require('../models/User');

// 发布学生信息（用于首次发布）
router.post('/', async (req, res) => {
  try {
    const student = new Student(req.body);
    await student.save();
    res.status(201).json({ message: '学生信息已发布' });
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
    const updated = await Student.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    if (!updated) return res.status(404).json({ error: '未找到该学生信息' });
    res.json(updated);
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
 */
router.get('/', async (req, res) => {
  try {
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
    if (teachMethod && teachMethod !== '全部') {
      query.teachMethod = { $in: [teachMethod, '全部'] };
    }
    if (province && city) {
      query.province = province;
      query.city = city;
    }
    if (phase && phase !== '全部') {
      query['subjects.phase'] = phase;
    }
    if (subject && subject !== '全部') {
      query['subjects.subject'] = subject;
    }
    if (gender && gender !== '全部') {
      query.gender = gender;
    }

    // 按创建时间倒序先查出全部数据（lean 方便后续处理）
    const students = await Student.find(query).sort({ createdAt: -1 }).lean();
    // 取出关联 userIds
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
    // 按会员优先排序，再保持创建时间倒序
    merged.sort((a, b) => {
      if (a.isMember === b.isMember) {
        return 0; // 保持原有按 createdAt 倒序的顺序
      }
      return (b.isMember ? 1 : 0) - (a.isMember ? 1 : 0);
    });
    // 分页处理
    const p = parseInt(page) || 1;
    const l = parseInt(limit) || 20;
    const start = (p - 1) * l;
    const paginated = merged.slice(start, start + l);
    res.json({ total: merged.length, data: paginated });
  } catch (err) {
    console.error('获取失败:', err);
    res.status(500).json({ error: '获取失败' });
  }
});

module.exports = router;
