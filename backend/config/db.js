const dns = require('dns');
try {
	dns.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);
} catch (_) {}
const mongoose = require('mongoose');

const dnsServers = (process.env.MONGO_DNS_SERVERS || '1.1.1.1,8.8.8.8')
	.split(',')
	.map((server) => server.trim())
	.filter(Boolean);
const resolver = new dns.promises.Resolver();
resolver.setServers(dnsServers);
dns.setServers(dnsServers);

function lookup(hostname, options, callback) {
	resolver.resolve4(hostname)
		.then((addresses) => callback(null, options?.all
			? addresses.map((address) => ({ address, family: 4 }))
			: addresses[0], 4))
		.catch(() => resolver.resolve6(hostname)
			.then((addresses) => callback(null, options?.all
				? addresses.map((address) => ({ address, family: 6 }))
				: addresses[0], 6))
			.catch(callback));
}

async function connectDatabase() {
	const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/smartopd';
	await mongoose.connect(uri, { lookup, serverSelectionTimeoutMS: 15000 });
	console.log('MongoDB connected');
}

module.exports = connectDatabase;
