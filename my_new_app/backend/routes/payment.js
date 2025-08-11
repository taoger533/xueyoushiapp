const express = require('express');
const router = express.Router();
const User = require('../models/User');

// 支付场景配置，可改为从数据库读取
const paymentScenarios = {
  member_teacher: { amount: 100, description: '教师会员，100元/年' },
  member_student: { amount: 10, description: '学生会员，10元/月' },
  professional_certification: { amount: 10, description: '专业教员认证，10元/次' },
  top_student_certification: { amount: 10, description: '学霸大学生认证，10元/次' },
};

// 1️⃣ 获取支付场景信息
router.get('/scenario/:id', (req, res) => {
  const { id } = req.params;
  const scenario = paymentScenarios[id];
  if (!scenario) return res.status(404).json({ error: '支付场景不存在' });
  res.json({ amount: scenario.amount, description: scenario.description });
});

// 2️⃣ 模拟确认支付
router.post('/confirm', async (req, res) => {
  const { scenarioId, userId, method } = req.body;

  if (!scenarioId || !userId || !method) {
    return res.status(400).json({ error: '缺少字段' });
  }

  const scenario = paymentScenarios[scenarioId];
  if (!scenario) return res.status(400).json({ error: '支付场景无效' });

  try {
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: '用户不存在' });

    // 模拟不同场景的支付逻辑
    if (scenarioId.startsWith('member')) {
      user.isMember = true; // 简化处理：标记会员
      await user.save();
    } else if (scenarioId === 'professional_certification') {
      // 此处仅记录支付，认证仍通过专业认证流程
      console.log(`[支付] 用户 ${user.username} 已支付专业教员认证费用`);
    } else if (scenarioId === 'top_student_certification') {
      console.log(`[支付] 用户 ${user.username} 已支付学霸大学生认证费用`);
    }

    res.json({
      message: `${method} 支付成功`,
      amount: scenario.amount,
      scenario: scenario.description,
    });
  } catch (e) {
    console.error('支付确认失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
