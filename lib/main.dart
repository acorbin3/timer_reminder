import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/reminder.dart';
import 'providers/reminder_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alarm_screen.dart';
import 'services/notification_service.dart';
import 'services/reminder_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Track app lifecycle to detect when coming from background
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[LIFECYCLE] App state changed to: $state');
    if (state == AppLifecycleState.resumed) {
      print('[LIFECYCLE] App resumed - rescheduling notifications and checking for pending alarms');
      // App came to foreground, reschedule all notifications and check for due reminders
      _onAppResumed();
    }
  }
}

// Called when app resumes from background or after reload
void _onAppResumed() async {
  final context = navigatorKey.currentContext;
  if (context != null) {
    try {
      final provider = context.read<ReminderProvider>();
      await provider.rescheduleAllReminders();
      print('[LIFECYCLE] ✓ Notifications rescheduled');
    } catch (e) {
      print('[LIFECYCLE] Error rescheduling notifications: $e');
    }
  }
  _checkForDueReminders();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register lifecycle observer
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  print('[MAIN] Lifecycle observer registered');

  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();
  await ReminderService.instance.initializeBackgroundTasks();

  // Check every second if any reminders are due and auto-show alarm
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    _checkForDueReminders();
  });

  // Set up notification callbacks
  NotificationService.onShowAlarm = (reminderId, title, description, triggerTime) async {
    print('[MAIN] onShowAlarm callback triggered for reminder $reminderId: $title');

    // Don't show duplicate alarm screen if one is already showing or queued
    if (AlarmScreen.isAlarmScreenShowing(reminderId)) {
      print('[MAIN] Alarm screen already showing for $reminderId, ignoring notification tap');
      return;
    }
    if (AlarmScreen.isAnyAlarmScreenShowing()) {
      print('[MAIN] Another alarm screen is showing, ignoring notification tap for $reminderId');
      return;
    }
    if (_shownAlarms.contains(reminderId)) {
      print('[MAIN] Alarm already in _shownAlarms for $reminderId, ignoring notification tap');
      return;
    }

    // Add to shown alarms immediately to prevent race conditions
    _shownAlarms.add(reminderId);

    final context = navigatorKey.currentContext;
    if (context == null) {
      print('[MAIN] No context available for navigation');
      _shownAlarms.remove(reminderId);
      return;
    }

    // Mark reminder as awaiting acknowledgment - prevents new alarms until user responds
    final provider = context.read<ReminderProvider>();
    await provider.markAwaitingAcknowledgment(reminderId);

    // Check context is still valid after async operation
    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      print('[MAIN] Context no longer available after async operation');
      _shownAlarms.remove(reminderId);
      return;
    }

    print('[MAIN] Navigating to AlarmScreen with trigger time: $triggerTime');
    Navigator.of(navContext).push(
      MaterialPageRoute(
        builder: (context) => AlarmScreen(
          reminderId: reminderId,
          title: title,
          description: description,
          triggerTime: triggerTime, // Pass the trigger time from notification payload
        ),
      ),
    ).then((_) {
      _shownAlarms.remove(reminderId);
      print('[MAIN] Alarm screen closed from notification, removed $reminderId from shown alarms');
    });
  };

  NotificationService.onMarkTaken = (reminderId) async {
    print('[MAIN] onMarkTaken callback triggered for reminder $reminderId');
    // Clear from shown alarms so it can trigger again after interval
    _shownAlarms.remove(reminderId);
    final context = navigatorKey.currentContext;
    if (context != null) {
      final provider = context.read<ReminderProvider>();
      await provider.markTaken(reminderId);
      print('[MAIN] ✓ Reminder marked as taken');
    }
  };

  NotificationService.onSkip = (reminderId) async {
    print('[MAIN] onSkip callback triggered for reminder $reminderId');
    // Clear from shown alarms so it can trigger again after interval
    _shownAlarms.remove(reminderId);
    final context = navigatorKey.currentContext;
    if (context != null) {
      final provider = context.read<ReminderProvider>();
      await provider.skipReminder(reminderId);
      print('[MAIN] ✓ Reminder skipped');
    }
  };

  NotificationService.onSnooze = (reminderId, minutes) async {
    print('[MAIN] onSnooze callback triggered for reminder $reminderId ($minutes min)');
    // Clear from shown alarms so it can trigger again after snooze
    _shownAlarms.remove(reminderId);
    final context = navigatorKey.currentContext;
    if (context != null) {
      final provider = context.read<ReminderProvider>();
      await provider.snoozeReminder(reminderId, minutes);
      print('[MAIN] ✓ Reminder snoozed for $minutes minutes');
    }
  };

  runApp(const MyApp());
}

Set<int> _shownAlarms = {};
DateTime _lastCheck = DateTime.now();

