import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_opd/widgets/glass.dart';

/// Content scrolls behind the translucent app bar, so the padding screens add
/// has to clear it. glassTopInset is read from the view rather than the
/// enclosing MediaQuery so that it returns the same number whether a screen
/// calls it above the Scaffold or from a widget inside the body.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    PreferredSizeWidget? bottom,
    required Widget Function(BuildContext context, double inset) body,
  }) async {
    // A phone with a status bar, so the app bar sits below it.
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 52);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) => GlassScaffold(
              title: 'Screen',
              bottom: bottom,
              body: body(context, glassTopInset(context)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double appBarBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(AppBar).first).dy;

  testWidgets('first card clears the app bar', (tester) async {
    await pumpScreen(
      tester,
      body: (context, inset) => ListView(
        padding: EdgeInsets.fromLTRB(20, inset, 20, 28),
        children: const [
          GlassSurface(key: Key('first'), child: Text('card')),
        ],
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('first'))).dy,
      greaterThanOrEqualTo(appBarBottom(tester)),
    );
  });

  testWidgets('inset is the same inside and outside the body', (tester) async {
    late double outside;
    late double inside;
    await pumpScreen(
      tester,
      body: (context, inset) {
        outside = inset;
        return Builder(
          builder: (inner) {
            inside = glassTopInset(inner);
            return const SizedBox.shrink();
          },
        );
      },
    );
    expect(inside, outside);
  });

  testWidgets('a tab strip needs its own height on top', (tester) async {
    await pumpScreen(
      tester,
      bottom: const TabBar(tabs: [Tab(text: 'A'), Tab(text: 'B')]),
      body: (context, inset) => ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16 + inset + kTextTabBarHeight,
          20,
          28,
        ),
        children: const [
          GlassSurface(key: Key('first'), child: Text('card')),
        ],
      ),
    );
    final gap =
        tester.getTopLeft(find.byKey(const Key('first'))).dy -
        appBarBottom(tester);
    expect(gap, greaterThanOrEqualTo(0));
    // A gap this big would read as an empty band under the tabs.
    expect(gap, lessThan(60));
  });
}
