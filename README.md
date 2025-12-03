# Timer Reminder

A Flutter application for managing medication reminders and water intake tracking, specifically designed for post-tonsillectomy care.

## Features

- **Recurring Reminders**: Set customizable interval-based reminders (minutes to hours)
- **Full-Screen Alarm**: In-app alarm screen with sound, elapsed time display, and quick actions
- **Notification Support**: Background notifications with action buttons when app is closed
- **Medication Logging**: Track medication intake with optional notes and dosage
- **Quiet Hours**: Configure do-not-disturb periods (supports overnight spans)
- **Water Reminder Behaviors**:
  - *Continuous*: Reminds at set intervals regardless of acknowledgment
  - *Reset on Check*: Resets timer when marked as taken
  - *Pause Until Resumed*: Stops after acknowledgment, requires manual resume
- **History Tracking**: View complete medication history with timestamps

## Screenshots

<!-- Add screenshots here -->

## Getting Started

### Prerequisites

- Flutter SDK ^3.8.1
- Dart SDK ^3.8.1
- Android Studio / VS Code with Flutter extensions
- Android device/emulator (API 21+) or iOS device/simulator

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/timer_reminder.git
   cd timer_reminder
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle (for Play Store)
flutter build appbundle

# Clean build artifacts
flutter clean
```

## Usage

### Creating a Reminder

1. Tap the **+** button on the dashboard
2. Enter a title and optional description
3. Set the reminder interval (e.g., every 30 minutes)
4. Choose a reminder type (Medication, Water, or Custom)
5. Configure optional settings:
   - Quiet hours (e.g., 10 PM - 6 AM)
   - Water reminder behavior
   - End date
   - Medication options (for selection on alarm)
6. Tap **Save**

### Responding to Alarms

When a reminder is due, you'll see a full-screen alarm with options:
- **Mark as Taken**: Logs the action and schedules the next reminder
- **Snooze (5/10/15 min)**: Delays the reminder
- **Skip**: Dismisses without logging

### Dashboard Features

- **Pull to Refresh**: Clears stuck alarms and reschedules notifications
- **Pause/Resume**: Temporarily disable reminders
- **Reset Timer**: Restart the countdown from now
- **View History**: See all logged medication events

## Permissions

The app requires the following permissions on Android:

| Permission | Purpose |
|------------|---------|
| `POST_NOTIFICATIONS` | Display reminder notifications |
| `SCHEDULE_EXACT_ALARM` | Precise alarm timing |
| `USE_EXACT_ALARM` | Exact alarm scheduling |
| `VIBRATE` | Notification vibration |
| `WAKE_LOCK` | Keep device awake for alarms |
| `RECEIVE_BOOT_COMPLETED` | Restore alarms after reboot |

## Tech Stack

- **Framework**: Flutter
- **State Management**: Provider
- **Local Database**: SQLite (sqflite)
- **Notifications**: flutter_local_notifications
- **Background Tasks**: Workmanager
- **Audio**: audioplayers

## Project Structure

```
lib/
├── main.dart                  # App entry point, alarm polling
├── models/                    # Data models
│   ├── reminder.dart
│   ├── reminder_type.dart
│   ├── medication_log.dart
│   └── app_settings.dart
├── services/                  # Business logic
│   ├── database_service.dart
│   ├── notification_service.dart
│   ├── reminder_service.dart
│   └── alarm_sound_service.dart
├── providers/
│   └── reminder_provider.dart
└── screens/
    ├── dashboard_screen.dart
    ├── alarm_screen.dart
    ├── reminder_form_screen.dart
    ├── history_screen.dart
    └── settings_screen.dart
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Notification handling via [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
