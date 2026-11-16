import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.0.2.2:3000/api/tasks';

// 1. Lấy danh sách công việc theo userId
Future<List<dynamic>> getTasks(String userId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl?userId=$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  } catch (e) {
    return [];
  }
}

// 2. Tạo công việc mới (kèm userId)
Future<bool> createTask(String title, String description, String userId) async {
  try {
    print('--- Đang gửi API Tạo Task ---');
    print('Dữ liệu gửi: title=$title, userId=$userId');

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'createdBy': userId,
      }),
    );

    // In ra mã lỗi và phản hồi chi tiết từ Node.js
    print('Mã trạng thái Server: ${response.statusCode}');
    print('Phản hồi từ Server: ${response.body}');

    return response.statusCode == 201;
  } catch (e) {
    print('Lỗi kết nối mạng / Sập server: $e');
    return false;
  }
}

// 3. Đổi trạng thái công việc
Future<bool> updateTaskStatus(String id, String newStatus) async {
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
Future<bool> deleteTask(String id) async {
  try {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// 5. Tìm kiếm người dùng
Future<List<dynamic>> searchUsers(String query) async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/users/search?q=$query'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  } catch (e) {
    return [];
  }
}

// 6. Chia sẻ công việc
Future<bool> shareTask(String taskId, String userId, String permission) async {
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