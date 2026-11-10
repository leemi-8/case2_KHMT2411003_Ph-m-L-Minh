const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');

// 1. Lấy danh sách thông báo theo userId
router.get('/:userId', async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi server', error });
  }
});

// 2. Đánh dấu thông báo đã đọc
router.put('/:id/read', async (req, res) => {
  try {
    await Notification.findByIdAndUpdate(req.params.id, { isRead: true });
    res.status(200).json({ message: 'Đã cập nhật trạng thái' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi server', error });
  }
});

module.exports = router;