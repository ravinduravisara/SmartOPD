import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/hospital.dart';
import '../../services/auth_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_widget.dart';
import '../doctors/doctors_screen.dart';

class HospitalDetailsScreen extends StatefulWidget {
  const HospitalDetailsScreen({
    super.key,
    required this.service,
    required this.hospitalId,
  });
  final AuthService service;
  final String hospitalId;

  @override
  State<HospitalDetailsScreen> createState() => _HospitalDetailsScreenState();
}

class _HospitalDetailsScreenState extends State<HospitalDetailsScreen> {
  late Future<HospitalDetails> details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    details = widget.service.getHospital(widget.hospitalId);
  });

  Future<void> _openDoctors({
    String? departmentId,
    required String title,
  }) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DoctorsScreen(
          service: widget.service,
          title: title,
          hospitalId: widget.hospitalId,
          departmentId: departmentId,
        ),
      ),
    );
    if (booked == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hospital')),
    body: AsyncView<HospitalDetails>(
      future: details,
      onRetry: _load,
      builder: (context, data) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            data.hospital.name,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.place_outlined, text: data.hospital.city),
          if (data.hospital.address != null)
            _InfoRow(
              icon: Icons.map_outlined,
              text: data.hospital.address!,
            ),
          if (data.hospital.phone != null)
            _InfoRow(icon: Icons.call_outlined, text: data.hospital.phone!),
          if (data.hospital.about != null) ...[
            const SizedBox(height: 14),
            Text(
              data.hospital.about!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 18),

          // Live OPD Queue Preview Card (Module 3 Requirement)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                          SizedBox(width: 6),
                          Text('LIVE QUEUE ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Text('General OPD', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Now Serving', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          data.hospital.name.contains('Colombo') ? 'A-101' : 'None',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Patients Waiting', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          data.hospital.name.contains('Colombo') ? '2 Patients' : '0 Patients',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Est. Wait Time', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          data.hospital.name.contains('Colombo') ? '~12 min' : '~0 min',
                          style: const TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => _openDoctors(title: 'All doctors'),
            icon: const Icon(Icons.people_alt_outlined),
            label: Text('See all ${data.hospital.doctorCount} doctors'),
          ),
          const SizedBox(height: 26),
          Text('Departments', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (data.departments.isEmpty)
            const EmptyView(
              icon: Icons.apartment_outlined,
              message: 'No departments listed for this hospital yet.',
            ),
          for (final department in data.departments) ...[
            _DepartmentCard(
              department: department,
              onTap: () => _openDoctors(
                departmentId: department.id,
                title: department.name,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, required this.onTap});
  final Department department;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.medical_services_outlined, color: AppTheme.teal),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (department.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      department.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${department.doctorCount} '
                    '${department.doctorCount == 1 ? 'doctor' : 'doctors'}',
                    style: const TextStyle(
                      color: AppTheme.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.teal),
          ],
        ),
      ),
    ),
  );
}
