const express = require('express');
const router = express.Router();
const User = require('../models/User');

// 支付场景配置（单位价格）
const paymentScenarios = {
  member_teacher: { amount: 100, description: '教师会员，100元/年', unit: 'year' },
  member_student: { amount: 10,  description: '学生会员，10元/月',   unit: 'month' },
  professional_certification: { amount: 10, description: '专业教员认证，10元/次', unit: 'time' },
  top_student_certification:   { amount: 10, description: '学霸大学生认证，10元/次', unit: 'time' },
};

// 获取支付场景信息（保持不变）
router.get('/scenario/:id', (req, res) => {
  const { id } = req.params;
  const s = paymentScenarios[id];
  if (!s) return res.status(404).json({ error: '支付场景不存在' });
  res.json({ amount: s.amount, description: s.description, unit: s.unit });
});

// 确认支付（新增数量/时长的合计计算）
router.post('/confirm', async (req, res) => {
  const { scenarioId, userId, method, quantity, months, years } = req.body;

  if (!scenarioId || !userId || !method) {
    return res.status(400).json({ error: '缺少字段' });
  }

  const s = paymentScenarios[scenarioId];
  if (!s) return res.status(400).json({ error: '支付场景无效' });

  // 计算合计金额：按场景单位选择倍数，默认 1
  let multiplier = 1;
  if (s.unit === 'time') {
    const q = parseInt(quantity ?? 1, 10);
    multiplier = Number.isFinite(q) && q > 0 ? q : 1;
  } else if (s.unit === 'month') {
    const m = parseInt(months ?? 1, 10);
    multiplier = Number.isFinite(m) && m > 0 ? m : 1;
  } else if (s.unit === 'year') {
    const y = parseInt(years ?? 1, 10);
    multiplier = Number.isFinite(y) && y > 0 ? y : 1;
  }

  const totalAmount = s.amount * multiplier;

  try {
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: '用户不存在' });

    // 支付后的业务效果（示例）
    if (scenarioId === 'member_student') {
      // 按月叠加会员；这里仅示意：真实可记录到期时间
      user.isMember = true;
      await user.save();
    } else if (scenarioId === 'member_teacher') {
      user.isMember = true;
      await user.save();
    } else if (scenarioId === 'professional_certification') {
      console.log(`[支付] ${user.username} 支付专业教员认证费用 x${multiplier}`);
    } else if (scenarioId === 'top_student_certification') {
      console.log(`[支付] ${user.username} 支付学霸大学生认证费用 x${multiplier}`);
    }

    res.json({
      message: `${method} 支付成功`,
      unit: s.unit,
      unitAmount: s.amount,
      multiplier,
      totalAmount,
      scenario: s.description,
    });
  } catch (e) {
    console.error('支付确认失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
