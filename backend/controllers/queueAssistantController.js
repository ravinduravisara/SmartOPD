const Queue = require('../models/Queue');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Build real-time queue context for the AI
async function getQueueContext(patientId) {
	if (!patientId) return null;

	const activeQueue = await Queue.findOne({
		patientId,
		status: { $in: ['CHECKED_IN', 'WAITING', 'CALLED', 'IN_CONSULTATION'] }
	})
	.populate('hospitalId', 'name')
	.populate('departmentId', 'name')
	.populate('doctorId', 'name');

	if (!activeQueue) return null;

	// Calculate real-time metrics
	const startOfDay = new Date(activeQueue.createdAt);
	startOfDay.setHours(0, 0, 0, 0);
	const endOfDay = new Date(activeQueue.createdAt);
	endOfDay.setHours(23, 59, 59, 999);

	const docId = activeQueue.doctorId?._id || activeQueue.doctorId;

	const patientsAhead = await Queue.countDocuments({
		doctorId: docId,
		status: { $in: ['CHECKED_IN', 'WAITING'] },
		queuePosition: { $lt: activeQueue.queuePosition },
		createdAt: { $gte: startOfDay, $lte: endOfDay }
	});

	const currentlyServing = await Queue.findOne({
		doctorId: docId,
		status: { $in: ['CALLED', 'IN_CONSULTATION'] },
		createdAt: { $gte: startOfDay, $lte: endOfDay }
	}).sort({ updatedAt: -1 });

	const completedToday = await Queue.find({
		doctorId: docId,
		status: 'COMPLETED',
		createdAt: { $gte: startOfDay, $lte: endOfDay },
		startedAt: { $ne: null },
		completedAt: { $ne: null }
	});

	let avgMins = 6;
	if (completedToday.length > 0) {
		const totalDuration = completedToday.reduce((sum, item) => {
			const mins = (item.completedAt - item.startedAt) / 60000;
			return sum + (mins > 0 ? mins : 6);
		}, 0);
		avgMins = Math.max(3, Math.round(totalDuration / completedToday.length));
	}

	const totalWaiting = await Queue.countDocuments({
		doctorId: docId,
		status: { $in: ['CHECKED_IN', 'WAITING'] },
		createdAt: { $gte: startOfDay, $lte: endOfDay }
	});

	const estWaitMins = Math.max(0, patientsAhead * avgMins);

	let isDelayed = false;
	if (currentlyServing && currentlyServing.calledAt) {
		const minsInCall = (Date.now() - new Date(currentlyServing.calledAt).getTime()) / 60000;
		if (minsInCall > avgMins * 2.5) isDelayed = true;
	}

	return {
		tokenNumber: activeQueue.tokenNumber,
		queuePosition: activeQueue.queuePosition,
		status: activeQueue.status,
		doctorName: activeQueue.doctorId?.name || 'Doctor',
		hospitalName: activeQueue.hospitalId?.name || 'Hospital',
		departmentName: activeQueue.departmentId?.name || 'OPD',
		patientsAhead,
		currentToken: currentlyServing ? currentlyServing.tokenNumber : 'None',
		estimatedWaitMinutes: estWaitMins,
		avgConsultationMinutes: avgMins,
		totalWaiting,
		totalCompletedToday: completedToday.length,
		isDelayed,
		checkInTime: activeQueue.checkInTime
	};
}

