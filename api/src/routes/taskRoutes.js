const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const { sendEmailNotification, sendTaskEmail } = require('../../services/emailService');

// Bộ lập lịch nhắc việc tự động trước hạn 24 giờ (chạy mỗi 30 phút)
const remindedTaskIds = new Set();
setInterval(async () => {
  try {
    const now = new Date();
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const upcomingTasks = await Task.find({
      status: { $ne: 'completed' },
      dueDate: { $gte: now, $lte: in24Hours }
    }).populate('createdBy', 'fullName email');

    for (const task of upcomingTasks) {
      const key = `${task._id.toString()}_${new Date(task.dueDate).toISOString()}`;
      if (remindedTaskIds.has(key)) continue;
      remindedTaskIds.add(key);

      // Tạo thông báo trong ứng dụng và gửi email nhắc hạn
      if (task.createdBy && task.createdBy._id) {
        await Notification.create({
          userId: task.createdBy._id,
          taskId: task._id,
          title: 'Nhắc việc sắp đến hạn (trong 24h)',
          message: `Công việc "${task.title}" sắp đến hạn hoàn thành!`,
        });

        if (task.createdBy.email) {
          sendTaskEmail({
            toEmail: task.createdBy.email,
            subject: `[Nhắc hạn] Công việc "${task.title}" sắp đến hạn!`,
            htmlContent: `<p>Công việc <b>"${task.title}"</b> sẽ đến hạn trong vòng 24 giờ tới. Hãy hoàn thành đúng tiến độ!</p>`,
            eventType: 'reminder'
          });
        }
      }
    }
  } catch (err) {
    console.error('Lỗi cron nhắc việc trước hạn:', err.message);
  }
}, 30 * 60 * 1000);

// 1. GET /api/tasks - Lấy danh sách công việc độc lập theo userId
router.get('/', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(200).json([]);
    }

    const objectUserId = new mongoose.Types.ObjectId(userId);
    let shareMap = {};

    const sharedRecords = await TaskShare.find({ userId: objectUserId });
    const sharedTaskIds = sharedRecords.map((record) => {
      shareMap[record.taskId.toString()] = record.permission;
      return record.taskId;
    });

    const query = {
      $or: [
        { createdBy: objectUserId },
        { _id: { $in: sharedTaskIds } }
      ]
    };

    const tasks = await Task.find(query)
      .populate('createdBy', 'fullName email')
      .sort({ createdAt: -1 });

    const tasksWithPermission = tasks.map((task) => {
      const taskObj = task.toObject();
      const creatorId = task.createdBy?._id ? task.createdBy._id.toString() : task.createdBy?.toString();

      if (creatorId === userId) {
        taskObj.userPermission = 'owner';
      } else {
        taskObj.userPermission = shareMap[task._id.toString()] || 'viewer';
      }
      return taskObj;
    });

    res.status(200).json(tasksWithPermission);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi lấy danh sách công việc', error: error.message });
  }
});

// 2. GET /api/tasks/email-logs - Xem lịch sử gửi email
router.get('/email-logs', async (req, res) => {
  try {
    const logs = await EmailLog.find().sort({ sentAt: -1 }).limit(50);
    res.status(200).json(logs);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi lấy lịch sử email', error: error.message });
  }
});

// 3. GET /api/tasks/users/search - Tìm kiếm người dùng
router.get('/users/search', async (req, res) => {
  try {
    const query = req.query.q || '';
    const users = await User.find({
      $or: [
        { fullName: { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } }
      ]
    }).select('_id fullName email');
    res.status(200).json(users);
  } catch (err) {
    res.status(500).json({ message: 'Lỗi máy chủ', error: err.message });
  }
});

// 4. GET /api/tasks/:id - Lấy chi tiết 1 công việc (để mở từ thông báo)
router.get('/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ' });
    }
    const task = await Task.findById(req.params.id).populate('createdBy', 'fullName email');
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });
    res.status(200).json(task);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi lấy chi tiết công việc', error: error.message });
  }
});

// 5. POST /api/tasks - Tạo công việc mới (+ gửi email nếu giao việc cho người khác)
router.post('/', async (req, res) => {
  try {
    const { title, description, priority, startDate, dueDate, userId, createdBy, assigneeId } = req.body;
    const ownerId = createdBy || userId;

    if (!ownerId || !mongoose.Types.ObjectId.isValid(ownerId)) {
      return res.status(400).json({ message: 'Thiếu hoặc sai định dạng userId người tạo' });
    }

    const newTask = new Task({
      title,
      description,
      priority: priority || 'medium',
      status: 'todo',
      startDate: startDate || new Date(),
      dueDate: dueDate || null,
      createdBy: new mongoose.Types.ObjectId(ownerId)
    });

    await newTask.save();

    // Sự kiện 1: Nếu có giao việc cho người phụ trách (assigneeId)
    if (assigneeId && mongoose.Types.ObjectId.isValid(assigneeId)) {
      const objAssigneeId = new mongoose.Types.ObjectId(assigneeId);
      await TaskShare.findOneAndUpdate(
        { taskId: newTask._id, userId: objAssigneeId },
        { taskId: newTask._id, userId: objAssigneeId, permission: 'editor' },
        { upsert: true }
      );
      await Notification.create({
        userId: objAssigneeId,
        taskId: newTask._id,
        title: 'Bạn được giao công việc mới',
        message: `Bạn vừa được giao phụ trách công việc "${newTask.title}"`,
      });
      const assignee = await User.findById(objAssigneeId);
      if (assignee && assignee.email) {
        sendEmailNotification(assignee.email, newTask.title, 'Người giao việc', 'assign');
      }
    }

    res.status(201).json(newTask);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi tạo công việc', error: error.message });
  }
});

