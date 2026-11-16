const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');

// 1. Lấy danh sách thông báo theo userId
router.get('/:userId', async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.params.userId })
      .sort({ createdAt: -1 });
    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi server', error: error.message });
  }
});

// 2. Đánh dấu 1 thông báo đã đọc
router.put('/:id/read', async (req, res) => {
  try {
    const updated = await Notification.findByIdAndUpdate(
      req.params.id,
      { isRead: true },
      { new: true }
    );
    res.status(200).json({ message: 'Đã đánh dấu đã đọc', notification: updated });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi server', error: error.message });
  }
});

// 3. Đánh dấu tất cả thông báo của user đã đọc
router.put('/user/:userId/read-all', async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.params.userId, isRead: false },
      { isRead: true }
    );
    res.status(200).json({ message: 'Đã đánh dấu đọc tất cả thông báo' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi server', error: error.message });
  }
});

module.exports = router;