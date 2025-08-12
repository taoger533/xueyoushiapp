const mongoose = require('mongoose');

// 子文档模式，用于表示教员的授课学段与科目配对
const subjectPairSchema = new mongoose.Schema({
  phase: {
    type: String,
    required: [true, '学段不能为空'],
  },
  subject: {
    type: String,
    required: [true, '科目不能为空'],
  },
}, { _id: false });

// 教员模型
const teacherSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'userId 必填'],
  },
  name: {
    type: String,
    required: [true, '称呼不能为空'],
  },
  gender: {
    type: String,
    enum: ['男', '女'],
    required: [true, '性别不能为空'],
  },
  identity: {
    type: String,
    required: [true, '当前身份不能为空'],
  },
  educationLevel: {
    type: String,
    enum: ['学士', '硕士', '博士'],
    required: [true, '最高学历不能为空'],
  },
  school: {
    type: String,
  },
  major: {
    type: String,
  },
  exp: {
    type: String,
  },
  subjects: {
    type: [subjectPairSchema],
    validate: {
      validator: arr => Array.isArray(arr) && arr.length > 0,
      message: '授课科目至少填写一项',
    },
    default: [],
  },
  rateMin: {
    type: Number,
    required: [true, '报价下限不能为空'],
  },
  rateMax: {
    type: Number,
    required: [true, '报价上限不能为空'],
  },
  wechat: {
    type: String,
    required: [true, '微信号不能为空'],
  },
  description: {
    type: String,
    required: [true, '个人自述不能为空'],
  },
  teachMethod: {
    type: String,
    enum: ['线上', '线下', '全部'],
    required: [true, '授课方式不能为空'],
  },
  province: {
    type: String,
    required: [true, '省份不能为空'],
  },
  city: {
    type: String,
    required: [true, '城市不能为空'],
  },
}, {
  timestamps: { createdAt: 'createdAt', updatedAt: 'updatedAt' },
});

// 为查询常用字段建立索引
teacherSchema.index({ teachMethod: 1 });
teacherSchema.index({ province: 1, city: 1 });
teacherSchema.index({ gender: 1 });
teacherSchema.index({ 'subjects.phase': 1 });
teacherSchema.index({ 'subjects.subject': 1 });
teacherSchema.index({ titleCode: 1 });
teacherSchema.index({ createdAt: -1 });
teacherSchema.index({ userId: 1 });

module.exports = mongoose.model('Teacher', teacherSchema);
