import 'package:flutter/material.dart';

import 'error_widget.dart';
import 'loading.dart';

/// Renders a future as loading / error / data, so every screen handles the
/// three states the same way.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LoadingView();
      }
      if (snapshot.hasError) {
        return ErrorView(message: '${snapshot.error}', onRetry: onRetry);
      }
      if (!snapshot.hasData) {
        return ErrorView(message: 'Nothing to show.', onRetry: onRetry);
      }
      return builder(context, snapshot.data as T);
    },
  );
}
