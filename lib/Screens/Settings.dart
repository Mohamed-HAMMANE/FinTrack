import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/SyncHelper.dart';
import '../Helpers/Funcs.dart';
import '../Helpers/DatabaseHelper.dart';
import 'Categories.dart';

class Settings extends StatefulWidget {
  final bool isSubView;
  const Settings({super.key, this.isSubView = false});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _ipController = TextEditingController();
  bool _isSyncing = false;
  String? _lastSyncStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', _ipController.text.trim());
  }

  Future<void> _handleSync() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      Func.showToast('Please enter the computer IP', type: 'error');
      return;
    }

    setState(() {
      _isSyncing = true;
      _lastSyncStatus = null;
    });

    await _saveSettings();
    final success = await SyncHelper.syncDatabase(ip);

    setState(() {
      _isSyncing = false;
      _lastSyncStatus = success ? 'Success' : 'Failed';
    });

    if (success) {
      Func.showToast('Database synced successfully!');
    } else {
      Func.showToast('Sync failed. Check IP and server status.', type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual Cloud Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your computer IP address to upload the local database to your web app.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Computer IP Address',
                    hintText: 'e.g. 192.168.1.15',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _handleSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_lastSyncStatus != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Last Sync: $_lastSyncStatus',
                      style: TextStyle(
                        color: _lastSyncStatus == 'Success'
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categories'),
                subtitle: const Text('Manage your spending categories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CategoriesState()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Local Backup'),
                subtitle: const Text('Save a backup of your local database'),
                onTap: () async {
                  if (await DatabaseHelper.backUp()) {
                    Func.showToast('Downloaded successfully.');
                  } else {
                    Func.showToast('Error on backup.', type: 'error');
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Local Restore'),
                subtitle: const Text('Restore database from a local file'),
                onTap: () async {
                  DatabaseHelper.restore(context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('API Configuration'),
            subtitle: Text(
              'Endpoint: /api/sync\nMethod: POST\nKey: fintrack_local_sync_123',
            ),
          ),
        ),
        const SizedBox(height: 80), // For bottom nav spacing
      ],
    );

    if (widget.isSubView) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Sync')),
      body: content,
    );
  }
}
