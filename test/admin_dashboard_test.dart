import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_opd/features/admin/admin_dashboard_screen.dart';
import 'package:smart_opd/features/auth/providers/auth_provider.dart';
import 'package:smart_opd/models/user.dart';
import 'package:smart_opd/services/api_service.dart';
import 'package:smart_opd/services/auth_service.dart';

class AdminTestApi extends ApiService {
  Map<String, dynamic>? created;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (method == 'POST') {
      created = body;
      return {};
    }
    return {
      'admins': [
        {
          'id': '1',
          'name': 'First Admin',
          'email': 'admin@example.com',
          'role': 'admin',
        },
      ],
    };
  }
}

void main() {
  testWidgets('admin creation validates confirmation and preserves session', (
    tester,
  ) async {
    final api = AdminTestApi();
    final service = AuthService(api: api);
    service.currentUser = const User(
      id: '1',
      name: 'First Admin',
      email: 'admin@example.com',
      role: 'admin',
    );
    final auth = AuthProvider(service: service);
    await tester.pumpWidget(
      MaterialApp(home: AdminDashboardScreen(auth: auth)),
    );
    await tester.pumpAndSettle();
    expect(find.text('SmartOPD Portal'), findsOneWidget);
    expect(find.text('Patient Flow Today'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('admin@example.com'), findsOneWidget);
    await tester.tap(find.text('Create new admin'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Second Admin');
    await tester.enterText(fields.at(1), 'second@example.com');
    await tester.enterText(fields.at(2), 'Strong-Pass123!');
    await tester.enterText(fields.at(3), 'wrong');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create admin'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(api.created, isNull);
    await tester.enterText(fields.at(3), 'Strong-Pass123!');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create admin'));
    await tester.pumpAndSettle();
    expect(api.created?['email'], 'second@example.com');
    expect(service.currentUser?.id, '1');
    expect(find.text('New administrator'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