void _checkForDueReminders() async {
  try {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('[ALARM CHECK] No navigator context available');
      return;
    }

    final provider = context.read<ReminderProvider>();
    final now = DateTime.now();

    // Only check once per second
    if (now.difference(_lastCheck).inSeconds < 1) return;
    _lastCheck = now;

    // Silenced verbose logging - only log when alarm is about to trigger
    // print('[ALARM CHECK] Checking ${provider.activeReminders.length} active reminders at ${now.toString()}');

    for (final reminder in provider.activeReminders) {
      // Skip reminders already awaiting acknowledgment
      if (reminder.awaitingAcknowledgment) {
        continue;
      }

      if (reminder.lastTriggered == null) {
        // print('[ALARM CHECK] Reminder ${reminder.id} (${reminder.title}) has no lastTriggered, skipping');
        continue;
      }

      // Calculate the next trigger time
      var nextTrigger = reminder.lastTriggered!.add(
        Duration(seconds: reminder.intervalSeconds),
      );

      // For resetOnCheck: DON'T skip past missed intervals
      // Wait for user to acknowledge before scheduling next one
      if (reminder.waterBehavior == WaterReminderBehavior.resetOnCheck) {
        // If the alarm time has passed and screen is showing, don't trigger again
        if (nextTrigger.isBefore(now) && AlarmScreen.isAlarmScreenShowing(reminder.id!)) {
          // print('[ALARM CHECK] resetOnCheck: Alarm screen showing, waiting for acknowledgment');
          continue;
        }
        // If alarm time has passed and it was already shown, don't show again until acknowledged
        if (nextTrigger.isBefore(now) && _shownAlarms.contains(reminder.id)) {
          // print('[ALARM CHECK] resetOnCheck: Alarm already triggered, waiting for acknowledgment');
          continue;
        }
      } else {
        // For continuous/pauseUntilResumed: skip past missed intervals to find next future trigger
        while (nextTrigger.isBefore(now)) {
          nextTrigger = nextTrigger.add(Duration(seconds: reminder.intervalSeconds));
        }
      }

      // Check if reminder is due (within next 5 seconds OR overdue by up to 30 seconds)
      final diff = nextTrigger.difference(now).inSeconds;

      // Silenced verbose logging - only log when showing alarm
      // print('[ALARM CHECK] Reminder ${reminder.id} (${reminder.title}):');
      // print('  - Last triggered: ${reminder.lastTriggered}');
      // print('  - Next trigger: $nextTrigger');
      // print('  - Seconds until trigger: $diff');
      // print('  - Water behavior: ${reminder.waterBehavior}');
      // print('  - Already shown: ${_shownAlarms.contains(reminder.id)}');

      // Show if upcoming (0-5 sec) OR recently passed (overdue by 0-30 sec)
      if (diff >= -30 && diff <= 5) {
        // Only show if:
        // 1. Not already in shown alarms set
        // 2. Not already showing alarm screen for this reminder
        // 3. No other alarm screen is currently showing (prevent stacking)
        if (!_shownAlarms.contains(reminder.id) &&
            !AlarmScreen.isAlarmScreenShowing(reminder.id!) &&
            !AlarmScreen.isAnyAlarmScreenShowing()) {
          _shownAlarms.add(reminder.id!);

          print('[ALARM CHECK] *** SHOWING ALARM for ${reminder.title} ***');
          print('[ALARM CHECK] Trigger time: $nextTrigger');
          print('[ALARM CHECK] Current time: $now');
          print('[ALARM CHECK] Time difference: ${now.difference(nextTrigger).inSeconds} seconds');

          // Mark reminder as awaiting acknowledgment - prevents new alarms until user responds
          final provider = context.read<ReminderProvider>();
          await provider.markAwaitingAcknowledgment(reminder.id!);

          // Fire notification immediately so both alarm screen AND notification show
          final reminderType = provider.getReminderTypeById(reminder.reminderTypeId);
          if (reminderType != null) {
            await NotificationService.instance.showImmediateNotification(reminder, reminderType, nextTrigger);
          }

          // Check context is still valid after async operation
          final navContext = navigatorKey.currentContext;
          if (navContext == null) {
            print('[ALARM CHECK] Context no longer available after async operation');
            return;
          }

          // Auto-show alarm screen with exact trigger time
          Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (context) => AlarmScreen(
                reminderId: reminder.id!,
                title: reminder.title,
                description: reminder.description,
                triggerTime: nextTrigger, // Pass the exact trigger time
              ),
            ),
          ).then((_) {
            // Only remove from shown alarms when the alarm screen is closed
            // This happens when user acknowledges (mark taken, skip, snooze)
            _shownAlarms.remove(reminder.id);
            print('[ALARM CHECK] Alarm screen closed, removed ${reminder.id} from shown alarms');
          });
        } else {
          if (AlarmScreen.isAnyAlarmScreenShowing()) {
            // Silent - don't spam logs when another alarm is showing
          } else if (AlarmScreen.isAlarmScreenShowing(reminder.id!)) {
            // Silent - alarm screen is showing for this reminder
          } else if (_shownAlarms.contains(reminder.id)) {
            // Silent - alarm was already shown, waiting for acknowledgment
          }
        }
      }
    }
  } catch (e) {
    print('[ALARM CHECK] ERROR: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReminderProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Timer Reminder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
