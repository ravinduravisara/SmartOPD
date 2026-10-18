import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/glass.dart';
import '../auth/providers/auth_provider.dart';
import 'catalog/departments_tab.dart';
import 'catalog/doctors_tab.dart';
import 'catalog/hospitals_tab.dart';
import 'data/catalog_service.dart';
import 'data/dashboard_service.dart';
import 'audit_activity_screen.dart';
import 'user_management_screen.dart';
import '../../services/queue_service.dart';
import 'queue_calling_console_screen.dart';

class _ManagementAction {
  const _ManagementAction(this.title, this.subtitle, this.icon, this.onTap);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart({required this.points});
  final List<DashboardPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No appointments scheduled today',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      );
    }
    final max = points.map((point) => point.count).fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Semantics(
      label: 'Hourly appointment volume for today',
      child: CustomPaint(
        painter: _BarChartPainter(points: points, maxValue: max),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.points, required this.maxValue});
  final List<DashboardPoint> points;
  final int maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 24;
    final slotWidth = size.width / points.length;
    final barWidth = (slotWidth * 0.42).clamp(14.0, 32.0);
    final max = maxValue == 0 ? 1 : maxValue;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final height = chartHeight * point.count / max;
      final x = slotWidth * index + (slotWidth - barWidth) / 2;
      final y = chartHeight - height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, height),
        const Radius.circular(8),
      );
      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.teal, AppTheme.mint],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
      textPainter.text = TextSpan(
        text: '${point.hour}:00',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.maxValue != maxValue;
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DonutChartPainter(values: values, colors: colors),
    child: const SizedBox.expand(),
  );
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 8;
    final stroke = radius * 0.28;
    final bounds = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    if (total == 0) {
      canvas.drawArc(
        bounds,
        0,
        2 * 3.141592653589793,
        false,
        Paint()
          ..color = AppTheme.glassBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      return;
    }
    var start = -3.141592653589793 / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = 2 * 3.141592653589793 * values[index] / total;
      canvas.drawArc(
        bounds,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  /// The catalog the booking flow reads: cities, hospitals, departments and
  /// doctors. It shares the signed-in admin's client, so it carries the token.
  late final AdminCatalogService _catalog = AdminCatalogService(
    widget.auth.service.api,
  );
  late final AdminDashboardService _dashboard = AdminDashboardService(
    widget.auth.service.api,
  );
  late final QueueService _queueService = QueueService(
    widget.auth.service.api,
  );
  late Future<AdminDashboardMetrics> _metrics;

  void _openQueueCallingConsole() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QueueCallingConsoleScreen(
          queueService: _queueService,
          catalogService: _catalog,
        ),
      ),
    );
  }

  /// Status hues that have to stay apart from each other and from the teal.
  static const _flow = Color(0xFF438AF0);
  static const _good = Color(0xFF10AD7C);
  static const _bad = Color(0xFFEF6D83);


  @override
  void initState() {
    super.initState();
    _metrics = _dashboard.metrics();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.user?.role != 'admin') {
      return const GlassScaffold(
        appBar: false,
        body: Center(child: Text('Administrator access required')),
      );
    }
    return GlassScaffold(
      titleWidget: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SmartOPD Portal',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Hospital administration',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.campaign_rounded, color: AppTheme.teal),
          tooltip: 'Doctor Calling Console',
          onPressed: _openQueueCallingConsole,
        ),
        PopupMenuButton<String>(
          tooltip: 'Administrator account',
          onSelected: (value) {
            if (value == 'logout') {
              widget.auth.logout();
            } else {
              setState(() => _tab = 4);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'admins',
              child: Text('Manage administrators'),
            ),
            PopupMenuItem(
              value: 'logout',
              enabled: !widget.auth.loading,
              child: const Text('Log out'),
            ),
          ],
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.teal, AppTheme.navy],
              ),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottomNavigationBar: _navigation(),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          18,
          18 + glassTopInset(context),
          18,
          110,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _tabBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Catalog tabs opened at least once. They stay in the tree behind an
  /// [Offstage] so returning to one shows the rows it already loaded, instead
  /// of tearing the state down and refetching behind a spinner every time.
  final _opened = <int>{};

  List<Widget> _tabBody() => [
    if (_tab == 0)
      FutureBuilder<AdminDashboardMetrics>(
        future: _metrics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _dashboardError(snapshot.error);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _overview(snapshot.data!),
          );
        },
      ),
    if (_tab == 4) ...[
      UserManagementScreen(auth: widget.auth),
    ],
    if (_tab == 5) ...[
      AuditActivityScreen(auth: widget.auth),
    ],
    if (_opened.contains(1))
      Offstage(
        offstage: _tab != 1,
        child: HospitalsAdminTab(service: _catalog),
      ),
    if (_opened.contains(2))
      Offstage(
        offstage: _tab != 2,
        child: DepartmentsAdminTab(service: _catalog),
      ),
    if (_opened.contains(3))
      Offstage(
        offstage: _tab != 3,
        child: DoctorsAdminTab(service: _catalog),
      ),
  ];

  /// Translucent bottom bar. It deliberately does NOT blur: this screen
  /// already blurs its app bar, and content scrolling under two blurred bars
  /// re-ran both full-width blurs every frame, which is what made the admin
  /// screens heavier than the rest of the app.
  Widget _navigation() => ClipRect(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          // Opaque enough to read against scrolling content now that the
          // bar no longer frosts what passes behind it.
          backgroundColor: const Color(0xF0FFFFFF),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppTheme.teal.withValues(alpha: 0.16),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AppTheme.teal
                  : AppTheme.textMuted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppTheme.teal
                  : AppTheme.textMuted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: widget.auth.loading
              ? null
              : (index) => setState(() {
                  _tab = index;
                  if (index > 0 && index < 4) _opened.add(index);
                }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              label: 'Hospitals',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: 'Depts',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Doctors',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'More',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              label: 'Audit',
            ),
          ],
        ),
      ),
    ),
  );

  /// Tinted square holding an icon — the pattern every status colour uses.
  Widget _iconChip(IconData icon, Color color, {double size = 38}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(size / 2.8),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );

  Widget _dashboardError(Object? error) => GlassSurface(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, color: _bad, size: 34),
        const SizedBox(height: 10),
        const Text(
          'Dashboard data could not be loaded',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          error.toString().replaceFirst('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => setState(() => _metrics = _dashboard.metrics()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  List<Widget> _overview(AdminDashboardMetrics metrics) => [
    GlassHeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 17 ? 'afternoon' : 'evening'}, Administrator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'General operations at a glance',
            style: TextStyle(color: Color(0xCCD9F2EE), fontSize: 12.5),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    _systemStatus(metrics),
    const SizedBox(height: 18),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleMedium),
        Text(
          'Today',
          style: const TextStyle(
            color: AppTheme.teal,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    const SizedBox(height: 18),
    const Text(
      'LIVE OPERATIONS OVERVIEW',
      style: TextStyle(
        fontSize: 10,
        color: AppTheme.textMuted,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: _metric(
            '${metrics.total('appointmentsToday')}',
            'Appointments today',
            _flow,
            Icons.groups_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            '${metrics.total('waiting')}',
            'Waiting',
            AppTheme.navy,
            Icons.hourglass_bottom_rounded,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _metric(
            '${metrics.total('completed')}',
            'Completed',
            _good,
            Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            '${metrics.total('noShows')}',
            'No-shows',
            _bad,
            Icons.event_busy_outlined,
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 18,
      tint: AppTheme.teal,
      borderColor: AppTheme.teal.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: AppTheme.teal, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Token Calling Console',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                ),
                SizedBox(height: 2),
                Text(
                  'Call next token, skip & complete consultations',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _openQueueCallingConsole,
            child: const Text('Open Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    Text('Management', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 10),
    _managementGrid(metrics),
    const SizedBox(height: 16),
    _recentActivity(metrics),
    const SizedBox(height: 16),
    Text('Analytics', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 10),
    GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Flow Today',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Scheduled appointments by hour',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 175,
            child: _HourlyBarChart(points: metrics.hourlyAppointments),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _chartCard(
            title: 'User distribution',
            subtitle: '${metrics.total('patients') + metrics.total('doctors') + metrics.total('administrators')} registered accounts',
            chart: _DonutChart(
              values: [
                metrics.usersByRole['patient'] ?? 0,
                metrics.usersByRole['doctor'] ?? 0,
                metrics.usersByRole['admin'] ?? 0,
              ],
              colors: const [_flow, _good, _bad],
            ),
            legend: _legend([
              ('Patients', metrics.usersByRole['patient'] ?? 0, _flow),
              ('Doctors', metrics.usersByRole['doctor'] ?? 0, _good),
              ('Admins', metrics.usersByRole['admin'] ?? 0, _bad),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _chartCard(
            title: 'Today’s appointments',
            subtitle: '${metrics.total('appointmentsToday')} scheduled today',
            chart: _DonutChart(
              values: [
                metrics.appointmentsByStatus['booked'] ?? 0,
                metrics.appointmentsByStatus['completed'] ?? 0,
                metrics.appointmentsByStatus['cancelled'] ?? 0,
              ],
              colors: const [_flow, _good, _bad],
            ),
            legend: _legend([
              ('Booked', metrics.appointmentsByStatus['booked'] ?? 0, _flow),
              ('Completed', metrics.appointmentsByStatus['completed'] ?? 0, _good),
              ('Cancelled', metrics.appointmentsByStatus['cancelled'] ?? 0, _bad),
            ]),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _status(
            'Active queue',
            '${metrics.total('waiting')} patients waiting',
            _good,
          ),
          const Divider(height: 24, color: AppTheme.glassBorder, thickness: 1),
          _status(
            'Clinical network',
            '${metrics.total('doctors')} doctors · ${metrics.total('hospitals')} hospitals',
            AppTheme.navy,
          ),
          const Divider(height: 24, color: AppTheme.glassBorder, thickness: 1),
          _status(
            'Last updated',
            _updatedLabel(metrics.generatedAt),
            AppTheme.teal,
          ),
        ],
      ),
    ),
  ];

  Widget _systemStatus(AdminDashboardMetrics metrics) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.navy,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'SmartOPD system is running normally',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF5FE0B1),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );

  Widget _managementGrid(AdminDashboardMetrics metrics) {
    final actions = [
      _ManagementAction(
        'Hospitals',
        '${metrics.total('hospitals')} registered',
        Icons.local_hospital_outlined,
        () => setState(() => _tab = 1),
      ),
      _ManagementAction(
        'Users',
        '${metrics.total('patients')} patients',
        Icons.people_outline_rounded,
        () => setState(() => _tab = 4),
      ),
      _ManagementAction(
        'Schedules',
        '${metrics.total('doctors')} doctors',
        Icons.calendar_month_outlined,
        () => setState(() => _tab = 3),
      ),
      _ManagementAction(
        'Departments',
        '${metrics.total('departments')} departments',
        Icons.account_tree_outlined,
        () => setState(() => _tab = 2),
      ),
      _ManagementAction(
        'Reports',
        'View analytics below',
        Icons.bar_chart_rounded,
        () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live reports are shown below.')),
        ),
      ),
      _ManagementAction(
        'Queue Calling',
        'Live OPD Calling',
        Icons.campaign_rounded,
        _openQueueCallingConsole,
      ),
      _ManagementAction(
        'Administrators',
        '${metrics.total('administrators')} accounts',
        Icons.admin_panel_settings_outlined,
        () => setState(() => _tab = 4),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) => _managementCard(actions[index]),
    );
  }

  Widget _managementCard(_ManagementAction action) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: action.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconChip(action.icon, AppTheme.teal, size: 34),
            const SizedBox(height: 8),
            Text(
              action.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              action.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _recentActivity(AdminDashboardMetrics metrics) => GlassSurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent activity', style: Theme.of(context).textTheme.titleSmall),
            const Text(
              'Live',
              style: TextStyle(
                color: AppTheme.teal,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _activityRow(
          Icons.calendar_today_outlined,
          '${metrics.total('appointmentsToday')} appointments scheduled today',
        ),
        _activityRow(
          Icons.people_outline_rounded,
          '${metrics.total('waiting')} patients currently in the queue',
        ),
        _activityRow(
          Icons.medical_services_outlined,
          '${metrics.total('doctors')} active doctors in the catalog',
        ),
      ],
    ),
  );

  Widget _activityRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.mint.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: AppTheme.teal),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: AppTheme.navy),
          ),
        ),
      ],
    ),
  );

  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget chart,
    required Widget legend,
  }) => GlassSurface(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 10),
        SizedBox(height: 108, child: chart),
        const SizedBox(height: 8),
        legend,
      ],
    ),
  );

  Widget _legend(List<(String, int, Color)> entries) => Column(
    children: entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: entry.$3, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(entry.$1, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ),
                Text('${entry.$2}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        )
        .toList(),
  );

  String _updatedLabel(DateTime? value) {
    if (value == null) return 'Not available';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} today';
  }

  Widget _metric(String value, String label, Color color, IconData icon) =>
      GlassSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconChip(icon, color, size: 34),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _status(String label, String value, Color color) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );

}
