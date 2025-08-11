const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true },  // 手机号
  password: { type: String, required: true },
  role: { type: String, enum: ['student', 'teacher'], required: true },
  isMember: { type: Boolean, default: false }, // 默认非会员

  // 教师头衔编号：0 普通教员，1 专业教员，2 学霸大学生，3 专业教员+学霸大学生
  titleCode: {
    type: Number,
    default: function () {
      return this.role === 'teacher' ? 0 : null; // 学生无头衔
    },
    enum: [0, 1, 2, 3, null],
  },

  acceptingStudents: {
    type: Boolean,
    default: function () {
      // 只有教师才会“接收学生”，默认接收
      return this.role === 'teacher' ? true : false;
    }
  }
});

userSchema.index({ username: 1, role: 1 }, { unique: true }); // 联合唯一

module.exports = mongoose.model('User', userSchema);
