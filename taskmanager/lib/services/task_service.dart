import "dart:convert";
import "package:http/http.dart" as http;

class TaskService {
  static const String baseUrl = "http://10.0.2.2:3000/api/tasks";

  static Future<dynamic> getTasks() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<dynamic> createTask({
    required String title,
    required String description,
    required String priority,
    required String createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "title": title,
          "description": description,
          "priority": priority,
          "createdBy": createdBy,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {"success": true, "message": data["message"] ?? "T?o c�ng vi?c th�nh c�ng!"};
      } else {
        return {"success": false, "message": data["message"] ?? "T?o c�ng vi?c th?t b?i"};
      }
    } catch (e) {
      return {"success": false, "message": "L?i k?t n?i Server"};
    }
  }
}
