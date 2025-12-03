import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../models/medication_log.dart';
import '../providers/reminder_provider.dart';
import '../services/alarm_sound_service.dart';
import '../services/reminder_service.dart';

class AlarmScreen extends StatefulWidget {
  final int reminderId;
  final String title;
  final String? description;
  final DateTime? triggerTime; // The exact time this alarm was scheduled to trigger

  // Track which alarms currently have screens showing
  static final Set<int> _activeAlarmScreens = {};

  const AlarmScreen({
    super.key,
    required this.reminderId,
    required this.title,
    this.description,
    this.triggerTime,
  });

  // Check if alarm screen is already showing for this reminder
  static bool isAlarmScreenShowing(int reminderId) {
    return _activeAlarmScreens.contains(reminderId);
  }

  // Check if ANY alarm screen is currently showing
  static bool isAnyAlarmScreenShowing() {
    return _activeAlarmScreens.isNotEmpty;
  }

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _elapsedTimer;
  String _elapsedTime = '';
  String _runtime = '0s';
  late DateTime _screenOpenedAt;
  Reminder? _reminder;
  MedicationLog? _lastLog;
  Set<String> _selectedOptions = {};
  bool _actionTaken = false; // Track if user took action (mark taken, skip, snooze)

  @override
  void initState() {
    super.initState();
    // Register this alarm screen as active
    AlarmScreen._activeAlarmScreens.add(widget.reminderId);

    _screenOpenedAt = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _loadReminderData();
    _startElapsedTimer();
    _startAlarmSound();
  }

  void _startAlarmSound() {
    print('[ALARM SCREEN] _startAlarmSound() called');
    AlarmSoundService.instance.playAlarm();
  }

  void _stopAlarmSound() {
    print('[ALARM SCREEN] _stopAlarmSound() called');
    AlarmSoundService.instance.stopAlarm();
  }

  void _loadReminderData() async {
    final provider = context.read<ReminderProvider>();
    final reminder = provider.reminders.firstWhere((r) => r.id == widget.reminderId);
    final logs = provider.getLogsForReminder(widget.reminderId);

    setState(() {
      _reminder = reminder;
      if (logs.isNotEmpty) {
        _lastLog = logs.first; // Most recent log
      }
    });
  }

