import 'package:flutter/material.dart';

class EmployeeNotificationSettingsScreen extends StatefulWidget {
  const EmployeeNotificationSettingsScreen({super.key});

  @override
  State<EmployeeNotificationSettingsScreen> createState() => _EmployeeNotificationSettingsScreenState();
}

class _EmployeeNotificationSettingsScreenState extends State<EmployeeNotificationSettingsScreen> {
  bool _leaveStatusUpdates    = true;
  bool _upcomingLeaveReminder = true;
  bool _policyAnnouncements   = true;
  bool _chatbotAlerts         = false;

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
            title: 'Leave Status Updates',
            subtitle: 'Get notified when your leave is approved or rejected',
            value: _leaveStatusUpdates,
            onChanged: (v) => setState(() => _leaveStatusUpdates = v),
          ),
          _buildSwitchTile(
            title: 'Upcoming Leave Reminder',
            subtitle: 'Reminder 1 day before your approved leave',
            value: _upcomingLeaveReminder,
            onChanged: (v) => setState(() => _upcomingLeaveReminder = v),
          ),
          _buildSwitchTile(
            title: 'Policy Announcements',
            subtitle: 'Important updates to leave policies',
            value: _policyAnnouncements,
            onChanged: (v) => setState(() => _policyAnnouncements = v),
          ),
          _buildSwitchTile(
            title: 'Chatbot Alerts',
            subtitle: 'Alerts when your AI assistant has messages',
            value: _chatbotAlerts,
            onChanged: (v) => setState(() => _chatbotAlerts = v),
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