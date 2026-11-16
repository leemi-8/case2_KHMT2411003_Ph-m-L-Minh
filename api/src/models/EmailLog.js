const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema({
  recipient: { type: String, required: true },
  subject: { type: String, required: true },
  eventType: { type: String, default: 'notification' }, // assign, share, update, completed, reminder
  status: { type: String, enum: ['success', 'failed'], required: true },
  errorMessage: { type: String, default: '' },
  sentAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('EmailLog', emailLogSchema);