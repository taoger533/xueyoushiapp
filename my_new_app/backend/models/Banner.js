const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema({
  imageUrl: { type: String, required: true }, // 图片访问地址
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Banner', bannerSchema);
