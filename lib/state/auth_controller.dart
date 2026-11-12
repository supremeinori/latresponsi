import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/local_db_service.dart';
import '../services/session_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this._database,
    required this._sessionService,
  });

  final AuthDatabase _database;
  final SessionService _sessionService;

  UserModel? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  Future<void> restoreSession() async {
    _currentUser = await _sessionService.getLoggedInUser();
    _isInitialized = true;
    notifyListeners();
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _database.authenticateUser(
        username: username,
        password: password,
      );
      if (user == null) {
        return 'Username atau password salah.';
      }
      await _sessionService.saveSession(user);
      _currentUser = user;
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal memproses login. Silakan coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _database.registerUser(
        name: name,
        username: username,
        password: password,
      );
      await _sessionService.saveSession(user);
      _currentUser = user;
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal mendaftar akun. Silakan coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _sessionService.clearSession();
    _currentUser = null;
    notifyListeners();
  }
}
