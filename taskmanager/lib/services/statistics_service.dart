import 'dart:convert';
import 'package:http/http.dart' as http;

class StatisticsService {
  static const String baseUrl = 'http://10.0.2.2:3000/api/statistics';

  static Future getSummary(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/summary/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'total': 0,
        'todo': 0,
        'inProgress': 0,
        'completed': 0,
        'overdue': 0
      };
    } catch (e) {
      return {
        'total': 0,
        'todo': 0,
        'inProgress': 0,
        'completed': 0,
        'overdue': 0
      };
    }
  }
}