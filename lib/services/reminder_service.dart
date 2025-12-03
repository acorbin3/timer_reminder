import 'package:workmanager/workmanager.dart';
import '../models/reminder.dart';
import '../models/medication_log.dart';
import 'database_service.dart';
import 'notification_service.dart';

class ReminderService {
  static final ReminderService instance = ReminderService._init();
  final _db = DatabaseService.instance;
  final _notifications = NotificationService.instance;

  ReminderService._init();

  Future<void> initializeBackgroundTasks() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );

    await Workmanager().registerPeriodicTask(
      "reminder-check",
      "checkReminders",
      frequency: const Duration(minutes: 15),
    );
  }

  Future<void> checkAndScheduleReminders() async {
    print('[REMINDER SERVICE] Checking and scheduling reminders...');
    final reminders = await _db.getActiveReminders();
    final now = DateTime.now();

    print('[REMINDER SERVICE] Found ${reminders.length} active reminders');

    for (final reminder in reminders) {
      print('[REMINDER SERVICE] Checking reminder ${reminder.id} (${reminder.title})');
      print('[REMINDER SERVICE]   - Should trigger: ${reminder.shouldTrigger(now)}');
      print('[REMINDER SERVICE]   - Awaiting acknowledgment: ${reminder.awaitingAcknowledgment}');

      // Skip reminders that are awaiting user acknowledgment
      if (reminder.awaitingAcknowledgment) {
        print('[REMINDER SERVICE]   - Skipping, awaiting acknowledgment');
        continue;
      }

      if (reminder.shouldTrigger(now)) {
        final reminderType = await _db.getReminderType(reminder.reminderTypeId);
        if (reminderType != null) {
          print('[REMINDER SERVICE]   - Scheduling notification for ${reminder.title}');
          await _notifications.scheduleReminder(reminder, reminderType);
        } else {
          print('[REMINDER SERVICE]   - No reminder type found for ${reminder.reminderTypeId}');
        }
      }
    }

    print('[REMINDER SERVICE] ✓ Finished checking reminders');
  }

  /// Mark a reminder as awaiting acknowledgment (called when alarm fires)
  Future<void> markAwaitingAcknowledgment(int reminderId) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    print('[REMINDER SERVICE] Marking reminder ${reminder.title} as awaiting acknowledgment');
    final updatedReminder = reminder.copyWith(awaitingAcknowledgment: true);
    await _db.updateReminder(updatedReminder);
  }

  /// Clear awaiting acknowledgment flag (called when alarm screen is dismissed without action)
  Future<void> clearAwaitingAcknowledgment(int reminderId) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    print('[REMINDER SERVICE] Clearing awaiting acknowledgment for ${reminder.title}');
    final updatedReminder = reminder.copyWith(awaitingAcknowledgment: false);
    await _db.updateReminder(updatedReminder);
  }

  /// Clear all awaiting acknowledgment flags (called on manual refresh)
  Future<void> clearAllAwaitingAcknowledgments() async {
    final reminders = await _db.getAllReminders();
    int clearedCount = 0;
    for (final reminder in reminders) {
      if (reminder.awaitingAcknowledgment) {
        final updatedReminder = reminder.copyWith(awaitingAcknowledgment: false);
        await _db.updateReminder(updatedReminder);
        clearedCount++;
        print('[REMINDER SERVICE] Cleared awaiting acknowledgment for ${reminder.title}');
      }
    }
    if (clearedCount > 0) {
      print('[REMINDER SERVICE] ✓ Cleared $clearedCount awaiting acknowledgments');
    }
  }

  Future<void> markReminderTaken(int reminderId, {String? notes, String? dosageAmount}) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    print('[REMINDER SERVICE] Marking reminder ${reminder.title} as taken');

    if (reminder.trackHistory) {
      await _db.createLog(
        MedicationLog(
          reminderId: reminderId,
          timestamp: DateTime.now(),
          action: LogAction.taken,
          notes: notes,
          dosageAmount: dosageAmount,
        ),
      );
    }

    if (reminder.waterBehavior == WaterReminderBehavior.pauseUntilResumed) {
      // Pause until manually resumed - don't schedule next alarm
      final updatedReminder = reminder.copyWith(
        isActive: false,
        awaitingAcknowledgment: false,
      );
      await _db.updateReminder(updatedReminder);
      await _notifications.cancelReminder(reminderId);
      print('[REMINDER SERVICE] ✓ Reminder paused until resumed');
    } else {
      // Clear awaiting flag and schedule next alarm
      final updatedReminder = reminder.copyWith(
        lastTriggered: DateTime.now(),
        awaitingAcknowledgment: false,
      );
      await _db.updateReminder(updatedReminder);

      final reminderType = await _db.getReminderType(reminder.reminderTypeId);
      if (reminderType != null) {
        await _notifications.scheduleReminder(updatedReminder, reminderType);
        print('[REMINDER SERVICE] ✓ Next alarm scheduled');
      }
    }
  }

  Future<void> skipReminder(int reminderId) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    print('[REMINDER SERVICE] Skipping reminder ${reminder.title}');

    if (reminder.trackHistory) {
      await _db.createLog(
        MedicationLog(
          reminderId: reminderId,
          timestamp: DateTime.now(),
          action: LogAction.skipped,
        ),
      );
    }

    // Clear awaiting flag and schedule next alarm
    final updatedReminder = reminder.copyWith(
      lastTriggered: DateTime.now(),
      awaitingAcknowledgment: false,
    );
    await _db.updateReminder(updatedReminder);

    await _notifications.cancelReminder(reminderId);
    final reminderType = await _db.getReminderType(reminder.reminderTypeId);
    if (reminderType != null) {
      await _notifications.scheduleReminder(updatedReminder, reminderType);
      print('[REMINDER SERVICE] ✓ Next alarm scheduled after skip');
    }
  }

  Future<void> snoozeReminder(int reminderId, int minutes) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    final now = DateTime.now();
    final snoozeUntil = now.add(Duration(minutes: minutes));

    print('[REMINDER SERVICE] Snoozing reminder ${reminder.title} for $minutes minutes');
    print('[REMINDER SERVICE] Current time: $now');
    print('[REMINDER SERVICE] Will trigger at: $snoozeUntil');

    if (reminder.trackHistory) {
      await _db.createLog(
        MedicationLog(
          reminderId: reminderId,
          timestamp: now,
          action: LogAction.snoozed,
          notes: 'Snoozed for $minutes minutes',
        ),
      );
    }

    await _notifications.cancelReminder(reminderId);

    // Set lastTriggered so that the next trigger is exactly snoozeUntil
    // Formula: lastTriggered + intervalSeconds = snoozeUntil
    // Therefore: lastTriggered = snoozeUntil - intervalSeconds
    // Clear awaitingAcknowledgment since user acknowledged by snoozing
    final snoozedReminder = reminder.copyWith(
      lastTriggered: snoozeUntil.subtract(Duration(seconds: reminder.intervalSeconds)),
      awaitingAcknowledgment: false,
    );

    print('[REMINDER SERVICE] Setting lastTriggered to: ${snoozedReminder.lastTriggered}');

    await _db.updateReminder(snoozedReminder);

    final reminderType = await _db.getReminderType(reminder.reminderTypeId);
    if (reminderType != null) {
      await _notifications.scheduleReminder(snoozedReminder, reminderType);
    }

    print('[REMINDER SERVICE] ✓ Reminder snoozed successfully');
  }

  Future<void> resumeWaterReminder(int reminderId) async {
    final reminder = await _db.getReminder(reminderId);
    if (reminder == null) return;

    final updatedReminder = reminder.copyWith(
      isActive: true,
      lastTriggered: DateTime.now(),
    );

    await _db.updateReminder(updatedReminder);

    final reminderType = await _db.getReminderType(reminder.reminderTypeId);
    if (reminderType != null) {
      await _notifications.scheduleReminder(updatedReminder, reminderType);
    }
  }

  Future<void> createReminder(Reminder reminder) async {
    print('[REMINDER SERVICE] Creating new reminder: ${reminder.title}');
    final newReminder = await _db.createReminder(reminder);
    final reminderType = await _db.getReminderType(reminder.reminderTypeId);
    if (reminderType != null && newReminder.isActive) {
      await _notifications.scheduleReminder(newReminder, reminderType);
    }
    print('[REMINDER SERVICE] ✓ Reminder created and scheduled');
  }

  Future<void> updateReminder(Reminder reminder) async {
    print('[REMINDER SERVICE] Updating reminder: ${reminder.title}');
    await _db.updateReminder(reminder);
    final reminderType = await _db.getReminderType(reminder.reminderTypeId);
    if (reminderType != null) {
      if (reminder.isActive) {
        await _notifications.scheduleReminder(reminder, reminderType);
      } else {
        await _notifications.cancelReminder(reminder.id!);
      }
    }
    print('[REMINDER SERVICE] ✓ Reminder updated and rescheduled');
  }

  Future<void> deleteReminder(int reminderId) async {
    await _notifications.cancelReminder(reminderId);
    await _db.deleteReminder(reminderId);
  }

  Future<List<Reminder>> getAllReminders() async {
    return await _db.getAllReminders();
  }

  Future<List<MedicationLog>> getTodayLogs() async {
    return await _db.getTodayLogs();
  }

  Future<List<MedicationLog>> getAllLogs() async {
    return await _db.getAllLogs();
  }

  Future<List<MedicationLog>> getLogsByReminder(int reminderId) async {
    return await _db.getLogsByReminder(reminderId);
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[WORKMANAGER] Background task triggered: $task');
    try {
      switch (task) {
        case 'checkReminders':
          print('[WORKMANAGER] Running checkReminders task');
          await ReminderService.instance.checkAndScheduleReminders();
          print('[WORKMANAGER] ✓ checkReminders task completed');
          break;
        default:
          print('[WORKMANAGER] Unknown task: $task');
      }
      return Future.value(true);
    } catch (e) {
      print('[WORKMANAGER] ERROR in task $task: $e');
      return Future.value(false);
    }
  });
}
