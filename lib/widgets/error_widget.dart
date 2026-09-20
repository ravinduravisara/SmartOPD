import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'glass.dart';

/// Failure notice: a pane of glass washed with the theme's error colour.
///
/// Single-layer on purpose — screens drop this straight into their content, so
/// it must never nest a [GlassSurface] inside another one.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return GlassSurface(
      tint: error,
      borderColor: error.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: error.withValues(alpha: 0.45)),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.navy),
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: error),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder for a list that loaded successfully but has nothing in it.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => GlassSurface(
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.mint.withValues(alpha: 0.55),
                AppTheme.teal.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.teal.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: AppTheme.teal, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
