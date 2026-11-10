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

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final tasks = await TaskService.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _toggleTaskStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'completed' ? 'todo' : 'completed';
    final success = await TaskService.updateTaskStatus(id, newStatus);
    if (success) _fetchTasks();
  }

  Future<void> _deleteTask(String id) async {
    final success = await TaskService.deleteTask(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc!'), backgroundColor: Colors.red),
      );
      _fetchTasks();
    }
  }

  void _showShareDialog(String taskId) {
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    String selectedPermission = 'viewer';
    bool isSearching = false;
    bool hasSearched = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chia sẻ công việc'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Nhập email/họ tên người dùng',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final query = searchController.text.trim();
                        if (query.isEmpty) return;

                        setDialogState(() {
                          isSearching = true;
                          hasSearched = true;
                        });

                        final users = await TaskService.searchUsers(query);

                        setDialogState(() {
                          searchResults = users;
                          isSearching = false;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedPermission,
                  decoration: const InputDecoration(labelText: 'Quyền truy cập'),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Chỉ xem (Viewer)')),
                    DropdownMenuItem(value: 'editor', child: Text('Chỉnh sửa (Editor)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedPermission = val);
                  },
                ),
                const SizedBox(height: 12),
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )
                else if (hasSearched && searchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Không tìm thấy người dùng phù hợp',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else if (searchResults.isNotEmpty)
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          final userName = user['fullName'] ?? user['name'] ?? user['email'] ?? 'Không tên';
                          final userEmail = user['email'] ?? '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(userEmail),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_add, color: Colors.blue),
                              onPressed: () async {
                                final success = await TaskService.shareTask(
                                  taskId,
                                  user['_id'],
                                  selectedPermission,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success ? 'Chia sẻ thành công!' : 'Lỗi chia sẻ công việc!',
                                      ),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

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
                  SnackBar(content: Text(res['message'] ?? 'Thao tác hoàn tất')),
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
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.blue),
                      onPressed: () => _showShareDialog(task['_id']),
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