// System prompt for Gemini
function buildSystemPrompt(queueContext) {
	const basePrompt = `You are "SmartOPD Assistant" — a friendly, casual, and helpful AI chatbot for a hospital OPD (Out-Patient Department) queue management app called SmartOPD.

PERSONALITY & STYLE:
- Be warm, friendly, natural and casual — like ChatGPT, NOT robotic
- Keep responses short, direct, and conversational (2-3 sentences max)
- Use 1-2 friendly emojis when appropriate

CRITICAL LANGUAGE RULE:
- If the user asks in Tanglish (Tamil in English letters like "vanakkam", "eppo varum", "late aaguma", "eppadi irukka"), respond IN TANGLISH
- If the user asks in Tamil script (தமிழ்), respond in Tamil script
- If the user asks in English, respond in English
- ALWAYS mirror the language the user speaks.

SCOPE:
- Your core knowledge is OPD queues: tokens, wait time, doctor, current queue progress
- For greetings, casual questions, and small talk, answer naturally and casually like ChatGPT
- For medical advice (medicines, symptoms, diagnosis), politely clarify that you are a queue assistant and encourage asking their doctor during the OPD consultation
- NEVER invent false queue numbers; use the exact real-time live data provided below:`;

	if (queueContext) {
		return `${basePrompt}

CURRENT PATIENT'S LIVE QUEUE DATA:
- Patient Token: ${queueContext.tokenNumber}
- Queue Position: ${queueContext.queuePosition}
- Status: ${queueContext.status}
- Doctor: ${queueContext.doctorName} (${queueContext.departmentName})
- Hospital: ${queueContext.hospitalName}
- Patients Ahead: ${queueContext.patientsAhead}
- Currently Serving Token: ${queueContext.currentToken}
- Estimated Wait Time: ~${queueContext.estimatedWaitMinutes} minutes
- Avg Consultation Time: ~${queueContext.avgConsultationMinutes} min/patient
- Total Waiting: ${queueContext.totalWaiting}
- Delayed: ${queueContext.isDelayed ? 'Yes' : 'No'}`;
	}

	return `${basePrompt}

QUEUE STATUS: The user does not have an active checked-in queue token right now. If they ask about their queue, casually let them know they can check in on the "My Visits" page.`;
}

exports.askQueueAssistant = async (req, res) => {
	try {
		const { query } = req.body;
		const patientId = (req.userRecord && req.userRecord._id) || (req.user && (req.user._id || req.user.id));

		if (!query || typeof query !== 'string') {
			return res.status(400).json({ message: 'Query string is required' });
		}

		// Get real-time queue context
		const queueContext = await getQueueContext(patientId);

		// Build system prompt with live data
		const systemPrompt = buildSystemPrompt(queueContext);

		let reply = '';
		const modelsToTry = ['gemini-3.6-flash', 'gemini-2.5-flash', 'gemini-1.5-flash'];

		for (const modelName of modelsToTry) {
			try {
				const model = genAI.getGenerativeModel({
					model: modelName,
					systemInstruction: { parts: [{ text: systemPrompt }] }
				});

				const result = await model.generateContent({
					contents: [{ role: 'user', parts: [{ text: query }] }],
					generationConfig: {
						maxOutputTokens: 250,
						temperature: 0.8,
					}
				});

				if (result && result.response) {
					reply = result.response.text().trim();
					if (reply) break;
				}
			} catch (mErr) {
				console.warn(`Model ${modelName} attempt failed:`, mErr.message);
			}
		}

		if (!reply) {
			// Fallback if AI service is temporarily unavailable
			if (queueContext) {
				reply = `You have Token ${queueContext.tokenNumber}. There are ${queueContext.patientsAhead} patients ahead of you, and estimated wait time is ~${queueContext.estimatedWaitMinutes} minutes. Currently serving Token ${queueContext.currentToken}.`;
			} else {
				reply = 'Hello! I am your SmartOPD Assistant. How can I help you with your hospital visit today? 😊';
			}
		}

		// Build response
		const response = { success: true, reply };

		if (queueContext) {
			response.context = {
				tokenNumber: queueContext.tokenNumber,
				currentToken: queueContext.currentToken,
				patientsAhead: queueContext.patientsAhead,
				estimatedWaitMinutes: queueContext.estimatedWaitMinutes,
				queuePosition: queueContext.queuePosition,
				totalWaiting: queueContext.totalWaiting,
				isDelayed: queueContext.isDelayed
			};
		}

		res.json(response);
	} catch (err) {
		console.error('Queue Assistant Error:', err);
		res.json({
			success: true,
			reply: 'Hello! I am your SmartOPD Assistant. How can I assist you with your queue or appointment today? 😊'
		});
	}
};
