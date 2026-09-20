import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/glass.dart';

/// Pieces every catalog tab shares, so the four entities are managed the same
/// way: same confirm step before a delete, same place errors appear, same
/// shape of form sheet.

/// Asks before deleting. The server refuses deletes that would orphan data, so
/// this is about intent, not safety.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  String? detail,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $what?'),
        content: Text(
          detail ?? 'This cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

/// Surfaces what the server said. Its messages explain refusals (a hospital
/// that still has doctors, a duplicate name), so they are shown verbatim.
void showCatalogMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.toString().replaceFirst('Exception: ', ''))),
  );
}

/// Opens a form as a glass sheet. Returns true when the form saved.
Future<bool> showCatalogForm(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context) builder,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          top: 12,
        ),
        child: GlassSurface(
          blur: 24,
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                builder(context),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;

/// Header above a list of catalog rows, with the action that adds one.
class CatalogHeader extends StatelessWidget {
  const CatalogHeader({
    super.key,
    required this.title,
    required this.count,
    required this.onAdd,
    this.addLabel = 'Add',
  });

  final String title;
  final int count;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          count == 0 ? title : '$title ($count)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(addLabel),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ],
  );
}

/// Edit and delete buttons for one row.
class CatalogRowActions extends StatelessWidget {
  const CatalogRowActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.busy = false,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) => busy
      ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Wrap(
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppTheme.navy,
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        );
}
