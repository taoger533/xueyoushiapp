const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const TopStudentCertification = require('../models/TopStudentCertification');
const User = require('../models/User');
const Message = require('../models/Message');

const uploadDir = path.join(__dirname, '..', 'uploads');

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

// 提交学霸大学生认证
router.post('/', async (req, res) => {
  const {
    userId,
    university,
    major,
    idFrontUrl,
    idBackUrl,
    studentIdUrl,
    suppUrls = []
  } = req.body;

  if (!userId || !university || !major || !idFrontUrl || !idBackUrl || !studentIdUrl) {
    return res.status(400).json({ error: '字段不完整' });
  }

  if (!Array.isArray(suppUrls) || suppUrls.length === 0) {
    return res.status(400).json({ error: '至少上传一张佐证材料' });
  }

  try {
    const exists = await TopStudentCertification.findOne({ userId });
    if (exists) {
      return res.status(409).json({ error: '您已提交过申请' });
    }

    const record = new TopStudentCertification({
      userId,
      university,
      major,
      idFrontUrl,
      idBackUrl,
      studentIdUrl,
      suppUrls
    });

    await record.save();
    res.status(201).json({ message: '提交成功' });
  } catch (e) {
    console.error('认证提交失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 获取所有认证申请（管理端）
router.get('/admin/list', async (req, res) => {
  try {
    const list = await TopStudentCertification.find()
      .populate('userId', 'username role titleCode')
      .sort({ submittedAt: -1 });

    // 如需返回 titles，可追加处理逻辑
    res.json(list);
  } catch (e) {
    console.error('获取认证列表失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 审核通过
router.patch('/admin/approve/:id', async (req, res) => {
  try {
    const record = await TopStudentCertification.findById(req.params.id).populate('userId');
    if (!record) return res.status(404).json({ error: '未找到申请记录' });

    // ✅ 更新用户 titleCode：已有 1（专业教员）则设为 3；否则设为 2
    const user = await User.findById(record.userId._id);
    if (user) {
      if (user.titleCode === 1) {
        user.titleCode = 3;
      } else {
        user.titleCode = 2;
      }
      await user.save();
    }

    // ✅ 创建系统消息
    await Message.create({
      toUserId: record.userId._id,
      type: 'system',
      content: '您的学霸大学生认证已通过，头衔已更新为学霸大学生。',
      extra: { role: record.userId.role },
    });

    // ✅ 删除上传图片
    deleteFileIfExists(record.idFrontUrl);
    deleteFileIfExists(record.idBackUrl);
    deleteFileIfExists(record.studentIdUrl);
    (record.suppUrls || []).forEach(deleteFileIfExists);

    // ✅ 删除数据库记录
    await TopStudentCertification.findByIdAndDelete(record._id);

    res.json({ message: '认证已通过，用户头衔已更新，消息已发送，申请记录和图片已删除' });
  } catch (e) {
    console.error('审核通过失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

// 审核否认
router.patch('/admin/reject/:id', async (req, res) => {
  try {
    const record = await TopStudentCertification.findById(req.params.id).populate('userId');
    if (!record) return res.status(404).json({ error: '未找到申请记录' });

    await Message.create({
      toUserId: record.userId._id,
      type: 'system',
      content: '您的学霸大学生认证未通过，请检查材料后重新提交。',
      extra: { role: record.userId.role },
    });

    deleteFileIfExists(record.idFrontUrl);
    deleteFileIfExists(record.idBackUrl);
    deleteFileIfExists(record.studentIdUrl);
    (record.suppUrls || []).forEach(deleteFileIfExists);

    await TopStudentCertification.findByIdAndDelete(record._id);

    res.json({ message: '认证已否认，消息已发送，申请记录和图片已删除' });
  } catch (e) {
    console.error('审核否认失败:', e);
    res.status(500).json({ error: '服务器错误' });
  }
});

module.exports = router;
