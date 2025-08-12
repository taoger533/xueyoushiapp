const mongoose = require('mongoose');

// 用户模型，包含用户名、密码、角色、会员状态、教师头衔、接收学生状态等字段。
const userSchema = new mongoose.Schema({
  username: { type: String, required: true }, // 手机号
  password: { type: String, required: true },
  role: { type: String, enum: ['student', 'teacher'], required: true },
  // 是否会员：会员优先排序
  isMember: { type: Boolean, default: false },
  // 教师头衔编号：0 普通教员，1 专业教员，2 学霸大学生，3 专业教员+学霸大学生；学生无头衔
  titleCode: {
    type: Number,
    default: function () {
      return this.role === 'teacher' ? 0 : null;
    },
    enum: [0, 1, 2, 3, null],
  },
  // 是否正在接收学生，只有教师才有；默认为教师接收
  acceptingStudents: {
    type: Boolean,
    default: function () {
      return this.role === 'teacher' ? true : false;
    },
  },
}, {
  timestamps: { createdAt: 'createdAt', updatedAt: 'updatedAt' },
});

// 联合唯一索引：username + role
userSchema.index({ username: 1, role: 1 }, { unique: true });
// 按会员状态建立索引，便于按会员排序
userSchema.index({ isMember: 1 });

module.exports = mongoose.model('User', userSchema);
