require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const statisticsRoutes = require('./src/routes/statisticsRoutes');
const app = express();
app.use(cors());
app.use(express.json());
const notificationRoutes = require('./src/routes/notificationRoutes');
app.use('/api/notifications', notificationRoutes);
// Khai báo các routes (trỏ đúng thư mục ./src/routes/)
app.use('/api/auth', require('./src/routes/authRoutes'));
app.use('/api/tasks', require('./src/routes/taskRoutes'));
app.use('/api/statistics', statisticsRoutes);
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('Đã kết nối MongoDB thành công');
    app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
  })
  .catch(err => console.error('Lỗi kết nối MongoDB:', err));