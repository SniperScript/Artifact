import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TimelineEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;

  TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
    };
  }

  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    return TimelineEvent(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      startTime: DateTime.parse(map['startTime']),
    );
  }
}

class TemporalOracle {
  static final TemporalOracle instance = TemporalOracle._();
  TemporalOracle._();

  late SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    
    // Corrected to use 'settings'
    await _notifications.initialize(settings: initSettings);
  }

  Future<void> scheduleEtherealWhisper(TimelineEvent event) async {
    final int exactId = event.id.hashCode.abs() % 2147483647;
    final int prepId = ("${event.id}_prep").hashCode.abs() % 2147483647;
    final DateTime prepTime = event.startTime.subtract(const Duration(minutes: 15));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'temporal_sanctum_channel',
      'Timeline Directives',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.indigoAccent,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    if (event.startTime.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id: exactId,
        title: event.title,
        body: event.description,
        scheduledDate: tz.TZDateTime.from(event.startTime, tz.local),
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (prepTime.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id: prepId,
        title: "Approaching: ${event.title}",
        body: "Commences in 15 minutes.",
        scheduledDate: tz.TZDateTime.from(prepTime, tz.local),
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelWhisper(String eventId) async {
    await _notifications.cancel(id: eventId.hashCode.abs() % 2147483647);
    await _notifications.cancel(id: ("${eventId}_prep").hashCode.abs() % 2147483647);
  }

  List<TimelineEvent> getAllEvents() {
    String? storedEvents = _prefs.getString('temporal_events');
    if (storedEvents == null) return [];
    List<dynamic> decoded = json.decode(storedEvents);
    return decoded.map((e) => TimelineEvent.fromMap(e)).toList();
  }

  List<TimelineEvent> getEventsForDay(DateTime day) {
    List<TimelineEvent> allEvents = getAllEvents();
    return allEvents.where((e) =>
        e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}
class AnimatedIconData extends StatelessWidget {
  final bool isZen;
  final bool isPlaying;
  final String currentSong;
  final Color accent;
  final double size;
  
  const AnimatedIconData({
    super.key, required this.isZen, required this.isPlaying, 
    required this.currentSong, required this.accent, required this.size
  });

  IconData _getIcon() {
    if (!isPlaying && !isZen) return Icons.spa_rounded;
    if (!isPlaying && isZen) return Icons.self_improvement_rounded;

    String lower = currentSong.toLowerCase();
    if (lower.contains('rain')) return Icons.grain_rounded;               // Rainfall drops
    if (lower.contains('fire')) return Icons.whatshot_rounded;            // Blazing Flame
    if (lower.contains('white') || lower.contains('static')) return Icons.graphic_eq_rounded; // Soundwaves
    if (lower.contains('forest') || lower.contains('wind')) return Icons.filter_vintage_rounded; // Nature Lotus

    return Icons.graphic_eq_rounded; // Default Drive / Custom Stream icon
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        _getIcon(), 
        key: ValueKey<String>("${isPlaying}_${isZen}_$currentSong"),
        size: size, 
        color: (isPlaying || isZen) ? accent : Colors.white24
      ),
    );
  }
}