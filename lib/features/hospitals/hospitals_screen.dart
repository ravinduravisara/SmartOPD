import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/hospital.dart';
import '../../services/auth_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_widget.dart';
import 'hospital_details_screen.dart';

class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key, required this.service});
  final AuthService service;

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  final search = TextEditingController();
  late Future<List<Hospital>> hospitals;
  String? city;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _load() => setState(() {
    hospitals = widget.service.getHospitals(query: search.text, city: city);
  });

  /// Passes a completed booking back up so the home screen can refresh.
  Future<void> _openHospital(String hospitalId) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HospitalDetailsScreen(
          service: widget.service,
          hospitalId: hospitalId,
        ),
      ),
    );
    if (booked == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hospitals')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search hospital or city',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _load,
              ),
            ),
          ),
        ),
        _CityFilter(
          service: widget.service,
          selected: city,
          onChanged: (value) {
            city = value;
            _load();
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: AsyncView<List<Hospital>>(
              future: hospitals,
              onRetry: _load,
              builder: (context, list) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  if (list.isEmpty)
                    const EmptyView(
                      icon: Icons.local_hospital_outlined,
                      message: 'No hospitals matched your search.',
                    ),
                  for (final hospital in list) ...[
                    _HospitalCard(
                      hospital: hospital,
                      onTap: () => _openHospital(hospital.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Horizontal chip row of the cities that actually have hospitals.
class _CityFilter extends StatefulWidget {
  const _CityFilter({
    required this.service,
    required this.selected,
    required this.onChanged,
  });
  final AuthService service;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  State<_CityFilter> createState() => _CityFilterState();
}

class _CityFilterState extends State<_CityFilter> {
  late final Future<List<String>> cities = widget.service.getHospitalCities();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: cities,
    builder: (context, snapshot) {
      final list = snapshot.data ?? const <String>[];
      if (list.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            ChoiceChip(
              label: const Text('All cities'),
              selected: widget.selected == null,
              onSelected: (_) => widget.onChanged(null),
            ),
            for (final city in list) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(city),
                selected: widget.selected == city,
                onSelected: (_) => widget.onChanged(city),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({required this.hospital, required this.onTap});
  final Hospital hospital;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospital.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hospital.city} · ${hospital.doctorCount} '
                    '${hospital.doctorCount == 1 ? 'doctor' : 'doctors'}',
                    style: Theme.of(context).textTheme.bodyMedium,
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
