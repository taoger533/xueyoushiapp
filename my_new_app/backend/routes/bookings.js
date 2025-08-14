const express = require('express');
const router = express.Router();
const Booking = require('../models/Booking');
const Message = require('../models/Message');
const ConfirmedBooking = require('../models/ConfirmedBooking');

const Student = require('../models/Student');
const Teacher = require('../models/Teacher');
const User = require('../models/User'); // 获取手机号和会员状态

// 创建预约
router.post('/', async (req, res) => {
  const { fromUserId, toUserId, targetType, targetId, targetInfo } = req.body;
  if (!fromUserId || !toUserId || !targetType || !targetId) {
    return res.status(400).json({ error: '字段不完整' });
  }

  try {
    const booking = new Booking({ fromUserId, toUserId, targetType, targetId, targetInfo });
    await booking.save();
    res.status(201).json(booking);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '创建预约失败' });
  }
});

// 获取用户收到的预约请求
router.get('/to/:userId', async (req, res) => {
  try {
    const bookings = await Booking
      .find({ toUserId: req.params.userId })
      .populate('fromUserId');
    res.json(bookings);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '获取预约失败' });
  }
});

// 获取用户发出的预约
router.get('/from/:userId', async (req, res) => {
  try {
    const bookings = await Booking.find({ fromUserId: req.params.userId });
    res.json(bookings);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '获取预约失败' });
  }
});

// 更新预约状态（确认或拒绝）
router.patch('/:id', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({ error: '预约不存在' });
    }

    const status = req.body.status;

    if (status === 'confirmed') {
      let studentInfo = null;
      let teacherInfo = null;

      let toSnapshot = {};    // 给预约发起人看的快照（对方信息）
      let fromSnapshot = {};  // 给确认者看的快照（对方信息）

      if (booking.targetType === 'teacher') {
        const teacher = await Teacher.findById(booking.targetId).lean();
        const student = await Student.findOne({ userId: booking.fromUserId }).lean();
        const teacherUser = await User.findById(teacher.userId).lean();
        const studentUser = await User.findById(student.userId).lean();

        if (!teacher || !student || !teacherUser || !studentUser) {
          return res.status(400).json({ error: '信息不完整，无法确认预约' });
        }

        teacherInfo = {
          userId: teacher.userId,
          name: teacher.name,
          subjects: teacher.subjects,
        };
        studentInfo = {
          userId: student.userId,
          name: student.name,
          subjects: student.subjects,
        };

        // 发给学生（发起者）的快照：教师的信息
        toSnapshot = {
          name: teacher.name,
          phone: teacherUser.username,
          subjects: teacher.subjects,
          role: 'teacher',
        };

        // 发给教师（确认者）的快照：学生的信息
        fromSnapshot = {
          name: student.name,
          phone: studentUser.username,
          subjects: student.subjects,
          role: 'student',
        };

      } else if (booking.targetType === 'student') {
        const student = await Student.findById(booking.targetId).lean();
        const teacher = await Teacher.findOne({ userId: booking.fromUserId }).lean();
        const teacherUser = await User.findById(teacher.userId).lean();
        const studentUser = await User.findById(student.userId).lean();

        if (!teacher || !student || !teacherUser || !studentUser) {
          return res.status(400).json({ error: '信息不完整，无法确认预约' });
        }

        teacherInfo = {
          userId: teacher.userId,
          name: teacher.name,
          subjects: teacher.subjects,
        };
        studentInfo = {
          userId: student.userId,
          name: student.name,
          subjects: student.subjects,
        };

        // 发给教师（发起者）的快照：学生的信息
        toSnapshot = {
          name: student.name,
          phone: studentUser.username,
          subjects: student.subjects,
          role: 'student',
        };

        // 发给学生（确认者）的快照：教师的信息
        fromSnapshot = {
          name: teacher.name,
          phone: teacherUser.username,
          subjects: teacher.subjects,
          role: 'teacher',
        };
      }

      // 写入 ConfirmedBooking
      await ConfirmedBooking.create({
        teacher: teacherInfo,
        student: studentInfo
      });

      // 获取发起者和确认者的会员状态
      const originUser = await User.findById(booking.fromUserId).lean();
      const confirmerUser = await User.findById(booking.toUserId).lean();
      const isOriginMember = originUser?.isMember ?? false;
      const isConfirmerMember = confirmerUser?.isMember ?? false;

      // 发给发起者的消息
      if (isOriginMember) {
        // 会员直接收到带联系方式的系统消息
        const msgToOrigin = new Message({
          fromUserId: booking.toUserId,
          toUserId: booking.fromUserId,
          type: 'booking',
          content: '你发起的预约已被确认',
          confirmed: false,
          extra: toSnapshot,
          memberOnly: false
        });
        await msgToOrigin.save();
      } else {
        // 非会员先收到提示消息，不含手机号
        const originPrompt = new Message({
          fromUserId: booking.toUserId,
          toUserId: booking.fromUserId,
          type: 'booking',
          content: '你发起的预约已被确认，但您尚未成为会员，暂时无法查看对方联系方式，请开通会员后查看',
          confirmed: false,
          extra: { ...toSnapshot, phone: undefined },
          memberOnly: false
        });
        await originPrompt.save();
        // 同时创建一个仅会员可见的带联系方式消息
        const originWithheld = new Message({
          fromUserId: booking.toUserId,
          toUserId: booking.fromUserId,
          type: 'booking',
          content: '你发起的预约已被确认',
          confirmed: false,
          extra: toSnapshot,
          memberOnly: true
        });
        await originWithheld.save();
      }

      // 发给确认者的消息
      if (isConfirmerMember) {
        const msgToConfirmer = new Message({
          fromUserId: booking.fromUserId,
          toUserId: booking.toUserId,
          type: 'booking',
          content: '你已成功确认对方的预约',
          confirmed: false,
          extra: fromSnapshot,
          memberOnly: false
        });
        await msgToConfirmer.save();
      } else {
        // 非会员确认者
        const confirmerPrompt = new Message({
          fromUserId: booking.fromUserId,
          toUserId: booking.toUserId,
          type: 'booking',
          content: '你已成功确认对方的预约，但您尚未成为会员，暂时无法查看对方联系方式，请开通会员后查看',
          confirmed: false,
          extra: { ...fromSnapshot, phone: undefined },
          memberOnly: false
        });
        await confirmerPrompt.save();
        const confirmerWithheld = new Message({
          fromUserId: booking.fromUserId,
          toUserId: booking.toUserId,
          type: 'booking',
          content: '你已成功确认对方的预约',
          confirmed: false,
          extra: fromSnapshot,
          memberOnly: true
        });
        await confirmerWithheld.save();
      }

      // 删除预约
      await Booking.findByIdAndDelete(req.params.id);
      return res.json({ success: true, message: '预约已确认并迁移' });
    }

    // 拒绝预约逻辑
    if (status === 'rejected') {
      const msgReject = new Message({
        fromUserId: booking.toUserId,
        toUserId: booking.fromUserId,
        type: 'booking',
        content: '你发起的预约已被拒绝',
        confirmed: false,
        extra: booking.targetInfo,
        memberOnly: false
      });
      await msgReject.save();

      await Booking.findByIdAndDelete(req.params.id);
      return res.json({ success: true, message: '预约已拒绝并删除' });
    }

    // 其他状态
    const updated = await Booking.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );
    res.json(updated);

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '更新预约失败' });
  }
});

module.exports = router;
