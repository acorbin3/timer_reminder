enum LogAction {
  taken,
  skipped,
  snoozed,
}

class MedicationLog {
  final int? id;
  final int reminderId;
  final DateTime timestamp;
  final LogAction action;
  final String? notes;
  final String? dosageAmount;

  MedicationLog({
    this.id,
    required this.reminderId,
    required this.timestamp,
    required this.action,
    this.notes,
    this.dosageAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'timestamp': timestamp.toIso8601String(),
      'action': action.name,
      'notes': notes,
      'dosageAmount': dosageAmount,
    };
  }

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'] as int?,
      reminderId: map['reminderId'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      action: LogAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => LogAction.taken,
      ),
      notes: map['notes'] as String?,
      dosageAmount: map['dosageAmount'] as String?,
    );
  }

  MedicationLog copyWith({
    int? id,
    int? reminderId,
    DateTime? timestamp,
    LogAction? action,
    String? notes,
    String? dosageAmount,
  }) {
    return MedicationLog(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      notes: notes ?? this.notes,
      dosageAmount: dosageAmount ?? this.dosageAmount,
    );
  }
}
