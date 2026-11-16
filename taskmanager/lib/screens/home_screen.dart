import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/task_service.dart';
import 'login_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String fullName;
  final String userId;

  const HomeScreen({super.key, required this.fullName, this.userId = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String taskApiUrl = 'http://10.0.2.2:3000/api/tasks';

  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];
  bool _isLoading = true;

  // Các biến tìm kiếm, lọc và sắp xếp
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // all, todo, in_progress, completed
  String _selectedPriorityFilter = 'all'; // all, low, medium, high
  String _selectedRoleFilter = 'all'; // all, owner, shared
  String _selectedSort = 'newest'; // newest, dueDate, priority

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final tasks = await getTasks(widget.userId);

    if (!mounted) return;
    setState(() {
      _allTasks = tasks;
      _applyFiltersAndSort();
      _isLoading = false;
    });
  }

  // Logic Tìm kiếm, Lọc và Sắp xếp
  void _applyFiltersAndSort() {
    final keyword = _searchController.text.trim().toLowerCase();

    List<dynamic> temp = _allTasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final status = (task['status'] ?? 'todo').toString();
      final priority = (task['priority'] ?? 'medium').toString();
      final permission = (task['userPermission'] ?? 'owner').toString();

      final matchKeyword = keyword.isEmpty || title.contains(keyword);
      final matchStatus = _selectedStatusFilter == 'all' || status == _selectedStatusFilter;
      final matchPriority = _selectedPriorityFilter == 'all' || priority == _selectedPriorityFilter;
      final matchRole = _selectedRoleFilter == 'all' ||
          (_selectedRoleFilter == 'owner' && permission == 'owner') ||
          (_selectedRoleFilter == 'shared' && permission != 'owner');

      return matchKeyword && matchStatus && matchPriority && matchRole;
    }).toList();

    // Sắp xếp
    temp.sort((a, b) {
      if (_selectedSort == 'priority') {
        const rank = {'high': 3, 'medium': 2, 'low': 1};
        final rA = rank[a['priority']] ?? 2;
        final rB = rank[b['priority']] ?? 2;
        return rB.compareTo(rA);
      } else if (_selectedSort == 'dueDate') {
        final dA = a['dueDate'] != null ? DateTime.tryParse(a['dueDate'].toString()) : null;
        final dB = b['dueDate'] != null ? DateTime.tryParse(b['dueDate'].toString()) : null;
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dA.compareTo(dB);
      }
      // Mặc định: Thời gian tạo mới nhất
      final cA = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime(2000);
      final cB = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime(2000);
      return cB.compareTo(cA);
    });

    setState(() {
      _filteredTasks = temp;
    });
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'Chưa đặt';
    final dt = DateTime.tryParse(dateStr.toString());
    if (dt == null) return 'Chưa đặt';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _toggleTaskStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'completed' ? 'todo' : 'completed';
    final success = await updateTaskStatus(id, newStatus);
    if (success && mounted) {
      _fetchTasks();
    }
  }

  Future<void> _deleteTask(String id) async {
    final success = await deleteTask(id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc!'), backgroundColor: Colors.red),
      );
      _fetchTasks();
    }
  }

  // Hộp thoại Xem chi tiết & Chỉnh sửa công việc
  void _showTaskDetailDialog(Map<String, dynamic> task) {
    final permission = task['userPermission'] ?? 'owner';
    final canEdit = permission == 'owner' || permission == 'editor';

    final titleController = TextEditingController(text: task['title'] ?? '');
    final descController = TextEditingController(text: task['description'] ?? '');
    String status = task['status'] ?? 'todo';
    String priority = task['priority'] ?? 'medium';
    DateTime? startDate =
    task['startDate'] != null ? DateTime.tryParse(task['startDate'].toString()) : null;
    DateTime? dueDate =
    task['dueDate'] != null ? DateTime.tryParse(task['dueDate'].toString()) : null;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
          title: Text(canEdit ? 'Chi tiết & Sửa công việc' : 'Chi tiết công việc (Chỉ xem)'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Tên công việc (*)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    readOnly: !canEdit,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todo', child: Text('Chưa thực hiện')),
                      DropdownMenuItem(value: 'in_progress', child: Text('Đang thực hiện')),
                      DropdownMenuItem(value: 'completed', child: Text('Đã hoàn thành')),
                    ],
                    onChanged: canEdit
                        ? (val) {
                      if (val != null) setDialogState(() => status = val);
                    }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(
                      labelText: 'Mức ưu tiên',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                    ],
                    onChanged: canEdit
                        ? (val) {
                      if (val != null) setDialogState(() => priority = val);
                    }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow, color: Colors.blue),
                    title: Text('Ngày bắt đầu: ${_formatDate(startDate?.toIso8601String())}'),
                    onTap: canEdit
                        ? () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    }
                        : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: Colors.redAccent),
                    title: Text('Hạn hoàn thành: ${_formatDate(dueDate?.toIso8601String())}'),
                    onTap: canEdit
                        ? () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    }
                        : null,
                  ),
                  if (task['createdBy'] is Map) ...[
                    const Divider(),
                    Text(
                      'Người tạo: ${task['createdBy']['fullName'] ?? task['createdBy']['email'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            if (canEdit)
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                  if (titleController.text.trim().isEmpty) return;
                  setDialogState(() => isSaving = true);
                  try {
                    final res = await http.put(
                      Uri.parse('$taskApiUrl/${task['_id']}'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'status': status,
                        'priority': priority,
                        'startDate': startDate?.toIso8601String(),
                        'dueDate': dueDate?.toIso8601String(),
                      }),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.statusCode == 200
                              ? 'Cập nhật công việc thành công!'
                              : 'Lỗi cập nhật công việc'),
                          backgroundColor:
                          res.statusCode == 200 ? Colors.green : Colors.red,
                        ),
                      );
                      _fetchTasks();
                    }
                  } catch (e) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Lưu thay đổi'),
              ),
          ],
        ),
      ),
    );
  }

  // Hộp thoại Tạo công việc mới (có Ngày bắt đầu & Hạn hoàn thành)
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';
    DateTime startDate = DateTime.now();
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
          title: const Text('Tạo công việc mới'),
          content: SingleChildScrollView(
            child: Column(
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
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_arrow, color: Colors.blue),
                  title: Text('Ngày bắt đầu: ${_formatDate(startDate.toIso8601String())}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event, color: Colors.redAccent),
                  title: Text('Hạn hoàn thành: ${_formatDate(dueDate?.toIso8601String())}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                try {
                  final response = await http.post(
                    Uri.parse(taskApiUrl),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'priority': priority,
                      'startDate': startDate.toIso8601String(),
                      'dueDate': dueDate?.toIso8601String(),
                      'userId': widget.userId,
                      'createdBy': widget.userId,
                    }),
                  );

                  final success = response.statusCode == 201 || response.statusCode == 200;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Tạo công việc thành công!' : 'Lỗi tạo công việc'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                    _fetchTasks();
                  }
                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(String taskId) {
    final searchController = TextEditingController();
    List<dynamic> searchResults = [];
    String selectedPermission = 'viewer';
    bool isSearching = false;
    bool hasSearched = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stfContext, setDialogState) => AlertDialog(
          title: const Text('Chia sẻ công việc'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
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

                          final users = await searchUsers(query);

                          if (dialogContext.mounted) {
                            setDialogState(() {
                              searchResults = users;
                              isSearching = false;
                            });
                          }
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
                      child: Text('Không tìm thấy người dùng phù hợp',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else if (searchResults.isNotEmpty)
                      ...searchResults.map((user) {
                        final userName =
                            user['fullName'] ?? user['name'] ?? user['email'] ?? 'Không tên';
                        final userEmail = user['email'] ?? '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(userEmail),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.blue),
                            onPressed: () async {
                              final success =
                              await shareTask(taskId, user['_id'], selectedPermission);

                              if (dialogContext.mounted) Navigator.pop(dialogContext);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'Chia sẻ thành công!'
                                        : 'Lỗi chia sẻ công việc!'),
                                    backgroundColor: success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color = Colors.orange;
    String label = 'TB';
    if (priority == 'high') {
      color = Colors.red;
      label = 'Cao';
    } else if (priority == 'low') {
      color = Colors.green;
      label = 'Thấp';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == 'in_progress') {
      return const Text('Đang thực hiện',
          style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600));
    } else if (status == 'completed') {
      return const Text('Đã hoàn thành',
          style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600));
    }
    return const Text('Chưa thực hiện',
        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Công việc của ${widget.fullName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    fullName: widget.fullName,
                    userId: widget.userId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(userId: widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Khu vực Tìm kiếm, Lọc và Sắp xếp
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFiltersAndSort(),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm công việc theo tên...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFiltersAndSort();
                      },
                    )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Lọc trạng thái
                      DropdownButton<String>(
                        value: _selectedStatusFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Trạng thái: Tất cả')),
                          DropdownMenuItem(value: 'todo', child: Text('Chưa làm')),
                          DropdownMenuItem(value: 'in_progress', child: Text('Đang làm')),
                          DropdownMenuItem(value: 'completed', child: Text('Hoàn thành')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _selectedStatusFilter = val;
                            _applyFiltersAndSort();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // Lọc mức ưu tiên
                      DropdownButton<String>(
                        value: _selectedPriorityFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Ưu tiên: Tất cả')),
                          DropdownMenuItem(value: 'high', child: Text('Cao')),
                          DropdownMenuItem(value: 'medium', child: Text('Trung bình')),
                          DropdownMenuItem(value: 'low', child: Text('Thấp')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _selectedPriorityFilter = val;
                            _applyFiltersAndSort();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // Lọc vai trò
                      DropdownButton<String>(
                        value: _selectedRoleFilter,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Vai trò: Tất cả')),
                          DropdownMenuItem(value: 'owner', child: Text('Của tôi')),
                          DropdownMenuItem(value: 'shared', child: Text('Được chia sẻ')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _selectedRoleFilter = val;
                            _applyFiltersAndSort();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // Sắp xếp
                      DropdownButton<String>(
                        value: _selectedSort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'newest', child: Text('SX: Mới nhất')),
                          DropdownMenuItem(value: 'dueDate', child: Text('SX: Hạn chót')),
                          DropdownMenuItem(value: 'priority', child: Text('SX: Ưu tiên')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _selectedSort = val;
                            _applyFiltersAndSort();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Danh sách công việc
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                ? const Center(child: Text('Không có công việc nào phù hợp.'))
                : RefreshIndicator(
              onRefresh: _fetchTasks,
              child: ListView.builder(
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  final isCompleted = task['status'] == 'completed';
                  final permission = task['userPermission'] ?? 'owner';
                  final isOwner = permission == 'owner';
                  final canEdit = permission == 'owner' || permission == 'editor';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: ListTile(
                      onTap: () => _showTaskDetailDialog(task),
                      leading: IconButton(
                        icon: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isCompleted
                              ? (canEdit ? Colors.green : Colors.grey)
                              : Colors.grey,
                        ),
                        onPressed: canEdit
                            ? () =>
                            _toggleTaskStatus(task['_id'], task['status'] ?? 'todo')
                            : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Bạn chỉ có quyền xem (Viewer), không thể chỉnh sửa!'),
                            ),
                          );
                        },
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              task['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          _buildPriorityBadge(task['priority'] ?? 'medium'),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((task['description'] ?? '').toString().isNotEmpty)
                            Text(
                              task['description'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildStatusBadge(task['status'] ?? 'todo'),
                              if (task['dueDate'] != null) ...[
                                const Text(' • ', style: TextStyle(fontSize: 11)),
                                Text(
                                  'Hạn: ${_formatDate(task['dueDate'])}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.redAccent),
                                ),
                              ],
                            ],
                          ),
                          if (!isOwner)
                            Text(
                              permission == 'editor'
                                  ? 'Được chia sẻ (Quyền: Chỉnh sửa)'
                                  : 'Được chia sẻ (Quyền: Chỉ xem)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      trailing: isOwner
                          ? Row(
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
                      )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}