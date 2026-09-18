import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'main.dart'; // To access globalPrefs, themeController, GlassCard, UnifiedBackground

class TemporalSanctum extends StatefulWidget {
  const TemporalSanctum({super.key});
  @override
  State<TemporalSanctum> createState() => _TemporalSanctumState();
}

class _TemporalSanctumState extends State<TemporalSanctum> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // A matrix mapping specific days to their respective tasks
  Map<DateTime, List<Map<String, dynamic>>> _scheduledTasks = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadScheduledTasks();
  }

  void _loadScheduledTasks() {
    String? storedTasks = globalPrefs.getString('scheduled_tasks');
    if (storedTasks != null) {
      Map<String, dynamic> decoded = json.decode(storedTasks);
      _scheduledTasks = {};
      decoded.forEach((key, value) {
        _scheduledTasks[DateTime.parse(key)] = List<Map<String, dynamic>>.from(value);
      });
      setState(() {});
    }
  }

  void _saveScheduledTasks() {
    Map<String, dynamic> encoded = {};
    _scheduledTasks.forEach((key, value) {
      encoded[key.toIso8601String()] = value;
    });
    globalPrefs.setString('scheduled_tasks', json.encode(encoded));
  }

  List<Map<String, dynamic>> _getTasksForDay(DateTime day) {
    // Normalize the date to strip away the time for accurate matching
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _scheduledTasks[normalizedDay] ?? [];
  }

  void _scheduleTaskForSelectedDay() {
    if (_selectedDay == null) return;
    
    final taskCtrl = TextEditingController();
    DateTime normalizedDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF09090B).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(top: BorderSide(color: themeController.timeline.withValues(alpha: 0.5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Schedule Task", style: GoogleFonts.outfit(color: themeController.timeline, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(DateFormat.yMMMMd().format(normalizedDay), style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: taskCtrl, autofocus: true,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(hintText: "Enter task description...", hintStyle: GoogleFonts.inter(color: Colors.white24), border: InputBorder.none),
                onSubmitted: (val) {
                  if (val.trim().isEmpty) return;
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_scheduledTasks[normalizedDay] == null) _scheduledTasks[normalizedDay] = [];
                    _scheduledTasks[normalizedDay]!.add({
                      "id": DateTime.now().millisecondsSinceEpoch,
                      "title": val.trim(),
                      "is_completed": false
                    });
                    _saveScheduledTasks();
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  void _toggleTask(DateTime day, int taskId) {
    HapticFeedback.lightImpact();
    setState(() {
      int index = _scheduledTasks[day]!.indexWhere((t) => t['id'] == taskId);
      if (index != -1) {
        _scheduledTasks[day]![index]['is_completed'] = !_scheduledTasks[day]![index]['is_completed'];
        _saveScheduledTasks();
      }
    });
  }

  void _deleteTask(DateTime day, int taskId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _scheduledTasks[day]!.removeWhere((t) => t['id'] == taskId);
      if (_scheduledTasks[day]!.isEmpty) _scheduledTasks.remove(day);
      _saveScheduledTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> selectedTasks = _selectedDay != null ? _getTasksForDay(_selectedDay!) : [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Calendar'), backgroundColor: Colors.transparent),
      body: UnifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // THE CALENDAR MATRIX
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GlassCard(
                  borderColor: themeController.timeline, padding: const EdgeInsets.all(8),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        HapticFeedback.selectionClick();
                        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) setState(() => _calendarFormat = format);
                    },
                    onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    eventLoader: _getTasksForDay,
                    
                    // AESTHETICS & FIXES
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold),
                      weekendStyle: GoogleFonts.inter(color: Colors.redAccent.withValues(alpha: 0.7), fontWeight: FontWeight.bold),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonShowsNext: false, // Ensures the button displays the current format
                      titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      formatButtonTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      formatButtonDecoration: BoxDecoration(color: themeController.timeline.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: GoogleFonts.inter(color: Colors.white),
                      weekendTextStyle: GoogleFonts.inter(color: Colors.redAccent.withValues(alpha: 0.9)),
                      outsideTextStyle: GoogleFonts.inter(color: Colors.white24),
                      selectedDecoration: BoxDecoration(color: themeController.timeline, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: themeController.timeline.withValues(alpha: 0.3), shape: BoxShape.circle),
                      markerDecoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // TASK VIEWER FOR SELECTED DAY
              Expanded(
                child: selectedTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_available, size: 48, color: Colors.white12),
                          const SizedBox(height: 16),
                          Text("No tasks scheduled for this day.", style: GoogleFonts.inter(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: selectedTasks.length,
                      itemBuilder: (context, index) {
                        final task = selectedTasks[index];
                        bool isDone = task['is_completed'];
                        DateTime normalizedDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDone ? Colors.transparent : themeController.timeline.withValues(alpha: 0.15), width: 1.5),
                          ),
                          child: ListTile(
                            leading: GestureDetector(
                              onTap: () => _toggleTask(normalizedDay, task['id']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), width: 24, height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, border: Border.all(color: isDone ? Colors.greenAccent : themeController.timeline, width: 2),
                                  color: isDone ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.transparent,
                                ),
                                child: isDone ? const Icon(Icons.check, size: 16, color: Colors.greenAccent) : null,
                              ),
                            ),
                            title: Text(task['title'], style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: isDone ? Colors.white38 : Colors.white, decoration: isDone ? TextDecoration.lineThrough : null)),
                            trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white24, size: 20), onPressed: () => _deleteTask(normalizedDay, task['id'])),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scheduleTaskForSelectedDay,
        backgroundColor: themeController.timeline,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }
}