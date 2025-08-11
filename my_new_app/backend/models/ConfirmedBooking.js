const mongoose = require('mongoose');

const subjectPairSchema = new mongoose.Schema({
  phase: { type: String, required: true },
  subject: { type: String, required: true },
}, { _id: false });

const confirmedBookingSchema = new mongoose.Schema({
  student: {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    name: { type: String, required: true },
    subjects: { type: [subjectPairSchema], required: true },
  },
  teacher: {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    name: { type: String, required: true },
    subjects: { type: [subjectPairSchema], required: true },
  }
});

module.exports = mongoose.model('ConfirmedBooking', confirmedBookingSchema);
