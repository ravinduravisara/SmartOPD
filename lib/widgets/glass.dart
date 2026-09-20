import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The coloured gradient every glass surface is blurred against. Without
/// something textured behind it, frosted glass reads as flat grey.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.backdropTop, AppTheme.backdropBottom],
      ),
    ),
    child: Stack(
      children: [
        // Soft colour pools that give the blur something to pick up.
        const Positioned(
          top: -110,
          left: -70,
          child: _Glow(size: 300, color: AppTheme.mint, opacity: 0.55),
        ),
        const Positioned(
          top: 120,
          right: -110,
          child: _Glow(size: 280, color: AppTheme.sky, opacity: 0.3),
        ),
        const Positioned(
          bottom: -130,
          left: -60,
          child: _Glow(size: 320, color: AppTheme.teal, opacity: 0.18),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// A pane of glass: a translucent white gradient with a light-catching border
/// over the coloured backdrop.
///
/// [blur] frosts what shows through, but a real blur costs a full read-back of
/// everything behind it, and a list of them drags the frame rate down. So it
/// is off by default: pass a blur only for a large, long-lived surface (a bar,
/// a sheet, one hero panel), not for cards in a scrolling list.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = 22,
    this.blur = 0,
    this.onTap,
    this.tint,
    this.borderColor,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  /// Sigma of the backdrop blur. 0 (the default) skips the blur entirely,
  /// which also skips the clip and the extra layer it would need.
  final double blur;
  final VoidCallback? onTap;

  /// Colour washed over the glass, for surfaces that need to stand out.
  final Color? tint;
  final Color? borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);
    final base = tint ?? Colors.white;
    final fill = BoxDecoration(
      borderRadius: corners,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withValues(alpha: tint == null ? 0.66 : 0.40),
          base.withValues(alpha: tint == null ? 0.38 : 0.20),
        ],
      ),
      border: Border.all(color: borderColor ?? AppTheme.glassBorder),
      boxShadow: null, // TEMP-PERF: measure what the shadows cost
    );
    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: corners,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (blur <= 0) {
      // No blur: no clip and no saved layer either, just one painted box.
      return Padding(
        padding: margin,
        child: DecoratedBox(decoration: fill, child: content),
      );
    }
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: fill.boxShadow,
        ),
        child: ClipRRect(
          borderRadius: corners,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: fill.copyWith(boxShadow: const []),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark glass, for cards that should read as the loudest thing on screen.
class GlassHeroSurface extends StatelessWidget {
  const GlassHeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.radius = 26,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final corners = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.28),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: corners,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: corners,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF20F2A31), Color(0xE61B4750)],
                ),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: corners,
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scaffold with the gradient backdrop behind a blurred, translucent app bar.
/// Content scrolls under the bar, which is what sells the glass.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.appBar = true,
    this.leading,
    this.bottom,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool appBar;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => GlassBackdrop(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: appBar
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                kToolbarHeight + (bottom?.preferredSize.height ?? 0),
              ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: AppBar(
                    title: titleWidget ?? (title == null ? null : Text(title!)),
                    leading: leading,
                    actions: actions,
                    bottom: bottom,
                    backgroundColor: const Color(0x59FFFFFF),
                    shape: const Border(
                      bottom: BorderSide(color: Color(0x40FFFFFF)),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: appBar ? SafeArea(top: false, child: body) : SafeArea(child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    ),
  );
}

/// Padding that clears the translucent app bar content scrolls beneath.
///
/// Read from the view rather than the enclosing MediaQuery on purpose: inside
/// a Scaffold body that extends behind its app bar, MediaQuery reports the
/// whole bar as top padding, so the same call would return different numbers
/// depending on whether it ran above or below the Scaffold. The view always
/// reports the status bar alone.
///
/// Screens whose bar carries a tab strip add [kTextTabBarHeight] themselves.
double glassTopInset(BuildContext context) =>
    MediaQueryData.fromView(View.of(context)).padding.top + kToolbarHeight + 12;
