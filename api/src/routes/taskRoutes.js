const express = require('express');
const router = express.Router();
const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const Notification = require('../models/Notification');
const { sendEmailNotification } = require('../../services/emailService');
// 1. GET /api/tasks - Lấy danh sách công việc
router.get('/', async (req, res) => {
  try {
    const tasks = await Task.find()
      .populate('createdBy', 'fullName email')
      .sort({ createdAt: -1 });
    res.status(200).json(tasks);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi lấy danh sách công việc', error: error.message });
  }
});

// 2. POST /api/tasks - Tạo công việc mới
router.post('/', async (req, res) => {
  try {
    const { title, description, priority, status, createdBy } = req.body;

    if (!title || !createdBy) {
      return res.status(400).json({ message: 'Tiêu đề và ID người tạo không được để trống' });
    }

    const newTask = new Task({
      title,
      description,
      priority: priority || 'medium',
      status: status || 'todo',
      createdBy
    });

    await newTask.save();
    res.status(201).json({ message: 'Tạo công việc thành công!', task: newTask });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi tạo công việc', error: error.message });
  }
});

// 3. PUT /api/tasks/:id - Cập nhật công việc
router.put('/:id', async (req, res) => {
  try {
    const updatedTask = await Task.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.status(200).json({ message: 'Cập nhật thành công!', task: updatedTask });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi cập nhật công việc', error: error.message });
  }
});

// 4. DELETE /api/tasks/:id - Xóa công việc
router.delete('/:id', async (req, res) => {
  try {
    await Task.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: 'Đã xóa công việc thành công!' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi xóa công việc', error: error.message });
  }
});
router.get('/users/search', async (req, res) => {
  try {
    const query = req.query.q || '';
    const users = await User.find({
      $or: [
        { fullName: { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } }
      ]
    }).select('_id fullName email');
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ' });
  }
});
router.post('/:id/shares', async (req, res) => {
  try {
    const taskId = req.params.id;
    const { userId, permission } = req.body; // userId được chia sẻ

    // ... (Code lưu TaskShare cũ của bạn ở đây) ...

    // 1. Tạo thông báo trong Database cho người được chia sẻ
    const task = await Task.findById(taskId);
    await Notification.create({
      userId: userId,
      title: 'Công việc mới được chia sẻ',
      message: `Bạn đã được cấp quyền ${permission} cho công việc "${task ? task.title : 'Công việc'}"`,
    });

    // 2. Gửi Email thông báo
    const recipientUser = await User.findById(userId);
    if (recipientUser && recipientUser.email) {
      sendEmailNotification(recipientUser.email, task.title, 'Hệ thống TaskManager');
    }

    res.status(201).json({ message: 'Chia sẻ công việc thành công!' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi chia sẻ công việc', error });
  }
});
module.exports = router;