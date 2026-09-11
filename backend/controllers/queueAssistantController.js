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

// Intelligent natural language fallback for Tanglish, Tamil, and English OPD questions
function generateSmartQueueReply(query, queueContext) {
	const q = query.toLowerCase();

	const isTanglishOrTamil = /[a-z]* (enna|eppadi|ethana|per|varum|kaat|iruk|vanakkam|sollu|paak|paath|panna|podhu)|வணக்கம்|எப்போது|டோக்கன்/.test(q) ||
		q.includes('enna') || q.includes('ethana') || q.includes('eppadi') || q.includes('varum') || q.includes('vanakkam') || q.includes('kaattudhu') || q.includes('solli') || q.includes('badhil') || q.includes('kaattala') || q.includes('aagum') || q.includes('olunga');

	// 1. Greetings
	if (q.includes('hi') || q.includes('hello') || q.includes('hey') || q.includes('vanakkam') || q.includes('வணக்கம்')) {
		if (isTanglishOrTamil) {
			return queueContext
				? `Vanakkam! 👋 Unga Token **${queueContext.tokenNumber}** (${queueContext.hospitalName}). Ungalukku munnadi ${queueContext.patientsAhead} patients irukaanga. Naan ungalukku eppadi help pannanum?`
				: `Vanakkam! 👋 Naan unga SmartOPD Assistant. Ungalukku token, wait time, or queue status patri enna theriyanum? 😊`;
		}
		return queueContext
			? `Hello! 👋 You have Token **${queueContext.tokenNumber}** for Dr. ${queueContext.doctorName}. How can I assist you with your OPD visit today? 😊`
			: `Hello! 👋 I am your SmartOPD Queue Assistant. How can I help you today? 😊`;
	}

	// If no active queue token
	if (!queueContext) {
		if (isTanglishOrTamil) {
			return `Ungalukku dharposedhu active check-in token edhum illai. Appointment page-la poyyi Check In panna live token tharappadum. 😊`;
		}
		return `You currently do not have an active checked-in token. Please check in from your appointments page when you arrive at the hospital. 😊`;
	}

	// 2. Token query ("What is my token?", "en token enna")
	if (q.includes('token') && (q.includes('my') || q.includes('mine') || q.includes('en') || q.includes('ennoda') || q.includes('what') || q.includes('number'))) {
		if (isTanglishOrTamil) {
			return `Unga Live OPD Token number **${queueContext.tokenNumber}** (${queueContext.hospitalName} - ${queueContext.doctorName}).`;
		}
		return `Your active digital OPD token number is **${queueContext.tokenNumber}** at ${queueContext.hospitalName} for Dr. ${queueContext.doctorName}.`;
	}

	// 3. Current token serving ("What is current token?", "now serving", "ipoh ethana token")
	if (q.includes('current') || q.includes('now serving') || q.includes('ipoh') || q.includes('ippo') || q.includes('podhu')) {
		if (isTanglishOrTamil) {
			return queueContext.currentToken && queueContext.currentToken !== 'None'
				? `Dharposedhu Doctor paarthukondirukkum token: **${queueContext.currentToken}**. Unga token: **${queueContext.tokenNumber}**.`
				: `Doctor innum token call panna thuvangavillai. Unga token **${queueContext.tokenNumber}** waiting list-la irukku.`;
		}
		return queueContext.currentToken && queueContext.currentToken !== 'None'
			? `The doctor is currently serving Token **${queueContext.currentToken}**. Your token is **${queueContext.tokenNumber}**.`
			: `No token is currently called yet. Your Token **${queueContext.tokenNumber}** is ready in the waiting list.`;
	}

	// 4. Patients ahead ("How many patients ahead?", "ethana per ahead", "munnadi ethana")
	if (q.includes('ahead') || q.includes('patients') || q.includes('ethana per') || q.includes('munnadi')) {
		if (isTanglishOrTamil) {
			return queueContext.patientsAhead === 0
				? `Ungalukku munnadi yaarume illai! (` + (queueContext.status === 'CALLED' ? `Unga turn vandhachu, Consultation room-kku ponga! 🟢` : `Next turn ungala thaan கூப்பிடுவாங்க 🟢`) + `)`
				: `Ungalukku munnadi **${queueContext.patientsAhead} patients** wait pannikitrukaanga. Est. wait time: ~${queueContext.estimatedWaitMinutes} mins.`;
		}
		return queueContext.patientsAhead === 0
			? `There are **0 patients ahead of you**! You are next in line for consultation. 🟢`
			: `There are currently **${queueContext.patientsAhead} patient(s) ahead of you** in the queue.`;
	}

	// 5. Wait time / ETA ("How long wait", "wait time", "eppadiku varum", "evvalavu neram")
	if (q.includes('wait') || q.includes('time') || q.includes('long') || q.includes('neram') || q.includes('evvalavu')) {
		if (isTanglishOrTamil) {
			return queueContext.estimatedWaitMinutes === 0
				? `Unga wait time ~0 mins! Ungalukku munnadi 0 patients, ready-a irunga. 🟢`
				: `Unga ethirpaarkkappadum wait time sumaar **~${queueContext.estimatedWaitMinutes} nimidangal** (${queueContext.patientsAhead} patients ahead).`;
		}
		return queueContext.estimatedWaitMinutes === 0
			? `Your estimated wait time is **0 minutes**! You are next to see the doctor.`
			: `Your estimated wait time is approximately **~${queueContext.estimatedWaitMinutes} minutes** (${queueContext.patientsAhead} patients ahead).`;
	}

	// 6. Delay query ("delay", "late", "doctor late")
	if (q.includes('delay') || q.includes('late') || q.includes('slow')) {
		if (isTanglishOrTamil) {
			return queueContext.isDelayed
				? `Aam, Doctor dharposedhu siridhu neram extra eduthu paarthu kondirukkiraar. Porumaiyaaga irunga. ⚠️`
				: `Illa, OPD queue normal speed-la dhaan poikitu irukku. No major delays detected! ✅`;
		}
		return queueContext.isDelayed
			? `Yes, doctor consultation is currently taking slightly longer than usual. Please stay seated nearby. ⚠️`
			: `No major delays detected! The OPD queue is moving normally. ✅`;
	}

	// Default intelligent response in user's language
	if (isTanglishOrTamil) {
		return `Unga Live OPD summary: Token **${queueContext.tokenNumber}** (${queueContext.hospitalName}), ${queueContext.patientsAhead} patients ahead, Est. Wait: ~${queueContext.estimatedWaitMinutes} mins. Mele ethavadhu kelvi irundha கேளுங்கள்! 😊`;
	}

	return `Here is your live OPD summary: Token **${queueContext.tokenNumber}** at ${queueContext.hospitalName}, ${queueContext.patientsAhead} patients ahead, Est. Wait: ~${queueContext.estimatedWaitMinutes} mins. Feel free to ask if you need more info! 😊`;
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
		const modelsToTry = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-2.0-flash-exp'];

		for (const modelName of modelsToTry) {
			try {
				const model = genAI.getGenerativeModel({
					model: modelName,
				});

				const result = await model.generateContent({
					contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\nUser Question: ${query}` }] }],
					generationConfig: {
						maxOutputTokens: 250,
						temperature: 0.7,
					}
				});

				if (result && result.response) {
					reply = result.response.text().trim();
					if (reply) break;
				}
			} catch (mErr) {
				// Silently failover
			}
		}

		if (!reply) {
			reply = generateSmartQueueReply(query, queueContext);
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
