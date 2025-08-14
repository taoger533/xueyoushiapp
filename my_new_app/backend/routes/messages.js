const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/User');

// 获取当前用户收到的消息
router.get('/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;

    const messages = await Message.find({ toUserId: userId })
      .sort({ createdAt: -1 })
      .lean();

    // 获取用户会员信息
    const user = await User.findById(userId).lean();
    const isMember = user?.isMember ?? false;

    const result = [];
    for (const msg of messages) {
      // memberOnly 消息仅会员能看到
      if (msg.memberOnly && !isMember) {
        continue;
      }
      const m = { ...msg };
      // 非会员时隐藏手机号
      const hasPhone = m.extra && typeof m.extra === 'object' && m.extra.phone;
      if (!isMember && hasPhone) {
        m.extra = { ...m.extra };
        delete m.extra.phone;
        // 前端用 needMembership 提示
        m.extra.needMembership = true;
        m.content = `${m.content}（会员可查看联系方式）`;
      }
      result.push(m);
    }

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: '加载消息失败' });
  }
});

// 标记为已读（可选）
router.patch('/:id/read', async (req, res) => {
  try {
    const message = await Message.findByIdAndUpdate(
      req.params.id,
      { read: true },
      { new: true }
    );
    res.json(message);
  } catch (err) {
    res.status(500).json({ error: '标记失败' });
  }
});

// 前端确认收到消息后，触发归档或删除
router.post('/:id/confirm', async (req, res) => {
  try {
    const message = await Message.findById(req.params.id);
    if (!message) {
      return res.status(404).json({ error: '消息不存在' });
    }

    // TODO: 可扩展为存入 ArchivedMessage 集合
    await Message.findByIdAndDelete(req.params.id);

    res.json({ message: '消息已确认并归档' });
  } catch (error) {
    console.error('回执确认失败:', error);
    res.status(500).json({ error: '回执失败' });
  }
});

module.exports = router;
