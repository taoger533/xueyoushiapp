const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  fromUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  toUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  targetType: { type: String, enum: ['student', 'teacher'], required: true },
  targetId: { type: mongoose.Schema.Types.ObjectId, required: true },
  status: { type: String, enum: ['pending', 'confirmed', 'rejected'], default: 'pending' },
  createdAt: { type: Date, default: Date.now },

  // 目标信息快照，subjects 为对象数组
  targetInfo: {
    name: { type: String },
    gender: { type: String },
    subjects: [{
      phase: { type: String },
      subject: { type: String }
    }],
    rateMin: { type: Number },
    rateMax: { type: Number },
  },
});

module.exports = mongoose.model('Booking', bookingSchema);
