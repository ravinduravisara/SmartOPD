import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/appointment.dart';
import '../models/dependent.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  AuthService({ApiService? api, SharedPreferences? preferences})
    : _api = api ?? ApiService(),
      _preferences = preferences;

  final ApiService _api;
  SharedPreferences? _preferences;
  User? currentUser;
  Future<void>? _googleInitialization;

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
    } on ApiException catch (error) {
      // Only a rejected token means the session is really gone. A server that
      // is down or unreachable must not throw the login away.
      if (error.statusCode == 401 || error.statusCode == 403) await logout();
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _api.request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );
  }

  Future<User> verifyEmail(String email, String code) async {
    final data = await _api.request(
      'POST',
      '/auth/verify-email',
      body: {'email': email, 'code': code},
    );
    return _saveSession(data);
  }

  Future<void> resendVerification(String email) =>
      _api.request('POST', '/auth/resend-verification', body: {'email': email});

  Future<User> login({required String email, required String password}) async {
    final data = await _api.request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _saveSession(data);
  }

  /// Must be the OAuth client of type **Web application**, not the Android
  /// client. Google rejects an Android client here with error 28444
  /// ("Developer console is not set up correctly"). The backend verifies the
  /// ID token against this same value, so both must be kept in sync.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1007022956651-togo3c6g08jj7jqp1mn2hbdq99f374e3.apps.googleusercontent.com',
  );

  Future<void> _initializeGoogle() async {
    final pending = _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    );
    try {
      await pending;
    } catch (_) {
      // A failed initialization must not be cached, or every later attempt
      // would replay the same failure without retrying.
      _googleInitialization = null;
      rethrow;
    }
  }

  Future<User> signInWithGoogle() async {
    await _initializeGoogle();
    try {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Clearing the previously selected account is best effort.
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token. Check that '
          'GOOGLE_SERVER_CLIENT_ID is the OAuth "Web application" client ID '
          'for this Google Cloud project.',
        );
      }
      final data = await _api.request(
        'POST',
        '/auth/google',
        body: {'idToken': idToken},
      );
      return _saveSession(data);
    } on GoogleSignInException catch (error) {
      throw Exception(_googleErrorMessage(error));
    }
  }

  String _googleErrorMessage(GoogleSignInException error) {
    // Android's Credential Manager reports configuration problems as a plain
    // cancellation, so a real cancel cannot be told apart from a bad setup.
    const setup =
        'Check that GOOGLE_SERVER_CLIENT_ID is the "Web application" OAuth '
        'client ID, and that an Android OAuth client exists for package '
        '"com.smartopd.smart_opd" with this build\'s signing SHA-1 in the '
        'same Google Cloud project.';
    // Play Services reports the OAuth setup failure as a bare 28444 with no
    // matching plugin code, so match on the message rather than the code.
    if (error.description?.contains('28444') ?? false) {
      return 'Google rejected the sign-in: the server client ID is not an '
          'OAuth "Web application" client. $setup';
    }
    if (error.description?.contains('28404') ?? false) {
      return 'Google could not issue an ID token: this app is not registered. '
          'Add an Android OAuth client for package "com.smartopd.smart_opd" '
          'with this build\'s signing SHA-1, in the same Google Cloud project '
          'as the web client.';
    }
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google sign-in did not complete. If you did not cancel it, the OAuth '
            'setup is wrong. $setup',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is misconfigured. $setup '
            '(${error.description ?? error.code.name})',
      _ =>
        'Google sign-in failed (${error.code.name}): '
            '${error.description ?? 'Please try again.'}',
    };
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

  Future<void> resetPassword(
    String email,
    String code,
    String password,
  ) async => _api.request(
    'POST',
    '/auth/reset-password',
    body: {'email': email, 'code': code, 'password': password},
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

  // --- Hospitals, departments and doctors ---

  Future<List<Hospital>> getHospitals({String? query, String? city}) async {
    final params = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (city != null && city.isNotEmpty) 'city': city,
    };
    final data = await _api.request('GET', '/hospitals${_query(params)}');
    return (data['hospitals'] as List)
        .map((item) => Hospital.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getHospitalCities() async =>
      ((await _api.request('GET', '/hospitals/cities'))['cities'] as List)
          .map((item) => item.toString())
          .toList();

  Future<HospitalDetails> getHospital(String id) async {
    final data = await _api.request('GET', '/hospitals/$id');
    return HospitalDetails(
      hospital: Hospital.fromJson(data['hospital'] as Map<String, dynamic>),
      departments: (data['departments'] as List)
          .map((item) => Department.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Doctor>> getDoctors({
    String? hospitalId,
    String? departmentId,
    String? query,
  }) async {
    final params = <String, String>{
      if (hospitalId != null) 'hospital': hospitalId,
      if (departmentId != null) 'department': departmentId,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final data = await _api.request('GET', '/doctors${_query(params)}');
    return (data['doctors'] as List)
        .map((item) => Doctor.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Doctor> getDoctor(String id) async => Doctor.fromJson(
    (await _api.request('GET', '/doctors/$id'))['doctor']
        as Map<String, dynamic>,
  );

  /// Bookable times for one day. [excludeAppointmentId] keeps an appointment's
  /// own slot in the list while it is being rescheduled.
  Future<List<DateTime>> getDoctorSlots(
    String doctorId,
    DateTime day, {
    String? excludeAppointmentId,
  }) async {
    final params = <String, String>{
      'date': _dayParam(day),
      if (excludeAppointmentId != null) 'exclude': excludeAppointmentId,
    };
    final data = await _api.request(
      'GET',
      '/doctors/$doctorId/slots${_query(params)}',
    );
    return (data['slots'] as List)
        .map((item) => DateTime.parse(item.toString()).toLocal())
        .toList();
  }

  // --- Appointments ---

  Future<List<Appointment>> getAppointments({String? scope}) async {
    final data = await _api.request(
      'GET',
      '/appointments${_query({if (scope != null) 'scope': scope})}',
    );
    return (data['appointments'] as List)
        .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Appointment> bookAppointment({
    required String doctorId,
    required DateTime scheduledAt,
    String? dependentId,
    String? reason,
  }) async => Appointment.fromJson(
    (await _api.request(
          'POST',
          '/appointments',
          body: {
            'doctor': doctorId,
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            if (dependentId != null) 'dependent': dependentId,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          },
        ))['appointment']
        as Map<String, dynamic>,
  );

  Future<Appointment> cancelAppointment(String id) async => Appointment.fromJson(
    (await _api.request('PATCH', '/appointments/$id/cancel'))['appointment']
        as Map<String, dynamic>,
  );

  Future<Appointment> rescheduleAppointment(
    String id,
    DateTime scheduledAt,
  ) async => Appointment.fromJson(
    (await _api.request(
          'PATCH',
          '/appointments/$id/reschedule',
          body: {'scheduledAt': scheduledAt.toUtc().toIso8601String()},
        ))['appointment']
        as Map<String, dynamic>,
  );

  static String _dayParam(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static String _query(Map<String, String> params) => params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

  Future<User> _saveSession(Map<String, dynamic> data) async {
    _api.token = data['token'] as String;
    await (await _prefs).setString('auth_token', _api.token!);
    currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
    return currentUser!;
  }
}
