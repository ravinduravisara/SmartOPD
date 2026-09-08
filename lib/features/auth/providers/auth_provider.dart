import 'package:flutter/foundation.dart';

import '../../../models/user.dart';
import '../../../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? service}) : service = service ?? AuthService();

  final AuthService service;
  User? get user => service.currentUser;
  bool loading = false;
  String? error;

  Future<void> restoreSession() => _run(service.restoreSession);
  Future<void> login(String email, String password) =>
      _run(() => service.login(email: email, password: password));
  Future<void> register(
    String name,
    String email,
    String password, {
    String? phone,
  }) => _run(
    () => service.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
    ),
  );
  Future<void> logout() => _run(service.logout);

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = exception.toString();
    }
    loading = false;
    notifyListeners();
  }
}
