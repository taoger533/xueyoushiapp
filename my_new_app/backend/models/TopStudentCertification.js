const mongoose = require('mongoose');

const topStudentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  university: { type: String, required: true, maxlength: 15 },
  major: { type: String, required: true, maxlength: 10 },
  idFrontUrl: { type: String, required: true },
  idBackUrl: { type: String, required: true },
  studentIdUrl: { type: String, required: true },
  suppUrls: [{ type: String }], // 最多三张
  submittedAt: { type: Date, default: Date.now },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' }
});

module.exports = mongoose.model('TopStudentCertification', topStudentSchema);
