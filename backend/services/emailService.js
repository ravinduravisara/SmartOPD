const path = require('path');
const fs = require('fs');
const nodemailer = require('nodemailer');

let transporter;

// Sent as an inline attachment rather than a link: Gmail blocks data: URIs,
// and a hosted URL would need a public server this project does not have.
const LOGO_PATH = path.join(__dirname, '..', 'assets', 'brand', 'logo.png');
const LOGO_CID = 'smartopd-logo';

function isConfigured() {
	return Boolean(process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
	if (transporter) return transporter;
	if (!process.env.SMTP_USER || !process.env.SMTP_PASS) throw new Error('SMTP_USER and SMTP_PASS must be configured');
	transporter = nodemailer.createTransport({ service: process.env.SMTP_SERVICE || 'gmail', auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } });
	return transporter;
}

function hasLogo() {
	try { return fs.existsSync(LOGO_PATH); } catch (error) { return false; }
}

// Table layout and inline styles: email clients strip stylesheets and most
// modern CSS, so anything fancier would arrive unstyled.
function template({ code, verification, withLogo }) {
	const heading = verification ? 'Verify your email' : 'Reset your password';
	const lead = verification
		? 'Use this code to finish setting up your SmartOPD account.'
		: 'Use this code to choose a new SmartOPD password.';
	const logo = withLogo
		? `<img src="cid:${LOGO_CID}" width="180" alt="SmartOPD" style="display:block;margin:0 auto 4px;max-width:180px;height:auto;border:0;">`
		: '<div style="font:700 22px Georgia,serif;color:#173A43;text-align:center;">SmartOPD</div>';
	return `<!doctype html>
<html>
<body style="margin:0;padding:24px 12px;background:#F2F9F8;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:480px;margin:0 auto;background:#FFFFFF;border-radius:18px;border:1px solid #E1EDEC;">
<tr><td style="padding:28px 28px 8px;">${logo}</td></tr>
<tr><td style="padding:0 28px;">
<h1 style="margin:16px 0 8px;font:700 22px Georgia,serif;color:#173A43;text-align:center;">${heading}</h1>
<p style="margin:0 0 20px;font:400 15px/1.5 Arial,sans-serif;color:#5B7076;text-align:center;">${lead}</p>
<div style="margin:0 auto 18px;padding:16px;background:#F2F9F8;border:1px solid #CDE7E3;border-radius:14px;text-align:center;">
<div style="font:700 32px/1.2 Arial,sans-serif;letter-spacing:6px;color:#007F73;">${code}</div>
</div>
<p style="margin:0 0 6px;font:400 14px/1.5 Arial,sans-serif;color:#5B7076;text-align:center;">This code expires in 10 minutes.</p>
<p style="margin:0 0 26px;font:400 13px/1.5 Arial,sans-serif;color:#8A9CA1;text-align:center;">If you did not request it, you can ignore this email.</p>
</td></tr>
<tr><td style="padding:0 28px 26px;border-top:1px solid #EEF4F3;">
<p style="margin:16px 0 0;font:400 12px/1.5 Arial,sans-serif;color:#8A9CA1;text-align:center;">SmartOPD &middot; Appointments, live queues and hospital services</p>
</td></tr>
</table>
</body>
</html>`;
}

async function sendOtpEmail({ to, code, purpose }) {
	const verification = purpose === 'verification';
	const withLogo = hasLogo();
	await getTransporter().sendMail({
		from: process.env.SMTP_FROM || `SmartOPD <${process.env.SMTP_USER}>`,
		to,
		subject: verification ? 'Verify your SmartOPD email' : 'Reset your SmartOPD password',
		text: `Your SmartOPD code is ${code}. It expires in 10 minutes.`,
		html: template({ code, verification, withLogo }),
		// cid makes it render in the body; without a contentDisposition of
		// inline some clients also list it as a downloadable attachment.
		attachments: withLogo
			? [{ filename: 'smartopd.png', path: LOGO_PATH, cid: LOGO_CID, contentDisposition: 'inline' }]
			: []
	});
}

module.exports = { sendOtpEmail };
module.exports.isConfigured = isConfigured;
