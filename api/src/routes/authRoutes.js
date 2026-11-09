const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs'); // Nếu cài bcrypt thì đổi thành require('bcrypt')
const User = require('../models/User'); // Import User model
const authController = require('../controllers/authController');

// Route Đăng ký (dùng controller có sẵn)
router.post('/register', authController.register);

// Route Đăng nhập (Feature B)
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // 1. Kiểm tra email có tồn tại không
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
    }

    // 2. So sánh mật khẩu nhập vào với mật khẩu mã hóa trong DB
   const isMatch = await bcrypt.compare(password, user.passwordHash || user.password);
   if (!isMatch) {
     return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
   }

    // 3. Đăng nhập thành công -> Trả về dữ liệu user
    res.status(200).json({
      message: 'Đăng nhập thành công!',
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email
      }
    });

  } catch (error) {
    res.status(500).json({ message: 'Lỗi máy chủ', error: error.message });
  }
});

// LUÔN ĐẶT DÒNG NÀY Ở CUỐI CÙNG CỦA FILE
module.exports = router;