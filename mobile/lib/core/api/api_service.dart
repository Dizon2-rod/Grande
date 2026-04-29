import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Change this to your Flask server IP/domain
  // For local development, use your computer's local IP address
  // Find it by running 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux)
  static const String baseUrl = 'http://192.168.123.34:5000';  // Change to your computer's IP if testing on physical device
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'auth_token');
  static Future<void> saveToken(String token) => _storage.write(key: 'auth_token', value: token);
  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: 'auth_user', value: jsonEncode(user));
  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: 'auth_user');
    if (raw == null) return null;
    return jsonDecode(raw);
  }
  static Future<void> clearAuth() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_user');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> delete(String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request('DELETE', uri);
    request.headers.addAll(await _headers());
    if (body != null) {
      request.body = jsonEncode(body);
      request.headers['Content-Type'] = 'application/json';
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path,
    File file,
    String fieldName,
    Map<String, String> fields,
  ) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> multipartPost(
    String path,
    Map<String, String> fields,
    Map<String, File> files, {
    bool auth = true,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (auth) {
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static Future<Map<String, dynamic>> multipartPostFiles(
    String path,
    Map<String, String> fields,
    Map<String, List<File>> files, {
    bool auth = true,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (auth) {
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      for (final file in entry.value) {
        request.files.add(await http.MultipartFile.fromPath(entry.key, file.path));
      }
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  static Map<String, dynamic> _parse(http.Response res) {
    try {
      if (res.body.isEmpty) {
        return {'error': 'Empty response from server', 'status': res.statusCode};
      }
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } catch (e) {
      debugPrint('[API] Parse error: $e');
      debugPrint('[API] Response body: ${res.body}');
      debugPrint('[API] Status code: ${res.statusCode}');
      return {'error': 'Invalid response: ${res.body.substring(0, res.body.length > 100 ? 100 : res.body.length)}', 'status': res.statusCode};
    }
  }

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
