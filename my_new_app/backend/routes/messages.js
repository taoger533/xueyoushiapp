const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/User');

// 获取当前用户收到的消息
router.get('/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;

    // 查询当前用户收到的消息
    const messages = await Message.find({ toUserId: userId })
      .sort({ createdAt: -1 })
      .lean(); // 返回 JSON，可直接前端使用

    // 获取用户会员信息
    let user;
    try {
      user = await User.findById(userId).lean();
    } catch (e) {
      user = null;
    }
    const isMember = user?.isMember ?? false;

    // 根据会员状态处理消息列表：非会员预约相关消息隐藏联系方式并标记提示
    const processedMessages = messages.map((msg) => {
      const m = { ...msg };
      // 非会员情况下，对预约成功/确认预约等 booking 类型消息做处理
      const needsMask =
        !isMember &&
        (m.type === 'booking' ||
          (typeof m.content === 'string' &&
            (m.content.includes('预约成功') || m.content.includes('确认预约'))));
      if (needsMask) {
        // 深拷贝 extra，避免修改原消息
        m.extra = m.extra ? { ...m.extra } : {};
        // 删除手机号
        if ('phone' in m.extra) {
          delete m.extra.phone;
        }
        // 标记需要会员才能查看联系方式，供前端识别
        m.extra.needMembership = true;
        // 在内容后附加提示，告知用户需要会员才能查看联系方式
        m.content = `${m.content}（会员可查看联系方式）`;
      }
      return m;
    });

    res.json(processedMessages);
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