  void _startElapsedTimer() {
    _updateElapsedTime();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateElapsedTime();
    });
  }

  void _updateElapsedTime() {
    final now = DateTime.now();

    // Update runtime (how long alarm screen has been open)
    final runtimeDuration = now.difference(_screenOpenedAt);
    String runtime;
    if (runtimeDuration.inMinutes < 1) {
      runtime = '${runtimeDuration.inSeconds}s';
    } else if (runtimeDuration.inMinutes < 60) {
      final secs = runtimeDuration.inSeconds % 60;
      runtime = '${runtimeDuration.inMinutes}m ${secs}s';
    } else {
      final hours = runtimeDuration.inHours;
      final mins = runtimeDuration.inMinutes % 60;
      runtime = '${hours}h ${mins}m';
    }

    // Update elapsed time since alarm was due
    // Use triggerTime if provided (from notification), otherwise calculate it
    DateTime nextTrigger;

    if (widget.triggerTime != null) {
      // Use provided trigger time from notification
      nextTrigger = widget.triggerTime!;
      print('[ALARM SCREEN] Using widget.triggerTime: $nextTrigger');
      print('[ALARM SCREEN] Current time: $now');
      print('[ALARM SCREEN] Difference: ${now.difference(nextTrigger).inSeconds} seconds');
    } else {
      // Calculate it ourselves (fallback - should always have widget.triggerTime from payload)
      if (_reminder == null || _reminder!.lastTriggered == null) {
        if (mounted) {
          setState(() {
            _runtime = runtime;
          });
        }
        return;
      }

      // Calculate the next trigger time WITHOUT skipping forward
      // This should match what the notification used for the chronometer
      nextTrigger = _reminder!.lastTriggered!.add(
        Duration(seconds: _reminder!.intervalSeconds),
      );

      print('[ALARM SCREEN] Fallback: calculated nextTrigger from lastTriggered: $nextTrigger');
    }

    // Calculate how long ago the alarm was due
    final diff = now.difference(nextTrigger);
    final elapsed = diff.abs();

    if (mounted) {
      setState(() {
        _runtime = runtime;
        if (diff.isNegative) {
          _elapsedTime = 'Upcoming';
        } else if (elapsed.inMinutes < 1) {
          _elapsedTime = '${elapsed.inSeconds} seconds ago';
        } else if (elapsed.inMinutes < 60) {
          _elapsedTime = '${elapsed.inMinutes} minute${elapsed.inMinutes > 1 ? 's' : ''} ago';
        } else {
          final hours = elapsed.inHours;
          final mins = elapsed.inMinutes % 60;
          _elapsedTime = '$hours hour${hours > 1 ? 's' : ''} ${mins}m ago';
        }
      });
    }
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      final minutes = seconds / 60;
      return '${minutes.toStringAsFixed(minutes % 1 == 0 ? 0 : 1)} min';
    } else if (seconds < 86400) {
      final hours = seconds / 3600;
      return '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} hr';
    } else {
      final days = seconds / 86400;
      return '${days.toStringAsFixed(days % 1 == 0 ? 0 : 1)} day';
    }
  }

  @override
  void dispose() {
    // Unregister this alarm screen as active
    AlarmScreen._activeAlarmScreens.remove(widget.reminderId);

    _stopAlarmSound();
    _animationController.dispose();
    _elapsedTimer?.cancel();

    // If user dismissed without taking action, clear the awaitingAcknowledgment flag
    // so the alarm can trigger again
    if (!_actionTaken) {
      print('[ALARM SCREEN] User dismissed without action, clearing awaitingAcknowledgment');
      // Schedule async cleanup - can't await in dispose
      ReminderService.instance.clearAwaitingAcknowledgment(widget.reminderId);
    }

    super.dispose();
  }

  Future<void> _handleMarkTaken() async {
    _actionTaken = true;
    _stopAlarmSound();
    final provider = context.read<ReminderProvider>();
    final selectedMeds = _selectedOptions.join(', ');
    await provider.markTaken(
      widget.reminderId,
      notes: selectedMeds.isNotEmpty ? selectedMeds : null,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSnooze(int minutes) async {
    _actionTaken = true;
    _stopAlarmSound();
    final provider = context.read<ReminderProvider>();
    await provider.snoozeReminder(widget.reminderId, minutes);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSkip() async {
    _actionTaken = true;
    _stopAlarmSound();
    final provider = context.read<ReminderProvider>();
    await provider.skipReminder(widget.reminderId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _reminder?.medicationOptions?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Icon(
                    Icons.alarm,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Badges row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Elapsed time since alarm was due
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.orange.shade900),
                          const SizedBox(width: 6),
                          Text(
                            _elapsedTime,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Runtime (alarm screen open duration)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 16, color: Colors.red.shade900),
                          const SizedBox(width: 6),
                          Text(
                            _runtime,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_reminder != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Every ${_formatInterval(_reminder!.intervalSeconds)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (widget.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                // Last medication taken
                if (_lastLog != null && _lastLog!.notes != null && _lastLog!.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Last: ${_lastLog!.notes}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.jm().format(_lastLog!.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Medication options checkboxes
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Medication:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...options.map((option) {
                          return CheckboxListTile(
                            title: Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                            value: _selectedOptions.contains(option),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedOptions.add(option);
                                } else {
                                  _selectedOptions.remove(option);
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _handleMarkTaken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text(
                      'Mark as Taken',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleSnooze(5),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '5 min',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleSnooze(10),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '10 min',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleSnooze(15),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '15 min',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _handleSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
