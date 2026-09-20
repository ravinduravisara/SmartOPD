import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/loading.dart';
import '../data/catalog_models.dart';
import '../data/catalog_service.dart';
import 'catalog_ui.dart';

/// Departments tab of the admin dashboard.
///
/// A department is what a patient picks before a doctor, so the list leads
/// with the hospital it belongs to and the number of doctors hanging off it —
/// the count is what decides whether a delete will be refused.
///
/// Lives inside the dashboard's own scroll view: a plain [Column], no
/// [Scaffold] and no scrollable of its own.
class DepartmentsAdminTab extends StatefulWidget {
  const DepartmentsAdminTab({required this.service, super.key});

  final AdminCatalogService service;

  @override
  State<DepartmentsAdminTab> createState() => _DepartmentsAdminTabState();
}

class _DepartmentsAdminTabState extends State<DepartmentsAdminTab> {
  List<AdminHospital> _hospitals = const [];
  List<AdminDepartment> _departments = const [];

  /// null is "All hospitals".
  String? _hospitalFilter;

  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  /// The row whose delete is in flight, so only its actions show a spinner.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hospitals = await widget.service.hospitals();
      // A filter pointing at a hospital that has since been deleted would
      // leave the dropdown holding a value none of its items carry, which
      // throws. Fall back to "All hospitals" instead.
      final filter = hospitals.any((hospital) => hospital.id == _hospitalFilter)
          ? _hospitalFilter
          : null;
      final departments = await widget.service.departments(hospitalId: filter);
      if (!mounted) return;
      setState(() {
        _hospitals = hospitals;
        _departments = departments;
        _hospitalFilter = filter;
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

  Future<void> _openForm([AdminDepartment? existing]) async {
    if (_hospitals.isEmpty) {
      showCatalogMessage(context, 'Add a hospital before adding departments.');
      return;
    }
    final saved = await showCatalogForm(
      context,
      title: existing == null ? 'New department' : 'Edit department',
      builder: (context) => _DepartmentForm(
        service: widget.service,
        hospitals: _hospitals,
        existing: existing,
        initialHospitalId: _hospitalFilter,
      ),
    );
    if (!mounted || !saved) return;
    showCatalogMessage(
      context,
      existing == null ? 'Department added.' : 'Department updated.',
    );
    await _load();
  }

  Future<void> _delete(AdminDepartment department) async {
    final confirmed = await confirmDelete(
      context,
      what: 'department',
      detail:
          '${department.name} at ${department.hospital.name} will be removed. '
          'The server refuses this while doctors are still attached.',
    );
    if (!mounted || !confirmed) return;
    setState(() => _busyId = department.id);
    try {
      await widget.service.deleteDepartment(department.id);
      if (!mounted) return;
      showCatalogMessage(context, 'Department deleted.');
      await _load();
    } catch (error) {
      // The server's refusal names what still points at the row; show it as-is.
      if (!mounted) return;
      showCatalogMessage(context, _readable(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
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
    if (_error != null && _hospitals.isEmpty && _departments.isEmpty) {
      return [ErrorView(message: _error!, onRetry: _load)];
    }
    return [
      CatalogHeader(
        title: 'Departments',
        count: _departments.length,
        onAdd: _openForm,
      ),
      const SizedBox(height: 6),
      Text(
        'Patients pick a department before a doctor.',
        style: text.bodyMedium?.copyWith(fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      _filterField(),
      const SizedBox(height: 16),
      if (_error != null) ...[
        ErrorView(message: _error!, onRetry: _load),
        const SizedBox(height: 16),
      ],
      if (_loading)
        const LoadingView(padding: 24)
      else if (_departments.isEmpty)
        EmptyView(
          icon: Icons.account_tree_outlined,
          message: _hospitalFilter == null
              ? 'No departments yet. Add the first one.'
              : 'This hospital has no departments yet.',
        )
      else
        // Shrink-wrapped and unscrollable: the dashboard owns the scrolling.
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _departments.length,
          itemBuilder: (context, index) => _row(_departments[index]),
        ),
    ];
  }

  Widget _filterField() => DropdownButtonFormField<String?>(
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
            setState(() => _hospitalFilter = value);
            _load();
          },
  );

  Widget _row(AdminDepartment department) {
    final text = Theme.of(context).textTheme;
    final description = department.description?.trim() ?? '';
    final doctors = department.doctorCount;
    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 6, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(department.name, style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  department.hospital.label,
                  style: text.bodyMedium?.copyWith(fontSize: 12.5),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: text.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                _Pill(
                  icon: Icons.people_outline,
                  label: doctors == 1 ? '1 doctor' : '$doctors doctors',
                  color: doctors == 0 ? AppTheme.textMuted : AppTheme.teal,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          CatalogRowActions(
            onEdit: () => _openForm(department),
            onDelete: () => _delete(department),
            busy: _busyId == department.id,
          ),
        ],
      ),
    );
  }
}

/// Add/edit sheet. Saves itself and pops true, so the tab only has to reload.
class _DepartmentForm extends StatefulWidget {
  const _DepartmentForm({
    required this.service,
    required this.hospitals,
    required this.existing,
    this.initialHospitalId,
  });

  final AdminCatalogService service;
  final List<AdminHospital> hospitals;
  final AdminDepartment? existing;
  final String? initialHospitalId;

  @override
  State<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends State<_DepartmentForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _hospitalId;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    final suggested = widget.initialHospitalId;
    _hospitalId =
        existing?.hospital.id ??
        (widget.hospitals.any((hospital) => hospital.id == suggested)
            ? suggested
            : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// The selected hospital must always have an item of its own, even if the
  /// listing no longer carries it — a dropdown value with no match throws.
  List<DropdownMenuItem<String>> get _hospitalItems {
    final items = [
      for (final hospital in widget.hospitals)
        DropdownMenuItem(
          value: hospital.id,
          child: Text(
            hospital.city.isEmpty
                ? hospital.name
                : '${hospital.name} · ${hospital.city}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    final selected = _hospitalId;
    if (selected != null &&
        !widget.hospitals.any((hospital) => hospital.id == selected)) {
      items.insert(
        0,
        DropdownMenuItem(
          value: selected,
          child: Text(
            widget.existing?.hospital.label ?? 'Current hospital',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    return items;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final hospitalId = _hospitalId;
    if (hospitalId == null) {
      setState(() => _error = 'Choose a hospital.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveDepartment(
        id: widget.existing?.id,
        hospitalId: hospitalId,
        name: _name.text.trim(),
        description: _description.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      // Duplicate names and other refusals arrive worded by the server.
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
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _hospitalId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Hospital',
              prefixIcon: const Icon(Icons.local_hospital_outlined),
              helperText: _editing
                  ? 'A department cannot be moved to another hospital.'
                  : null,
              helperMaxLines: 2,
            ),
            items: _hospitalItems,
            // Locked while editing: moving a department would strand its
            // doctors under the old hospital, and the server refuses it.
            onChanged: _editing || _saving
                ? null
                : (value) => setState(() => _hospitalId = value),
            validator: (value) => value == null ? 'Choose a hospital' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.account_tree_outlined),
              counterText: '',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a department name' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            maxLength: 400,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
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
            child: Text(_saving ? 'Saving…' : 'Save department'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Small tinted capsule for a count. Not a [GlassSurface]: these sit inside one.
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
