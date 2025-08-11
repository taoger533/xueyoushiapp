require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

const authRoutes = require('./routes/auth');
const studentRoutes = require('./routes/student');
const teacherRoutes = require('./routes/teacher');
const bookingRoutes = require('./routes/bookings');
const confirmedBookingRoutes = require('./routes/confirmedBookings');
const messageRoutes = require('./routes/messages');
const professionalCertificationRoutes = require('./routes/professionalCertification');
const topStudentRoutes = require('./routes/topStudentCertification');
const uploadRoutes = require('./routes/upload');
const adminRoutes = require('./routes/admin');
const bannersRoutes = require('./routes/banners');
const paymentRoutes = require('./routes/payment');
const confirmedBookingsRouter = require('./routes/confirmedBookings');
const app = express();

// ✅ 中间件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ✅ 静态资源 & 上传接口
app.use('/api/upload', uploadRoutes);
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ✅ 提供静态网站（用于备案或测试）
// 在项目根目录创建 public/index.html
app.use(express.static(path.join(__dirname, 'public')));

// ✅ API 路由
app.use('/api/professional-certification', professionalCertificationRoutes);
app.use('/api/top-student-certification', topStudentRoutes);
app.use('/api', authRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/teachers', teacherRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/confirmed-bookings', confirmedBookingRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/banners', bannersRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/confirmedBookings', confirmedBookingsRouter);
// ✅ 测试路由（方便手机直接访问测试）
app.get('/ping', (req, res) => {
  res.send('pong');
});

// ✅ 数据库连接与启动服务
mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB connected');
    const port = process.env.PORT || 3000;
    app.listen(port, '0.0.0.0', () => {
      console.log(`✅ Server running at http://0.0.0.0:${port}`);
      console.log(`✅ Test route: http://112.124.25.171:${port}/ping`);
    });
  })
  .catch((err) => console.error('❌ MongoDB connection error:', err));
