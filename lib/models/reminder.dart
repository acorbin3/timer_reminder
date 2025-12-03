enum WaterReminderBehavior {
  continuous,
  resetOnCheck,
  pauseUntilResumed,
}

class QuietTime {
  final int hour;
  final int minute;

  const QuietTime({required this.hour, required this.minute});

  factory QuietTime.fromDateTime(DateTime dateTime) {
    return QuietTime(hour: dateTime.hour, minute: dateTime.minute);
  }

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class Reminder {
  final int? id;
  final int reminderTypeId;
  final String title;
  final String? description;
  final int intervalSeconds; // Changed from intervalMinutes to intervalSeconds
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final QuietTime? quietHoursStart;
  final QuietTime? quietHoursEnd;
  final DateTime? lastTriggered;
  final WaterReminderBehavior? waterBehavior;
  final bool trackHistory;
  final String? notificationSound;
  final String? medicationOptions; // Comma-separated list like "Tylenol,Ibuprofen"
  final bool awaitingAcknowledgment; // True when alarm has fired, waiting for user action

  Reminder({
    this.id,
    required this.reminderTypeId,
    required this.title,
    this.description,
    required this.intervalSeconds,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.lastTriggered,
    this.waterBehavior,
    this.trackHistory = true,
    this.notificationSound,
    this.medicationOptions,
    this.awaitingAcknowledgment = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderTypeId': reminderTypeId,
      'title': title,
      'description': description,
      'intervalSeconds': intervalSeconds,
      'isActive': isActive ? 1 : 0,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'quietHoursStart': quietHoursStart != null
          ? '${quietHoursStart!.hour}:${quietHoursStart!.minute}'
          : null,
      'quietHoursEnd': quietHoursEnd != null
          ? '${quietHoursEnd!.hour}:${quietHoursEnd!.minute}'
          : null,
      'lastTriggered': lastTriggered?.toIso8601String(),
      'waterBehavior': waterBehavior?.name,
      'trackHistory': trackHistory ? 1 : 0,
      'notificationSound': notificationSound,
      'medicationOptions': medicationOptions,
      'awaitingAcknowledgment': awaitingAcknowledgment ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    // Support both intervalSeconds (new) and intervalMinutes (old) for backward compatibility
    final intervalSeconds = map['intervalSeconds'] as int? ??
                          (map['intervalMinutes'] as int? ?? 60) * 60;

    return Reminder(
      id: map['id'] as int?,
      reminderTypeId: map['reminderTypeId'] as int,
      title: map['title'] as String,
      description: map['description'] as String?,
      intervalSeconds: intervalSeconds,
      isActive: (map['isActive'] as int) == 1,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      quietHoursStart: map['quietHoursStart'] != null
          ? _parseTimeOfDay(map['quietHoursStart'] as String)
          : null,
      quietHoursEnd: map['quietHoursEnd'] != null
          ? _parseTimeOfDay(map['quietHoursEnd'] as String)
          : null,
      lastTriggered: map['lastTriggered'] != null
          ? DateTime.parse(map['lastTriggered'] as String)
          : null,
      waterBehavior: map['waterBehavior'] != null
          ? WaterReminderBehavior.values.firstWhere(
              (e) => e.name == map['waterBehavior'],
              orElse: () => WaterReminderBehavior.continuous,
            )
          : null,
      trackHistory: (map['trackHistory'] as int?) == 1 ? true : (map['trackHistory'] == null ? true : false),
      notificationSound: map['notificationSound'] as String?,
      medicationOptions: map['medicationOptions'] as String?,
      awaitingAcknowledgment: (map['awaitingAcknowledgment'] as int?) == 1,
    );
  }

  static QuietTime _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return QuietTime(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Reminder copyWith({
    int? id,
    int? reminderTypeId,
    String? title,
    String? description,
    int? intervalSeconds,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    QuietTime? quietHoursStart,
    QuietTime? quietHoursEnd,
    DateTime? lastTriggered,
    WaterReminderBehavior? waterBehavior,
    bool? trackHistory,
    String? notificationSound,
    String? medicationOptions,
    bool? awaitingAcknowledgment,
  }) {
    return Reminder(
      id: id ?? this.id,
      reminderTypeId: reminderTypeId ?? this.reminderTypeId,
      title: title ?? this.title,
      description: description ?? this.description,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      waterBehavior: waterBehavior ?? this.waterBehavior,
      trackHistory: trackHistory ?? this.trackHistory,
      notificationSound: notificationSound ?? this.notificationSound,
      medicationOptions: medicationOptions ?? this.medicationOptions,
      awaitingAcknowledgment: awaitingAcknowledgment ?? this.awaitingAcknowledgment,
    );
  }

  bool isInQuietHours(DateTime time) {
    if (quietHoursStart == null || quietHoursEnd == null) {
      return false;
    }

    final now = QuietTime.fromDateTime(time);
    final start = quietHoursStart!;
    final end = quietHoursEnd!;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }

  bool shouldTrigger(DateTime now) {
    if (!isActive) return false;
    if (awaitingAcknowledgment) return false; // Don't schedule new alarms until user acknowledges
    if (endDate != null && now.isAfter(endDate!)) return false;
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (isInQuietHours(now)) return false;
    return true;
  }
}
