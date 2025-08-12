const express = require('express');
const router = express.Router();
const Student = require('../models/Student');

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
 * 获取学生列表，并支持筛选：
 * - teachMethod: '线上' | '线下' | '全部'
 * - province, city: 地区（仅在线下模式传入）
 * - phase: 学段（小学/初中/高中/全部）
 * - subject: 科目（语文/数学/.../全部）
 * - gender: 学生性别（男/女/全部）
 * 返回时仅包括公开学生（isPublic=true），按照发布时间倒序排序。
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
    } = req.query;

    const query = { isPublic: true };
    // 授课方式筛选，允许 teachMethod=线上/线下，只返回对应模式或全部
    if (teachMethod && teachMethod !== '全部') {
      query.teachMethod = { $in: [teachMethod, '全部'] };
    }
    // 地区筛选（通常仅线下需要）
    if (province && city) {
      query.province = province;
      query.city = city;
    }
    // 学段筛选
    if (phase && phase !== '全部') {
      query['subjects.phase'] = phase;
    }
    // 科目筛选
    if (subject && subject !== '全部') {
      query['subjects.subject'] = subject;
    }
    // 学员性别筛选
    if (gender && gender !== '全部') {
      query.gender = gender;
    }

    const students = await Student.find(query).sort({ createdAt: -1 });
    res.json(students);
  } catch (err) {
    console.error('获取失败:', err);
    res.status(500).json({ error: '获取失败' });
  }
});

module.exports = router;
