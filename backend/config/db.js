const mongoose = require('mongoose');

async function connectDatabase() {
	const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/smartopd';
	await mongoose.connect(uri);
	console.log('MongoDB connected');
}

module.exports = connectDatabase;
