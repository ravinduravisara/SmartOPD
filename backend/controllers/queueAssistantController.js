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
function buildSystemPrompt(queueContext, language = 'en') {
	let langInstruction = '';
	if (language === 'ta') {
		langInstruction = `CRITICAL LANGUAGE RULE: You MUST respond in Tamil (தமிழ் script, or conversational Tamil/Tanglish). Be friendly, warm, and natural.`;
	} else if (language === 'si') {
		langInstruction = `CRITICAL LANGUAGE RULE: You MUST respond in Sinhala (සිංහල script, or conversational Sinhala). Be polite, warm, and helpful.`;
	} else {
		langInstruction = `CRITICAL LANGUAGE RULE: Respond in clear, friendly, and natural English. If user asks in Tanglish, reply in Tanglish.`;
	}

	const basePrompt = `You are "SmartOPD Assistant" — a friendly, casual, and helpful AI chatbot for a hospital OPD (Out-Patient Department) queue management app called SmartOPD.

PERSONALITY & STYLE:
- Be warm, friendly, natural and casual — like ChatGPT, NOT robotic
- Keep responses short, direct, and conversational (2-3 sentences max)
- Use 1-2 friendly emojis when appropriate

${langInstruction}

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

GENERAL HOSPITAL & OPD INFORMATION (User has no active token right now):
- OPD Working Hours: Government OPD Clinics are open daily from 8:00 AM to 4:00 PM. Emergency care is available 24/7.
- Doctor Availability: General and specialist doctors (Cardiology, OPD, Pediatrics, Orthopedics, etc.) consult patients during working hours.
- How to Book an Appointment: Users can browse hospitals, select a doctor, and pick an available time slot on the "Hospitals / Book Appointment" page.
- How to Get a Token: On the day of the appointment, when arriving at the hospital, users tap "Check In & Get Live Token" under My Appointments to receive their live queue token.`;
}

