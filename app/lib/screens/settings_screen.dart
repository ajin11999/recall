import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../notifications.dart';
import 'labels_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.api, required this.onLogout});

  final Api api;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Server'),
            subtitle: Text(api.baseUrl),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Manage labels'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LabelsScreen(api: api)),
            ),
          ),
          if (!kIsWeb) ...[
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send test notification'),
              onTap: () async {
                await Notifications.showTest();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Test notification sent')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Re-sync maintenance reminders'),
              subtitle: const Text('Happens automatically on app start and after changes'),
              onTap: () async {
                await Notifications.sync(api);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Reminders re-scheduled')));
                }
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: const Text('Log out? Scheduled reminders will be cancelled.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
                  ],
                ),
              );
              if (ok == true) await onLogout();
            },
          ),
        ],
      ),
    );
  }
}
