const User = require('../models/user');
const bcrypt = require('bcryptjs');

exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'Email này đã được đăng ký' });
    }
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const user = new User({ fullName, email, passwordHash });
    await user.save();

    res.status(201).json({ message: 'Đăng ký tài khoản thành công', userId: user._id });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};