// Intelligent natural language responder for English, Tamil/Tanglish, and Sinhala
function generateSmartQueueReply(query, queueContext, language = 'en') {
	const q = query.toLowerCase().trim();

	const isSinhala = language === 'si' || /[\u0D80-\u0DFF]/.test(q) || q.includes('token eka') || q.includes('aayubowan') || q.includes('kiyada') || q.includes('wela');
	const isTamil = language === 'ta' || /[\u0B80-\u0BFF]/.test(q) || q.includes('enna') || q.includes('ethana') || q.includes('eppadi') || q.includes('varum') || q.includes('vanakkam') || q.includes('iruk') || q.includes('neram');

	// --- 1. SINHALA RESPONSES ---
	if (isSinhala) {
		if (q.includes('ආයුබෝවන්') || q.includes('hello') || q.includes('hi') || q.includes('aayubowan')) {
			return queueContext
				? `ආයුබෝවන්! 👋 ඔබේ සක්‍රිය OPD ටෝකනය **${queueContext.tokenNumber}** (${queueContext.hospitalName}). ඔබට ඉදිරියෙන් රෝගීන් ${queueContext.patientsAhead} දෙනෙකු සිටී. මම ඔබට කෙසේ උදව් කරන්නද? 😊`
				: `ආයුබෝවන්! 👋 මම SmartOPD සහායකයා. OPD ටෝකන්, බලා සිටින වේලාව හෝ වෛද්‍යවරුන් ගැන ඕනෑම දෙයක් අසන්න! 😊`;
		}
		if (!queueContext) {
			return `ඔබට දැනට සක්‍රිය ටෝකනයක් නොමැත. රෝහලට පැමිණි පසු Appointment පිටුවෙන් "Check In" කරන්න. 🎟️`;
		}
		if (q.includes('ටෝකන්') || q.includes('token') || q.includes('අංකය') || q.includes('මගේ')) {
			return `ඔබේ සක්‍රිය OPD ටෝකන් අංකය **${queueContext.tokenNumber}** වේ (${queueContext.hospitalName} - වෛද්‍ය ${queueContext.doctorName}).`;
		}
		if (q.includes('ඉදිරියෙන්') || q.includes('ahead') || q.includes('කී දෙනෙක්') || q.includes('patients')) {
			return queueContext.patientsAhead === 0
				? `ඔබට ඉදිරියෙන් කිසිවෙකු නැත! ඊළඟ වාරය ඔබගේ වේ. 🟢`
				: `ඔබට ඉදිරියෙන් රෝගීන් **${queueContext.patientsAhead} දෙනෙකු** පෝලිමේ රැඳී සිටී. බලා සිටිය යුතු කාලය: ~${queueContext.estimatedWaitMinutes} මිනිත්තු.`;
		}
		if (q.includes('වේලාව') || q.includes('wait') || q.includes('time') || q.includes('කොපමණ')) {
			return queueContext.estimatedWaitMinutes === 0
				? `ඔබ බලා සිටිය යුතු කාලය මිනිත්තු 0 කි! ඔබ ඊළඟට වෛද්‍යවරයා හමුවීමට සූදානම් වන්න. 🟢`
				: `ඔබ බලා සිටිය යුතු ඇස්තමේන්තුගත කාලය මිනිත්තු **~${queueContext.estimatedWaitMinutes}** පමණ වේ (${queueContext.patientsAhead} දෙනෙකු ඉදිරියෙන්).`;
		}
		if (q.includes('දැනට') || q.includes('current') || q.includes('යන')) {
			return queueContext.currentToken && queueContext.currentToken !== 'None'
				? `වෛද්‍යවරයා දැනට පරීක්ෂා කරන්නේ ටෝකන් **${queueContext.currentToken}** ය. ඔබේ ටෝකනය: **${queueContext.tokenNumber}**.`
				: `තවමත් ටෝකන් ඇමතීම ආරම්භ කර නොමැත. ඔබේ ටෝකනය **${queueContext.tokenNumber}** රැඳී සිටීමේ ලැයිස්තුවේ ඇත.`;
		}
		if (q.includes('ප්‍රමාද') || q.includes('delay') || q.includes('late')) {
			return queueContext.isDelayed
				? `ඔව්, වෛද්‍ය පරීක්ෂණය සුළු වශයෙන් ප්‍රමාද විය හැක. කරුණාකර රැඳී සිටින්න. ⚠️`
				: `නැත, OPD පෝලිම සාමාන්‍ය වේගයෙන් ක්‍රියාත්මක වේ! ✅`;
		}
		return `ඔබේ සජීවී OPD විස්තරය: ටෝකනය **${queueContext.tokenNumber}**, ඉදිරියෙන් ${queueContext.patientsAhead} දෙනෙක්, ඇස්තමේන්තුගත වේලාව: ~${queueContext.estimatedWaitMinutes} මිනිත්තු. වැඩිදුර විස්තර සඳහා අසන්න! 😊`;
	}

	// --- 2. TAMIL / TANGLISH RESPONSES ---
	if (isTamil) {
		if (q.includes('vanakkam') || q.includes('வணக்கம்') || q === 'hi' || q === 'hello') {
			return queueContext
				? `வணக்கம்! 👋 உங்கள் நேரடி OPD டோக்கன் **${queueContext.tokenNumber}** (${queueContext.hospitalName}). உங்களுக்கு முன்னால் ${queueContext.patientsAhead} நோயாளிகள் உள்ளனர். நான் உங்களுக்கு எவ்வாறு உதவ வேண்டும்? 😊`
				: `வணக்கம்! 👋 நான் உங்கள் SmartOPD உதவியாளர். OPD டோக்கன், காத்திருப்பு நேரம் அல்லது மருத்துவர் நேரம் பற்றி கேளுங்கள்! 😊`;
		}
		if (!queueContext) {
			return `உங்களுக்கு தற்போது நேரடி டோக்கன் எதுவும் இல்லை. மருத்துவமனைக்கு வந்ததும் Appointment பக்கத்தில் "Check In" செய்து நேரடி டோக்கனைப் பெறுங்கள். 🎟️`;
		}
		if (q.includes('டோக்கன்') || q.includes('token') || q.includes('எண்') || q.includes('ennoda') || q.includes('my')) {
			return `உங்கள் நேரடி OPD டோக்கன் எண் **${queueContext.tokenNumber}** (${queueContext.hospitalName} - ${queueContext.doctorName}).`;
		}
		if (q.includes('முன்னாடி') || q.includes('முன்னால்') || q.includes('ahead') || q.includes('ethana') || q.includes('patients')) {
			return queueContext.patientsAhead === 0
				? `உங்களுக்கு முன்னால் எவரும் இல்லை! நீங்கள் தான் அடுத்ததாக அழைக்கப்படுவீர்கள். 🟢`
				: `உங்களுக்கு முன்னால் **${queueContext.patientsAhead} நோயாளிகள்** காத்திருக்கின்றனர். எதிர்பார்க்கப்படும் நேரம்: ~${queueContext.estimatedWaitMinutes} நிமிடங்கள்.`;
		}
		if (q.includes('நேரம்') || q.includes('wait') || q.includes('time') || q.includes('evvalavu')) {
			return queueContext.estimatedWaitMinutes === 0
				? `உங்கள் காத்திருப்பு நேரம் ~0 நிமிடங்கள்! அடுத்ததாக நீங்கள் மருத்துவரைச் சந்திக்கலாம். 🟢`
				: `உங்கள் எதிர்பார்க்கப்படும் காத்திருப்பு நேரம் சுமார் **~${queueContext.estimatedWaitMinutes} நிமிடங்கள்** (${queueContext.patientsAhead} நோயாளிகள் முன்னால் உள்ளனர்).`;
		}
		if (q.includes('தற்போது') || q.includes('current') || q.includes('ippo') || q.includes('போகிறது')) {
			return queueContext.currentToken && queueContext.currentToken !== 'None'
				? `மருத்துவர் தற்போது பார்க்கும் டோக்கன்: **${queueContext.currentToken}**. உங்கள் டோக்கன்: **${queueContext.tokenNumber}**.`
				: `மருத்துவர் இன்னும் டோக்கன்களை அழைக்கத் தொடங்கவில்லை. உங்கள் டோக்கன் **${queueContext.tokenNumber}** காத்திருப்புப் பட்டியலில் உள்ளது.`;
		}
		if (q.includes('delay') || q.includes('late') || q.includes('லேட்') || q.includes('தாமதம்')) {
			return queueContext.isDelayed
				? `ஆம், மருத்துவர் சற்று கூடுதல் நேரம் எடுத்து பரிசோதிக்கிறார். தயவுசெய்து பொறுமையாக இருங்கள். ⚠️`
				: `இல்லை, OPD வரிசை இயல்பான வேகத்தில் செல்கிறது. பெரிய தாமதங்கள் எதுவும் இல்லை! ✅`;
		}
		return `உங்கள் நேரடி OPD விவரம்: டோக்கன் **${queueContext.tokenNumber}**, முன்னால் ${queueContext.patientsAhead} நோயாளிகள், காத்திருப்பு: ~${queueContext.estimatedWaitMinutes} நிமிடங்கள். மேலும் கேள்விகளை கேட்கலாம்! 😊`;
	}

	// --- 3. ENGLISH RESPONSES ---
	if (q === 'hi' || q === 'hello' || q === 'hey') {
		return queueContext
			? `Hello! 👋 You have Token **${queueContext.tokenNumber}** for Dr. ${queueContext.doctorName}. How can I assist you with your OPD visit today? 😊`
			: `Hello! 👋 I am your SmartOPD Assistant. Ask me anything about OPD tokens, doctor schedules, or wait times! 😊`;
	}

	if (!queueContext) {
		if (q.includes('token') || q.includes('queue') || q.includes('wait') || q.includes('ahead')) {
			return `You currently do not have an active checked-in token. Please check in from your appointments page when you arrive at the hospital. 🎟️`;
		}
		return `I am your SmartOPD Assistant. How can I help you with your hospital visit or queue status today? 😊`;
	}

	if (q.includes('token') && (q.includes('my') || q.includes('mine') || q.includes('what') || q.includes('number'))) {
		return `Your active digital OPD token number is **${queueContext.tokenNumber}** at ${queueContext.hospitalName} for Dr. ${queueContext.doctorName}.`;
	}

	if (q.includes('current') || q.includes('now serving')) {
		return queueContext.currentToken && queueContext.currentToken !== 'None'
			? `The doctor is currently serving Token **${queueContext.currentToken}**. Your token is **${queueContext.tokenNumber}**.`
			: `No token is currently called yet. Your Token **${queueContext.tokenNumber}** is ready in the waiting list.`;
	}

	if (q.includes('ahead') || q.includes('patients')) {
		return queueContext.patientsAhead === 0
			? `There are **0 patients ahead of you**! You are next in line for consultation. 🟢`
			: `There are currently **${queueContext.patientsAhead} patient(s) ahead of you** in the queue. Est. wait: ~${queueContext.estimatedWaitMinutes} mins.`;
	}

	if (q.includes('wait') || q.includes('time') || q.includes('long')) {
		return queueContext.estimatedWaitMinutes === 0
			? `Your estimated wait time is **0 minutes**! You are next to see the doctor. 🟢`
			: `Your estimated wait time is approximately **~${queueContext.estimatedWaitMinutes} minutes** (${queueContext.patientsAhead} patients ahead).`;
	}

	if (q.includes('delay') || q.includes('late') || q.includes('slow')) {
		return queueContext.isDelayed
			? `Yes, doctor consultation is currently taking slightly longer than usual. Please stay seated nearby. ⚠️`
			: `No major delays detected! The OPD queue is moving normally. ✅`;
	}

	return `Here is your live OPD summary: Token **${queueContext.tokenNumber}** at ${queueContext.hospitalName}, ${queueContext.patientsAhead} patients ahead, Est. Wait: ~${queueContext.estimatedWaitMinutes} mins. Feel free to ask if you need more info! 😊`;
}

exports.askQueueAssistant = async (req, res) => {
	try {
		const { query, language = 'en' } = req.body;
		const patientId = (req.userRecord && req.userRecord._id) || (req.user && (req.user._id || req.user.id));

		if (!query || typeof query !== 'string') {
			return res.status(400).json({ message: 'Query string is required' });
		}

		// Get real-time queue context from MongoDB
		const queueContext = await getQueueContext(patientId);

		// Build system prompt with live queue data for Gemini AI
		const systemPrompt = buildSystemPrompt(queueContext, language);

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
						maxOutputTokens: 300,
						temperature: 0.7,
					}
				});

				if (result && result.response) {
					reply = result.response.text().trim();
					if (reply) break;
				}
			} catch (mErr) {
				// Gemini API key failover
			}
		}

		if (!reply) {
			reply = generateSmartQueueReply(query, queueContext, language);
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
			reply: 'Hello! I am your SmartOPD Assistant. How can I help you with your hospital visit or queue status today? 😊'
		});
	}
};
