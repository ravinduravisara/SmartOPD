const nodemailer = require('nodemailer');

let transporter;

function isConfigured() {
	return Boolean(process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
	if (transporter) return transporter;
	if (!process.env.SMTP_USER || !process.env.SMTP_PASS) throw new Error('SMTP_USER and SMTP_PASS must be configured');
	transporter = nodemailer.createTransport({ service: process.env.SMTP_SERVICE || 'gmail', auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } });
	return transporter;
}

async function sendOtpEmail({ to, code, purpose }) {
	const verification = purpose === 'verification';
	await getTransporter().sendMail({
		from: process.env.SMTP_FROM || `SmartOPD <${process.env.SMTP_USER}>`,
		to,
		subject: verification ? 'Verify your SmartOPD email' : 'Reset your SmartOPD password',
		text: `Your SmartOPD code is ${code}. It expires in 10 minutes.`,
		html: `<p>Your SmartOPD code is:</p><h2>${code}</h2><p>This code expires in 10 minutes.</p>`
	});
}

module.exports = { sendOtpEmail };
module.exports.isConfigured = isConfigured;