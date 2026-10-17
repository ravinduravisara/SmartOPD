import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_opd/models/user.dart';
import 'package:smart_opd/features/profile/edit_profile_screen.dart';
import 'package:smart_opd/services/auth_service.dart';
import 'package:smart_opd/services/api_service.dart';

class MockApi extends ApiService {
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    lastBody = body;
    return {
      'user': {
        'id': 'user-1',
        'name': body?['name'] ?? 'Test User',
        'email': 'test@example.com',
        'phone': body?['phone'] ?? '0712345678',
        'nic': body?['nic'] ?? '991234567V',
        'dateOfBirth': body?['dateOfBirth'] ?? '2000-01-01T00:00:00.000Z',
        'gender': body?['gender'] ?? 'male',
        'role': 'patient',
        'isEmailVerified': true,
      }
    };
  }
}

void main() {
  group('User Model NIC and Profile Completion Tests', () {
    test('User without NIC is not complete and reports 75%', () {
      final user = User(
        id: '1',
        name: 'Dasun',
        email: 'dasun@example.com',
        role: 'patient',
        phone: '0711422940',
        nic: null,
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'male',
      );

      expect(user.isProfileComplete, isFalse);
      expect(user.profileCompletionPercentage, equals(75));
      expect(user.missingProfileFields, contains('NIC number'));
    });

    test('User with NIC is 100% complete', () {
      final user = User(
        id: '1',
        name: 'Dasun',
        email: 'dasun@example.com',
        role: 'patient',
        phone: '0711422940',
        nic: '991234567V',
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'male',
      );

      expect(user.isProfileComplete, isTrue);
      expect(user.profileCompletionPercentage, equals(100));
      expect(user.missingProfileFields, isEmpty);
    });
  });

  group('EditProfileScreen NIC Input & Submission Tests', () {
    testWidgets('allows entering Old NIC and saves cleaned uppercase NIC', (tester) async {
      final mockApi = MockApi();
      final authService = AuthService(api: mockApi);
      final initialUser = User(
        id: 'user-1',
        name: 'Dasun',
        email: 'dasun@example.com',
        role: 'patient',
        phone: '0711422940',
        nic: null,
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'male',
      );
      authService.currentUser = initialUser;

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            service: authService,
            user: initialUser,
            initialFocusNic: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find NIC field
      final nicField = find.widgetWithText(TextField, 'NIC number');
      expect(nicField, findsOneWidget);

      // Enter Old NIC with lowercase and hyphen: "991234567-v"
      await tester.enterText(nicField, '991234567-v');
      await tester.pumpAndSettle();

      // Tap Save changes
      final saveButton = find.text('Save changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify that NIC was sanitized and uppercase: '991234567V'
      expect(mockApi.lastBody?['nic'], equals('991234567V'));
      expect(authService.currentUser?.nic, equals('991234567V'));
      expect(authService.currentUser?.isProfileComplete, isTrue);
    });

    testWidgets('allows entering 12-digit New NIC with spaces', (tester) async {
      final mockApi = MockApi();
      final authService = AuthService(api: mockApi);
      final initialUser = User(
        id: 'user-1',
        name: 'Dasun',
        email: 'dasun@example.com',
        role: 'patient',
        phone: '0711422940',
        nic: null,
        dateOfBirth: DateTime(2000, 1, 1),
        gender: 'male',
      );
      authService.currentUser = initialUser;

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            service: authService,
            user: initialUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nicField = find.widgetWithText(TextField, 'NIC number');
      await tester.enterText(nicField, '2000 1234 5678');
      await tester.pumpAndSettle();

      final saveButton = find.text('Save changes');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(mockApi.lastBody?['nic'], equals('200012345678'));
    });
  });
}

