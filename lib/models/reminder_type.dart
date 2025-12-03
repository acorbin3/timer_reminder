enum ReminderCategory {
  water,
  medication,
  custom,
}

class ReminderType {
  final int? id;
  final String name;
  final ReminderCategory category;
  final String? color;
  final String? iconName;
  final String? notificationSound;
  final int priority;

  ReminderType({
    this.id,
    required this.name,
    required this.category,
    this.color,
    this.iconName,
    this.notificationSound,
    this.priority = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'color': color,
      'iconName': iconName,
      'notificationSound': notificationSound,
      'priority': priority,
    };
  }

  factory ReminderType.fromMap(Map<String, dynamic> map) {
    return ReminderType(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: ReminderCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ReminderCategory.custom,
      ),
      color: map['color'] as String?,
      iconName: map['iconName'] as String?,
      notificationSound: map['notificationSound'] as String?,
      priority: map['priority'] as int? ?? 0,
    );
  }

  ReminderType copyWith({
    int? id,
    String? name,
    ReminderCategory? category,
    String? color,
    String? iconName,
    String? notificationSound,
    int? priority,
  }) {
    return ReminderType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      notificationSound: notificationSound ?? this.notificationSound,
      priority: priority ?? this.priority,
    );
  }
}
