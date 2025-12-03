import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import '../models/reminder_type.dart';
import '../models/medication_log.dart';
import '../models/app_settings.dart';
import '../services/reminder_service.dart';
import '../services/database_service.dart';

class ReminderProvider with ChangeNotifier {
  final _reminderService = ReminderService.instance;
  final _db = DatabaseService.instance;

  List<Reminder> _reminders = [];
  List<ReminderType> _reminderTypes = [];
  List<MedicationLog> _todayLogs = [];
  List<MedicationLog> _allLogs = [];

  bool _isLoading = false;

  List<Reminder> get reminders => _reminders;
  List<ReminderType> get reminderTypes => _reminderTypes;
  List<MedicationLog> get todayLogs => _todayLogs;
  List<MedicationLog> get allLogs => _allLogs;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _reminders = await _reminderService.getAllReminders();
      _reminderTypes = await _db.getAllReminderTypes();
      _todayLogs = await _reminderService.getTodayLogs();
      _allLogs = await _reminderService.getAllLogs();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    await _reminderService.createReminder(reminder);
    await loadData();
  }

  Future<void> updateReminder(Reminder reminder) async {
    await _reminderService.updateReminder(reminder);
    await loadData();
  }

  Future<void> deleteReminder(int reminderId) async {
    await _reminderService.deleteReminder(reminderId);
    await loadData();
  }

  Future<void> markTaken(int reminderId, {String? notes, String? dosageAmount}) async {
    await _reminderService.markReminderTaken(
      reminderId,
      notes: notes,
      dosageAmount: dosageAmount,
    );
    await loadData();
  }

  Future<void> skipReminder(int reminderId) async {
    await _reminderService.skipReminder(reminderId);
    await loadData();
  }

  Future<void> snoozeReminder(int reminderId, int minutes) async {
    await _reminderService.snoozeReminder(reminderId, minutes);
    await loadData();
  }

  Future<void> resumeWaterReminder(int reminderId) async {
    await _reminderService.resumeWaterReminder(reminderId);
    await loadData();
  }

  /// Mark a reminder as awaiting acknowledgment (called when alarm fires)
  Future<void> markAwaitingAcknowledgment(int reminderId) async {
    await _reminderService.markAwaitingAcknowledgment(reminderId);
    await loadData();
  }

  /// Clear awaiting acknowledgment flag (called when alarm screen is dismissed without action)
  Future<void> clearAwaitingAcknowledgment(int reminderId) async {
    await _reminderService.clearAwaitingAcknowledgment(reminderId);
    await loadData();
  }

  /// Clear all awaiting acknowledgment flags (called on manual refresh)
  Future<void> clearAllAwaitingAcknowledgments() async {
    await _reminderService.clearAllAwaitingAcknowledgments();
    await loadData();
  }

  Future<ReminderType?> addReminderType(ReminderType type) async {
    final createdType = await _db.createReminderType(type);
    await loadData();
    return createdType;
  }

  Future<void> updateReminderType(ReminderType type) async {
    await _db.updateReminderType(type);
    await loadData();
  }

  Future<void> deleteReminderType(int typeId) async {
    await _db.deleteReminderType(typeId);
    await loadData();
  }

  ReminderType? getReminderTypeById(int id) {
    try {
      return _reminderTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }

  List<MedicationLog> getLogsForReminder(int reminderId) {
    return _allLogs.where((log) => log.reminderId == reminderId).toList();
  }

  Future<AppSettings> getSettings() async {
    return await _db.getSettings();
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _db.updateSettings(settings);
    notifyListeners();
  }

  List<Reminder> get activeReminders {
    return _reminders.where((r) => r.isActive).toList();
  }

  List<Reminder> get inactiveReminders {
    return _reminders.where((r) => !r.isActive).toList();
  }

  List<MedicationLog> get missedDoses {
    final now = DateTime.now();
    final missed = <MedicationLog>[];

    for (final reminder in _reminders.where((r) => r.isActive)) {
      final lastLog = _todayLogs
          .where((log) => log.reminderId == reminder.id && log.action == LogAction.taken)
          .toList();

      if (lastLog.isEmpty && reminder.lastTriggered != null) {
        final timeSinceLastTrigger = now.difference(reminder.lastTriggered!);
        if (timeSinceLastTrigger.inSeconds > reminder.intervalSeconds * 1.5) {
          missed.add(MedicationLog(
            reminderId: reminder.id!,
            timestamp: reminder.lastTriggered!,
            action: LogAction.skipped,
            notes: 'Potentially missed',
          ));
        }
      }
    }

    return missed;
  }

  /// Reschedule all active reminders - useful after app restart or resume
  Future<void> rescheduleAllReminders() async {
    print('[PROVIDER] Rescheduling all active reminders...');
    await _reminderService.checkAndScheduleReminders();
    print('[PROVIDER] ✓ All reminders rescheduled');
  }
}
