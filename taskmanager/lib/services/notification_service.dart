import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static const String baseUrl = 'http://10.0.2.2:3000/api/notifications';

  static Future<List<dynamic>> getNotifications(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}