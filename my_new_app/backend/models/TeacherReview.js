// models/TeacherReview.js
const mongoose = require('mongoose');

const scoreSchema = new mongoose.Schema({
  clarity:         { type: Number, min: 1, max: 5, required: true }, // 讲解清晰
  professionalism: { type: Number, min: 1, max: 5, required: true }, // 专业程度
  patience:        { type: Number, min: 1, max: 5, required: true }, // 耐心程度
  punctuality:     { type: Number, min: 1, max: 5, required: true }, // 守时守约
}, { _id: false });

const teacherReviewSchema = new mongoose.Schema({
  // 用于唯一定位这次成交（防止重复评价）
  bookingId:      { type: mongoose.Schema.Types.ObjectId, ref: 'ConfirmedBooking', required: true, index: true },
  // 学生与老师的 userId（均为 User 表的 _id）
  studentUserId:  { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  teacherUserId:  { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

  teacherName:    { type: String, default: '' },  // 冗余存一份，方便列表直出
  scores:         { type: scoreSchema, required: true },
  avgScore:       { type: Number, min: 1, max: 5, required: true },
}, {
  timestamps: { createdAt: true, updatedAt: false }
});

// 防止同一确认单被同一学生重复评价
teacherReviewSchema.index({ bookingId: 1, studentUserId: 1 }, { unique: true });
// 老师侧常用：按老师 + 时间倒序
teacherReviewSchema.index({ teacherUserId: 1, createdAt: -1 });

module.exports = mongoose.model('TeacherReview', teacherReviewSchema);
