import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/reminder.dart';
import '../models/reminder_type.dart';
import '../providers/reminder_provider.dart';

enum IntervalUnit {
  seconds,
  minutes,
  hours,
  days,
}

class ReminderFormScreen extends StatefulWidget {
  final Reminder? reminder;

  const ReminderFormScreen({super.key, this.reminder});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _intervalTextController;
  late TextEditingController _medicationOptionsController;

  int? _selectedTypeId;
  bool _isActive = true;
  bool _trackHistory = true;
  DateTime? _endDate;
  QuietTime? _quietHoursStart;
  QuietTime? _quietHoursEnd;
  WaterReminderBehavior _waterBehavior = WaterReminderBehavior.continuous;
  String? _notificationSound;

  double _intervalValue = 15;
  IntervalUnit _intervalUnit = IntervalUnit.minutes;
  bool _isUpdatingFromSlider = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder?.title ?? '');
    _descriptionController = TextEditingController(text: widget.reminder?.description ?? '');
    _intervalTextController = TextEditingController(text: '15');
    _medicationOptionsController = TextEditingController(text: widget.reminder?.medicationOptions ?? '');

    if (widget.reminder != null) {
      _selectedTypeId = widget.reminder!.reminderTypeId;
      _isActive = widget.reminder!.isActive;
      _trackHistory = widget.reminder!.trackHistory;
      _endDate = widget.reminder!.endDate;
      _quietHoursStart = widget.reminder!.quietHoursStart;
      _quietHoursEnd = widget.reminder!.quietHoursEnd;
      _waterBehavior = widget.reminder!.waterBehavior ?? WaterReminderBehavior.continuous;
      _notificationSound = widget.reminder!.notificationSound;

      _convertFromSeconds(widget.reminder!.intervalSeconds);
    }

    _intervalTextController.text = _intervalValue.toInt().toString();
    _intervalTextController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_isUpdatingFromSlider) return;

    final value = int.tryParse(_intervalTextController.text);
    if (value != null && value >= 1) {
      setState(() {
        _intervalValue = value.toDouble();
      });
    }
  }

  void _convertFromSeconds(int seconds) {
    if (seconds % 86400 == 0) {
      _intervalValue = (seconds / 86400).toDouble();
      _intervalUnit = IntervalUnit.days;
    } else if (seconds % 3600 == 0) {
      _intervalValue = (seconds / 3600).toDouble();
      _intervalUnit = IntervalUnit.hours;
    } else if (seconds % 60 == 0) {
      _intervalValue = (seconds / 60).toDouble();
      _intervalUnit = IntervalUnit.minutes;
    } else {
      _intervalValue = seconds.toDouble();
      _intervalUnit = IntervalUnit.seconds;
    }

    if (_intervalValue > 600) {
      _intervalValue = 600;
    }
  }

  int _convertToSeconds() {
    switch (_intervalUnit) {
      case IntervalUnit.seconds:
        return _intervalValue.toInt();
      case IntervalUnit.minutes:
        return (_intervalValue * 60).toInt();
      case IntervalUnit.hours:
        return (_intervalValue * 3600).toInt();
      case IntervalUnit.days:
        return (_intervalValue * 86400).toInt();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalTextController.dispose();
    _medicationOptionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder == null ? 'New Reminder' : 'Edit Reminder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.reminder != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final provider = context.read<ReminderProvider>();
                final navigator = Navigator.of(context);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Reminder'),
                    content: const Text('Are you sure you want to delete this reminder?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await provider.deleteReminder(widget.reminder!.id!);
                  navigator.pop();
                }
              },
            ),
        ],
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          if (provider.reminderTypes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No reminder types available'),
                  ElevatedButton(
                    onPressed: () => _createDefaultTypes(provider),
                    child: const Text('Create Default Types'),
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicationOptionsController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Options (optional)',
                    hintText: 'e.g., Tylenol, Ibuprofen',
                    helperText: 'Comma-separated list for alternating medications',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _intervalTextController,
                                decoration: const InputDecoration(
                                  labelText: 'Interval Value',
                                  border: OutlineInputBorder(),
                                  helperText: '1-100 (slider) or type any value',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  final num = int.tryParse(value);
                                  if (num == null || num < 1) {
                                    return 'Must be ≥ 1';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _intervalUnit.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _intervalValue > 100 ? 100 : (_intervalValue < 1 ? 1 : _intervalValue),
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: _intervalValue > 100 ? '100+' : _intervalValue.toInt().toString(),
                          onChanged: (value) {
                            setState(() {
                              _isUpdatingFromSlider = true;
                              _intervalValue = value;
                              _intervalTextController.text = value.toInt().toString();
                              _isUpdatingFromSlider = false;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Interval Type',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Seconds'),
                              selected: _intervalUnit == IntervalUnit.seconds,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _intervalUnit = IntervalUnit.seconds;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Minutes'),
                              selected: _intervalUnit == IntervalUnit.minutes,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _intervalUnit = IntervalUnit.minutes;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Hours'),
                              selected: _intervalUnit == IntervalUnit.hours,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _intervalUnit = IntervalUnit.hours;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Days'),
                              selected: _intervalUnit == IntervalUnit.days,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _intervalUnit = IntervalUnit.days;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Track History'),
                  subtitle: const Text('Save logs when this reminder is marked as taken'),
                  value: _trackHistory,
                  onChanged: (value) {
                    setState(() {
                      _trackHistory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Water Reminder Behavior', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<WaterReminderBehavior>(
                  title: const Text('Continuous'),
                  subtitle: const Text('Keep reminding every interval'),
                  value: WaterReminderBehavior.continuous,
                  groupValue: _waterBehavior,
                  onChanged: (value) {
                    setState(() {
                      _waterBehavior = value!;
                    });
                  },
                ),
                RadioListTile<WaterReminderBehavior>(
                  title: const Text('Reset on Check'),
                  subtitle: const Text('Reset timer when marked as taken'),
                  value: WaterReminderBehavior.resetOnCheck,
                  groupValue: _waterBehavior,
                  onChanged: (value) {
                    setState(() {
                      _waterBehavior = value!;
                    });
                  },
                ),
                RadioListTile<WaterReminderBehavior>(
                  title: const Text('Pause Until Resumed'),
                  subtitle: const Text('Stop after taking, resume manually'),
                  value: WaterReminderBehavior.pauseUntilResumed,
                  groupValue: _waterBehavior,
                  onChanged: (value) {
                    setState(() {
                      _waterBehavior = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('End Date (optional)'),
                  subtitle: Text(_endDate != null ? _endDate.toString().split(' ')[0] : 'None'),
                  trailing: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _endDate = null;
                            });
                          },
                        )
                      : null,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Quiet Hours Start (optional)'),
                  subtitle: Text(_quietHoursStart?.toString() ?? 'None'),
                  trailing: _quietHoursStart != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _quietHoursStart = null;
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
                        _quietHoursStart = QuietTime(hour: time.hour, minute: time.minute);
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Quiet Hours End (optional)'),
                  subtitle: Text(_quietHoursEnd?.toString() ?? 'None'),
                  trailing: _quietHoursEnd != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _quietHoursEnd = null;
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
                        _quietHoursEnd = QuietTime(hour: time.hour, minute: time.minute);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Notification Sound (optional)'),
                  subtitle: Text(_notificationSound != null
                      ? _notificationSound!.split('/').last
                      : 'Default sound'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_notificationSound != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _notificationSound = null;
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.music_note),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.audio,
                          );
                          if (result != null && result.files.single.path != null) {
                            setState(() {
                              _notificationSound = result.files.single.path;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Text(
                      widget.reminder == null ? 'Create Reminder' : 'Update Reminder',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_intervalValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval must be greater than 0')),
      );
      return;
    }

    final provider = context.read<ReminderProvider>();

    // Auto-create default reminder type if it doesn't exist
    int reminderTypeId = _selectedTypeId ?? 0;
    if (reminderTypeId == 0 || provider.reminderTypes.isEmpty) {
      final defaultType = await provider.addReminderType(
        ReminderType(
          name: 'General Reminder',
          category: ReminderCategory.custom,
          color: '#2196F3',
          priority: 5,
        ),
      );
      reminderTypeId = defaultType?.id ?? 1;
    }

    final reminder = Reminder(
      id: widget.reminder?.id,
      reminderTypeId: reminderTypeId,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      intervalSeconds: _convertToSeconds(),
      isActive: _isActive,
      trackHistory: _trackHistory,
      endDate: _endDate,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
      waterBehavior: _waterBehavior,
      notificationSound: _notificationSound,
      medicationOptions: _medicationOptionsController.text.isEmpty ? null : _medicationOptionsController.text,
      startDate: widget.reminder?.startDate ?? DateTime.now(),
      lastTriggered: widget.reminder?.lastTriggered ?? DateTime.now(), // Keep existing lastTriggered if updating
    );

    if (widget.reminder == null) {
      await provider.addReminder(reminder);
    } else {
      await provider.updateReminder(reminder);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _createDefaultTypes(ReminderProvider provider) async {
    await provider.addReminderType(ReminderType(
      name: 'Water',
      category: ReminderCategory.water,
      color: '#2196F3',
      priority: 1,
    ));

    await provider.addReminderType(ReminderType(
      name: 'Pain Medication',
      category: ReminderCategory.medication,
      color: '#FF5722',
      priority: 10,
    ));

    await provider.addReminderType(ReminderType(
      name: 'Antibiotic',
      category: ReminderCategory.medication,
      color: '#4CAF50',
      priority: 9,
    ));

    await provider.addReminderType(ReminderType(
      name: 'Other Medication',
      category: ReminderCategory.medication,
      color: '#9C27B0',
      priority: 5,
    ));
  }
}
