const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const User = require('../models/User');
const authController = require('../controllers/authController');

// Tải bcryptjs hoặc bcrypt tùy theo máy bạn đã cài gói nào
let bcrypt;
try {
  bcrypt = require('bcryptjs');
} catch (e) {
  bcrypt = require('bcrypt');
}

// 1. Route Đăng ký
router.post('/register', authController.register);

// 2. Route Đăng nhập
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ email và mật khẩu' });
    }

    // Tìm người dùng theo email
    const user = await User.findOne({ email: email.trim() });
    if (!user) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
    }

    // Kiểm tra mật khẩu
    const storedPassword = user.passwordHash || user.password;
    if (!storedPassword) {
      return res.status(400).json({ message: 'Tài khoản chưa có mật khẩu hợp lệ' });
    }

    const isMatch = await bcrypt.compare(password, storedPassword);
    if (!isMatch) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
    }

    // Tạo token bằng module crypto có sẵn của Node.js
    const token = crypto.randomBytes(32).toString('hex');

    // Trả về đầy đủ thông tin user kèm _id và id
    return res.status(200).json({
      message: 'Đăng nhập thành công',
      token,
      user: {
        _id: user._id,
        id: user._id,
        fullName: user.fullName,
        email: user.email
      }
    });
  } catch (error) {
    console.error('>>> LỖI CHI TIẾT KHI ĐĂNG NHẬP:', error);
    return res.status(500).json({
      message: `Lỗi máy chủ: ${error.message}`
    });
  }
});

// 3. Route Lấy thông tin chi tiết User
router.get('/profile/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-passwordHash -password');
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    res.status(200).json(user);
  } catch (error) {
    res.status(500).json({ message: 'Lỗi lấy thông tin cá nhân', error: error.message });
  }
});

// 4. Route Cập nhật thông tin cá nhân (Họ tên)
router.put('/profile/:id', async (req, res) => {
  try {
    const { fullName } = req.body;
    if (!fullName || !fullName.trim()) {
      return res.status(400).json({ message: 'Họ tên không được để trống' });
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.params.id,
      { fullName: fullName.trim() },
      { new: true }
    ).select('-passwordHash -password');

    if (!updatedUser) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    res.status(200).json({
      message: 'Cập nhật hồ sơ thành công!',
      user: updatedUser
    });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi cập nhật hồ sơ', error: error.message });
  }
});

// 5. Route Đổi mật khẩu
router.put('/change-password/:id', async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ mật khẩu cũ và mới' });
    }

    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    const storedPassword = user.passwordHash || user.password;
    const isMatch = await bcrypt.compare(oldPassword, storedPassword);
    if (!isMatch) {
      return res.status(400).json({ message: 'Mật khẩu hiện tại không chính xác!' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedNewPassword = await bcrypt.hash(newPassword, salt);

    user.passwordHash = hashedNewPassword;
    if (user.password) user.password = hashedNewPassword;
    await user.save();

    res.status(200).json({ message: 'Đổi mật khẩu thành công!' });
  } catch (error) {
    res.status(500).json({ message: 'Lỗi đổi mật khẩu', error: error.message });
  }
});

module.exports = router;