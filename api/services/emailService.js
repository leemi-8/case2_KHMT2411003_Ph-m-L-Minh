const nodemailer = require('nodemailer');
const EmailLog = require('../src/models/EmailLog');

// Cấu hình dịch vụ gửi Email (Ưu tiên biến môi trường .env nếu có)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'kirapo123456654321@gmail.com',
    pass: process.env.EMAIL_PASS || 'zcgh sykg xxau ozqc'

  }
});

// Hàm gửi email tổng quát và tự động lưu lịch sử vào collection EmailLog
const sendTaskEmail = async ({ toEmail, subject, htmlContent, eventType = 'notification' }) => {
  if (!toEmail) return;
  try {
    const mailOptions = {
      from: `"Task Manager App" <${process.env.EMAIL_USER || 'your_email@gmail.com'}>`,
      to: toEmail,
      subject,
      html: htmlContent
    };

    await transporter.sendMail(mailOptions);
    console.log(`[Email SUCCESS] Đã gửi (${eventType}) tới:`, toEmail);

    await EmailLog.create({
      recipient: toEmail,
      subject,
      eventType,
      status: 'success',
      sentAt: new Date()
    });
  } catch (error) {
    console.error(`[Email FAILED] Lỗi gửi (${eventType}) tới ${toEmail}:`, error.message);

    await EmailLog.create({
      recipient: toEmail,
      subject,
      eventType,
      status: 'failed',
      errorMessage: error.message,
      sentAt: new Date()
    });
  }
};

// Giữ tương thích với hàm cũ khi chia sẻ/giao việc
const sendEmailNotification = async (toEmail, taskTitle, senderName, eventType = 'share') => {
  const subject = eventType === 'assign'
    ? `Bạn được giao công việc mới: "${taskTitle}"`
    : `Bạn được mời tham gia công việc: "${taskTitle}"`;

  const htmlContent = `
    <div style="font-family: Arial, sans-serif; padding: 20px;">
      <h2>${subject}</h2>
      <p>Xin chào,</p>
      <p><b>${senderName}</b> vừa thực hiện thao tác trên công việc <b>"${taskTitle}"</b>.</p>
      <p>Vui lòng mở ứng dụng Task Manager để kiểm tra chi tiết.</p>
    </div>
  `;
  await sendTaskEmail({ toEmail, subject, htmlContent, eventType });
};

module.exports = { sendEmailNotification, sendTaskEmail };