const mongoose = require('mongoose');
require('dotenv').config();
const Hospital = require('./models/Hospital');

const mongoUri = process.env.MONGODB_URI || 'mongodb+srv://ravinduravisara61_db_user:van5v5fNr307MgZF@cluster0.u9h6ezs.mongodb.net/smartopd?appName=Cluster0';

const sriLankaGovernmentHospitals = [
  // Western Province
  { name: 'National Hospital of Sri Lanka (Colombo General)', city: 'Colombo', address: 'E W Perera Mawatha, Colombo 01000', lat: 6.9187, lng: 79.8686 },
  { name: 'Lady Ridgeway Hospital for Children', city: 'Colombo', address: 'Dr Danister De Silva Mawatha, Colombo 00800', lat: 6.9197, lng: 79.8732 },
  { name: 'Castle Street Hospital for Women', city: 'Colombo', address: 'Castle Street, Colombo 00800', lat: 6.9126, lng: 79.8821 },
  { name: 'Colombo South Teaching Hospital (Kalubowila)', city: 'Dehiwala', address: 'Hospital Road, Kalubowila, Dehiwala', lat: 6.8703, lng: 79.8837 },
  { name: 'Colombo North Teaching Hospital (Ragama)', city: 'Ragama', address: 'Hospital Road, Ragama', lat: 7.0279, lng: 79.9238 },
  { name: 'Base Hospital Homagama', city: 'Homagama', address: 'High Level Road, Homagama', lat: 6.8442, lng: 80.0028 },
  { name: 'District General Hospital Gampaha', city: 'Gampaha', address: 'Hospital Road, Gampaha', lat: 7.0886, lng: 79.9925 },
  { name: 'Base Hospital Negombo', city: 'Negombo', address: 'Colombo Road, Negombo', lat: 7.2081, lng: 79.8398 },
  { name: 'District General Hospital Kalutara', city: 'Kalutara', address: 'Nagoda, Kalutara', lat: 6.5843, lng: 79.9723 },
  { name: 'Base Hospital Panadura', city: 'Panadura', address: 'Hospital Road, Panadura', lat: 6.7134, lng: 79.9076 },

  // Central Province
  { name: 'National Hospital Kandy (Teaching Hospital)', city: 'Kandy', address: 'William Gopallawa Mawatha, Kandy', lat: 7.2882, lng: 80.6299 },
  { name: 'Sirimavo Bandaranaike Specialized Children Hospital', city: 'Peradeniya', address: 'Peradeniya, Kandy', lat: 7.2625, lng: 80.5960 },
  { name: 'Teaching Hospital Peradeniya', city: 'Peradeniya', address: 'Gatembe, Peradeniya', lat: 7.2689, lng: 80.5952 },
  { name: 'District General Hospital Matale', city: 'Matale', address: 'Hospital Road, Matale', lat: 7.4675, lng: 80.6234 },
  { name: 'District General Hospital Nuwara Eliya', city: 'Nuwara Eliya', address: 'Hospital Road, Nuwara Eliya', lat: 6.9664, lng: 80.7681 },

  // Southern Province
  { name: 'Teaching Hospital Karapitiya (Galle)', city: 'Galle', address: 'Karapitiya, Galle', lat: 6.0658, lng: 80.2263 },
  { name: 'District General Hospital Matara', city: 'Matara', address: 'Station Road, Matara', lat: 5.9478, lng: 80.5486 },
  { name: 'District General Hospital Hambantota', city: 'Hambantota', address: 'Siribopura, Hambantota', lat: 6.1362, lng: 81.1185 },

  // Northern Province
  { name: 'Teaching Hospital Jaffna', city: 'Jaffna', address: 'Hospital Road, Jaffna', lat: 9.6644, lng: 80.0167 },
  { name: 'District General Hospital Vavuniya', city: 'Vavuniya', address: 'Inner Ring Road, Vavuniya', lat: 8.7514, lng: 80.4974 },
  { name: 'District General Hospital Kilinochchi', city: 'Kilinochchi', address: 'A9 Road, Kilinochchi', lat: 9.3854, lng: 80.3982 },

  // Eastern Province
  { name: 'Teaching Hospital Batticaloa', city: 'Batticaloa', address: 'Hospital Road, Batticaloa', lat: 7.7170, lng: 81.7005 },
  { name: 'District General Hospital Trincomalee', city: 'Trincomalee', address: 'Hospital Road, Trincomalee', lat: 8.5772, lng: 81.2335 },
  { name: 'District General Hospital Ampara', city: 'Ampara', address: 'Hospital Road, Ampara', lat: 7.2912, lng: 81.6747 },

  // North Western Province
  { name: 'Teaching Hospital Kurunegala', city: 'Kurunegala', address: 'Hospital Road, Kurunegala', lat: 7.4863, lng: 80.3647 },
  { name: 'District General Hospital Chilaw', city: 'Chilaw', address: 'Hospital Road, Chilaw', lat: 7.5758, lng: 79.7952 },

  // North Central Province
  { name: 'Teaching Hospital Anuradhapura', city: 'Anuradhapura', address: 'Maithripala Senanayake Mawatha, Anuradhapura', lat: 8.3350, lng: 80.4026 },
  { name: 'District General Hospital Polonnaruwa', city: 'Polonnaruwa', address: 'Hospital Road, Polonnaruwa', lat: 7.9392, lng: 81.0028 },

  // Uva Province
  { name: 'Provincial General Hospital Badulla', city: 'Badulla', address: 'Hospital Road, Badulla', lat: 6.9897, lng: 81.0558 },
  { name: 'District General Hospital Monaragala', city: 'Monaragala', address: 'Hospital Road, Monaragala', lat: 6.8724, lng: 81.3508 },

  // Sabaragamuwa Province
  { name: 'Provincial General Hospital Ratnapura', city: 'Ratnapura', address: 'Hospital Road, Ratnapura', lat: 6.6828, lng: 80.3992 },
  { name: 'District General Hospital Kegalle', city: 'Kegalle', address: 'Main Street, Kegalle', lat: 7.2513, lng: 80.3464 }
];

async function seedAllSriLankaHospitals() {
  try {
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    await Hospital.deleteMany({});

    const docs = sriLankaGovernmentHospitals.map(h => ({
      name: h.name,
      city: h.city,
      address: h.address,
      phone: '+94 11 269 1111',
      about: 'Sri Lanka Government OPD & Specialist Clinic Services.',
      lat: h.lat,
      lng: h.lng,
      active: true
    }));

    await Hospital.insertMany(docs);
    console.log(`Successfully seeded ${docs.length} Sri Lanka Government Hospitals!`);
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

seedAllSriLankaHospitals();
