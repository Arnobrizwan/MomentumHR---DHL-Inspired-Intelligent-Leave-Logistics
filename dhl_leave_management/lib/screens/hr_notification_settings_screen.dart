import 'package:flutter/material.dart';

class HRNotificationSettingsScreen extends StatefulWidget {
  const HRNotificationSettingsScreen({super.key});

  @override
  State<HRNotificationSettingsScreen> createState() => _HRNotificationSettingsScreenState();
}

class _HRNotificationSettingsScreenState extends State<HRNotificationSettingsScreen> {
  bool _newLeaveRequests = true;
  bool _approvalReminders = true;
  bool _systemAlerts = true;
  bool _emailSummaries = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: const Color(0xFFD40511),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSwitchTile(
            title: 'New Leave Requests',
            subtitle: 'Be notified when an employee submits a new leave application',
            value: _newLeaveRequests,
            onChanged: (val) => setState(() => _newLeaveRequests = val),
          ),
          _buildSwitchTile(
            title: 'Approval Reminders',
            subtitle: 'Get reminders to approve or reject pending leaves',
            value: _approvalReminders,
            onChanged: (val) => setState(() => _approvalReminders = val),
          ),
          _buildSwitchTile(
            title: 'System Alerts',
            subtitle: 'Important system-wide updates and maintenance notifications',
            value: _systemAlerts,
            onChanged: (val) => setState(() => _systemAlerts = val),
          ),
          _buildSwitchTile(
            title: 'Daily Email Summaries',
            subtitle: 'Receive daily summary of leave activities via email',
            value: _emailSummaries,
            onChanged: (val) => setState(() => _emailSummaries = val),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preferences saved successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Preferences'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD40511),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFD40511),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}