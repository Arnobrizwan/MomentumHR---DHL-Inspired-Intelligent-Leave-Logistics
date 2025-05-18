import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'package:dhl_leave_management/services/auth_service.dart';
import 'package:dhl_leave_management/services/firebase_service.dart';
import 'package:dhl_leave_management/screens/profile_screen.dart';
import 'package:dhl_leave_management/screens/import_screen.dart';
import 'package:dhl_leave_management/screens/leave_detail_screen.dart';
import 'package:dhl_leave_management/screens/chatbot_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userName = 'Employee';
  Map<String, dynamic>? _userDetails;

  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final details = await _authService.getCurrentUserDetails();
      if (details != null) {
        setState(() {
          _userName = details['name'] ?? 'Employee';
          _userDetails = details;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/DHL_Express_logo_rgb.png', height: 30),
          const SizedBox(width: 12),
          const Text('My Leave Dashboard'),
        ]),
        backgroundColor: const Color(0xFFD40511),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFD40511)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/DHL_Express_logo_rgb.png', height: 40, color: Colors.white),
                const SizedBox(height: 16),
                Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 20)),
                const Text('Employee', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
          _buildDrawerItem(Icons.calendar_today, 'My Applications', 1),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD40511)))
          : _buildBody(),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int idx) {
    final selected = idx == _selectedIndex;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFFD40511) : Colors.grey),
      title: Text(title,
          style: TextStyle(
            color: selected ? const Color(0xFFD40511) : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      selected: selected,
      onTap: () {
        setState(() => _selectedIndex = idx);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return _buildMyApplications();
      case 0:
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firebaseService.getLeaveStatistics(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data ?? {};
        final total = stats['total'] ?? 0;
        final pend = stats['status']?['pending'] ?? 0;
        final appr = stats['status']?['approved'] ?? 0;
        final rej = stats['status']?['rejected'] ?? 0;
        final ann = stats['type']?['annual'] ?? 0;
        final med = stats['type']?['medical'] ?? 0;
        final emg = stats['type']?['emergency'] ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, ${_userName.split(' ').first}!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(children: [
              _buildStatCard('Total', total.toString(), Colors.blue, Icons.list_alt),
              _buildStatCard('Pending', pend.toString(), const Color(0xFFFFA000), Icons.pending),
              _buildStatCard('Approved', appr.toString(), const Color(0xFF43A047), Icons.check_circle),
              _buildStatCard('Rejected', rej.toString(), const Color(0xFFE53935), Icons.cancel),
            ]),
            const SizedBox(height: 24),

            // — Status Pie Chart —
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.pie_chart, color: Colors.grey[700], size: 18),
                    const SizedBox(width: 8),
                    const Text('Status Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(PieChartData(
                      sections: [
                        PieChartSectionData(
                            value: pend.toDouble(),
                            title: 'Pending',
                            color: const Color(0xFFFFA000),
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                        PieChartSectionData(
                            value: appr.toDouble(),
                            title: 'Approved',
                            color: const Color(0xFF43A047),
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                        PieChartSectionData(
                            value: rej.toDouble(),
                            title: 'Rejected',
                            color: const Color(0xFFE53935),
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    )),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _buildLegendItem('Pending', const Color(0xFFFFA000)),
                    const SizedBox(width: 16),
                    _buildLegendItem('Approved', const Color(0xFF43A047)),
                    const SizedBox(width: 16),
                    _buildLegendItem('Rejected', const Color(0xFFE53935)),
                  ]),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // — Type Pie Chart —
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.pie_chart, color: Colors.grey[700], size: 18),
                    const SizedBox(width: 8),
                    const Text('Type Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: PieChart(PieChartData(
                      sections: [
                        PieChartSectionData(
                            value: ann.toDouble(),
                            title: 'Annual',
                            color: Colors.blue,
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                        PieChartSectionData(
                            value: med.toDouble(),
                            title: 'Medical',
                            color: Colors.purple,
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                        PieChartSectionData(
                            value: emg.toDouble(),
                            title: 'Emergency',
                            color: Colors.orange,
                            radius: 50,
                            titleStyle: const TextStyle(color: Colors.white)),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    )),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _buildLegendItem('Annual', Colors.blue),
                    const SizedBox(width: 16),
                    _buildLegendItem('Medical', Colors.purple),
                    const SizedBox(width: 16),
                    _buildLegendItem('Emergency', Colors.orange),
                  ]),
                ]),
              ),
            ),

            const SizedBox(height: 32),

            // — Recent Applications —
            Text('Recent Applications',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<List<LeaveApplication>>(
              stream: _firebaseService.getAllLeaveApplications(),
              builder: (ctx, snapApp) {
                if (snapApp.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final apps = snapApp.data ?? [];
                final recent = apps.length > 5 ? apps.sublist(0, 5) : apps;
                if (recent.isEmpty) {
                  return const Text('No recent applications.');
                }
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final app = recent[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFD40511).withOpacity(0.1),
                        child: Text(app.employeeName[0].toUpperCase(),
                            style: const TextStyle(color: Color(0xFFD40511))),
                      ),
                      title: Text(app.leaveType),
                      subtitle: Text(
                          '${DateFormat.yMMMd().format(app.startDate)} → ${DateFormat.yMMMd().format(app.endDate)}'),
                      trailing: _buildStatusChip(app.status),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LeaveDetailScreen(leaveId: app.id))),
                    );
                  },
                );
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _buildMyApplications() {
    return StreamBuilder<List<LeaveApplication>>(
      stream: _firebaseService.getAllLeaveApplications(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? [];
        if (all.isEmpty) {
          return const Center(child: Text('You have no leave applications.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: all.length,
          itemBuilder: (ctx, i) {
            final app = all[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(app.leaveType),
                subtitle: Text(
                    '${DateFormat.yMMMd().format(app.startDate)} - ${DateFormat.yMMMd().format(app.endDate)}'),
                trailing: _buildStatusChip(app.status),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LeaveDetailScreen(leaveId: app.id))),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, color: color)),
            const SizedBox(height: 4),
            Text(title),
          ]),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label),
    ]);
  }

  Widget _buildStatusChip(String status) {
    Color c;
    switch (status) {
      case 'Pending':
        c = const Color(0xFFFFA000);
        break;
      case 'Approved':
        c = const Color(0xFF43A047);
        break;
      case 'Rejected':
        c = const Color(0xFFE53935);
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: c)),
    );
  }
}