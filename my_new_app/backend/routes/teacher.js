const express = require('express');
const router = express.Router();
const Teacher = require('../models/Teacher');
const User = require('../models/User');  // 引入 User 模型

// 教师头衔映射表
const titleCodeMap = {
  0: ['普通教员'],
  1: ['专业教员'],
  2: ['学霸大学生'],
  3: ['专业教员', '学霸大学生'],
};

// 发布教员信息
router.post('/', async (req, res) => {
  try {
    const teacher = new Teacher(req.body);
    await teacher.save();
    res.status(201).json({ message: '教员信息已发布' });
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
    const updated = await Teacher.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    if (!updated) return res.status(404).json({ error: '未找到该教员' });
    res.json(updated);
  } catch (err) {
    console.error('更新失败:', err);
    res.status(500).json({ error: '更新失败' });
  }
});

// 获取所有教员信息，并附加用户的 acceptingStudents、titleCode 与 titles 字段
router.get('/', async (req, res) => {
  try {
    // 先取出所有教师
    const teachers = await Teacher.find().sort({ createdAt: -1 }).lean();

    // 收集所有关联的 userId（可能存在 null）
    const userIds = teachers.map(t => t.userId).filter(Boolean);

    // 查询对应用户的 acceptingStudents 和 titleCode 字段
    const users = await User.find(
      { _id: { $in: userIds } },
      'acceptingStudents titleCode'
    ).lean();

    // 构造 user 映射表：_id(string) -> { acceptingStudents, titleCode, titles }
    const userMap = users.reduce((acc, u) => {
      const code = Number.isInteger(u.titleCode) ? u.titleCode : 0;
      acc[u._id.toString()] = {
        acceptingStudents: !!u.acceptingStudents,
        titleCode: code,
        titles: titleCodeMap[code] || [],
      };
      return acc;
    }, {});

    // 合并到教师对象中
    const result = teachers.map(t => {
      const key = t.userId ? t.userId.toString() : '';
      const userInfo = userMap[key] ?? {};
      return {
        ...t,
        acceptingStudents: userInfo.acceptingStudents ?? false,
        titleCode: userInfo.titleCode ?? 0,     // ← 新增：返回整型 code
        titles: userInfo.titles ?? [],          // ← 保留：字符串数组
      };
    });

    res.json(result);
  } catch (err) {
    console.error('获取失败:', err);
    res.status(500).json({ error: '获取失败' });
  }
});

module.exports = router;
