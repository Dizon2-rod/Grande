import 'package:flutter/material.dart';
import 'dart:io';
import '../api/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String get role => _user?['role'] ?? '';
  String get name => _user?['name'] ?? '';
  String get email => _user?['email'] ?? '';
  int get userId => _user?['id'] ?? 0;

  Future<void> loadUser() async {
    _user = await ApiService.getUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.post(
        '/api/auth/login',
        {'email': email, 'password': password},
        auth: false,
      );
      if (res['success'] == true) {
        await ApiService.saveToken(res['token']);
        await ApiService.saveUser(res['user']);
        _user = res['user'];
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = res['error'] ?? 'Login failed';
    } catch (e) {
      _error = 'Connection error. Check your network.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.post('/api/auth/register', data, auth: false);
      _loading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = res['error'] ?? 'Registration failed';
    } catch (e) {
      _error = 'Connection error. Check your network.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerWithFiles(Map<String, dynamic> data, Map<String, File> files) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final fields = data.map((key, value) => MapEntry(key, value.toString()));
      final res = await ApiService.multipartPost('/api/auth/register', fields, files, auth: false);
      _loading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = res['error'] ?? 'Registration failed';
    } catch (e) {
      _error = 'Connection error. Check your network.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.post('/api/auth/logout', {});
    await ApiService.clearAuth();
    _user = null;
    notifyListeners();
  }

  Future<bool> forgotPassword(String email) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.post('/api/auth/forgot-password', {'email': email}, auth: false);
      _loading = false;
      if (res['success'] == true) {
        notifyListeners();
        return true;
      }
      _error = res['error'] ?? res['message'] ?? 'Failed to send reset email';
      notifyListeners();
      return false;
    } catch (e) {
      print('Forgot password error: $e');
      _error = 'Connection error. Please check your network.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