// 6. PUT /api/tasks/:id - Cập nhật công việc (+ gửi email khi đổi hạn/thông tin hoặc hoàn thành)
router.put('/:id', async (req, res) => {
  try {
    const oldTask = await Task.findById(req.params.id).populate('createdBy', 'fullName email');
    if (!oldTask) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    const { title, description, status, priority, startDate, dueDate } = req.body;
    const updateData = {};

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (status !== undefined) updateData.status = status;
    if (priority !== undefined) updateData.priority = priority;
    if (startDate !== undefined) updateData.startDate = startDate;
    if (dueDate !== undefined) updateData.dueDate = dueDate;

    const updatedTask = await Task.findByIdAndUpdate(req.params.id, updateData, { new: true });

    // Tìm danh sách người liên quan (chủ sở hữu + người được chia sẻ) để thông báo
    const shares = await TaskShare.find({ taskId: updatedTask._id }).populate('userId', 'email fullName');
    const recipients = new Map();
    if (oldTask.createdBy && oldTask.createdBy.email) {
      recipients.set(oldTask.createdBy._id.toString(), oldTask.createdBy);
    }
    for (const s of shares) {
      if (s.userId && s.userId.email) {
        recipients.set(s.userId._id.toString(), s.userId);
      }
    }

    // Sự kiện 4: Công việc được đánh dấu hoàn thành
    if (status === 'completed' && oldTask.status !== 'completed') {
      for (const [uid, u] of recipients.entries()) {
        await Notification.create({
          userId: uid,
          taskId: updatedTask._id,
          title: 'Công việc đã hoàn thành',
          message: `Công việc "${updatedTask.title}" đã được đánh dấu hoàn thành.`,
        });
        sendTaskEmail({
          toEmail: u.email,
          subject: `[Hoàn thành] Công việc "${updatedTask.title}" đã xong!`,
          htmlContent: `<p>Công việc <b>"${updatedTask.title}"</b> đã được cập nhật trạng thái <b>Đã hoàn thành</b>.</p>`,
          eventType: 'completed'
        });
      }
    }
    // Sự kiện 3: Thay đổi hạn hoàn thành hoặc thông tin quan trọng
    else if (
      (dueDate !== undefined && String(dueDate) !== String(oldTask.dueDate)) ||
      (title !== undefined && title !== oldTask.title) ||
      (priority !== undefined && priority !== oldTask.priority)
    ) {
      for (const [uid, u] of recipients.entries()) {
        await Notification.create({
          userId: uid,
          taskId: updatedTask._id,
          title: 'Cập nhật thông tin công việc',
          message: `Công việc "${updatedTask.title}" vừa thay đổi hạn hoàn thành hoặc thông tin quan trọng.`,
        });
        sendTaskEmail({
          toEmail: u.email,
          subject: `[Cập nhật] Công việc "${updatedTask.title}" có thay đổi`,
          htmlContent: `<p>Thông tin quan trọng hoặc hạn hoàn thành của công việc <b>"${updatedTask.title}"</b> vừa được cập nhật.</p>`,
          eventType: 'update'
        });
      }
    }

    res.status(200).json({ message: 'Cập nhật thành công!', task: updatedTask });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi cập nhật công việc', error: error.message });
  }
});

// 7. DELETE /api/tasks/:id - Xóa công việc
router.delete('/:id', async (req, res) => {
  try {
    await Task.findByIdAndDelete(req.params.id);
    await TaskShare.deleteMany({ taskId: req.params.id });
    res.status(200).json({ message: 'Đã xóa công việc thành công!' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi xóa công việc', error: error.message });
  }
});

// 8. POST /api/tasks/:id/shares - Sự kiện 2: Mời xem hoặc tham gia công việc
router.post('/:id/shares', async (req, res) => {
  try {
    const taskId = req.params.id;
    const { userId, permission } = req.body;

    if (!mongoose.Types.ObjectId.isValid(taskId) || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ message: 'ID công việc hoặc người dùng không hợp lệ' });
    }

    const objectTaskId = new mongoose.Types.ObjectId(taskId);
    const objectUserId = new mongoose.Types.ObjectId(userId);

    await TaskShare.findOneAndUpdate(
      { taskId: objectTaskId, userId: objectUserId },
      { taskId: objectTaskId, userId: objectUserId, permission: permission || 'viewer' },
      { upsert: true, new: true }
    );

    const task = await Task.findById(objectTaskId);
    await Notification.create({
      userId: objectUserId,
      taskId: objectTaskId,
      title: 'Công việc mới được chia sẻ',
      message: `Bạn đã được cấp quyền ${permission || 'viewer'} cho công việc "${task ? task.title : 'Công việc'}"`,
    });

    const recipientUser = await User.findById(objectUserId);
    if (recipientUser && recipientUser.email && task) {
      sendEmailNotification(recipientUser.email, task.title, 'Hệ thống TaskManager', 'share');
    }

    res.status(201).json({ message: 'Chia sẻ công việc thành công!' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi chia sẻ công việc', error: error.message });
  }
});

module.exports = router;