const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const ProfessionalCertification = require('../models/ProfessionalCertification');
const User = require('../models/User');
const Message = require('../models/Message');

// 获取服务器 uploads 目录的绝对路径
const uploadDir = path.join(__dirname, '..', 'uploads');

// 教师头衔映射
const titleCodeMap = {
  0: ['普通教员'],
  1: ['专业教员'],
  2: ['学霸大学生'],
  3: ['专业教员', '学霸大学生'],
};

// 删除文件工具函数
function deleteFileIfExists(filePath) {
  if (!filePath) return;
  const localPath = filePath.startsWith('/uploads/')
    ? path.join(uploadDir, filePath.replace('/uploads/', ''))
    : filePath;
  fs.unlink(localPath, (err) => {
    if (err) console.warn('删除文件失败:', localPath, err.message);
    else console.log('已删除文件:', localPath);
  });
}

// 提交专业教员认证申请
router.post('/', async (req, res) => {
  const { userId, school, major, idFrontUrl, idBackUrl, certificateUrl } = req.body;
  if (!userId || !school || !major || !idFrontUrl || !idBackUrl || !certificateUrl) {
    return res.status(400).json({ error: '字段不完整' });
  }

  try {
    const existing = await ProfessionalCertification.findOne({ userId });
    if (existing) {
      return res.status(409).json({ error: '您已提交过申请' });
    }

    const record = new ProfessionalCertification({
      userId,
      school,
      major,
      idFrontUrl,
      idBackUrl,
      certificateUrl,
    });

    await record.save();
    res.status(201).json({ message: '提交成功' });
  } catch (e) {
    console.error('提交认证失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 获取所有认证申请（管理端）
router.get('/admin/list', async (req, res) => {
  try {
    const list = await ProfessionalCertification.find()
      .populate('userId', 'username role titleCode')
      .sort({ submittedAt: -1 });

    const result = list.map(item => {
      const user = item.userId || {};
      return {
        ...item.toObject(),
        userId: {
          ...user,
          titles: titleCodeMap[user.titleCode] || ['普通教员'],
        },
      };
    });

    res.json(result);
  } catch (e) {
    console.error('获取认证列表失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 审核通过
router.patch('/admin/approve/:id', async (req, res) => {
  try {
    const record = await ProfessionalCertification.findById(req.params.id).populate('userId');
    if (!record) return res.status(404).json({ error: '未找到申请记录' });

    const user = await User.findById(record.userId._id);
    if (user) {
      // 更新 titleCode：若已有学霸（2），则设置为组合（3），否则设置为专业教员（1）
      if (user.titleCode === 2) {
        user.titleCode = 3;
      } else {
        user.titleCode = 1;
      }
      await user.save();
    }

    await Message.create({
      toUserId: record.userId._id,
      type: 'system',
      content: '您的专业教员认证已通过，头衔已更新为专业教员。',
      extra: { role: record.userId.role },
    });

    deleteFileIfExists(record.idFrontUrl);
    deleteFileIfExists(record.idBackUrl);
    deleteFileIfExists(record.certificateUrl);

    await ProfessionalCertification.findByIdAndDelete(record._id);

    res.json({ message: '认证已通过，用户头衔已更新，消息已发送，申请记录和图片已删除' });
  } catch (e) {
    console.error('审核通过失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 审核否认
router.patch('/admin/reject/:id', async (req, res) => {
  try {
    const record = await ProfessionalCertification.findById(req.params.id).populate('userId');
    if (!record) return res.status(404).json({ error: '未找到申请记录' });

    await Message.create({
      toUserId: record.userId._id,
      type: 'system',
      content: '您的专业教员认证未通过，请检查材料后重新提交。',
      extra: { role: record.userId.role },
    });

    deleteFileIfExists(record.idFrontUrl);
    deleteFileIfExists(record.idBackUrl);
    deleteFileIfExists(record.certificateUrl);

    await ProfessionalCertification.findByIdAndDelete(record._id);

    res.json({ message: '认证已否认，消息已发送，申请记录和图片已删除' });
  } catch (e) {
    console.error('审核否认失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
