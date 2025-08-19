// routes/confirmedBookings.js

const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const ConfirmedBooking = require('../models/ConfirmedBooking');
const User = require('../models/User'); // 用于累加教员好评数

/// 获取某学生的所有确认预约（用于统计学生当前的老师总数）
router.get('/student/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;
    const items = await ConfirmedBooking.find({
      'student.userId': studentId
    });
    res.json(items);
  } catch (err) {
    console.error('获取学生确认预约失败:', err);
    res.status(500).json({ error: '获取学生确认预约失败' });
  }
});

/// 获取某用户作为学生或教员参与的所有确认预约
router.get('/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;
    const items = await ConfirmedBooking.find({
      $or: [
        { 'student.userId': userId },
        { 'teacher.userId': userId }
      ]
    });
    res.json(items);
  } catch (err) {
    console.error('获取已确认预约失败:', err);
    res.status(500).json({ error: '获取已确认预约失败' });
  }
});

/// 评价接口：like=true 时给教员好评数 +1，然后删除该确认预约；like=false 仅删除
router.post('/:id/review', async (req, res) => {
  try {
    const { id } = req.params;
    const { like } = req.body || {};

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ error: 'id 非法' });
    }

    // 1) 找到该确认预约
    const booking = await ConfirmedBooking.findById(id);
    if (!booking) return res.status(404).json({ error: '未找到确认预约' });

    // 2) 如为好评，给教员 +1
    let newCount;
    if (like === true) {
      const teacherId = booking.teacher?.userId;
      if (!teacherId || !mongoose.Types.ObjectId.isValid(String(teacherId))) {
        return res.status(400).json({ error: '该记录的 teacher.userId 非法或缺失' });
      }
      const updated = await User.findOneAndUpdate(
        { _id: teacherId, role: 'teacher' },
        { $inc: { goodReviewCount: 1 } },
        { new: true }
      );
      if (!updated) {
        return res.status(404).json({ error: '未找到对应教员用户' });
      }
      newCount = updated.goodReviewCount ?? 0;
    }

    // 3) 删除该确认预约（评价完成即清理）
    await ConfirmedBooking.deleteOne({ _id: id });

    return res.json({
      ok: true,
      deletedId: id,
      incremented: like === true,
      ...(like === true ? { goodReviewCount: newCount } : {})
    });
  } catch (err) {
    console.error('评价处理失败:', err);
    return res.status(500).json({ error: '评价处理失败' });
  }
});

/// 删除一条确认预约（用于评价完成后清空待评价）
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const doc = await ConfirmedBooking.findByIdAndDelete(id);
    if (!doc) return res.status(404).json({ error: '未找到记录' });
    res.status(204).end();
  } catch (err) {
    console.error('删除确认预约失败:', err);
    res.status(500).json({ error: '删除确认预约失败' });
  }
});

module.exports = router;
