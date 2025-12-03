import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../models/reminder_type.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create high-priority notification channel for alarms
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      print('[NOTIFICATION] Creating alarm notification channel');
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'alarm_channel',
          'Alarm Reminders',
          description: 'High priority alarm notifications',
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm_sound'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFFFF0000),
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }
  }

  Future<bool> requestPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosImpl = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    bool? androidGranted;
    bool? iosGranted;

    if (androidImpl != null) {
      androidGranted = await androidImpl.requestNotificationsPermission();
    }

    if (iosImpl != null) {
      iosGranted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  static Function(int reminderId)? onMarkTaken;
  static Function(int reminderId)? onSkip;
  static Function(int reminderId, int minutes)? onSnooze;
  static Function(int reminderId, String title, String? description, DateTime? triggerTime)? onShowAlarm;

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    print('[NOTIFICATION BACKGROUND] Notification tapped in background!');
    final payload = response.payload;
    if (payload == null) return;

    print('[NOTIFICATION BACKGROUND] Payload: $payload');
    final parts = payload.split('|');
    final reminderId = int.parse(parts[0]);
    final title = parts.length > 2 ? parts[2] : 'Reminder';
    final description = parts.length > 3 ? parts[3] : null;
    final triggerTime = parts.length > 4
      ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]))
      : null;

    print('[NOTIFICATION BACKGROUND] Triggering alarm for $title');
    print('[NOTIFICATION BACKGROUND] Trigger time from payload: $triggerTime');
    if (triggerTime != null) {
      print('[NOTIFICATION BACKGROUND] Time difference: ${DateTime.now().difference(triggerTime).inSeconds} seconds');
    }
    onShowAlarm?.call(reminderId, title, description, triggerTime);
  }

  void _onNotificationTapped(NotificationResponse response) async {
    print('[NOTIFICATION] Notification tapped!');
    final payload = response.payload;
    if (payload == null) {
      print('[NOTIFICATION] No payload in notification');
      return;
    }

    print('[NOTIFICATION] Payload: $payload');
    final parts = payload.split('|');
    final action = response.actionId;
    final reminderId = int.parse(parts[0]);

    print('[NOTIFICATION] Action: $action, Reminder ID: $reminderId');

    if (action == 'mark_taken') {
      print('[NOTIFICATION] Calling onMarkTaken');
      onMarkTaken?.call(reminderId);
    } else if (action == 'skip') {
      print('[NOTIFICATION] Calling onSkip');
      onSkip?.call(reminderId);
    } else if (action?.startsWith('snooze_') == true) {
      final minutes = int.parse(action!.split('_')[1]);
      print('[NOTIFICATION] Calling onSnooze with $minutes minutes');
      onSnooze?.call(reminderId, minutes);
    } else {
      // No action means notification was tapped - show full screen alarm
      final title = parts.length > 2 ? parts[2] : 'Reminder';
      final description = parts.length > 3 ? parts[3] : null;
      final triggerTime = parts.length > 4
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]))
        : null;
      print('[NOTIFICATION] Calling onShowAlarm for "$title"');
      print('[NOTIFICATION] Trigger time from payload: $triggerTime');
      print('[NOTIFICATION] Current time: ${DateTime.now()}');
      if (triggerTime != null) {
        print('[NOTIFICATION] Time difference: ${DateTime.now().difference(triggerTime).inSeconds} seconds');
      }
      onShowAlarm?.call(reminderId, title, description, triggerTime);
    }
  }

  Future<void> scheduleReminder(Reminder reminder, ReminderType type) async {
    print('[NOTIFICATION] ========================================');
    print('[NOTIFICATION] Scheduling reminder ${reminder.id} (${reminder.title})');
    await cancelReminder(reminder.id!);

    final now = DateTime.now();
    print('[NOTIFICATION] Current time: $now');

    // Don't schedule if reminder is awaiting acknowledgment from user
    if (reminder.awaitingAcknowledgment) {
      print('[NOTIFICATION] Reminder ${reminder.id} is awaiting acknowledgment, not scheduling new alarm');
      return;
    }

    if (!reminder.shouldTrigger(now)) {
      print('[NOTIFICATION] Reminder should not trigger now, skipping');
      return;
    }

    final nextTrigger = _calculateNextTrigger(reminder, now);
    if (nextTrigger == null) {
      print('[NOTIFICATION] No next trigger calculated, skipping');
      print('[NOTIFICATION] ========================================');
      return;
    }

    final secondsUntilTrigger = nextTrigger.difference(now).inSeconds;
    print('[NOTIFICATION] Last triggered: ${reminder.lastTriggered}');
    print('[NOTIFICATION] Interval: ${reminder.intervalSeconds} seconds');
    print('[NOTIFICATION] Next trigger: $nextTrigger');
    print('[NOTIFICATION] Time until trigger: $secondsUntilTrigger seconds (${(secondsUntilTrigger / 60).toStringAsFixed(1)} minutes)');

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel', // Use dedicated alarm channel
      'Alarm Reminders',
      channelDescription: 'High priority alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      color: type.color != null ? _parseColor(type.color!) : null,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]), // Continuous vibration pattern
      autoCancel: false,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      channelShowBadge: true,
      timeoutAfter: null, // Don't auto-dismiss
      // Show chronometer counting up from when alarm was due
      when: nextTrigger.millisecondsSinceEpoch,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: false, // Count up, not down
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_taken',
          'Mark as Taken',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze_5',
          'Snooze 5 min',
        ),
        const AndroidNotificationAction(
          'snooze_10',
          'Snooze 10 min',
        ),
        const AndroidNotificationAction(
          'snooze_15',
          'Snooze 15 min',
        ),
        const AndroidNotificationAction(
          'skip',
          'Skip',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      reminder.id!,
      reminder.title,
      reminder.description ?? type.name,
      tz.TZDateTime.from(nextTrigger, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${reminder.id}|${type.id}|${reminder.title}|${reminder.description ?? ""}|${nextTrigger.millisecondsSinceEpoch}',
      matchDateTimeComponents: null,
    );

    print('[NOTIFICATION] ✓ Notification scheduled for ${reminder.title} at $nextTrigger');
    print('[NOTIFICATION] ========================================');
  }

  /// Show a notification immediately (used when alarm screen shows in foreground)
  /// This notification complements the in-app alarm screen - no fullScreenIntent needed
  Future<void> showImmediateNotification(Reminder reminder, ReminderType type, DateTime triggerTime) async {
    print('[NOTIFICATION] ========================================');
    print('[NOTIFICATION] Showing IMMEDIATE notification for ${reminder.id} (${reminder.title})');

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Reminders',
      channelDescription: 'High priority alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      color: type.color != null ? _parseColor(type.color!) : null,
      fullScreenIntent: false, // Don't use fullScreenIntent - alarm screen is already showing
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: false, // Don't play sound - alarm screen already plays it
      enableVibration: false, // Don't vibrate - alarm screen handles this
      autoCancel: false,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      channelShowBadge: true,
      when: triggerTime.millisecondsSinceEpoch,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_taken',
          'Mark as Taken',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze_5',
          'Snooze 5 min',
        ),
        const AndroidNotificationAction(
          'skip',
          'Skip',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use show() for immediate notification instead of zonedSchedule()
    await _notifications.show(
      reminder.id!,
      reminder.title,
      reminder.description ?? type.name,
      details,
      payload: '${reminder.id}|${type.id}|${reminder.title}|${reminder.description ?? ""}|${triggerTime.millisecondsSinceEpoch}',
    );

    print('[NOTIFICATION] ✓ Immediate notification shown for ${reminder.title}');
    print('[NOTIFICATION] ========================================');
  }

  DateTime? _calculateNextTrigger(Reminder reminder, DateTime now) {
    if (reminder.lastTriggered == null) {
      return now.add(Duration(seconds: reminder.intervalSeconds));
    }

    var nextTrigger = reminder.lastTriggered!.add(
      Duration(seconds: reminder.intervalSeconds),
    );

    // For resetOnCheck behavior: if the alarm time has passed, don't auto-schedule the next one
    // Wait for user to mark as taken, which will reset lastTriggered to NOW
    if (reminder.waterBehavior == WaterReminderBehavior.resetOnCheck) {
      if (nextTrigger.isBefore(now) || nextTrigger.isAtSameMomentAs(now)) {
        print('[NOTIFICATION] resetOnCheck: alarm time passed, waiting for user to mark as taken');
        return null;
      }
      // If nextTrigger is in the future, schedule it normally
    } else {
      // For other behaviors: skip past missed alarms to find the next future trigger
      while (nextTrigger.isBefore(now)) {
        nextTrigger = nextTrigger.add(Duration(seconds: reminder.intervalSeconds));
      }
    }

    if (reminder.isInQuietHours(nextTrigger)) {
      nextTrigger = _skipQuietHours(reminder, nextTrigger);
    }

    if (reminder.endDate != null && nextTrigger.isAfter(reminder.endDate!)) {
      return null;
    }

    return nextTrigger;
  }

  DateTime _skipQuietHours(Reminder reminder, DateTime time) {
    if (reminder.quietHoursEnd == null) return time;

    final endTime = reminder.quietHoursEnd!;
    return DateTime(
      time.year,
      time.month,
      time.day,
      endTime.hour,
      endTime.minute,
    );
  }

  Color? _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> cancelReminder(int reminderId) async {
    await _notifications.cancel(reminderId);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

}
