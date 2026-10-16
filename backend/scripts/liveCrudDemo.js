require('dotenv').config();
const connectDatabase = require('../config/db');
const Queue = require('../models/Queue');
const Notification = require('../models/Notification');
const Appointment = require('../models/Appointment');
const User = require('../models/User');
const Hospital = require('../models/Hospital');
const Doctor = require('../models/Doctor');

async function liveDemo() {
	await connectDatabase();
	console.log('\n======================================================');
	console.log('🚀 LIVE CRUD DEMO: SMART OPD (Queue & Notification)');
	console.log('======================================================\n');

	// 1. Fetch real patient and appointment from DB
	const user = (await User.findOne({ role: 'patient' })) || (await User.findOne());
	const appointment = await Appointment.findOne({ status: 'booked' });

	if (!user || !appointment) {
		console.log('❌ Patient or Appointment not found in DB');
		process.exit(1);
	}

	console.log(`👤 Active Patient: ${user.name} (${user.email})`);
	console.log(`📅 Linked Appointment ID: ${appointment._id}`);
	console.log('------------------------------------------------------\n');

	// ====================================================
	// 🔴 PART 1: LIVE QUEUE MANAGEMENT CRUD
	// ====================================================

	// [C] CREATE
	console.log('🔹 [QUEUE - 1. CREATE]');
	console.log('👉 Patient clicks "Check In & Get Live Token"...');
	const startOfDay = new Date();
	startOfDay.setHours(0, 0, 0, 0);
	const count = await Queue.countDocuments({ createdAt: { $gte: startOfDay } });
	const tokenNumber = 'A-' + (count + 1).toString().padStart(3, '0');

	const newQueue = await Queue.create({
		appointmentId: appointment._id,
		patientId: user._id,
		hospitalId: appointment.hospital,
		departmentId: appointment.department,
		doctorId: appointment.doctor,
		tokenNumber,
		queuePosition: count + 1,
		status: 'CHECKED_IN',
		checkInTime: new Date()
	});
	console.log(`   ✅ Token Generated: ${newQueue.tokenNumber}`);
	console.log(`   ✅ Status: ${newQueue.status} | Queue ID: ${newQueue._id}\n`);

	// [R] READ
	console.log('🔹 [QUEUE - 2. READ]');
	console.log('👉 Patient opens Live Queue Tracker screen...');
	const fetchedQueue = await Queue.findById(newQueue._id)
		.populate('hospitalId', 'name')
		.populate('doctorId', 'name specialization');
	console.log(`   ✅ Hospital: ${fetchedQueue.hospitalId?.name}`);
	console.log(`   ✅ Doctor: ${fetchedQueue.doctorId?.name} (${fetchedQueue.doctorId?.specialization})`);
	console.log(`   ✅ Digital Token: ${fetchedQueue.tokenNumber} (Position: #${fetchedQueue.queuePosition})\n`);

	// [U] UPDATE
	console.log('🔹 [QUEUE - 3. UPDATE]');
	console.log('👉 Doctor calls the token into consultation...');
	fetchedQueue.status = 'CALLED';
	fetchedQueue.calledAt = new Date();
	await fetchedQueue.save();
	console.log(`   ✅ Queue Status Updated: ${fetchedQueue.status}`);
	console.log(`   ✅ Called Time: ${fetchedQueue.calledAt.toLocaleTimeString()}\n`);

	// ====================================================
	// 🔔 PART 2: NOTIFICATION MANAGEMENT CRUD
	// ====================================================

	// [C] CREATE
	console.log('🔹 [NOTIFICATION - 1. CREATE]');
	console.log('👉 System auto-creates "YOUR_TURN" Notification...');
	const newNotif = await Notification.create({
		userId: user._id,
		queueId: fetchedQueue._id,
		title: 'YOUR TURN! 🚨',
		message: `Token ${fetchedQueue.tokenNumber} is called! Please proceed to the consultation room.`,
		type: 'YOUR_TURN',
		readStatus: false
	});
	console.log(`   ✅ Notification ID: ${newNotif._id}`);
	console.log(`   ✅ Title: "${newNotif.title}"`);
	console.log(`   ✅ Message: "${newNotif.message}"\n`);

	// [R] READ
	console.log('🔹 [NOTIFICATION - 2. READ]');
	console.log('👉 Patient views Notification bell screen...');
	const unread = await Notification.countDocuments({ userId: user._id, readStatus: false });
	const latestNotifs = await Notification.find({ userId: user._id }).sort({ createdAt: -1 }).limit(3);
	console.log(`   ✅ Unread Notifications Count: ${unread}`);
	console.log(`   ✅ Latest Notification: [${latestNotifs[0]?.title}] - readStatus: ${latestNotifs[0]?.readStatus}\n`);

	// [U] UPDATE
	console.log('🔹 [NOTIFICATION - 3. UPDATE]');
	console.log('👉 Patient taps notification to mark as READ...');
	newNotif.readStatus = true;
	await newNotif.save();
	console.log(`   ✅ Notification Updated! readStatus: ${newNotif.readStatus} (Read)\n`);

	// [D] DELETE
	console.log('🔹 [NOTIFICATION - 4. DELETE]');
	console.log('👉 Patient clears/deletes this notification...');
	await Notification.findByIdAndDelete(newNotif._id);
	const checkDeleted = await Notification.findById(newNotif._id);
	console.log(`   ✅ Notification Deleted from DB! Exists?: ${checkDeleted ? 'Yes' : 'No (Deleted Successfully)'}\n`);

	// ====================================================
	// 🔴 PART 1 (D): QUEUE CANCEL/DELETE
	// ====================================================

	// [D] DELETE
	console.log('🔹 [QUEUE - 4. DELETE]');
	console.log('👉 Patient cancels queue entry (DELETE operation)...');
	fetchedQueue.status = 'CANCELLED';
	fetchedQueue.completedAt = new Date();
	await fetchedQueue.save();
	console.log(`   ✅ Queue Entry Cancelled/Removed: Status is now "${fetchedQueue.status}"\n`);

	// Clean up demo queue row from DB
	await Queue.findByIdAndDelete(fetchedQueue._id);
	console.log('   🧹 Test data cleaned up.');

	console.log('======================================================');
	console.log('🎉 LIVE VERIFICATION SUCCESSFUL!');
	console.log('   1. Queue CRUD: [Create ✅] [Read ✅] [Update ✅] [Delete ✅]');
	console.log('   2. Notification CRUD: [Create ✅] [Read ✅] [Update ✅] [Delete ✅]');
	console.log('======================================================\n');
	process.exit(0);
}

liveDemo().catch((err) => {
	console.error('Demo Error:', err);
	process.exit(1);
});
