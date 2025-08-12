const express = require('express');
const User = require('../models/User');
// 引入 ConfirmedBooking 模型用于订单管理（已确认预约）
const ConfirmedBooking = require('../models/ConfirmedBooking');

const router = express.Router();

// 教师头衔映射
const titleCodeMap = {
  0: ['普通教员'],
  1: ['专业教员'],
  2: ['学霸大学生'],
  3: ['专业教员', '学霸大学生'],
};

/**
 * 获取所有学生列表
 * GET /api/admin/students
 */
router.get('/students', async (req, res) => {
  try {
    const students = await User.find({ role: 'student' })
      .select('username isMember role')
      .sort({ _id: -1 });
    res.json(students);
  } catch (err) {
    console.error('获取学生列表失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 获取所有教师列表
 * GET /api/admin/teachers
 */
router.get('/teachers', async (req, res) => {
  try {
    const teachers = await User.find({ role: 'teacher' })
      .select('username isMember role titleCode acceptingStudents')
      .sort({ _id: -1 })
      .lean();

    const result = teachers.map(t => ({
      ...t,
      titles: titleCodeMap[t.titleCode] || [], // 补充头衔字段给前端展示
    }));

    res.json(result);
  } catch (err) {
    console.error('获取教师列表失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 更新会员状态
 * PATCH /api/admin/user/:id/membership
 * { isMember: true/false }
 */
router.patch('/user/:id/membership', async (req, res) => {
  const { id } = req.params;
  const { isMember } = req.body;

  if (typeof isMember !== 'boolean') {
    return res.status(400).json({ error: 'isMember 必须是布尔值' });
  }

  try {
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });

    user.isMember = isMember;
    await user.save();

    res.json({ message: '会员状态更新成功', isMember: user.isMember });
  } catch (err) {
    console.error('更新会员状态失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 更新教师头衔
 * PATCH /api/admin/user/:id/title-code
 * { titleCode: 0~3 }
 */
router.patch('/user/:id/title-code', async (req, res) => {
  const { id } = req.params;
  const { titleCode } = req.body;

  if (![0, 1, 2, 3].includes(titleCode)) {
    return res.status(400).json({ error: '无效的 titleCode，必须是 0~3 的整数' });
  }

  try {
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });
    if (user.role !== 'teacher') {
      return res.status(403).json({ error: '只有教师可以修改头衔' });
    }

    user.titleCode = titleCode;
    await user.save();

    res.json({
      message: '头衔更新成功',
      titleCode: user.titleCode,
      titles: titleCodeMap[titleCode] || [],
    });
  } catch (err) {
    console.error('更新教师头衔失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 删除用户（可选）
 * DELETE /api/admin/user/:id
 */
router.delete('/user/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const user = await User.findByIdAndDelete(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });
    res.json({ message: '用户已删除' });
  } catch (err) {
    console.error('删除用户失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 获取所有订单（已确认预约）
 * GET /api/admin/orders
 */
router.get('/orders', async (req, res) => {
  try {
    // 按创建时间倒序返回全部已确认预约作为订单列表
    const orders = await ConfirmedBooking.find().sort({ _id: -1 });
    res.json(orders);
  } catch (err) {
    console.error('获取订单列表失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 删除订单（已确认预约）
 * DELETE /api/admin/order/:id
 */
router.delete('/order/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const order = await ConfirmedBooking.findByIdAndDelete(id);
    if (!order) {
      return res.status(404).json({ error: '订单不存在' });
    }
    res.json({ message: '订单已删除' });
  } catch (err) {
    console.error('删除订单失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
