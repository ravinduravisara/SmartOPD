import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// What the app shows while it restores the saved session.
///
/// It stays up for a moment even when the restore is instant, because a splash
/// that flashes for three frames reads as a glitch rather than a start-up.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.version = '1.0'});

  /// Shown under the wordmark. Kept in step with `version:` in pubspec.yaml.
  final String version;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backdropTop,
    body: Stack(
      children: [
        // Two soft quarter circles bleeding off opposite corners.
        const Positioned(top: -150, left: -110, child: _Corner(size: 330)),
        const Positioned(bottom: -170, right: -120, child: _Corner(size: 360)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const _LogoCard(),
                const SizedBox(height: 34),
                Text(
                  'Healthcare, simplified.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Appointments, live queues and hospital services\n'
                  'in one secure place.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(flex: 3),
                const SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Color(0x33007F73),
                      color: AppTheme.teal,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'SmartOPD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Version $version',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(32, 30, 32, 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: AppTheme.glassShadow,
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/hospital_management_system.png',
          width: 150,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            'SmartOPD',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'MANAGEMENT SYSTEM',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
  );
}

/// A circle placed so only its inner quarter shows at a screen corner.
class _Corner extends StatelessWidget {
  const _Corner({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.mint.withValues(alpha: 0.28),
      ),
    ),
  );
}
