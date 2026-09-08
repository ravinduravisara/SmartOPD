import 'package:shared_preferences/shared_preferences.dart';

import '../models/dependent.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  AuthService({ApiService? api, SharedPreferences? preferences})
    : _api = api ?? ApiService(),
      _preferences = preferences;

  final ApiService _api;
  SharedPreferences? _preferences;
  User? currentUser;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> restoreSession() async {
    final prefs = await _prefs;
    _api.token = prefs.getString('auth_token');
    if (_api.token == null) return;
    try {
      currentUser = User.fromJson(
        (await _api.request('GET', '/auth/me'))['user'] as Map<String, dynamic>,
      );
    } catch (_) {
      await logout();
    }
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final data = await _api.request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );
    return _saveSession(data);
  }

  Future<User> login({required String email, required String password}) async {
    final data = await _api.request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _saveSession(data);
  }

  Future<void> logout() async {
    if (_api.token != null) {
      try {
        await _api.request('POST', '/auth/logout');
      } catch (_) {}
    }
    _api.token = null;
    currentUser = null;
    await (await _prefs).remove('auth_token');
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final user = User.fromJson(
      (await _api.request('PATCH', '/auth/me', body: updates))['user']
          as Map<String, dynamic>,
    );
    currentUser = user;
    return user;
  }

  Future<void> forgotPassword(String email) async =>
      _api.request('POST', '/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword(String token, String password) async =>
      _api.request(
        'POST',
        '/auth/reset-password/$token',
        body: {'password': password},
      );

  Future<List<Dependent>> getDependents() async =>
      ((await _api.request('GET', '/dependents'))['dependents'] as List)
          .map((item) => Dependent.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<Dependent> addDependent(Dependent dependent) async =>
      Dependent.fromJson(
        (await _api.request(
              'POST',
              '/dependents',
              body: dependent.toJson(),
            ))['dependent']
            as Map<String, dynamic>,
      );

  Future<Dependent> updateDependent(
    String id,
    Map<String, dynamic> updates,
  ) async => Dependent.fromJson(
    (await _api.request('PATCH', '/dependents/$id', body: updates))['dependent']
        as Map<String, dynamic>,
  );

  Future<void> removeDependent(String id) async =>
      _api.request('DELETE', '/dependents/$id');

  Future<Map<String, dynamic>> bookAppointment({
    required String doctorId,
    required DateTime scheduledAt,
    String? dependentId,
    String? reason,
  }) => _api.request(
    'POST',
    '/appointments',
    body: {
      'doctor': doctorId,
      'scheduledAt': scheduledAt.toIso8601String(),
      if (dependentId != null) 'dependent': dependentId,
      if (reason != null) 'reason': reason,
    },
  );

  Future<User> _saveSession(Map<String, dynamic> data) async {
    _api.token = data['token'] as String;
    await (await _prefs).setString('auth_token', _api.token!);
    currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
    return currentUser!;
  }
}
