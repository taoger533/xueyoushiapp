const express = require('express');
const router = express.Router();
const Message = require('../models/Message');

// 获取当前用户收到的消息
router.get('/:userId', async (req, res) => {
  try {
    const messages = await Message.find({ toUserId: req.params.userId })
      .sort({ createdAt: -1 })
      .lean(); // 返回 JSON，可直接前端使用

    res.json(messages);
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
