import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/loading.dart';
import '../data/catalog_models.dart';
import '../data/catalog_service.dart';
import 'catalog_ui.dart';

/// Strips the `Exception: ` prefix `toString()` adds, so the server's own
/// wording is what the admin reads. [showCatalogMessage] does the same for
/// snack bars; this is for the places that render a message inline.
String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

/// Sentinel city option meaning "I want to type one that isn't registered
/// yet". A NUL byte keeps it apart from anything the server could return.
const _newCityOption = '\u0000new-city';

/// Cities and hospitals: the top of the catalog the patient booking flow
/// reads. A hospital's city has to be one the server knows, so the two are
/// managed together here — the city pills double as the filter for the list.
///
/// Lives inside the dashboard's scrolling column, so it is a plain
/// [Column] with no scaffold and no scroll view of its own.
class HospitalsAdminTab extends StatefulWidget {
  const HospitalsAdminTab({required this.service, super.key});

  final AdminCatalogService service;

  @override
  State<HospitalsAdminTab> createState() => _HospitalsAdminTabState();
}

class _HospitalsAdminTabState extends State<HospitalsAdminTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// Bumped on every load so a slow reply from an earlier search cannot
  /// overwrite the results of a later one.
  int _request = 0;

  List<AdminCity> _cities = const [];
  List<AdminHospital> _hospitals = const [];

  bool _loading = true;
  bool _filtering = false;
  String? _error;

  String _query = '';
  String? _cityFilter;

  /// Drives the clear button. Tracked separately from [_query], which only
  /// catches up when the debounce fires.
  bool _searchEmpty = true;

  /// Which row is mid-request, so only that row shows a spinner.
  String? _busyCity;
  String? _busyHospital;

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

  // --- Loading ---

  /// Full reload: both lists, so the per-city and per-hospital counts stay
  /// truthful after anything is created, renamed or deleted.
  ///
  /// [silent] keeps what is already on screen and shows the small inline
  /// spinner instead of replacing the whole section — a toggle should not make
  /// the list disappear and come back. A silent reload that fails says so in a
  /// snack bar rather than blanking a list that is still perfectly readable.
  Future<void> _load({bool silent = false}) async {
    final token = ++_request;
    setState(() {
      _loading = !silent;
      _filtering = silent;
      _error = null;
    });
    try {
      final cities = await widget.service.cities();
      if (!mounted || token != _request) return;
      // A city that was renamed or deleted must not keep filtering the list.
      final names = cities.map((city) => city.name).toSet();
      final filter = names.contains(_cityFilter) ? _cityFilter : null;
      final hospitals = await widget.service.hospitals(
        query: _query,
        city: filter,
      );
      if (!mounted || token != _request) return;
      setState(() {
        _cities = cities;
        _hospitals = hospitals;
        _cityFilter = filter;
      });
    } catch (error) {
      if (!mounted || token != _request) return;
      if (silent) {
        showCatalogMessage(context, error);
      } else {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && token == _request) {
        setState(() {
          _loading = false;
          _filtering = false;
        });
      }
    }
  }

  /// Re-runs just the hospital query. The list stays on screen while it runs —
  /// only the search field shows that something is in flight.
  Future<void> _loadHospitals() async {
    final token = ++_request;
    setState(() => _filtering = true);
    try {
      final hospitals = await widget.service.hospitals(
        query: _query,
        city: _cityFilter,
      );
      if (!mounted || token != _request) return;
      setState(() => _hospitals = hospitals);
    } catch (error) {
      if (!mounted || token != _request) return;
      showCatalogMessage(context, error);
    } finally {
      if (mounted && token == _request) setState(() => _filtering = false);
    }
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty != _searchEmpty) {
      setState(() => _searchEmpty = value.isEmpty);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _query) return;
      _query = next;
      _loadHospitals();
    });
  }

  void _setCityFilter(String? city) {
    if (city == _cityFilter) return;
    setState(() => _cityFilter = city);
    _loadHospitals();
  }

  // --- City actions ---

  Future<void> _addCity() async {
    final saved = await showCatalogForm(
      context,
      title: 'Add city',
      builder: (_) => _CityForm(service: widget.service),
    );
    if (!mounted || !saved) return;
    await _load(silent: true);
  }

  Future<void> _renameCity(AdminCity city) async {
    final saved = await showCatalogForm(
      context,
      title: 'Rename city',
      builder: (_) => _CityForm(service: widget.service, original: city.name),
    );
    if (!mounted || !saved) return;
    await _load(silent: true);
  }

  Future<void> _deleteCity(AdminCity city) async {
    final confirmed = await confirmDelete(
      context,
      what: 'city',
      detail: city.hospitalCount == 0
          ? '${city.name} will no longer be offered when adding a hospital.'
          : '${city.name} still has ${_plural(city.hospitalCount, 'hospital')}. '
                'The server will refuse while they exist.',
    );
    if (!mounted || !confirmed) return;

    setState(() => _busyCity = city.name);
    Object? failure;
    try {
      await widget.service.deleteCity(city.name);
    } catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() => _busyCity = null);
    // A refusal is shown in the server's own words, and the reload below puts
    // the city back on screen with its real count either way.
    if (failure != null) showCatalogMessage(context, failure);
    await _load(silent: true);
  }

  // --- Hospital actions ---

  Future<void> _editHospital([AdminHospital? hospital]) async {
    final saved = await showCatalogForm(
      context,
      title: hospital == null ? 'Add hospital' : 'Edit hospital',
      builder: (_) => _HospitalForm(
        service: widget.service,
        cities: _cities.map((city) => city.name).toList(),
        hospital: hospital,
      ),
    );
    if (!mounted || !saved) return;
    await _load(silent: true);
  }

  Future<void> _deleteHospital(AdminHospital hospital) async {
    final attached = hospital.departmentCount > 0 || hospital.doctorCount > 0;
    final confirmed = await confirmDelete(
      context,
      what: 'hospital',
      detail: attached
          ? '${hospital.name} still has '
                '${_plural(hospital.departmentCount, 'department')} and '
                '${_plural(hospital.doctorCount, 'doctor')}. '
                'The server will refuse while they exist.'
          : '${hospital.name} will be removed from the booking flow. '
                'This cannot be undone.',
    );
    if (!mounted || !confirmed) return;

    await _run(hospital.id, () => widget.service.deleteHospital(hospital.id));
  }

  /// Flips `active` by saving the row back unchanged apart from the flag.
  Future<void> _toggleActive(AdminHospital hospital) => _run(
    hospital.id,
    () => widget.service.saveHospital(
      id: hospital.id,
      name: hospital.name,
      city: hospital.city,
      address: hospital.address,
      phone: hospital.phone,
      about: hospital.about,
      active: !hospital.active,
    ),
  );

  /// Runs a mutation for one row, then reloads whether or not it worked, so
  /// the screen never keeps a state the server rejected.
  Future<void> _run(String id, Future<void> Function() action) async {
    setState(() => _busyHospital = id);
    Object? failure;
    try {
      await action();
    } catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() => _busyHospital = null);
    if (failure != null) showCatalogMessage(context, failure);
    await _load(silent: true);
  }

  static String _plural(int count, String noun) =>
      '$count $noun${count == 1 ? '' : 's'}';

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hospital catalog', style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Cities and hospitals patients can book at.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Reload',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              color: AppTheme.navy,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loading)
          const LoadingView(padding: 28)
        else if (_error != null)
          ErrorView(message: _error!, onRetry: _load)
        else ...[
          _citiesSection(),
          const SizedBox(height: 16),
          _hospitalsToolbar(),
          const SizedBox(height: 12),
          if (_hospitals.isEmpty)
            EmptyView(
              icon: Icons.local_hospital_outlined,
              message: _query.isEmpty && _cityFilter == null
                  ? 'No hospitals yet. Add one to open it for booking.'
                  : 'No hospitals match this search.',
            )
          else
            for (final hospital in _hospitals) _hospitalRow(hospital),
        ],
      ],
    );
  }

  // --- Cities ---

  Widget _citiesSection() => GlassSurface(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    radius: 24,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CatalogHeader(
          title: 'Cities',
          count: _cities.length,
          onAdd: _addCity,
          addLabel: 'Add',
        ),
        const SizedBox(height: 6),
        Text(
          _cities.isEmpty
              ? 'Add a city before adding a hospital — the server only accepts registered cities.'
              : 'Tap a city to filter the list, rename it or delete it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_cities.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final city in _cities) _cityPill(city)],
          ),
        ],
      ],
    ),
  );

  Widget _cityPill(AdminCity city) {
    final selected = _cityFilter == city.name;
    final busy = _busyCity == city.name;
    final accent = selected ? AppTheme.teal : AppTheme.navy;
    return PopupMenuButton<String>(
      tooltip: city.name,
      enabled: !busy,
      position: PopupMenuPosition.under,
      onSelected: (value) => switch (value) {
        'filter' => _setCityFilter(selected ? null : city.name),
        'rename' => _renameCity(city),
        _ => _deleteCity(city),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'filter',
          child: _menuRow(
            selected
                ? Icons.filter_alt_off_outlined
                : Icons.filter_alt_outlined,
            selected ? 'Show all cities' : 'Show only this city',
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: _menuRow(Icons.edit_outlined, 'Rename'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _menuRow(
            Icons.delete_outline_rounded,
            'Delete',
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.teal.withValues(alpha: 0.16)
                : const Color(0x73FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppTheme.teal.withValues(alpha: 0.5)
                  : AppTheme.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  city.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${city.hospitalCount}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              busy
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _menuRow(IconData icon, String label, {Color? color}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color ?? AppTheme.navy),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color ?? AppTheme.navy),
        ),
      ),
    ],
  );

  // --- Hospitals ---

  Widget _hospitalsToolbar() => GlassSurface(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    radius: 24,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CatalogHeader(
          title: 'Hospitals',
          count: _hospitals.length,
          onAdd: _editHospital,
          addLabel: 'Add',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search name or city',
            prefixIcon: const Icon(Icons.search_rounded),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            suffixIcon: _filtering
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            _query = '';
                            _searchEmpty = true;
                            _loadHospitals();
                          },
                        )),
          ),
        ),
        const SizedBox(height: 10),
        _cityFilterField(),
      ],
    ),
  );

  Widget _cityFilterField() => InputDecorator(
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.place_outlined),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: _cityFilter,
        isExpanded: true,
        borderRadius: BorderRadius.circular(18),
        icon: const Icon(Icons.expand_more_rounded),
        style: Theme.of(context).textTheme.labelLarge,
        onChanged: _setCityFilter,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All cities'),
          ),
          for (final city in _cities)
            DropdownMenuItem<String?>(
              value: city.name,
              child: Text(city.name, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    ),
  );

  Widget _hospitalRow(AdminHospital hospital) {
    final text = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    final busy = _busyHospital == hospital.id;
    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      radius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconChip(
                Icons.local_hospital_outlined,
                hospital.active ? AppTheme.teal : AppTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hospital.name, style: text.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      hospital.city.isEmpty ? 'No city' : hospital.city,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((hospital.phone ?? '').isNotEmpty ||
              (hospital.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            if ((hospital.address ?? '').isNotEmpty)
              _detailLine(Icons.location_on_outlined, hospital.address!),
            if ((hospital.phone ?? '').isNotEmpty)
              _detailLine(Icons.call_outlined, hospital.phone!),
          ],
          const SizedBox(height: 12),
          // One Wrap so the badges and the buttons drop onto their own lines
          // on a narrow screen instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge(
                    '${hospital.departmentCount} dept'
                    '${hospital.departmentCount == 1 ? '' : 's'}',
                    AppTheme.navy,
                  ),
                  _badge(
                    '${hospital.doctorCount} doctor'
                    '${hospital.doctorCount == 1 ? '' : 's'}',
                    AppTheme.sky,
                  ),
                  if (!hospital.active) _badge('Inactive', error),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!busy)
                    IconButton(
                      tooltip: hospital.active ? 'Set inactive' : 'Set active',
                      onPressed: () => _toggleActive(hospital),
                      icon: Icon(
                        hospital.active
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_outlined,
                        size: 24,
                      ),
                      color: hospital.active
                          ? AppTheme.teal
                          : AppTheme.textMuted,
                    ),
                  CatalogRowActions(
                    busy: busy,
                    onEdit: () => _editHospital(hospital),
                    onDelete: () => _deleteHospital(hospital),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    ),
  );

  static Widget _iconChip(IconData icon, Color color) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Icon(icon, color: color, size: 22),
  );

  static Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// --- Sheets ---

