import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; 

class NotificationOracle {
  static final NotificationOracle instance = NotificationOracle._();
  NotificationOracle._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Strictly binds the scheduling engine to Indian Standard Time
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); 

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    
    await _plugin.initialize(settings: initSettings);
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation = 
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleSystemAlert(int id, String title, String body, DateTime scheduledTime) async {
    if (scheduledTime.isBefore(DateTime.now())) return;
    
    // Accurately converts thy selected time into the synchronized timezone
    final tz.TZDateTime scheduledTzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'artifact_alerts', 'Task Alert',
        importance: Importance.max, priority: Priority.high,
        enableLights: true, enableVibration: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: id, title: title, body: body,
        scheduledDate: scheduledTzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      await _plugin.zonedSchedule(
        id: id, title: title, body: body,
        scheduledDate: scheduledTzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
  Future<void> cancelNotification(int id) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(id: id); // Added 'id:'
  } catch (e) {
    debugPrint("Failed to cancel notification $id: $e");
  }
}
/// Schedules an alert for a specific time across multiple chosen days.
  /// [daysOfWeek] should be a list of integers where Monday = 1 and Sunday = 7.
  Future<void> scheduleRecurringAlert(int baseId, String title, String body, TimeOfDay time, List<int> daysOfWeek) async {
    for (int day in daysOfWeek) {
      // Calculates the next valid date for this specific weekday and time
      final tz.TZDateTime scheduledDate = _nextInstanceOfTimeAndDay(time, day);
      
      await _plugin.zonedSchedule(
        id: baseId + day, // Explicitly named
        title: title,     // Explicitly named
        body: body,       // Explicitly named
        scheduledDate: scheduledDate, // Explicitly named
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'artifact_alerts', 
            'System Alerts', 
            importance: Importance.max, 
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
      );
    }
  }
  /// Schedules a one-time, high-priority heads-up alert for custom tasks.
  /// It rings normally (not continuously) and drops a banner from the top of the screen.
  Future<void> scheduleTaskAlert(int id, String title, String body, DateTime scheduledTime) async {
    if (scheduledTime.isBefore(DateTime.now())) return;
    
    final tz.TZDateTime scheduledTzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders_channel', // Distinct channel for single-strike alerts
        'Task Reminders',
        channelDescription: 'Single-ring alerts for critical tasks',
        importance: Importance.max, // Forces Heads-Up Banner
        priority: Priority.high,    // Forces audio output
        enableVibration: true,
        playSound: true,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: id, 
        title: title, 
        body: body,
        scheduledDate: scheduledTzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint("Alert Forge Failed (Permission missing?): $e");
    }
  }

  /// Schedules a daily alert at a specific time, repeating only until the deadline is reached.
  Future<void> scheduleAlertsUntilDeadline(int baseId, String title, String body, TimeOfDay alertTime, DateTime deadline) async {
    DateTime now = DateTime.now();
    DateTime currentScheduled = DateTime(now.year, now.month, now.day, alertTime.hour, alertTime.minute);
    
    // If the time has already passed today, start tomorrow
    if (currentScheduled.isBefore(now)) {
      currentScheduled = currentScheduled.add(const Duration(days: 1));
    }

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'deadline_reminders_channel', 
        'Deadline Reminders',
        channelDescription: 'Daily alerts leading up to a deadline',
        importance: Importance.max, 
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    int count = 0;
    // Cap at 30 days to prevent overloading the OS notification limit
    while ((currentScheduled.isBefore(deadline) || currentScheduled.isAtSameMomentAs(deadline)) && count < 30) {
      final tz.TZDateTime tzTime = tz.TZDateTime.from(currentScheduled, tz.local);
      try {
        await _plugin.zonedSchedule(
          id: baseId + count,              // REQUIRED: named parameter 'id'
          title: title,                    // REQUIRED: named parameter 'title'
          body: body,                      // REQUIRED: named parameter 'body'
          scheduledDate: tzTime,           // REQUIRED: named parameter 'scheduledDate'
          notificationDetails: details,    // REQUIRED: named parameter 'notificationDetails'
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint("Failed to forge daily alert fragment: $e");
      }
      currentScheduled = currentScheduled.add(const Duration(days: 1));
      count++;
    }
  }
  
tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTimeAndDay(TimeOfDay time, int day) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(time);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}