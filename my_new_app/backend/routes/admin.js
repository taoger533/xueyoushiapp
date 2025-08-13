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

// 导入学生和教师登记信息模型
let StudentInfo;
let TeacherInfo;
try {
  // 根据实际路径引入 Student.js 和 Teacher.js
  StudentInfo = require('../models/Student');
} catch (err) {
  console.warn('未找到 Student 模型，请确认路径是否正确');
}
try {
  TeacherInfo = require('../models/Teacher');
} catch (err) {
  console.warn('未找到 Teacher 模型，请确认路径是否正确');
}

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

/**
 * 获取指定用户详情
 * GET /api/admin/user/:id
 * 返回不含密码字段的用户信息
 */
router.get('/user/:id', async (req, res) => {
  const { id } = req.params;
  try {
    // 查询用户并排除密码字段
    const user = await User.findById(id).select('-password');
    if (!user) return res.status(404).json({ error: '用户不存在' });
    res.json(user);
  } catch (err) {
    console.error('获取用户详情失败:', err);
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 更新用户登记信息
 * PATCH /api/admin/user/:id
 * 支持更新字段：username（手机号），isMember，titleCode，acceptingStudents
 */
router.patch('/user/:id', async (req, res) => {
  const { id } = req.params;
  const { username, isMember, titleCode, acceptingStudents } = req.body;
  try {
    const user = await User.findById(id);
    if (!user) return res.status(404).json({ error: '用户不存在' });
    // username 更新：必须是字符串
    if (typeof username !== 'undefined') {
      if (typeof username !== 'string' || !username.trim()) {
        return res.status(400).json({ error: 'username 必须是非空字符串' });
      }
      user.username = username.trim();
    }
    // isMember 更新：必须是布尔值
    if (typeof isMember !== 'undefined') {
      if (typeof isMember !== 'boolean') {
        return res.status(400).json({ error: 'isMember 必须是布尔值' });
      }
      user.isMember = isMember;
    }
    // titleCode 更新：必须是 0~3 的整数，且仅允许教师修改
    if (typeof titleCode !== 'undefined') {
      if (![0, 1, 2, 3].includes(titleCode)) {
        return res.status(400).json({ error: '无效的 titleCode，必须是 0~3 的整数' });
      }
      if (user.role !== 'teacher') {
        return res.status(403).json({ error: '只有教师可以修改头衔' });
      }
      user.titleCode = titleCode;
    }
    // acceptingStudents 更新：必须是布尔值且只有教师可以修改
    if (typeof acceptingStudents !== 'undefined') {
      if (typeof acceptingStudents !== 'boolean') {
        return res.status(400).json({ error: 'acceptingStudents 必须是布尔值' });
      }
      if (user.role !== 'teacher') {
        return res.status(403).json({ error: '只有教师可以修改是否接受学生' });
      }
      user.acceptingStudents = acceptingStudents;
    }
    // 保存更新
    await user.save();
    // 返回更新后的用户信息（排除密码）
    const updated = await User.findById(id).select('-password');
    res.json(updated);
  } catch (err) {
    console.error('更新用户登记信息失败:', err);
    // 重复用户名报错，可能违反唯一索引
    if (err.code === 11000) {
      return res.status(409).json({ error: '用户名已存在' });
    }
    res.status(500).json({ error: '服务器错误' });
  }
});

/**
 * 学生登记信息管理接口
 * GET /api/admin/student-registrations    - 获取所有学生登记记录
 * GET /api/admin/student-registration/:id - 获取单个学生登记记录
 * PATCH /api/admin/student-registration/:id - 更新学生登记信息
 * DELETE /api/admin/student-registration/:id - 删除学生登记信息
 */
if (StudentInfo) {
  // 获取所有学生登记信息
  router.get('/student-registrations', async (req, res) => {
    try {
      const records = await StudentInfo.find().sort({ _id: -1 });
      res.json(records);
    } catch (err) {
      console.error('获取学生登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 获取单个学生登记信息
  router.get('/student-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await StudentInfo.findById(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      res.json(record);
    } catch (err) {
      console.error('获取学生登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 更新学生登记信息
  router.patch('/student-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await StudentInfo.findById(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      // 使用传入的字段更新登记信息，但不允许修改 _id
      Object.keys(req.body).forEach(key => {
        if (key !== '_id') {
          record[key] = req.body[key];
        }
      });
      await record.save();
      res.json(record);
    } catch (err) {
      console.error('更新学生登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 删除学生登记信息
  router.delete('/student-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await StudentInfo.findByIdAndDelete(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      res.json({ message: '学生登记信息已删除' });
    } catch (err) {
      console.error('删除学生登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
}

/**
 * 教师登记信息管理接口
 * GET /api/admin/teacher-registrations    - 获取所有教师登记记录
 * GET /api/admin/teacher-registration/:id - 获取单个教师登记记录
 * PATCH /api/admin/teacher-registration/:id - 更新教师登记信息
 * DELETE /api/admin/teacher-registration/:id - 删除教师登记信息
 */
if (TeacherInfo) {
  // 获取所有教师登记信息
  router.get('/teacher-registrations', async (req, res) => {
    try {
      const records = await TeacherInfo.find().sort({ _id: -1 });
      res.json(records);
    } catch (err) {
      console.error('获取教师登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 获取单个教师登记信息
  router.get('/teacher-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await TeacherInfo.findById(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      res.json(record);
    } catch (err) {
      console.error('获取教师登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 更新教师登记信息
  router.patch('/teacher-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await TeacherInfo.findById(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      Object.keys(req.body).forEach(key => {
        if (key !== '_id') {
          record[key] = req.body[key];
        }
      });
      await record.save();
      res.json(record);
    } catch (err) {
      console.error('更新教师登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
  // 删除教师登记信息
  router.delete('/teacher-registration/:id', async (req, res) => {
    const { id } = req.params;
    try {
      const record = await TeacherInfo.findByIdAndDelete(id);
      if (!record) return res.status(404).json({ error: '记录不存在' });
      res.json({ message: '教师登记信息已删除' });
    } catch (err) {
      console.error('删除教师登记信息失败:', err);
      res.status(500).json({ error: '服务器错误' });
    }
  });
}

module.exports = router;
