import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotificationScreen extends StatefulWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String baseUrl = 'http://10.0.2.2:5000/api/notifications';
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/${widget.userId}'));
      if (response.statusCode == 200) {
        setState(() {
          _notifications = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await http.put(Uri.parse('$baseUrl/$notificationId/read'));
      _fetchNotifications();
    } catch (e) {
      // Bỏ qua lỗi mạng nhẹ
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await http.put(Uri.parse('$baseUrl/user/${widget.userId}/read-all'));
      _fetchNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đánh dấu tất cả thông báo là đã đọc!')),
        );
      }
    } catch (e) {
      // Bỏ qua lỗi mạng nhẹ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (_notifications.any((n) => n['isRead'] == false))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
        child: Text(
          'Bạn chưa có thông báo nào.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final item = _notifications[index];
            final bool isRead = item['isRead'] ?? false;
            final String? taskId = item['taskId']?.toString();

            return Container(
              color: isRead ? Colors.white : Colors.blue.withOpacity(0.08),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey.shade300 : Colors.blue,
                  child: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: isRead ? Colors.black54 : Colors.white,
                  ),
                ),
                title: Text(
                  item['title'] ?? 'Thông báo',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(item['message'] ?? ''),
                    if (taskId != null && taskId.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Chạm để mở công việc liên quan →',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: !isRead
                    ? const Icon(Icons.circle, color: Colors.blue, size: 10)
                    : null,
                onTap: () async {
                  if (!isRead) {
                    await _markAsRead(item['_id']);
                  }
                  if (taskId != null && taskId.isNotEmpty && mounted) {
                    Navigator.pop(context, taskId);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}