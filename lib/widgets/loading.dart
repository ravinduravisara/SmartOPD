import 'package:flutter/material.dart';

import 'glass.dart';

/// Spinner sitting in a small frosted pill, so waiting looks like the rest of
/// the app rather than a bare Material indicator.
///
/// Single-layer: screens place this inside their own content, so it must not
/// nest a [GlassSurface] inside another one.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = 40});

  /// Breathing room around the pill.
  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: const Center(
      child: GlassSurface(
        padding: EdgeInsets.all(16),
        radius: 999,
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    ),
  );
}
