import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  bool _useGlobalQuietHours = false;
  QuietTime? _globalQuietHoursStart;
  QuietTime? _globalQuietHoursEnd;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final provider = context.read<ReminderProvider>();
    final settings = await provider.getSettings();
    setState(() {
      _settings = settings;
      _useGlobalQuietHours = settings.useGlobalQuietHours;
      _globalQuietHoursStart = settings.globalQuietHoursStart;
      _globalQuietHoursEnd = settings.globalQuietHoursEnd;
    });
  }

  Future<void> _saveSettings() async {
    final provider = context.read<ReminderProvider>();
    final newSettings = AppSettings(
      useGlobalQuietHours: _useGlobalQuietHours,
      globalQuietHoursStart: _globalQuietHoursStart,
      globalQuietHoursEnd: _globalQuietHoursEnd,
    );
    await provider.updateSettings(newSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Global Quiet Hours',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Enable Global Quiet Hours'),
                          subtitle: const Text(
                            'Apply quiet hours to all reminders',
                          ),
                          value: _useGlobalQuietHours,
                          onChanged: (value) {
                            setState(() {
                              _useGlobalQuietHours = value;
                            });
                          },
                        ),
                        if (_useGlobalQuietHours) ...[
                          const SizedBox(height: 8),
                          ListTile(
                            title: const Text('Start Time'),
                            subtitle: Text(_globalQuietHoursStart?.toString() ?? 'Not set'),
                            trailing: _globalQuietHoursStart != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _globalQuietHoursStart = null;
                                      });
                                    },
                                  )
                                : null,
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 22, minute: 0),
                              );
                              if (time != null) {
                                setState(() {
                                  _globalQuietHoursStart = QuietTime(
                                    hour: time.hour,
                                    minute: time.minute,
                                  );
                                });
                              }
                            },
                          ),
                          ListTile(
                            title: const Text('End Time'),
                            subtitle: Text(_globalQuietHoursEnd?.toString() ?? 'Not set'),
                            trailing: _globalQuietHoursEnd != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _globalQuietHoursEnd = null;
                                      });
                                    },
                                  )
                                : null,
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 6, minute: 0),
                              );
                              if (time != null) {
                                setState(() {
                                  _globalQuietHoursEnd = QuietTime(
                                    hour: time.hour,
                                    minute: time.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
