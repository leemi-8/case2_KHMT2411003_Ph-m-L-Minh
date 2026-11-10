import 'package:flutter/material.dart';
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
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    final data = await StatisticsService.getSummary(widget.userId);
    setState(() {
      _stats = data;
      _isLoading = false;
    });
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
        onRefresh: _fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Thông tin cá nhân
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.person, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fullName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('ID: ${widget.userId}', style: const TextStyle(color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Thống kê công việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStatCard('Tổng số công việc', _stats['total'] ?? 0, Colors.blue, Icons.assignment),
            _buildStatCard('Chưa thực hiện', _stats['todo'] ?? 0, Colors.orange, Icons.hourglass_empty),
            _buildStatCard('Đang thực hiện', _stats['inProgress'] ?? 0, Colors.purple, Icons.directions_run),
            _buildStatCard('Đã hoàn thành', _stats['completed'] ?? 0, Colors.green, Icons.check_circle),
            _buildStatCard('Công việc quá hạn', _stats['overdue'] ?? 0, Colors.red, Icons.warning),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Đăng xuất', style: TextStyle(color: Colors.white, fontSize: 16)),
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