// Populates hospitals, departments and doctors so the booking flow has real
// data to work with. Safe to re-run: it clears only these three collections
// and leaves users, dependents and appointments untouched.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const connectDatabase = require('../config/db');
const Hospital = require('../models/Hospital');
const Department = require('../models/Department');
const Doctor = require('../models/Doctor');

const weekdays = (startTime, endTime, days) => days.map((dayOfWeek) => ({ dayOfWeek, startTime, endTime }));

const HOSPITALS = [
	{
		name: 'Colombo General Hospital',
		city: 'Colombo',
		address: 'Regent Street, Colombo 08',
		phone: '+94112691111',
		lat: 6.9271,
		lng: 79.8612,
		about: 'Tertiary care hospital with 24-hour emergency and specialist OPD clinics.',
		departments: [
			{
				name: 'Cardiology',
				description: 'Heart and vascular care, ECG, echocardiography and cardiac follow-up.',
				doctors: [
					{
						name: 'Dr. Anushka Perera', specialization: 'Consultant Cardiologist',
						qualifications: 'MBBS, MD (Cardiology)', experienceYears: 14, consultationFee: 4500,
						about: 'Focuses on preventive cardiology and heart failure management.',
						availability: weekdays('09:00', '12:30', [1, 3, 5]), slotMinutes: 30
					},
					{
						name: 'Dr. Ruwan Jayasinghe', specialization: 'Cardiologist',
						qualifications: 'MBBS, MRCP', experienceYears: 8, consultationFee: 3500,
						about: 'Interventional cardiology and post-operative review clinics.',
						availability: [...weekdays('14:00', '17:00', [2, 4]), ...weekdays('09:00', '11:00', [6])], slotMinutes: 20
					}
				]
			},
			{
				name: 'Dermatology',
				description: 'Skin, hair and nail conditions including allergy and cosmetic referrals.',
				doctors: [
					{
						name: 'Dr. Nimali Fernando', specialization: 'Consultant Dermatologist',
						qualifications: 'MBBS, MD (Dermatology)', experienceYears: 11, consultationFee: 4000,
						about: 'Treats eczema, psoriasis and paediatric skin conditions.',
						availability: weekdays('08:30', '12:00', [1, 2, 4]), slotMinutes: 20
					}
				]
			},
			{
				name: 'Paediatrics',
				description: 'Newborn, child and adolescent health with immunisation clinics.',
				doctors: [
					{
						name: 'Dr. Sanjaya Wickramasinghe', specialization: 'Consultant Paediatrician',
						qualifications: 'MBBS, DCH, MD', experienceYears: 17, consultationFee: 4000,
						about: 'Growth, development and childhood asthma clinics.',
						availability: weekdays('15:00', '18:00', [1, 2, 3, 4, 5]), slotMinutes: 15
					}
				]
			}
		]
	},
	{
		name: 'Kandy Teaching Hospital',
		city: 'Kandy',
		address: 'William Gopallawa Mawatha, Kandy',
		phone: '+94812233337',
		lat: 7.2906,
		lng: 80.6337,
		about: 'Teaching hospital serving the central province with specialist clinics.',
		departments: [
			{
				name: 'Orthopaedics',
				description: 'Bone, joint and sports injury care including fracture clinics.',
				doctors: [
					{
						name: 'Dr. Harsha Bandara', specialization: 'Consultant Orthopaedic Surgeon',
						qualifications: 'MBBS, MS (Ortho)', experienceYears: 19, consultationFee: 5000,
						about: 'Joint replacement and sports injury rehabilitation.',
						availability: weekdays('09:00', '13:00', [2, 5]), slotMinutes: 30
					},
					{
						name: 'Dr. Chamari Silva', specialization: 'Orthopaedic Surgeon',
						qualifications: 'MBBS, MS', experienceYears: 7, consultationFee: 3500,
						about: 'Spine and trauma clinics, post-fracture follow-up.',
						availability: weekdays('10:00', '12:30', [1, 4]), slotMinutes: 25
					}
				]
			},
			{
				name: 'General Medicine',
				description: 'Adult general medical clinics, diabetes and hypertension review.',
				doctors: [
					{
						name: 'Dr. Ishara Gunawardena', specialization: 'Consultant Physician',
						qualifications: 'MBBS, MD (Medicine)', experienceYears: 12, consultationFee: 3000,
						about: 'Diabetes, thyroid and long-term condition management.',
						availability: weekdays('08:00', '11:30', [1, 2, 3, 4, 5]), slotMinutes: 20
					}
				]
			}
		]
	},
	{
		name: 'Galle Base Hospital',
		city: 'Galle',
		address: 'Hospital Road, Karapitiya, Galle',
		phone: '+94912232276',
		lat: 6.0535,
		lng: 80.2210,
		about: 'Regional hospital with outpatient specialist clinics and maternity care.',
		departments: [
			{
				name: 'Obstetrics & Gynaecology',
				description: 'Antenatal care, womens health and fertility clinics.',
				doctors: [
					{
						name: 'Dr. Dilhani Rathnayake', specialization: 'Consultant Gynaecologist',
						qualifications: 'MBBS, MS (OBG)', experienceYears: 15, consultationFee: 4500,
						about: 'Antenatal clinics and minimally invasive gynaecological surgery.',
						availability: weekdays('09:00', '12:00', [1, 3, 6]), slotMinutes: 30
					}
				]
			},
			{
				name: 'ENT',
				description: 'Ear, nose and throat clinics including hearing assessment.',
				doctors: [
					{
						name: 'Dr. Kasun Alwis', specialization: 'ENT Surgeon',
						qualifications: 'MBBS, MS (ENT)', experienceYears: 9, consultationFee: 3500,
						about: 'Sinus, hearing loss and paediatric ENT clinics.',
						availability: weekdays('13:30', '16:30', [2, 4]), slotMinutes: 20
					}
				]
			}
		]
	}
];

async function seed() {
	await connectDatabase();
	await Promise.all([Doctor.deleteMany({}), Department.deleteMany({}), Hospital.deleteMany({})]);
	let departmentCount = 0;
	let doctorCount = 0;
	for (const { departments, ...hospitalData } of HOSPITALS) {
		const hospital = await Hospital.create(hospitalData);
		for (const { doctors, ...departmentData } of departments) {
			const department = await Department.create({ ...departmentData, hospital: hospital._id });
			departmentCount += 1;
			for (const doctor of doctors) {
				await Doctor.create({ ...doctor, hospital: hospital._id, department: department._id });
				doctorCount += 1;
			}
		}
	}
	console.log(`Seeded ${HOSPITALS.length} hospitals, ${departmentCount} departments, ${doctorCount} doctors`);
	await mongoose.connection.close();
}

seed().catch((error) => {
	console.error('Seed failed:', error.message);
	process.exitCode = 1;
	mongoose.connection.close();
});
