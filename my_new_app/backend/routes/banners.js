const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const bannersDir = path.join(__dirname, '..', 'uploads', 'banners');

// 获取轮播图列表（读取文件夹）
router.get('/', async (req, res) => {
  try {
    if (!fs.existsSync(bannersDir)) {
      return res.json([]); // 文件夹不存在直接返回空
    }

    // 读取文件夹所有文件
    const files = fs.readdirSync(bannersDir)
      .filter(file => /\.(jpg|jpeg|png|gif|webp)$/i.test(file)) // 过滤图片
      .map(file => `/uploads/banners/${file}`); // 返回可访问路径

    res.json(files);
  } catch (err) {
    console.error('读取轮播图失败:', err);
    res.status(500).json({ error: '获取轮播图失败' });
  }
});

module.exports = router;
