const mongoose = require('mongoose');

const professionalCertificationSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  school: { type: String, required: true, maxlength: 15 },
  major: { type: String, required: true, maxlength: 10 },
  idFrontUrl: { type: String, required: true },
  idBackUrl: { type: String, required: true },
  certificateUrl: { type: String, required: true },
  submittedAt: { type: Date, default: Date.now },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' }
});

module.exports = mongoose.model('ProfessionalCertification', professionalCertificationSchema);
