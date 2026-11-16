import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/statistics_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String fullName;
  final String userId;

  const ProfileScreen({super.key, required this.fullName, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Đổi IP này nếu bạn chạy trên thiết bị thật (10.0.2.2 dành cho máy ảo Android)
  static const String baseUrl = 'http://10.0.2.2:3000/api/auth';

  late String _currentFullName;
  String _email = '';
  Map<String, dynamic> _stats = {
    'total': 0,
    'todo': 0,
    'inProgress': 0,
    'completed': 0,
    'overdue': 0
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentFullName = widget.fullName;
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchProfile(),
      _fetchStats(),
    ]);

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profile/${widget.userId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _currentFullName = data['fullName'] ?? _currentFullName;
            _email = data['email'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải thông tin hồ sơ: $e');
    }
  }

  Future<void> _fetchStats() async {
    final data = await StatisticsService.getSummary(widget.userId);
    if (mounted) {
      setState(() {
        _stats = data;
      });
    }
  }

  // Hộp thoại cập nhật họ tên
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentFullName);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
          title: const Text('Cập nhật thông tin cá nhân'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên (*)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_email.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email (Không thể thay đổi)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                setDialogState(() => isSaving = true);
                try {
                  final response = await http.put(
                    Uri.parse('$baseUrl/profile/${widget.userId}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'fullName': newName}),
                  );
                  final result = jsonDecode(response.body);

                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  if (response.statusCode == 200) {
                    if (mounted) {
                      setState(() => _currentFullName = newName);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Cập nhật hồ sơ thành công!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Lỗi cập nhật hồ sơ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể kết nối tới máy chủ'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // Hộp thoại đổi mật khẩu
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại (*)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới (*)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới (*)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                final oldPass = oldPassController.text.trim();
                final newPass = newPassController.text.trim();
                final confirmPass = confirmPassController.text.trim();

                if (oldPass.isEmpty || newPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đầy đủ mật khẩu cũ và mới'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mật khẩu nhập lại không khớp!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  final response = await http.put(
                    Uri.parse('$baseUrl/change-password/${widget.userId}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'oldPassword': oldPass,
                      'newPassword': newPass,
                    }),
                  );
                  final result = jsonDecode(response.body);

                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Thao tác hoàn tất'),
                        backgroundColor:
                        response.statusCode == 200 ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể kết nối tới máy chủ'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Text(
              '$count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang cá nhân & Thống kê'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchAllData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Thông tin cá nhân
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          child: Icon(Icons.person, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentFullName,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (_email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _email,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${widget.userId}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Sửa hồ sơ'),
                            onPressed: _showEditProfileDialog,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.lock_reset, size: 18),
                            label: const Text('Đổi mật khẩu'),
                            onPressed: _showChangePasswordDialog,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Thống kê công việc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatCard(
                'Tổng số công việc', _stats['total'] ?? 0, Colors.blue, Icons.assignment),
            _buildStatCard(
                'Chưa thực hiện', _stats['todo'] ?? 0, Colors.orange, Icons.hourglass_empty),
            _buildStatCard('Đang thực hiện', _stats['inProgress'] ?? 0, Colors.purple,
                Icons.directions_run),
            _buildStatCard(
                'Đã hoàn thành', _stats['completed'] ?? 0, Colors.green, Icons.check_circle),
            _buildStatCard(
                'Công việc quá hạn', _stats['overdue'] ?? 0, Colors.red, Icons.warning),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Đăng xuất',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}