const express = require('express');
const bcrypt = require('bcrypt');
const User = require('../models/User');

const router = express.Router();

// 教师头衔映射
const titleCodeMap = {
  0: ['普通教员'],
  1: ['专业教员'],
  2: ['学霸大学生'],
  3: ['专业教员', '学霸大学生'],
};

// 注册接口
router.post('/register', async (req, res) => {
  console.log('[REGISTER] 请求体:', req.body); 
  const { username, password, role } = req.body;

  if (!username || !password || !role) {
    return res.status(400).json({ error: '缺少字段' });
  }

  const existing = await User.findOne({ username, role });
  if (existing) return res.status(400).json({ error: '该手机号已注册该身份' });

  const hashed = await bcrypt.hash(password, 10);
  const newUser = new User({ username, password: hashed, role });
  await newUser.save();

  res.status(201).json({ message: '注册成功' });
});

// 登录接口
router.post('/login', async (req, res) => {
  const { username, password, role } = req.body;

  if (!username || !password || !role) {
    return res.status(400).json({ error: '缺少字段' });
  }

  const user = await User.findOne({ username, role });
  if (!user) return res.status(400).json({ error: '该身份下的用户不存在' });

  const match = await bcrypt.compare(password, user.password);
  if (!match) return res.status(401).json({ error: '密码错误' });

  const titles = user.role === 'teacher'
    ? titleCodeMap[user.titleCode] || ['普通教员']
    : [];

  res.json({
    message: '登录成功',
    userId: user._id,
    role: user.role,
    isMember: user.isMember ?? false,
    titles,
    titleCode: user.titleCode ?? 0,
    acceptingStudents: user.acceptingStudents ?? false,
    goodReviewCount: user.role === 'teacher'                 // NEW（可选，但有用）
      ? (typeof user.goodReviewCount === 'number' ? user.goodReviewCount : 0)
      : null,
  });
});

// 检查手机号是否已注册
router.post('/check-phone', async (req, res) => {
  const { phone, role } = req.body;
  if (!phone || !role) {
    return res.status(400).json({ error: '缺少手机号或身份' });
  }

  const user = await User.findOne({ username: phone, role });
  res.json({ exists: !!user });
});

// 重置密码
router.post('/reset-password', async (req, res) => {
  const { phone, role, newPassword } = req.body;

  if (!phone || !role || !newPassword) {
    return res.status(400).json({ error: '缺少字段' });
  }

  const user = await User.findOne({ username: phone, role });
  if (!user) {
    return res.status(404).json({ error: '该手机号未注册此身份' });
  }

  const hashed = await bcrypt.hash(newPassword, 10);
  user.password = hashed;
  await user.save();

  res.json({ message: '密码重置成功' });
});

// 获取用户信息接口
router.get('/user-info/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });

    const titles = user.role === 'teacher'
      ? titleCodeMap[user.titleCode] || ['普通教员']
      : [];

    // NEW: 返回好评数（教师默认 0；学生可为 null）
    const goodReviewCount = user.role === 'teacher'
      ? (typeof user.goodReviewCount === 'number' ? user.goodReviewCount : 0)
      : null;

    res.json({
      isMember: user.isMember ?? false,
      titles,
      titleCode: user.titleCode ?? 0,
      rating: user.rating ?? 0,
      studentsCount: user.studentsCount ?? 0, // 如需更真实统计，可用 ConfirmedBooking 去重计算
      acceptingStudents: user.acceptingStudents ?? false,
      goodReviewCount, // NEW
    });
  } catch (e) {
    console.error('获取用户信息失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 更新用户信息接口（支持 acceptingStudents / isMember）
router.patch('/user-info/:id', async (req, res) => {
  const { id } = req.params;
  const { acceptingStudents, isMember } = req.body; // CHANGED

  // CHANGED: 宽松校验两种布尔字段（只要传了就必须是布尔）
  if (typeof acceptingStudents !== 'undefined' && typeof acceptingStudents !== 'boolean') {
    return res.status(400).json({ error: 'acceptingStudents 字段必须为布尔值' });
  }
  if (typeof isMember !== 'undefined' && typeof isMember !== 'boolean') {
    return res.status(400).json({ error: 'isMember 字段必须为布尔值' });
  }

  try {
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });

    // 只有教师能改 acceptingStudents；isMember 两端都允许
    if (typeof acceptingStudents !== 'undefined') {
      if (user.role !== 'teacher') {
        return res.status(403).json({ error: '只有教师用户可以更改接收学生状态' });
      }
      user.acceptingStudents = acceptingStudents;
    }

    if (typeof isMember !== 'undefined') {
      user.isMember = isMember;
    }

    await user.save();
    res.json({
      message: '用户信息更新成功',
      acceptingStudents: user.acceptingStudents ?? false,
      isMember: user.isMember ?? false,
    });
  } catch (e) {
    console.error('更新用户信息失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
