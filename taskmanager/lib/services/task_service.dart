import 'dart:convert';
import 'package:http/http.dart' as http;

class TaskService {
  static const String baseUrl = 'http://10.0.2.2:3000/api/tasks';

  // 1. Lấy danh sách công việc
  static Future<List<dynamic>> getTasks() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // 2. Tạo công việc mới
  static Future createTask({
    required String title,
    required String description,
    required String priority,
    required String createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'priority': priority,
          'createdBy': createdBy,
        }),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Thao tác hoàn tất'
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối Server'};
    }
  }

  // 3. Đổi trạng thái công việc
  static Future<bool> updateTaskStatus(String id, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. Xóa công việc
  static Future<bool> deleteTask(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$id'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. Tìm kiếm người dùng
  static Future<List<dynamic>> searchUsers(String query) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/search?q=$query'));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // 6. Chia sẻ công việc
  static Future<bool> shareTask(String taskId, String userId, String permission) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$taskId/shares'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'permission': permission}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}