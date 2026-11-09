import 'package:flutter/material.dart';
import '../services/task_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String fullName;
  final String userId;

  const HomeScreen({super.key, required this.fullName, this.userId = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  // Tải danh sách công việc từ Backend
  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final tasks = await TaskService.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  // Hộp thoại tạo công việc mới
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo công việc mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Tên công việc (*)'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Mô tả công việc'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(labelText: 'Đức ưu tiên'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Thấp')),
                DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                DropdownMenuItem(value: 'high', child: Text('Cao')),
              ],
              onChanged: (val) {
                if (val != null) priority = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;

              final res = await TaskService.createTask(
                title: titleController.text,
                description: descController.text,
                priority: priority,
                createdBy: widget.userId.isNotEmpty ? widget.userId : '650000000000000000000000',
              );

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'])),
                );
                _fetchTasks(); // Tải lại danh sách sau khi thêm thành công
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Công việc của ${widget.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? const Center(child: Text('Chưa có công việc nào. Nhấn nút (+) để thêm!'))
          : RefreshIndicator(
        onRefresh: _fetchTasks,
        child: ListView.builder(
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final task = _tasks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  task['status'] == 'completed'
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task['status'] == 'completed' ? Colors.green : Colors.orange,
                ),
                title: Text(
                  task['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: task['status'] == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(task['description'] ?? 'Không có mô tả'),
                trailing: Chip(
                  label: Text(
                    (task['priority'] ?? 'medium').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  backgroundColor: task['priority'] == 'high'
                      ? Colors.red
                      : task['priority'] == 'medium'
                      ? Colors.blue
                      : Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}