/// Add or rename a city. Saves itself and pops true so the tab reloads.
class _CityForm extends StatefulWidget {
  const _CityForm({required this.service, this.original});

  final AdminCatalogService service;

  /// The current name when renaming; null when adding.
  final String? original;

  @override
  State<_CityForm> createState() => _CityFormState();
}

class _CityFormState extends State<_CityForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.original ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final value = _name.text.trim();
    final original = widget.original;
    if (original == value) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (original == null) {
        await widget.service.createCity(value);
      } else {
        await widget.service.renameCity(original, value);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // Duplicates and validation failures are explained by the server.
      setState(() {
        _error = _message(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _name,
          enabled: !_saving,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'City name',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter a city name' : null,
          onFieldSubmitted: (_) => _saving ? null : _submit(),
        ),
        if (widget.original != null)
          Text(
            'Hospitals in this city move with it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _FormError(message: _error!),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(
            _saving
                ? 'Saving…'
                : (widget.original == null ? 'Add city' : 'Save name'),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// Add or edit a hospital. The city is picked from the registered list because
/// the server validates it, with an option to type a new one.
class _HospitalForm extends StatefulWidget {
  const _HospitalForm({
    required this.service,
    required this.cities,
    this.hospital,
  });

  final AdminCatalogService service;
  final List<String> cities;
  final AdminHospital? hospital;

  @override
  State<_HospitalForm> createState() => _HospitalFormState();
}

class _HospitalFormState extends State<_HospitalForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _about;
  final _newCity = TextEditingController();

  late List<String> _options;
  String? _city;
  String? _cityError;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hospital = widget.hospital;
    _name = TextEditingController(text: hospital?.name ?? '');
    _address = TextEditingController(text: hospital?.address ?? '');
    _phone = TextEditingController(text: hospital?.phone ?? '');
    _about = TextEditingController(text: hospital?.about ?? '');
    _active = hospital?.active ?? true;
    // A row whose city was dropped from the list still has to show its own.
    _options = <String>{
      ...widget.cities,
      if ((hospital?.city ?? '').isNotEmpty) hospital!.city,
    }.toList()..sort();
    _city = _options.contains(hospital?.city) ? hospital!.city : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _about.dispose();
    _newCity.dispose();
    super.dispose();
  }

  bool get _typingCity => _city == _newCityOption;

  String get _chosenCity =>
      _typingCity ? _newCity.text.trim() : (_city ?? '').trim();

  Future<void> _submit() async {
    final formOk = _form.currentState!.validate();
    final city = _chosenCity;
    setState(() => _cityError = city.isEmpty ? 'Choose a city' : null);
    if (!formOk || city.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The server only accepts registered cities, so a typed one is
      // registered first. If it already exists that call is what fails, not
      // the save below, so its result is not worth reporting.
      if (_typingCity && !widget.cities.contains(city)) {
        try {
          await widget.service.createCity(city);
        } catch (_) {}
      }
      await widget.service.saveHospital(
        id: widget.hospital?.id,
        name: _name.text.trim(),
        city: city,
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        about: _about.text.trim(),
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
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
          TextFormField(
            controller: _name,
            enabled: !_saving,
            autofocus: widget.hospital == null,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.local_hospital_outlined),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 4),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'City',
              errorText: _cityError,
              prefixIcon: const Icon(Icons.place_outlined),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
            isEmpty: _city == null,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _city,
                isExpanded: true,
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(Icons.expand_more_rounded),
                style: text.labelLarge,
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _city = value;
                        _cityError = null;
                      }),
                items: [
                  for (final city in _options)
                    DropdownMenuItem(
                      value: city,
                      child: Text(city, overflow: TextOverflow.ellipsis),
                    ),
                  const DropdownMenuItem(
                    value: _newCityOption,
                    child: Text('Type a new city…'),
                  ),
                ],
              ),
            ),
          ),
          if (_typingCity) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCity,
              enabled: !_saving,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'New city',
                helperText: 'It is registered when you save.',
                prefixIcon: Icon(Icons.add_location_alt_outlined),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a city name' : null,
              onChanged: (_) {
                if (_cityError != null) setState(() => _cityError = null);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            enabled: !_saving,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _phone,
            enabled: !_saving,
            maxLength: 32,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.call_outlined),
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _about,
            enabled: !_saving,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'About',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            value: _active,
            onChanged: _saving
                ? null
                : (value) => setState(() => _active = value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.teal,
            title: Text('Active', style: text.titleMedium),
            subtitle: Text(
              'Patients can book here while this is on.',
              style: text.bodyMedium,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _FormError(message: _error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving
                  ? 'Saving…'
                  : (widget.hospital == null ? 'Add hospital' : 'Save changes'),
            ),
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

/// What the server said about a save, verbatim, inside the sheet that tried
/// it. No [GlassSurface] here — the sheet already is one.
class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
          ),
        ],
      ),
    );
  }
}
