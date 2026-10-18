const connectDatabase = require('../config/db');
const User = require('../models/User');
const Doctor = require('../models/Doctor');
const Hospital = require('../models/Hospital');
const Department = require('../models/Department');
const AuditLog = require('../models/AuditLog');

async function backfill() {
	const actor = await User.findOne({ role: 'admin' }).sort({ createdAt: 1 }).select('_id name');
	if (!actor) throw new Error('At least one administrator is required before importing audit history');

	const sources = [
		['users', User, 'user account'],
		['doctors', Doctor, 'doctor catalog record'],
		['hospitals', Hospital, 'hospital record'],
		['departments', Department, 'department record'],
	];
	let inserted = 0;

	for (const [module, Model, label] of sources) {
		const records = await Model.find().select('_id name email createdAt').lean();
		for (const record of records) {
			const exists = await AuditLog.exists({
				'metadata.legacyRecordId': String(record._id),
				'metadata.legacyImport': true,
			});
			if (exists) continue;
			await AuditLog.create({
				actor: actor._id,
				action: 'CREATE',
				module,
				description: `Existing ${label} imported into audit history`,
				method: 'IMPORT',
				path: `legacy/${module}/${record._id}`,
				statusCode: 200,
				success: true,
				metadata: {
					legacyImport: true,
					legacyRecordId: String(record._id),
					recordName: record.name || record.email || String(record._id),
					originalCreatedAt: record.createdAt || null,
				},
				createdAt: record.createdAt || new Date(),
				updatedAt: record.createdAt || new Date(),
			});
			inserted += 1;
		}
	}
	console.log(`Audit history backfill complete. Added ${inserted} existing records.`);
}

connectDatabase()
	.then(backfill)
	.then(() => process.exit(0))
	.catch((error) => {
		console.error('Audit history backfill failed:', error.message);
		process.exit(1);
	});
