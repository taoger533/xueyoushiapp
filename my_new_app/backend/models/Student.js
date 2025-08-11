const mongoose = require('mongoose');

const subjectPairSchema = new mongoose.Schema({
  phase: {
    type: String,
    required: [true, '学段不能为空'],
  },
  subject: {
    type: String,
    required: [true, '科目不能为空'],
  }
}, { _id: false });

const studentSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: [true, 'userId 必填'] 
  },

  name: { 
    type: String, 
    required: [true, '称呼不能为空'],
    maxlength: [5, '称呼不能超过5个字']
  },

  gender: { 
    type: String, 
    enum: ['男', '女'], 
    required: [true, '学员性别不能为空'] 
  },

  tutorGender: {
    type: String,
    enum: ['男', '女', '无'],
    required: [true, '教员性别要求不能为空']
  },

  tutorIdentity: {
    type: String,
    required: [true, '教员身份要求不能为空']
  },

  subjects: {
    type: [subjectPairSchema],
    validate: {
      validator: arr => Array.isArray(arr) && arr.length > 0,
      message: '学习科目至少填写一项'
    },
    default: []
  },

  rateMin: {
    type: Number,
    required: [true, '报价下限不能为空']
  },
  rateMax: {
    type: Number,
    required: [true, '报价上限不能为空']
  },

  duration: {
    type: String,
    maxlength: [3, '上课时长不能超过3个字'],
    required: [true, '上课时长不能为空']
  },

  frequency: {
    type: String,
    maxlength: [3, '一周次数不能超过3个字'],
    required: [true, '一周次数不能为空']
  },

  teachMethod: {
    type: String,
    enum: ['线上', '线下', '全部'],
    required: [true, '上课方式不能为空']
  },

  region: {
    type: String,
    maxlength: [20, '授课区域不能超过20个字'],
    // teachMethod = 线上 时可以为空
  },

  wechat: {
    type: String,
    required: [true, '微信号不能为空'],
    maxlength: [20, '微信号不能超过20个字']
  },

  description: {
    type: String,
    required: [true, '学员详细情况不能为空']
  },

  province: { 
    type: String,
    required: [true, '省份不能为空']
  },
  city: { 
    type: String,
    required: [true, '城市不能为空']
  },

  // —— 新增字段：是否公开 —— 
  isPublic: {
    type: Boolean,
    required: true,
    default: false
  },

}, {
  timestamps: { createdAt: 'createdAt', updatedAt: 'updatedAt' }
});

module.exports = mongoose.model('Student', studentSchema);
