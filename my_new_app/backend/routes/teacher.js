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

/**
 * 获取教员列表（带筛选）：
 * 支持 query 参数：
 * - teachMethod: '线上' | '线下' | '全部'（或不传）
 * - province, city：地区（通常仅线下需要）
 * - phase: 学段（'全部' 或 具体：小学/初中/高中）
 * - subject: 科目（'全部' 或 具体：语文/数学/...）
 * - gender: 性别（'全部' | '男' | '女'）
 * - titleFilter: 0/1/2/3；其中 3 同时满足 1 与 2 的查询含义
 */
router.get('/', async (req, res) => {
  try {
    const {
      teachMethod,   // 线上/线下/全部
      province,
      city,
      phase,         // 小学/初中/高中/全部
      subject,       // 语文/数学/.../全部
      gender,        // 男/女/全部
      titleFilter,   // 0/1/2/3
    } = req.query;

    // 1) 组装 Teacher 基础查询条件
    const query = {};

    // 授课方式：允许 '全部' 的老师同时出现在'线上'或'线下'筛选结果中
    if (teachMethod && teachMethod !== '全部') {
      query.teachMethod = { $in: [teachMethod, '全部'] };
    }

    // 地区：前端一般只有线下才会传递，若传递则按 province + city 精确匹配
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

    // 2) 查 Teacher
    const teachers = await Teacher.find(query).sort({ createdAt: -1 }).lean();

    // 3) 取出所有有效 userId 并查 User 的 acceptingStudents 与 titleCode
    const userIds = teachers.map(t => t.userId).filter(Boolean);
    const users = await User.find(
      { _id: { $in: userIds } },
      'acceptingStudents titleCode'
    ).lean();

    // 4) 构造 user 映射表
    const userMap = users.reduce((acc, u) => {
      const code = Number.isInteger(u.titleCode) ? u.titleCode : 0;
      acc[u._id.toString()] = {
        acceptingStudents: !!u.acceptingStudents,
        titleCode: code,
        titles: titleCodeMap[code] || [],
      };
      return acc;
    }, {});

    // 5) 合并 user 信息回 teacher，并先得到基础列表
    let merged = teachers.map(t => {
      const key = t.userId ? t.userId.toString() : '';
      const userInfo = userMap[key] ?? {};
      return {
        ...t,
        acceptingStudents: userInfo.acceptingStudents ?? false,
        titleCode: userInfo.titleCode ?? 0,
        titles: userInfo.titles ?? [],
      };
    });

    // 6) 头衔过滤（titleFilter）：3 视为同时满足 1 和 2
    if (typeof titleFilter !== 'undefined') {
      const tf = parseInt(titleFilter, 10);
      merged = merged.filter((item) => {
        const c = item.titleCode ?? 0;
        if (tf === 3) return c === 3;          // 只要 code==3
        if (tf === 1) return c === 1 || c === 3; // 专业教员 或 复合
        if (tf === 2) return c === 2 || c === 3; // 学霸大学生 或 复合
        if (tf === 0) return c === 0;          // 仅普通教员
        return true;
      });
    }

    res.json(merged);
  } catch (err) {
    console.error('获取失败:', err);
    res.status(500).json({ error: '获取失败' });
  }
});

module.exports = router;
