import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/loading.dart';
import '../data/catalog_models.dart';
import '../data/catalog_service.dart';
import 'catalog_ui.dart';

/// Doctors tab of the admin dashboard.
///
/// Doctors are what the booking flow ends on, so a row shows everything a
/// patient would see — fee, experience, which days there are hours on — plus
/// the active flag, which is the soft alternative to deleting.
///
/// Lives inside the dashboard's own scroll view: a plain [Column], no
/// [Scaffold] and no scrollable of its own.
class DoctorsAdminTab extends StatefulWidget {
  const DoctorsAdminTab({required this.service, super.key});

  final AdminCatalogService service;

  @override
  State<DoctorsAdminTab> createState() => _DoctorsAdminTabState();
}

class _DoctorsAdminTabState extends State<DoctorsAdminTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<AdminHospital> _hospitals = const [];

  /// Every department, across all hospitals: the pickers narrow this down.
  List<AdminDepartment> _departments = const [];
  List<AdminDoctor> _doctors = const [];

  String? _hospitalFilter;
  String? _departmentFilter;

  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  /// The row whose delete or toggle is in flight.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Departments belonging to [hospitalId], or all of them when no hospital is
  /// chosen. The server rejects a doctor whose department sits under another
  /// hospital, so every department picker is built from this.
  List<AdminDepartment> _departmentsFor(String? hospitalId) =>
      hospitalId == null
      ? _departments
      : _departments
            .where((department) => department.hospital.id == hospitalId)
            .toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hospitals = await widget.service.hospitals();
      final departments = await widget.service.departments();
      // Filters pointing at rows that are gone — or at a department that no
      // longer matches the chosen hospital — would leave a dropdown holding a
      // value none of its items carry, which throws. Drop them instead.
      final hospitalId = hospitals.any((h) => h.id == _hospitalFilter)
          ? _hospitalFilter
          : null;
      final departmentId =
          departments.any(
            (department) =>
                department.id == _departmentFilter &&
                (hospitalId == null || department.hospital.id == hospitalId),
          )
          ? _departmentFilter
          : null;
      final doctors = await widget.service.doctors(
        hospitalId: hospitalId,
        departmentId: departmentId,
        query: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _hospitals = hospitals;
        _departments = departments;
        _doctors = doctors;
        _hospitalFilter = hospitalId;
        _departmentFilter = departmentId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _readable(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedOnce = true;
        });
      }
    }
  }

  /// One request per pause in typing rather than one per keystroke.
  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _openForm([AdminDoctor? existing]) async {
    if (_hospitals.isEmpty || _departments.isEmpty) {
      showCatalogMessage(
        context,
        'Add a hospital and a department before adding doctors.',
      );
      return;
    }
    final saved = await showCatalogForm(
      context,
      title: existing == null ? 'New doctor' : 'Edit doctor',
      builder: (context) => _DoctorForm(
        service: widget.service,
        hospitals: _hospitals,
        departments: _departments,
        existing: existing,
        initialHospitalId: _hospitalFilter,
        initialDepartmentId: _departmentFilter,
      ),
    );
    if (!mounted || !saved) return;
    showCatalogMessage(
      context,
      existing == null ? 'Doctor added.' : 'Doctor updated.',
    );
    await _load();
  }

  Future<void> _delete(AdminDoctor doctor) async {
    final confirmed = await confirmDelete(
      context,
      what: 'doctor',
      detail:
          '${doctor.name} will be removed. Deactivate instead to keep the '
          'record while taking them off the booking list.',
    );
    if (!mounted || !confirmed) return;
    setState(() => _busyId = doctor.id);
    try {
      await widget.service.deleteDoctor(doctor.id);
      if (!mounted) return;
      showCatalogMessage(context, 'Doctor deleted.');
      await _load();
    } catch (error) {
      // The server's refusal names what still points at the row; show it as-is.
      if (!mounted) return;
      showCatalogMessage(context, _readable(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Saves the doctor back unchanged apart from the flipped flag — the PATCH
  /// body is a whole record, so every field has to be sent again.
  Future<void> _toggleActive(AdminDoctor doctor) async {
    setState(() => _busyId = doctor.id);
    try {
      await widget.service.saveDoctor(
        id: doctor.id,
        name: doctor.name,
        specialization: doctor.specialization,
        hospitalId: doctor.hospital.id,
        departmentId: doctor.department.id,
        qualifications: doctor.qualifications,
        about: doctor.about,
        experienceYears: doctor.experienceYears,
        consultationFee: doctor.consultationFee,
        slotMinutes: doctor.slotMinutes,
        active: !doctor.active,
        availability: doctor.availability,
      );
      if (!mounted) return;
      showCatalogMessage(
        context,
        doctor.active
            ? '${doctor.name} is no longer bookable.'
            : '${doctor.name} is bookable again.',
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCatalogMessage(context, _readable(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _hospitalFilter = null;
      _departmentFilter = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _content(context),
  );

  List<Widget> _content(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!_loadedOnce) return const [LoadingView(padding: 32)];
    // Nothing loaded at all: the error is the whole screen.
    if (_error != null && _hospitals.isEmpty && _doctors.isEmpty) {
      return [ErrorView(message: _error!, onRetry: _load)];
    }
    final filtered =
        _hospitalFilter != null ||
        _departmentFilter != null ||
        _search.text.trim().isNotEmpty;
    return [
      CatalogHeader(title: 'Doctors', count: _doctors.length, onAdd: _openForm),
      const SizedBox(height: 6),
      Text(
        'Hours set here are the slots patients can book.',
        style: text.bodyMedium?.copyWith(fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      _searchField(),
      const SizedBox(height: 12),
      _hospitalFilterField(),
      const SizedBox(height: 12),
      _departmentFilterField(),
      if (filtered)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _loading ? null : _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Clear filters'),
          ),
        )
      else
        const SizedBox(height: 16),
      if (_error != null) ...[
        ErrorView(message: _error!, onRetry: _load),
        const SizedBox(height: 16),
      ],
      if (_loading)
        const LoadingView(padding: 24)
      else if (_doctors.isEmpty)
        EmptyView(
          icon: Icons.person_search_outlined,
          message: filtered
              ? 'No doctors match these filters.'
              : 'No doctors yet. Add the first one.',
        )
      else
        // Shrink-wrapped and unscrollable: the dashboard owns the scrolling.
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _doctors.length,
          itemBuilder: (context, index) => _row(_doctors[index]),
        ),
    ];
  }

  Widget _searchField() => TextField(
    controller: _search,
    onChanged: _onSearchChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      labelText: 'Search',
      hintText: 'Name or specialization',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                _search.clear();
                _onSearchChanged('');
              },
            ),
    ),
  );

  Widget _hospitalFilterField() => DropdownButtonFormField<String?>(
    initialValue: _hospitalFilter,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Hospital',
      prefixIcon: Icon(Icons.local_hospital_outlined),
    ),
    items: [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('All hospitals'),
      ),
      for (final hospital in _hospitals)
        DropdownMenuItem<String?>(
          value: hospital.id,
          child: Text(hospital.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _loading
        ? null
        : (value) {
            setState(() {
              _hospitalFilter = value;
              // The chosen department may not belong to the new hospital.
              if (!_departmentsFor(
                value,
              ).any((department) => department.id == _departmentFilter)) {
                _departmentFilter = null;
              }
            });
            _load();
          },
  );

  Widget _departmentFilterField() {
    final options = _departmentsFor(_hospitalFilter);
    return DropdownButtonFormField<String?>(
      initialValue: _departmentFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Department',
        prefixIcon: Icon(Icons.account_tree_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All departments'),
        ),
        for (final department in options)
          DropdownMenuItem<String?>(
            value: department.id,
            child: Text(
              _hospitalFilter == null
                  ? '${department.name} · ${department.hospital.name}'
                  : department.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _departmentFilter = value);
              _load();
            },
    );
  }

  Widget _row(AdminDoctor doctor) {
    final text = Theme.of(context).textTheme;
    final busy = _busyId == doctor.id;
    final years = doctor.experienceYears;
    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row: a long name plus the badge overflows on a
                    // phone, and the app's slab font is wide.
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(doctor.name, style: text.titleMedium),
                        if (!doctor.active)
                          const _Pill(label: 'Inactive', color: _inactive),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialization,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doctor.hospital.label} · ${doctor.department.name}',
                      style: text.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              CatalogRowActions(
                onEdit: () => _openForm(doctor),
                onDelete: () => _delete(doctor),
                busy: busy,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.payments_outlined,
                label: 'Rs. ${doctor.consultationFee}',
                color: AppTheme.teal,
              ),
              _Pill(
                icon: Icons.workspace_premium_outlined,
                label: years == 1 ? '1 year' : '$years years',
                color: AppTheme.navy,
              ),
              _Pill(
                icon: Icons.schedule_outlined,
                label: _availabilitySummary(doctor.availability),
                color: doctor.availability.isEmpty
                    ? AppTheme.textMuted
                    : AppTheme.sky,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : () => _toggleActive(doctor),
              style: TextButton.styleFrom(
                foregroundColor: doctor.active ? _inactive : AppTheme.teal,
              ),
              icon: Icon(
                doctor.active
                    ? Icons.toggle_off_outlined
                    : Icons.toggle_on_outlined,
                size: 20,
              ),
              label: Text(doctor.active ? 'Deactivate' : 'Activate'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Mon, Wed, Fri", or a plain statement when there is nothing to book.
String _availabilitySummary(List<AdminAvailability> availability) {
  if (availability.isEmpty) return 'No hours set';
  final days = availability.map((slot) => slot.dayOfWeek % 7).toSet().toList()
    ..sort();
  return days
      .map((day) => AdminAvailability.dayNames[day].substring(0, 3))
      .join(', ');
}

/// Add/edit sheet. Saves itself and pops true, so the tab only has to reload.
class _DoctorForm extends StatefulWidget {
  const _DoctorForm({
    required this.service,
    required this.hospitals,
    required this.departments,
    required this.existing,
    this.initialHospitalId,
    this.initialDepartmentId,
  });

  final AdminCatalogService service;
  final List<AdminHospital> hospitals;
  final List<AdminDepartment> departments;
  final AdminDoctor? existing;
  final String? initialHospitalId;
  final String? initialDepartmentId;

  @override
  State<_DoctorForm> createState() => _DoctorFormState();
}

class _DoctorFormState extends State<_DoctorForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _specialization;
  late final TextEditingController _qualifications;
  late final TextEditingController _about;
  late final TextEditingController _experience;
  late final TextEditingController _fee;
  late final TextEditingController _slot;

  String? _hospitalId;
  String? _departmentId;
  bool _active = true;
  late final List<_Block> _blocks;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final doctor = widget.existing;
    _name = TextEditingController(text: doctor?.name ?? '');
    _specialization = TextEditingController(text: doctor?.specialization ?? '');
    _qualifications = TextEditingController(text: doctor?.qualifications ?? '');
    _about = TextEditingController(text: doctor?.about ?? '');
    _experience = TextEditingController(
      text: doctor == null ? '' : '${doctor.experienceYears}',
    );
    _fee = TextEditingController(
      text: doctor == null ? '' : '${doctor.consultationFee}',
    );
    _slot = TextEditingController(text: '${doctor?.slotMinutes ?? 30}');
    _active = doctor?.active ?? true;
    _hospitalId =
        doctor?.hospital.id ??
        (widget.hospitals.any(
              (hospital) => hospital.id == widget.initialHospitalId,
            )
            ? widget.initialHospitalId
            : null);
    final suggested = widget.initialDepartmentId;
    _departmentId =
        doctor?.department.id ??
        (_departmentOptions.any((department) => department.id == suggested)
            ? suggested
            : null);
    _blocks = [
      for (final slot in doctor?.availability ?? const <AdminAvailability>[])
        _Block(
          day: slot.dayOfWeek % 7,
          start: _parseTime(
            slot.startTime,
            const TimeOfDay(hour: 9, minute: 0),
          ),
          end: _parseTime(slot.endTime, const TimeOfDay(hour: 17, minute: 0)),
        ),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _specialization.dispose();
    _qualifications.dispose();
    _about.dispose();
    _experience.dispose();
    _fee.dispose();
    _slot.dispose();
    super.dispose();
  }

  /// Only the departments of the chosen hospital: the server rejects any other
  /// pairing outright.
  List<AdminDepartment> get _departmentOptions => _hospitalId == null
      ? const []
      : widget.departments
            .where((department) => department.hospital.id == _hospitalId)
            .toList();

  /// A selected value must always have an item of its own, or the dropdown
  /// throws. Editing a doctor whose hospital or department is missing from the
  /// listing gets a stand-in item carrying the stored name.
  List<DropdownMenuItem<String>> _items(
    Iterable<MapEntry<String, String>> options,
    String? selected,
    String fallbackLabel,
  ) {
    final items = [
      for (final option in options)
        DropdownMenuItem(
          value: option.key,
          child: Text(option.value, overflow: TextOverflow.ellipsis),
        ),
    ];
    if (selected != null && !items.any((item) => item.value == selected)) {
      items.insert(
        0,
        DropdownMenuItem(
          value: selected,
          child: Text(fallbackLabel, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return items;
  }

  void _addBlock() {
    setState(
      () => _blocks.add(
        _Block(
          day: DateTime.now().weekday % 7,
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 17, minute: 0),
        ),
      ),
    );
  }

  Future<void> _pickTime(_Block block, {required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? block.start : block.end,
      // The stored format is 24-hour, so the picker shows 24-hour too.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        block.start = picked;
      } else {
        block.end = picked;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final hospitalId = _hospitalId;
    final departmentId = _departmentId;
    if (hospitalId == null || departmentId == null) {
      setState(() => _error = 'Choose a hospital and a department.');
      return;
    }
    for (final block in _blocks) {
      if (block.endMinutes <= block.startMinutes) {
        setState(
          () => _error =
              '${AdminAvailability.dayNames[block.day]}: the end time must be '
              'after the start time.',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveDoctor(
        id: widget.existing?.id,
        name: _name.text.trim(),
        specialization: _specialization.text.trim(),
        hospitalId: hospitalId,
        departmentId: departmentId,
        qualifications: _qualifications.text.trim(),
        about: _about.text.trim(),
        experienceYears: _boundedInt(_experience.text, 0, 0, 70),
        consultationFee: _boundedInt(_fee.text, 0, 0, 100000000),
        slotMinutes: _boundedInt(_slot.text, 30, 5, 120),
        active: _active,
        availability: [
          for (final block in _blocks)
            AdminAvailability(
              dayOfWeek: block.day,
              startTime: _formatTime(block.start),
              endTime: _formatTime(block.end),
            ),
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      // A mismatched department or a validation refusal arrives worded by the
      // server; it is shown exactly as sent.
      if (!mounted) return;
      setState(() {
        _error = _readable(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final departments = _departmentOptions;
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.badge_outlined),
              counterText: '',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _specialization,
            enabled: !_saving,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Specialization',
              prefixIcon: Icon(Icons.medical_services_outlined),
              counterText: '',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a specialization' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _hospitalId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Hospital',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
            items: _items(
              widget.hospitals.map(
                (hospital) => MapEntry(
                  hospital.id,
                  hospital.city.isEmpty
                      ? hospital.name
                      : '${hospital.name} · ${hospital.city}',
                ),
              ),
              _hospitalId,
              widget.existing?.hospital.label ?? 'Current hospital',
            ),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _hospitalId = value;
                    // Departments belong to one hospital, so the old pick is
                    // almost certainly invalid now.
                    if (!_departmentOptions.any(
                      (department) => department.id == _departmentId,
                    )) {
                      _departmentId = null;
                    }
                  }),
            validator: (value) => value == null ? 'Choose a hospital' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Department',
              prefixIcon: const Icon(Icons.account_tree_outlined),
              helperText: _hospitalId == null
                  ? 'Choose a hospital first.'
                  : departments.isEmpty
                  ? 'This hospital has no departments yet.'
                  : null,
              helperMaxLines: 2,
            ),
            items: _items(
              departments.map(
                (department) => MapEntry(department.id, department.name),
              ),
              _departmentId,
              widget.existing?.department.name ?? 'Current department',
            ),
            onChanged: _saving || _hospitalId == null
                ? null
                : (value) => setState(() => _departmentId = value),
            validator: (value) => value == null ? 'Choose a department' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _qualifications,
            enabled: !_saving,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Qualifications',
              hintText: 'MBBS, MD',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _about,
            enabled: !_saving,
            maxLength: 600,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'About',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  controller: _experience,
                  label: 'Experience',
                  suffix: 'yrs',
                  min: 0,
                  max: 70,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: _fee,
                  label: 'Fee',
                  suffix: 'Rs.',
                  min: 0,
                  max: 100000000,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _numberField(
            controller: _slot,
            label: 'Slot length',
            suffix: 'min',
            min: 5,
            max: 120,
            helper: 'How long one appointment runs. 5–120, default 30.',
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            value: _active,
            onChanged: _saving
                ? null
                : (value) => setState(() => _active = value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.teal,
            title: Text('Bookable', style: text.titleMedium),
            subtitle: Text(
              _active
                  ? 'Patients can book this doctor.'
                  : 'Hidden from the booking flow.',
              style: text.bodyMedium?.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          _availabilityEditor(text),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save doctor'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required int min,
    required int max,
    String? helper,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helper,
      helperMaxLines: 2,
    ),
    // Empty is allowed and falls back to the default; anything typed has to
    // land in range, so the server never sees a number it would refuse.
    validator: (value) {
      final raw = (value ?? '').trim();
      if (raw.isEmpty) return null;
      final parsed = int.tryParse(raw);
      if (parsed == null) return 'Numbers only';
      if (parsed < min || parsed > max) return 'Between $min and $max';
      return null;
    },
  );

  Widget _availabilityEditor(TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text('Weekly hours', style: text.titleMedium)),
          TextButton.icon(
            onPressed: _saving ? null : _addBlock,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add block'),
          ),
        ],
      ),
      if (_blocks.isEmpty)
        Text(
          'No hours set. Patients cannot book until one block exists.',
          style: text.bodyMedium?.copyWith(fontSize: 12),
        ),
      for (var index = 0; index < _blocks.length; index++)
        _blockRow(index, _blocks[index]),
    ],
  );

  /// Plain container, not a [GlassSurface]: the sheet around it is already one.
  Widget _blockRow(int index, _Block block) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.glassBorder),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: block.day,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: [
                  for (var day = 0; day < 7; day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(
                        AdminAvailability.dayNames[day],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => block.day = value ?? block.day),
              ),
            ),
            IconButton(
              tooltip: 'Remove block',
              onPressed: _saving
                  ? null
                  : () => setState(() => _blocks.removeAt(index)),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeButton(
                'From',
                block.start,
                () => _pickTime(block, start: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _timeButton(
                'To',
                block.end,
                () => _pickTime(block, start: false),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _timeButton(String label, TimeOfDay value, VoidCallback onPressed) =>
      OutlinedButton(
        onPressed: _saving ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label ${_formatTime(value)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// One weekly block while it is being edited — mutable, unlike the model.
class _Block {
  _Block({required this.day, required this.start, required this.end});

  int day;
  TimeOfDay start;
  TimeOfDay end;

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;
}

/// Formatted by hand rather than through [TimeOfDay.format]: the server wants
/// "HH:MM" in 24 hours, and a localized format would send "9:00 AM".
String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String raw, TimeOfDay fallback) {
  final parts = raw.split(':');
  if (parts.length < 2) return fallback;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return fallback;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Empty input is not an error: it means "use the default".
int _boundedInt(String raw, int fallback, int min, int max) {
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) return fallback;
  if (parsed < min) return min;
  if (parsed > max) return max;
  return parsed;
}

/// The soft-deleted look: apart from the theme's error red, which is reserved
/// for destructive actions.
const _inactive = Color(0xFF9A7B4F);

/// Small tinted capsule. Not a [GlassSurface]: these sit inside one.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// `ApiException.toString()` is already the server's own wording; this only
/// drops the `Exception: ` prefix a plain thrown Exception would add.
String _readable(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
