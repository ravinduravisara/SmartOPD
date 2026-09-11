const { Server } = require('socket.io');

let io = null;

function initSocket(server) {
	io = new Server(server, {
		cors: {
			origin: '*',
			methods: ['GET', 'POST']
		}
	});

	io.on('connection', (socket) => {
		console.log(`Socket connected: ${socket.id}`);

		// Join doctor/hospital queue room
		socket.on('join_queue', ({ doctorId, patientId }) => {
			if (doctorId) {
				socket.join(`queue:doctor:${doctorId}`);
			}
			if (patientId) {
				socket.join(`queue:patient:${patientId}`);
			}
		});

		socket.on('leave_queue', ({ doctorId, patientId }) => {
			if (doctorId) {
				socket.leave(`queue:doctor:${doctorId}`);
			}
			if (patientId) {
				socket.leave(`queue:patient:${patientId}`);
			}
		});

		socket.on('disconnect', () => {
			console.log(`Socket disconnected: ${socket.id}`);
		});
	});

	return io;
}

function getIO() {
	return io;
}

function notifyDoctorQueueUpdate(doctorId, queueData) {
	if (io) {
		io.to(`queue:doctor:${doctorId}`).emit('queue:updated', queueData);
	}
}

function notifyPatientQueueUpdate(patientId, queueData) {
	if (io) {
		io.to(`queue:patient:${patientId}`).emit('queue:updated', queueData);
	}
}

module.exports = {
	initSocket,
	getIO,
	notifyDoctorQueueUpdate,
	notifyPatientQueueUpdate
};
