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
    res.status(500).json({ error: '发布失败' });
  }
});

// 获取所有学生信息
router.get('/', async (req, res) => {
  try {
    const students = await Student.find().sort({ createdAt: -1 });
    res.json(students);
  } catch (err) {
    res.status(500).json({ error: '获取失败' });
  }
});

// 根据 userId 获取学生信息（判断是否已发布过）
router.get('/user/:userId', async (req, res) => {
  try {
    const student = await Student.findOne({ userId: req.params.userId });
    if (!student) return res.status(404).end();
    res.json(student);
  } catch (err) {
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
    res.status(500).json({ error: '更新失败' });
  }
});

module.exports = router;
