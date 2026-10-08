import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/glass.dart';
import '../auth/providers/auth_provider.dart';
import 'data/audit_service.dart';

class AuditActivityScreen extends StatefulWidget {
  const AuditActivityScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<AuditActivityScreen> createState() => _AuditActivityScreenState();
}

class _AuditActivityScreenState extends State<AuditActivityScreen> {
  late final AuditService _service = AuditService(widget.auth.service.api);
  final _search = TextEditingController();
  Timer? _debounce;
  AuditPage? _page;
  String? _error;
  bool _loading = true;

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

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.list(
        query: _search.text,
        page: page,
      );
      if (mounted) setState(() => _page = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Audit & Activity', style: Theme.of(context).textTheme.headlineSmall),
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const Text(
        'Protected administrator activity records and notifications.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      _summary(),
      const SizedBox(height: 14),
      GlassSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _load);
              },
              decoration: const InputDecoration(
                hintText: 'Search module or activity',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        GlassSurface(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        )
      else if (_page?.logs.isEmpty ?? true)
        const GlassSurface(
          child: Center(
            child: Text(
              'No administrator activity recorded yet.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        )
      else ...[
        Text(
          '${_page!.total} recorded actions',
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ..._page!.logs.map(_entry),
        if (_page!.pages > 1) _pagination(),
      ],
    ],
  );

  Widget _summary() {
    final total = _page?.total ?? 0;
    return Row(
      children: [
        Expanded(child: _summaryCard('Total actions', '$total', Icons.receipt_long_outlined, AppTheme.teal)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Protected', 'Admin only', Icons.lock_outline_rounded, AppTheme.navy)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) =>
      GlassSurface(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _entry(AuditEntry entry) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GlassSurface(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!entry.seen)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 13, right: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF438AF0),
                shape: BoxShape.circle,
              ),
            ),
          CircleAvatar(
            radius: 17,
            backgroundColor: _actionColor(entry.action).withValues(alpha: 0.14),
            child: Icon(_actionIcon(entry.action), size: 17, color: _actionColor(entry.action)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  '${entry.actorName} · ${entry.module} · ${_date(entry.createdAt)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Activity actions',
            padding: EdgeInsets.zero,
            onSelected: (value) => _entryAction(value, entry),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'seen',
                child: Text(entry.seen ? 'Seen' : 'Mark as seen'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete record'),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
          ),
        ],
      ),
    ),
  );

  Future<void> _entryAction(String action, AuditEntry entry) async {
    if (action == 'seen') {
      if (!entry.seen) {
        await _service.markSeen(entry.id);
        _load(page: _page?.page ?? 1);
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity record?'),
        content: const Text('This removes the selected audit message from the activity list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.delete(entry.id);
      _load(page: _page?.page ?? 1);
    }
  }

  Widget _pagination() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: _page!.page > 1 ? () => _load(page: _page!.page - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text('${_page!.page} / ${_page!.pages}'),
      IconButton(
        onPressed: _page!.page < _page!.pages ? () => _load(page: _page!.page + 1) : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );

  Color _actionColor(String action) => switch (action) {
    'CREATE' => const Color(0xFF10AD7C),
    'DELETE' => const Color(0xFFEF6D83),
    _ => AppTheme.teal,
  };

  IconData _actionIcon(String action) => switch (action) {
    'CREATE' => Icons.add_circle_outline_rounded,
    'DELETE' => Icons.delete_outline_rounded,
    _ => Icons.edit_note_rounded,
  };

  String _date(DateTime? value) {
    if (value == null) return 'Unknown time';
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
