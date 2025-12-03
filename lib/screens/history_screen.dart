import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reminder_provider.dart';
import '../models/medication_log.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final logs = provider.allLogs;

          if (logs.isEmpty) {
            return const Center(
              child: Text('No history available'),
            );
          }

          final groupedLogs = _groupLogsByDate(logs);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedLogs.length,
            itemBuilder: (context, index) {
              final date = groupedLogs.keys.elementAt(index);
              final logsForDate = groupedLogs[date]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...logsForDate.map((log) {
                      final reminder = provider.reminders
                          .where((r) => r.id == log.reminderId)
                          .firstOrNull;

                      if (reminder == null) {
                        return const SizedBox.shrink();
                      }

                      IconData icon;
                      Color color;
                      String actionText;

                      switch (log.action) {
                        case LogAction.taken:
                          icon = Icons.check_circle;
                          color = Colors.green;
                          actionText = 'Taken';
                          break;
                        case LogAction.skipped:
                          icon = Icons.cancel;
                          color = Colors.orange;
                          actionText = 'Skipped';
                          break;
                        case LogAction.snoozed:
                          icon = Icons.snooze;
                          color = Colors.blue;
                          actionText = 'Snoozed';
                          break;
                      }

                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(reminder.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$actionText at ${DateFormat.jm().format(log.timestamp)}'),
                            if (log.dosageAmount != null)
                              Text('Amount: ${log.dosageAmount}'),
                            if (log.notes != null)
                              Text(
                                log.notes!,
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<MedicationLog>> _groupLogsByDate(List<MedicationLog> logs) {
    final grouped = <DateTime, List<MedicationLog>>{};

    for (final log in logs) {
      final date = DateTime(
        log.timestamp.year,
        log.timestamp.month,
        log.timestamp.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }

      grouped[date]!.add(log);
    }

    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMMd().format(date);
    }
  }
}
