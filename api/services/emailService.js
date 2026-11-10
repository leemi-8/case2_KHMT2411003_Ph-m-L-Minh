const nodemailer = require('nodemailer');

// Cấu hình dịch vụ gửi Email (Sử dụng SMTP Gmail)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'your_email@gmail.com', // Thay bằng Email gửi của bạn
    pass: 'your_app_password'     // Mật khẩu ứng dụng Gmail (App Password)
  }
});

const sendEmailNotification = async (toEmail, taskTitle, senderName) => {
  try {
    const mailOptions = {
      from: '"Task Manager App" <your_email@gmail.com>',
      to: toEmail,
      subject: 'Bạn vừa được chia sẻ một công việc mới!',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>Thông báo công việc mới</h2>
          <p>Xin chào,</p>
          <p>Người dùng <b>${senderName}</b> vừa chia sẻ công việc <b>"${taskTitle}"</b> với bạn.</p>
          <p>Vui lòng mở ứng dụng Task Manager để xem chi tiết.</p>
        </div>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log('Đã gửi email thông báo thành công đến:', toEmail);
  } catch (error) {
    console.error('Lỗi khi gửi email:', error);
  }
};

module.exports = { sendEmailNotification };