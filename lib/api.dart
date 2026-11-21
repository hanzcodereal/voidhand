import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const base = 'https://voidhand-api.vercel.app';

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http
        .get(Uri.parse('$base$path'))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 204) return {};
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final r = await http
        .post(
          Uri.parse('$base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body ?? {}),
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final r = await http
        .delete(Uri.parse('$base$path'))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode >= 400) throw Exception('HTTP ${r.statusCode}');
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
