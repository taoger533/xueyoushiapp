// routes/confirmedBookings.js

const express = require('express');
const router = express.Router();
const ConfirmedBooking = require('../models/ConfirmedBooking');

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

module.exports = router;
