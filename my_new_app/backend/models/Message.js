const mongoose = require('mongoose');

const subjectPairSchema = new mongoose.Schema({
  phase: { type: String, required: true },
  subject: { type: String, required: true }
}, { _id: false });

const messageSchema = new mongoose.Schema({
  fromUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  toUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  type: { type: String, enum: ['system', 'booking', 'payment'], default: 'system' },
  content: { type: String, required: true },
  read: { type: Boolean, default: false },
  confirmed: { type: Boolean, default: false }, // 前端回执确认标记
  createdAt: { type: Date, default: Date.now },

  // ✅ 新增：快照信息，用于展示称呼、科目、手机号等
  extra: {
    name: { type: String },                  // 称呼，如“张同学”
    subjects: [subjectPairSchema],           // 科目快照 [{ phase, subject }]
    phone: { type: String },                 // 手机号（注册时的 username）
    role: { type: String, enum: ['student', 'teacher'] }, // 可选：角色标记
  },

  // 如果为 true，则该消息仅在接收用户成为会员后才会显示
  memberOnly: { type: Boolean, default: false },
});

module.exports = mongoose.model('Message', messageSchema);
