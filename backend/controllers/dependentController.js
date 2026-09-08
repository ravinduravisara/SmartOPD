const Dependent = require('../models/Dependent');

async function list(req, res, next) {
  try { res.json({ dependents: await Dependent.find({ patient: req.user.id }).sort({ name: 1 }) }); } catch (error) { next(error); }
}

async function create(req, res, next) {
  try {
    const { name, relationship, dateOfBirth, gender, phone } = req.body;
    if (!name || !relationship || !dateOfBirth) return res.status(400).json({ message: 'Name, relationship and date of birth are required' });
    const dependent = await Dependent.create({ patient: req.user.id, name, relationship, dateOfBirth, gender, phone });
    res.status(201).json({ dependent });
  } catch (error) { next(error); }
}

async function update(req, res, next) {
  try {
    const dependent = await Dependent.findOneAndUpdate({ _id: req.params.id, patient: req.user.id }, req.body, { new: true, runValidators: true });
    if (!dependent) return res.status(404).json({ message: 'Dependent not found' });
    res.json({ dependent });
  } catch (error) { next(error); }
}

async function remove(req, res, next) {
  try {
    const dependent = await Dependent.findOneAndDelete({ _id: req.params.id, patient: req.user.id });
    if (!dependent) return res.status(404).json({ message: 'Dependent not found' });
    res.json({ message: 'Dependent removed' });
  } catch (error) { next(error); }
}

module.exports = { list, create, update, remove };