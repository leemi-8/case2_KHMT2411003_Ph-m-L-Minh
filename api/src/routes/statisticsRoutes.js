const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Task = require('../models/Task');

// GET /api/statistics/summary/:userId - Thống kê công việc
router.get('/summary/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    let userQuery = {};
    if (mongoose.Types.ObjectId.isValid(userId)) {
      const userObjId = new mongoose.Types.ObjectId(userId);
      userQuery = {
        $or: [
          { createdBy: userObjId },
          { assigneeIds: userObjId },
          { primaryAssigneeId: userObjId }
        ]
      };
    }

    let tasks = await Task.find(userQuery);
    if (tasks.length === 0) {
      tasks = await Task.find({});
    }

    const total = tasks.length;
    const todo = tasks.filter(t => t.status === 'todo').length;
    const inProgress = tasks.filter(t => t.status === 'in_progress').length;
    const completed = tasks.filter(t => t.status === 'completed' || t.status === true).length;

    const now = new Date();
    const overdue = tasks.filter(t => t.dueDate && new Date(t.dueDate) < now && t.status !== 'completed').length;

    res.status(200).json({
      total,
      todo,
      inProgress,
      completed,
      overdue
    });
  } catch (error) {
    console.error('Lỗi thống kê:', error);
    res.status(500).json({ message: 'Lỗi server khi lấy thống kê', error: error.message });
  }
});

module.exports = router;