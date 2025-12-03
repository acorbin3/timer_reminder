import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reminder_provider.dart';
import '../models/medication_log.dart';
import '../models/reminder.dart';
import 'reminder_form_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ReminderProvider>();
      await provider.loadData();
      // Reschedule all notifications to ensure they're active after reload
      await provider.rescheduleAllReminders();
    });
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer Reminder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.clearAllAwaitingAcknowledgments();
              await provider.loadData();
              await provider.rescheduleAllReminders();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMissedDosesSection(provider),
                const SizedBox(height: 16),
                _buildTodayLogsSection(provider),
                const SizedBox(height: 16),
                _buildActiveRemindersSection(provider),
                const SizedBox(height: 16),
                _buildInactiveRemindersSection(provider),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReminderFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMissedDosesSection(ReminderProvider provider) {
    final missed = provider.missedDoses;

    if (missed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Missed Doses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...missed.map((log) {
              final reminder = provider.reminders
                  .where((r) => r.id == log.reminderId)
                  .firstOrNull;
              if (reminder == null) return const SizedBox.shrink();

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reminder.title),
                subtitle: Text('Expected: ${DateFormat.jm().format(log.timestamp)}'),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayLogsSection(ReminderProvider provider) {
    final logs = provider.todayLogs;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Today\'s Activity',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: logs.isEmpty
          ? const Text('No activity yet today', style: TextStyle(fontSize: 12))
          : Text('${logs.length} ${logs.length == 1 ? 'entry' : 'entries'}', style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                if (logs.isEmpty)
                  const SizedBox.shrink()
                else
                  ...logs.map((log) {
                    final reminder = provider.reminders
                        .where((r) => r.id == log.reminderId)
                        .firstOrNull;
                    if (reminder == null) return const SizedBox.shrink();

                    IconData icon;
                    Color color;
                    switch (log.action) {
                      case LogAction.taken:
                        icon = Icons.check_circle;
                        color = Colors.green;
                        break;
                      case LogAction.skipped:
                        icon = Icons.cancel;
                        color = Colors.orange;
                        break;
                      case LogAction.snoozed:
                        icon = Icons.snooze;
                        color = Colors.blue;
                        break;
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: color),
                      title: Text(reminder.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat.jm().format(log.timestamp)),
                          if (log.notes != null) Text(log.notes!, style: const TextStyle(fontSize: 12)),
                          if (log.dosageAmount != null)
                            Text('Amount: ${log.dosageAmount}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRemindersSection(ReminderProvider provider) {
    final activeReminders = provider.activeReminders;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (activeReminders.isEmpty)
              const Text('No active reminders')
            else
              ...activeReminders.map((reminder) {
                return _buildReminderCard(reminder, provider);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, ReminderProvider provider) {
    final nextTime = _calculateNextReminderTime(reminder);
    final now = DateTime.now();
    final timeUntilNext = nextTime?.difference(now);

    // Check if this reminder was recently snoozed
    final logs = provider.getLogsForReminder(reminder.id!);
    final lastLog = logs.isNotEmpty ? logs.first : null;
    final isSnoozed = lastLog?.action == LogAction.snoozed &&
        now.difference(lastLog!.timestamp).inMinutes < 30; // Consider snoozed if within last 30 min

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReminderFormScreen(reminder: reminder),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Every ${_formatInterval(reminder.intervalSeconds)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.pause, size: 20),
                        tooltip: 'Pause',
                        onPressed: () async {
                          final updatedReminder = reminder.copyWith(isActive: false);
                          await provider.updateReminder(updatedReminder);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Reset Timer',
                        onPressed: () async {
                          final updatedReminder = reminder.copyWith(
                            lastTriggered: DateTime.now(),
                          );
                          await provider.updateReminder(updatedReminder);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (timeUntilNext != null && !timeUntilNext.isNegative) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSnoozed
                      ? Colors.orange.shade100
                      : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSnoozed ? Icons.snooze : Icons.timer_outlined,
                            size: 16,
                            color: isSnoozed ? Colors.orange.shade900 : Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSnoozed ? 'Snoozed for:' : 'Next in:',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSnoozed ? Colors.orange.shade900 : Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCountdown(timeUntilNext),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSnoozed ? Colors.orange.shade900 : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _calculateNextReminderTime(Reminder reminder) {
    final now = DateTime.now();
    if (!reminder.shouldTrigger(now)) return null;

    final lastTrigger = reminder.lastTriggered ?? now;
    var nextTime = lastTrigger.add(Duration(seconds: reminder.intervalSeconds));

    while (nextTime.isBefore(now)) {
      nextTime = nextTime.add(Duration(seconds: reminder.intervalSeconds));
    }

    if (reminder.isInQuietHours(nextTime)) {
      if (reminder.quietHoursEnd != null) {
        nextTime = DateTime(
          nextTime.year,
          nextTime.month,
          nextTime.day,
          reminder.quietHoursEnd!.hour,
          reminder.quietHoursEnd!.minute,
        );
        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
      }
    }

    return nextTime;
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

  Widget _buildInactiveRemindersSection(ReminderProvider provider) {
    final inactiveReminders = provider.inactiveReminders;

    if (inactiveReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paused Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...inactiveReminders.map((reminder) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reminder.title),
                subtitle: Text('Every ${_formatInterval(reminder.intervalSeconds)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Resume',
                  onPressed: () {
                    provider.resumeWaterReminder(reminder.id!);
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReminderFormScreen(reminder: reminder),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
