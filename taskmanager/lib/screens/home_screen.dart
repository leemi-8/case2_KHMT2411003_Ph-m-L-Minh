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

  // Tải danh sách công việc
  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final tasks = await TaskService.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  // Đổi trạng thái công việc (Hoàn thành / Chưa hoàn thành)
  Future<void> _toggleTaskStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'completed' ? 'todo' : 'completed';
    final success = await TaskService.updateTaskStatus(id, newStatus);
    if (success) _fetchTasks();
  }

  // Xóa công việc
  Future<void> _deleteTask(String id) async {
    final success = await TaskService.deleteTask(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc!'), backgroundColor: Colors.red),
      );
      _fetchTasks();
    }
  }

  // Hộp thoại tạo mới công việc
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
              decoration: const InputDecoration(labelText: 'Mức ưu tiên'),
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
                _fetchTasks();
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
            final isCompleted = task['status'] == 'completed';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: IconButton(
                  icon: Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => _toggleTaskStatus(task['_id'], task['status'] ?? 'todo'),
                ),
                title: Text(
                  task['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(task['description'] ?? 'Không có mô tả'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
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
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteTask(task['_id']),
                    ),
                  ],
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