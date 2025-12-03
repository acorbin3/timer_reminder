# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter application for managing medication reminders and water intake tracking, specifically designed for post-tonsillectomy care. The app supports recurring timers, background notifications, medication logging with notes, and customizable quiet hours.

**Package**: `com.corbin.timer_reminder`
**Dart SDK**: ^3.8.1
**Platforms**: Android, iOS, Linux, macOS, Windows, Web

## Development Commands

### Running the App
```bash
flutter run                    # Run on connected device/emulator
flutter run -d <device-id>     # Run on specific device
flutter run --release          # Run release build
```

### Building
```bash
flutter build apk              # Build Android APK
flutter build appbundle        # Build Android App Bundle
flutter clean                  # Clean build artifacts before building
```

### Testing
```bash
flutter test                   # Run all tests
flutter analyze                # Run static analysis
```

## Architecture

### Project Structure
```
lib/
├── main.dart                  # App entry point, provider setup
├── models/                    # Data models
│   ├── reminder.dart          # Reminder model with quiet hours support
│   ├── reminder_type.dart     # Reminder categories and types
│   └── medication_log.dart    # Log entries for tracking
├── services/                  # Business logic services
│   ├── database_service.dart  # SQLite database operations
│   ├── notification_service.dart # Notification scheduling
│   └── reminder_service.dart  # Reminder logic and background tasks
├── providers/                 # State management
│   └── reminder_provider.dart # App-wide state with ChangeNotifier
├── screens/                   # UI screens
│   ├── dashboard_screen.dart  # Main dashboard
│   ├── reminder_form_screen.dart # Add/edit reminders
│   └── history_screen.dart    # View all medication logs
└── widgets/                   # Reusable components
```

### Key Dependencies
- **provider**: ^6.1.1 (State management)
- **sqflite**: ^2.3.0 (Local database)
- **flutter_local_notifications**: ^17.0.0 (Notifications)
- **workmanager**: ^0.9.0 (Background tasks)
- **intl**: ^0.19.0 (Date/time formatting)
- **timezone**: ^0.9.2 (Timezone support)

### Data Models

**Reminder**: Core model for reminders
- Support for recurring intervals (minutes)
- Quiet hours configuration (start/end times)
- Water reminder behaviors: continuous, resetOnCheck, pauseUntilResumed
- Optional end dates
- Track history flag to enable/disable logging

**ReminderType**: Categories for different reminder types
- Custom colors and priority levels
- Notification sound configuration
- Categories: water, medication, custom

**MedicationLog**: Log entries for tracking
- Actions: taken, skipped, snoozed
- Optional notes and dosage amounts
- Timestamp tracking

### Services

**DatabaseService**: SQLite database operations
- CRUD operations for reminders, types, and logs
- Optimized queries with indexes
- Foreign key constraints for data integrity

**NotificationService**: Handle all notification operations
- Schedule recurring notifications
- Custom notification channels per reminder type
- Actions: mark taken, skip, snooze (5/10/15 min)
- Quiet hours support

**ReminderService**: Business logic for reminders
- Background task management with Workmanager
- Check and schedule reminders every 15 minutes
- Handle notification actions
- Water reminder behavior logic

### State Management

Uses **Provider** pattern with ChangeNotifier:
- `ReminderProvider`: Central state management
- Exposes reminders, logs, and reminder types
- Methods for CRUD operations
- Computed properties for active/inactive reminders

## Android Configuration

### Gradle Setup
- **NDK Version**: 27.0.12077973
- **Java Version**: 17 (required for core library desugaring)
- **Core Library Desugaring**: Enabled for modern Java APIs

### Permissions (AndroidManifest.xml)
- `RECEIVE_BOOT_COMPLETED`: Restart reminders after device reboot
- `VIBRATE`: Notification vibration
- `WAKE_LOCK`: Keep device awake for notifications
- `SCHEDULE_EXACT_ALARM`: Precise notification timing
- `POST_NOTIFICATIONS`: Android 13+ notification permission
- `USE_EXACT_ALARM`: Exact alarm scheduling

### Notification Receivers
- `ScheduledNotificationReceiver`: Handle scheduled notifications
- `ScheduledNotificationBootReceiver`: Restore notifications after reboot

## Important Implementation Details

### Quiet Hours Implementation
- Custom `QuietTime` class (not Flutter's TimeOfDay) to avoid naming conflicts
- Handles overnight quiet hours (e.g., 10pm-6am spans midnight)
- Reminders automatically skip quiet hours

### Water Reminder Behaviors
1. **Continuous**: Keep reminding at set intervals regardless of acknowledgment
2. **Reset on Check**: Reset timer when marked as taken (next reminder is interval from now)
3. **Pause Until Resumed**: Stop after acknowledgment, requires manual resume

### Background Tasks
- Workmanager checks active reminders every 15 minutes
- Schedules notifications for upcoming reminders
- Handles quiet hours and end dates

### Notification Actions
Users can interact with notifications via:
- **Mark as Taken**: Log the medication and handle water reminder behavior
- **Skip**: Dismiss without logging
- **Snooze**: Delay for 5, 10, or 15 minutes

### History Tracking
- Optional per-reminder (some reminders don't need history)
- Water reminders typically have tracking disabled
- Medication reminders keep full history with notes

## Testing Notes

When testing notifications:
- Grant notification permissions on first launch
- Background notifications require exact alarm permissions on Android 12+
- Test quiet hours with different time ranges
- Verify notifications persist after app closure
- Test different water reminder behaviors

## Future Enhancements

Potential features to add:
- Multiple notification sounds per reminder type
- Medication dosage tracking graphs
- Export history to CSV
- Reminder templates
- Multi-user support for families
