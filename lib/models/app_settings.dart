import 'reminder.dart';

class AppSettings {
  final QuietTime? globalQuietHoursStart;
  final QuietTime? globalQuietHoursEnd;
  final bool useGlobalQuietHours;

  AppSettings({
    this.globalQuietHoursStart,
    this.globalQuietHoursEnd,
    this.useGlobalQuietHours = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'globalQuietHoursStart': globalQuietHoursStart != null
          ? '${globalQuietHoursStart!.hour}:${globalQuietHoursStart!.minute}'
          : null,
      'globalQuietHoursEnd': globalQuietHoursEnd != null
          ? '${globalQuietHoursEnd!.hour}:${globalQuietHoursEnd!.minute}'
          : null,
      'useGlobalQuietHours': useGlobalQuietHours ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      globalQuietHoursStart: map['globalQuietHoursStart'] != null
          ? _parseTimeOfDay(map['globalQuietHoursStart'] as String)
          : null,
      globalQuietHoursEnd: map['globalQuietHoursEnd'] != null
          ? _parseTimeOfDay(map['globalQuietHoursEnd'] as String)
          : null,
      useGlobalQuietHours: (map['useGlobalQuietHours'] as int?) == 1,
    );
  }

  static QuietTime _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return QuietTime(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  AppSettings copyWith({
    QuietTime? globalQuietHoursStart,
    QuietTime? globalQuietHoursEnd,
    bool? useGlobalQuietHours,
  }) {
    return AppSettings(
      globalQuietHoursStart: globalQuietHoursStart ?? this.globalQuietHoursStart,
      globalQuietHoursEnd: globalQuietHoursEnd ?? this.globalQuietHoursEnd,
      useGlobalQuietHours: useGlobalQuietHours ?? this.useGlobalQuietHours,
    );
  }
}
