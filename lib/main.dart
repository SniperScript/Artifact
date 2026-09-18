import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'timeline_logic.dart';
import 'notification_oracle.dart';
import 'gmail_oracle.dart';
import 'zenspace_screen.dart';
import 'protocols_screen.dart';
import 'gpa_screen.dart';
import 'academic_ledger.dart';
import 'package:http/http.dart' as http;

// ==========================================
// CORE INITIALIZATION & ENTRY POINT
// ==========================================
late SharedPreferences globalPrefs;
final ThemeController themeController = ThemeController();
final GoogleSignIn globalGoogleSignIn = GoogleSignIn(scopes: ['email']);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // IMMERSION OVERRIDE: Makes the Android Status Bar and Navigation Bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize the Android Lock Screen Daemon
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Artifact Audio',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  // Oracle & Memory Initialization
  await NotificationOracle.instance.init();
  globalPrefs = await SharedPreferences.getInstance();
  await themeController.init(globalPrefs);
  await TemporalOracle.instance.init(globalPrefs);
  
  runApp(const ArtifactApp());
}

class ArtifactApp extends StatelessWidget {
  const ArtifactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'Artifact',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.transparent, 
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white),
              bodySmall: TextStyle(color: Colors.white54),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              titleSmall: TextStyle(color: Colors.white70),
            ).apply(
              fontSizeFactor: themeController.fontScale,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent, 
              elevation: 0, centerTitle: true, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w600, 
                color: Colors.white
              ),
            ),
          ),
          // THE FIX: Direct entry into the Artifact. The Gatekeeper is banished.
          home: const MainNavigationHub(), 
        );
      }
    );
  }
}

class InitializerWidget extends StatefulWidget {
  const InitializerWidget({super.key});
  @override
  State<InitializerWidget> createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<InitializerWidget> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final bool isSignedIn = await globalGoogleSignIn.isSignedIn();
    if (mounted) {
      setState(() {
        _isAuthenticated = isSignedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));
    return _isAuthenticated ? const MainNavigationHub() : const GatekeeperScreen();
  }
}

class GatekeeperScreen extends StatelessWidget {
  const GatekeeperScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UnifiedBackground(
        child: Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.sanctum, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text("Pierce the Veil (Google Sign-In)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            onPressed: () async {
              try {
                HapticFeedback.heavyImpact();
                await globalGoogleSignIn.signIn();
                if (await globalGoogleSignIn.isSignedIn() && context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationHub()));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication Failed.")));
              }
            },
          ),
        ),
      ),
    );
  }
}
// ==========================================
// THE ARTIFACT'S MULTI-THEME CORE
// ==========================================
class ThemeController extends ChangeNotifier {
  Color ledger = Colors.greenAccent;
  Color todo = Colors.orangeAccent;
  Color sanctum = Colors.deepPurpleAccent;
  Color timeline = Colors.indigoAccent; 
  Color notes = Colors.cyanAccent;
  Color settings = Colors.blueGrey;
  Color pact = Colors.pinkAccent; 
  
  // Bash (formerly Protocols) and Zenspace
  Color attendance = Colors.deepPurpleAccent;
  Color gpa = Colors.pinkAccent;
  Color protocols = Colors.tealAccent;
  Color zenspace = Colors.blueAccent;

  String userName = "Architect"; 
  int bgType = 1; 
  double glassFrost = 40.0; 
  double currentCycleAllowance = 0.0;
  double fontScale = 1.0; 
  SharedPreferences? prefs; 
  bool isZenMode = false;
  
  void toggleZenMode() { 
    isZenMode = !isZenMode; 
    notifyListeners(); 
  }

  Future<void> init(SharedPreferences p) async {
    prefs = p;
    userName = prefs?.getString('userName') ?? "Architect";
    bgType = prefs?.getInt('bgType') ?? 1;
    glassFrost = prefs?.getDouble('glassFrost') ?? 40.0;
    currentCycleAllowance = prefs?.getDouble('monthlyAllowance') ?? 0.0;
    fontScale = prefs?.getDouble('fontScale') ?? 1.0;
    
    // The keys now perfectly match the save keys in updateColor
    ledger = Color(prefs?.getInt('theme_ledger') ?? Colors.greenAccent.toARGB32());
    todo = Color(prefs?.getInt('theme_todo') ?? Colors.orangeAccent.toARGB32());
    sanctum = Color(prefs?.getInt('theme_sanctum') ?? Colors.deepPurpleAccent.toARGB32());
    timeline = Color(prefs?.getInt('theme_timeline') ?? Colors.indigoAccent.toARGB32()); 
    notes = Color(prefs?.getInt('theme_notes') ?? Colors.cyanAccent.toARGB32());      
    settings = Color(prefs?.getInt('theme_settings') ?? Colors.blueGrey.toARGB32());   
    pact = Color(prefs?.getInt('theme_pact') ?? Colors.pinkAccent.toARGB32());   
    
    // Bash and Zenspace are now securely tethered to memory
    protocols = Color(prefs?.getInt('theme_protocols') ?? Colors.tealAccent.toARGB32());
    zenspace = Color(prefs?.getInt('theme_zenspace') ?? Colors.blueAccent.toARGB32());
    attendance = Color(prefs?.getInt('theme_attendance') ?? Colors.deepPurpleAccent.toARGB32());
    gpa = Color(prefs?.getInt('theme_gpa') ?? Colors.pinkAccent.toARGB32());
    notifyListeners();
  }

  void updateUserName(String newName) { userName = newName.trim().isEmpty ? "Architect" : newName.trim(); prefs?.setString('userName', userName); notifyListeners(); }
  void updateBgType(int type) { bgType = type; prefs?.setInt('bgType', type); notifyListeners(); }
  void updateGlassFrost(double value) { glassFrost = value; prefs?.setDouble('glassFrost', value); notifyListeners(); }
  void updateAllowance(double value) { currentCycleAllowance = value; prefs?.setDouble('monthlyAllowance', value); notifyListeners(); }
  void updateFontScale(double value) { fontScale = value; prefs?.setDouble('fontScale', value); notifyListeners(); }

  void updateColor(int index, Color color) {
    // Employing prefs directly ensures absolute stability within the controller
    if (index == 0) { ledger = color; prefs?.setInt('theme_ledger', color.toARGB32()); }
    if (index == 1) { todo = color; prefs?.setInt('theme_todo', color.toARGB32()); }
    if (index == 2) { sanctum = color; prefs?.setInt('theme_sanctum', color.toARGB32()); }
    if (index == 3) { timeline = color; prefs?.setInt('theme_timeline', color.toARGB32()); }
    if (index == 4) { notes = color; prefs?.setInt('theme_notes', color.toARGB32()); }
    if (index == 5) { settings = color; prefs?.setInt('theme_settings', color.toARGB32()); }
    if (index == 6) { pact = color; prefs?.setInt('theme_pact', color.toARGB32()); }
    if (index == 7) { protocols = color; prefs?.setInt('theme_protocols', color.toARGB32()); } 
    if (index == 8) { zenspace = color; prefs?.setInt('theme_zenspace', color.toARGB32()); }
    if (index == 9) { attendance = color; prefs?.setInt('theme_attendance', color.toARGB32()); }
    if (index == 10) { gpa = color; prefs?.setInt('theme_gpa', color.toARGB32()); }
    
    notifyListeners();
  }
}
// ==========================================
// 1. NAVIGATION CONTROL HUB
// ==========================================
class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});
  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0; // Defaults to the Home Sanctum

  // THE REFINED MATRIX: Ledger, Protocols, Sanctum, To Do, Zenspace
  final List<Widget> _screens = [
    const HomeScreen(),
    const TaskScreen(),
    const FinanceScreen(),
    const ProtocolsScreen(),
    const ZenspaceScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    // The AnimatedBuilder forces the Hub to rebuild whenever the themeController notifies a change (like Zen Mode toggling)
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true, 
          body: IndexedStack(
            index: _currentIndex, 
            children: _screens, 
          ),
          bottomNavigationBar: themeController.isZenMode
              ? const SizedBox.shrink() // This completely banishes the nav bar during immersion
              : ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Theme(
                      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
                      child: BottomNavigationBar(
                        currentIndex: _currentIndex,
                        onTap: (index) { 
                          HapticFeedback.lightImpact(); 
                          setState(() => _currentIndex = index); 
                          
                          // THE DYNAMIC ORIENTATION SEAL
                          if (index == 4) {
                            // Shatter the seal for Zenspace: Allow all rotations
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                              DeviceOrientation.landscapeLeft,
                              DeviceOrientation.landscapeRight,
                            ]);
                          } else {
                            // Reinforce the seal: Lock everything else to Portrait
                            SystemChrome.setPreferredOrientations([
                              DeviceOrientation.portraitUp,
                            ]);
                          }
                        },
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: const Color(0xFF131314).withValues(alpha: 0.65), 
                        selectedItemColor: _getSelectedColor(), 
                        unselectedItemColor: Colors.white38,
                        elevation: 0,
                        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
                        items: const [
                          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Sanctum'),
                          BottomNavigationBarItem(icon: Icon(Icons.task_alt_rounded), label: 'Directives'),
                          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Ledger'),
                          BottomNavigationBarItem(icon: Icon(Icons.terminal_rounded), label: 'Bash'),
                          BottomNavigationBarItem(icon: Icon(Icons.self_improvement_rounded), label: 'Zenspace'), 
                        ],
                      ),
                    ),
                  ),
                ),
        );
      }
    );
  }

  Color _getSelectedColor() {
    switch (_currentIndex) {
      case 0: return themeController.sanctum;    // Sanctum (Home)
      case 1: return themeController.todo;       // Directives (To-Do)
      case 2: return themeController.ledger;     // Ledger
      case 3: return themeController.protocols;  // Bash (Protocols)
      case 4: return themeController.zenspace;   // Zenspace
      default: return Colors.white;
    }
  }
}
// ==========================================
// 2. THE SANCTUM (Student Dashboard)
// ==========================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _pendingTasksCount = 0;
  double _remainingBudget = 0.0;
  List<Map<String, dynamic>> _activeAlerts = [];
  String _activeProfileName = 'Ledger';
  bool _isTimetableVisible = true; // Tracks the collapse/expand state

  int _selectedDayIndex = 0;
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<Map<String, dynamic>> _todayClasses = [];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
    _loadDashboardData();
    int currentDay = DateTime.now().weekday - 1;
    _selectedDayIndex = currentDay < 5 ? currentDay : 0;
    
    // THE CLOUD TRIGGER: Silently updates the timetable in the background
    SheetSyncService.syncTimetableFromCloud().then((success) {
      if (success && mounted) {
        _loadTimetable(); // Refreshes the UI instantly if changes are found
      }
    });
  }

  void _loadTimetable() {
    String? storedData = globalPrefs.getString('sanctum_timetable');
    if (storedData != null) {
      Map<String, dynamic> allDays = json.decode(storedData);
      if (allDays.containsKey(_selectedDayIndex.toString())) {
        _todayClasses = List<Map<String, dynamic>>.from(allDays[_selectedDayIndex.toString()]);
      } else {
        _todayClasses = [];
      }
    }
    setState(() {}); // Refreshes the UI with the loaded classes
  }

  void _loadDashboardData() {
    String? storedTasks = globalPrefs.getString('internal_tasks');
    if (storedTasks != null) {
      List<dynamic> tasks = json.decode(storedTasks);
      _pendingTasksCount = tasks.where((t) => t['is_completed'] == false).length;
    }

    _activeProfileName = globalPrefs.getString('current_ledger_profile') ?? 'Primary';
    double limit = globalPrefs.getDouble('monthlyExpendLimit_$_activeProfileName') ?? globalPrefs.getDouble('monthlyExpendLimit') ?? 0.0;
    
    String currentMonthStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
    String? storedTxns = globalPrefs.getString('ledger_transactions_$_activeProfileName') ?? globalPrefs.getString('ledger_transactions');
    
    double spent = 0.0;
    if (storedTxns != null) {
      List<dynamic> txns = json.decode(storedTxns);
      spent = txns.where((t) => t['date'].toString().startsWith(currentMonthStr) && t['type'] == 'spend_budget').fold(0.0, (sum, t) => sum + t['amount']);
    }
    _remainingBudget = limit - spent;

    String? storedAlerts = globalPrefs.getString('artifact_alerts');
    if (storedAlerts != null) {
      _activeAlerts = List<Map<String, dynamic>>.from(json.decode(storedAlerts));
      _activeAlerts.removeWhere((a) => DateTime.parse(a['time']).isBefore(DateTime.now()));
      _activeAlerts.sort((a, b) => DateTime.parse(a['time']).compareTo(DateTime.parse(b['time'])));
      globalPrefs.setString('artifact_alerts', json.encode(_activeAlerts));
    }

    setState(() {});
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _buildWeekCalendar() {
    DateTime now = DateTime.now();
    DateTime currentMonday = now.subtract(Duration(days: now.weekday - 1));

    return SizedBox(
      height: 85, // Expanded height to provide breathing room for the text
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          bool isSelected = _selectedDayIndex == index;
          DateTime dayDate = currentMonday.add(Duration(days: index));
          bool isToday = dayDate.day == now.day && dayDate.month == now.month;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                  _selectedDayIndex = index;
                  _loadTimetable(); // Load new classes when day is tapped
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Refined padding
              decoration: BoxDecoration(
                color: isSelected ? themeController.ledger.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? themeController.ledger : (isToday ? Colors.white38 : Colors.transparent), 
                  width: 1.5
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Prevents elements from stretching into overflow territory
                children: [
                  Text(_weekDays[index], style: TextStyle(color: isSelected ? themeController.ledger : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("${dayDate.day}", style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- ACADEMIC HUB MODALS ---
  void _openAlertManager() async {
    await NotificationOracle.instance.requestPermissions();
    final titleCtrl = TextEditingController();
    DateTime selectedTime = DateTime.now().add(const Duration(minutes: 1));
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          // Dynamically pushes the entire sheet up when the keyboard appears
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 24),
              decoration: BoxDecoration(color: const Color(0xFF131314), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border(top: BorderSide(color: themeController.sanctum))),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: themeController.sanctum, size: 28),
                      const SizedBox(width: 12),
                      const Text("Alert Manager", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl, style: const TextStyle(color: Colors.white), autofocus: true,
                    decoration: const InputDecoration(hintText: "What must you be reminded of?", hintStyle: TextStyle(color: Colors.white24), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Alert Time", style: TextStyle(color: Colors.white70)),
                    trailing: TextButton(
                      onPressed: () async {
                        DateTime? d = await showDatePicker(context: ctx, initialDate: selectedTime, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (d != null) {
                          TimeOfDay? t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selectedTime));
                          if (t != null) {
                            setModalState(() => selectedTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                          }
                        }
                      },
                      child: Text("${selectedTime.day}/${selectedTime.month} • ${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}", style: TextStyle(color: themeController.sanctum, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: themeController.sanctum, minimumSize: const Size(double.infinity, 50)),
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty || selectedTime.isBefore(DateTime.now())) return;
                      HapticFeedback.lightImpact();
                      
                      int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
                      Map<String, dynamic> newAlert = { "id": id, "title": titleCtrl.text.trim(), "time": selectedTime.toIso8601String() };
                      
                      _activeAlerts.add(newAlert);
                      _activeAlerts.sort((a, b) => DateTime.parse(a['time']).compareTo(DateTime.parse(b['time'])));
                      globalPrefs.setString('artifact_alerts', json.encode(_activeAlerts));
                      
                      try { NotificationOracle.instance.scheduleSystemAlert(id, "System Alert", titleCtrl.text.trim(), selectedTime); } catch(e) {}

                      _loadDashboardData();
                      Navigator.pop(ctx);
                    },
                    child: const Text("Engage Alert", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        )
      )
    );
  }

  void _openAttendanceManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      builder: (context) => const Padding(
        padding: EdgeInsets.only(top: 60.0), // Prevents it from hitting the very top of the screen
        child: AcademicLedgerWidget(),
      ),
    );
  }

  void _openGradePredictor() {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (context) => const GpaPredictorScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26), onPressed: _openAlertManager),
          IconButton(icon: Icon(Icons.auto_stories, color: themeController.notes, size: 26), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesScreen()))),
          IconButton(icon: Icon(Icons.settings, color: themeController.settings, size: 26), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
          const SizedBox(width: 8),
        ],
      ),
      body: UnifiedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: 120.0),
            children: [
              Text("${_getGreeting()},\n${themeController.userName}.", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
              const SizedBox(height: 32),
              
              // --- OVERVIEW ---
              const Text("Overview", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      borderColor: themeController.todo, padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, color: themeController.todo, size: 28),
                          const SizedBox(height: 12),
                          const Text("Pending Tasks", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text("$_pendingTasksCount", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassCard(
                      borderColor: themeController.ledger, padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, color: themeController.ledger, size: 28),
                          const SizedBox(height: 12),
                          const Text("Primary Budget", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text("₹${_remainingBudget.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- TEMPORAL SANCTUM (CALENDAR) ---
              const Text("Calendar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildWeekCalendar(),
              const SizedBox(height: 24),
              
              // --- COMPACT COLLAPSABLE TIMETABLE ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TODAY'S SCHEDULE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_document, color: Colors.white54, size: 20),
                        tooltip: "Cloud Sync",
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF131314),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.sanctum ?? Colors.blueAccent, width: 0.5)),
                              title: const Text("Cloud Timetable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: const Text("Thy schedule is now eternally synced with the cloud.\n\nOpen thy Google Sheets app on this device to modify the matrix. Tap below to force a sync if thou hast just made changes.", style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.white54))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: themeController.sanctum ?? Colors.blueAccent, foregroundColor: Colors.black),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Querying the Cloud...", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87));
                                    SheetSyncService.syncTimetableFromCloud().then((success) {
                                      if (mounted) {
                                        _loadTimetable();
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? "Matrix Synced!" : "Sync Failed.", style: const TextStyle(color: Colors.white)), backgroundColor: success ? Colors.green : Colors.red));
                                      }
                                    });
                                  },
                                  child: const Text("Force Sync", style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              ],
                            )
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(_isTimetableVisible ? Icons.expand_less : Icons.expand_more, color: Colors.white54, size: 24),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() { _isTimetableVisible = !_isTimetableVisible; });
                        },
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 4),

              // The Animated Collapse Window
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                child: _isTimetableVisible
                  ? (_todayClasses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: Text("No directives scheduled for today.", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))),
                        )
                      : Column(
                          children: _todayClasses.map((cls) {
                            bool isPractical = cls['type'] == 'Practical';
                            Color typeColor = isPractical ? Colors.orangeAccent : (themeController.sanctum ?? Colors.blueAccent);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161618),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: typeColor.withValues(alpha: 0.2), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(width: 3, height: 28, decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cls['title'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text("${cls['time']} • ${cls['room']}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text(cls['type'], style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ))
                  : const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // --- ACADEMIC HUB ---
              const Text("Academic Hub", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () { HapticFeedback.lightImpact(); _openAttendanceManager(); },
                      child: GlassCard(
                        borderColor: themeController.attendance ?? Colors.blueAccent, 
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.fact_check, color: themeController.attendance ?? Colors.blueAccent, size: 32),
                            const SizedBox(height: 12),
                            const Text("Attendance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () { HapticFeedback.lightImpact(); _openGradePredictor(); },
                      child: GlassCard(
                        borderColor: themeController.gpa ?? Colors.purpleAccent, 
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.timeline, color: themeController.gpa ?? Colors.purpleAccent, size: 32),
                            const SizedBox(height: 12),
                            const Text("Grades (GPA)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SYSTEM ALERTS ---
              if (_activeAlerts.isNotEmpty) ...[
                const Text("Active System Alerts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                GlassCard(
                  borderColor: themeController.sanctum, padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _activeAlerts.map((alert) {
                      DateTime t = DateTime.parse(alert['time']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: themeController.sanctum, size: 10),
                            const SizedBox(width: 12),
                            Expanded(child: Text(alert['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                            Text("${t.hour}:${t.minute.toString().padLeft(2, '0')} (${t.day}/${t.month})", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                ),
                const SizedBox(height: 24),
              ],

              // --- QUICK ACTIONS ---
              const Text("Quick Actions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              GlassCard(
                borderColor: Colors.transparent, padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(backgroundColor: themeController.notes.withValues(alpha: 0.1), child: Icon(Icons.note_add, color: themeController.notes)),
                      title: const Text("New Note", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => const NoteEditorScreen())); },
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.05), indent: 16, endIndent: 16),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: themeController.pact.withValues(alpha: 0.1), child: Icon(Icons.handshake, color: themeController.pact)),
                      title: const Text("Review Pact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => const PactScreen())); },
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.05), indent: 16, endIndent: 16),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: themeController.ledger.withValues(alpha: 0.1), child: Icon(Icons.receipt_long, color: themeController.ledger)),
                      title: const Text("Log Expense", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => const FinanceScreen())); },
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.05), indent: 16, endIndent: 16),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: themeController.todo.withValues(alpha: 0.1), child: Icon(Icons.add_task, color: themeController.todo)),
                      title: const Text("Add Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                      onTap: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskScreen())); },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. STUDENT FINANCIAL LEDGER (Sanctum Bug Resolved)
// ==========================================

class FinanceScreen extends StatefulWidget { const FinanceScreen({super.key}); @override State<FinanceScreen> createState() => _FinanceScreenState(); }

class _FinanceScreenState extends State<FinanceScreen> { 
  List<Map<String, dynamic>> _transactions = []; 
  final _amountController = TextEditingController(); 
  final _descController = TextEditingController(); 
  String _txType = 'spend_budget'; 
  double _savings = 0.0; 
  double _monthlyAllowance = 0.0; 
  double _monthlyExpendLimit = 0.0; 
  String? _cycleEndDate; 
  bool _needsCycleSetup = false; 

  List<String> _profiles = ['Primary'];
  String _currentProfile = 'Primary';

  @override void initState() { super.initState(); _loadProfiles(); } 
  DateTime _getLocalTime() { double offset = globalPrefs.getDouble('tzOffset') ?? 5.5; return DateTime.now().toUtc().add(Duration(minutes: (offset * 60).toInt())); } 
  
  void _loadProfiles() {
    String? storedProfiles = globalPrefs.getString('ledger_profiles');
    if (storedProfiles != null) { _profiles = List<String>.from(json.decode(storedProfiles)); }
    String? savedCurrent = globalPrefs.getString('current_ledger_profile');
    if (savedCurrent != null && _profiles.contains(savedCurrent)) { _currentProfile = savedCurrent; }
    _loadState();
  }

  void _switchProfile(String newProfile) {
    HapticFeedback.mediumImpact();
    setState(() { _currentProfile = newProfile; globalPrefs.setString('current_ledger_profile', _currentProfile); _loadState(); });
  }

  void _manageProfilesDialog() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF131314), borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), border: Border(top: BorderSide(color: themeController.ledger.withValues(alpha: 0.5)))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ledger Profiles", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ..._profiles.map((p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p, style: TextStyle(color: Colors.white, fontWeight: p == _currentProfile ? FontWeight.bold : FontWeight.normal)),
                  trailing: _profiles.length > 1 ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      setModalState(() {
                        _profiles.remove(p);
                        globalPrefs.setString('ledger_profiles', json.encode(_profiles));
                        globalPrefs.remove('ledger_transactions_$p'); globalPrefs.remove('savings_$p'); globalPrefs.remove('cycleEndDate_$p');
                        if (_currentProfile == p) _switchProfile(_profiles.first);
                        setState((){});
                      });
                    }
                  ) : null,
                  onTap: () { Navigator.pop(context); _switchProfile(p); },
                )),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: themeController.ledger, minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text("Create New Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: () { Navigator.pop(context); _showAddProfileDialog(); },
                )
              ],
            ),
          );
        }
      )
    );
  }
  void _checkDailyRollover() {
    String? lastRec = globalPrefs.getString('lastReconciledDate_$_currentProfile');
    String todayStr = _getLocalTime().toIso8601String().split('T')[0];

    if (lastRec != todayStr) {
      // A new day has dawned! Calculate yesterday's leftover
      DateTime localNow = _getLocalTime();
      DateTime yesterday = localNow.subtract(const Duration(days: 1));
      String yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      double spentYesterday = _transactions.where((t) {
        if (t['type'] != 'spend_budget') return false;
        return t['date'].toString().startsWith(yesterdayStr);
      }).fold(0.0, (sum, t) => sum + t['amount']);

      int totalCycleDays = 30;
      if (_cycleEndDate != null) {
        String? startStr = globalPrefs.getString('cycleStartDate_$_currentProfile');
        DateTime startDate = startStr != null ? DateTime.parse(startStr) : localNow;
        DateTime endDate = DateTime.parse(_cycleEndDate!);
        totalCycleDays = endDate.difference(startDate).inDays + 1;
        if (totalCycleDays <= 0) totalCycleDays = 1;
      }

      double dailyLimit = _monthlyExpendLimit > 0 ? (_monthlyExpendLimit / totalCycleDays) : 0.0;
      double leftoverYesterday = dailyLimit - spentYesterday;

      if (leftoverYesterday > 0) {
        int surplusAction = globalPrefs.getInt('surplusAction') ?? 0;
        if (surplusAction == 1) {
          // Send leftover directly to Vault Reserve
          _savings += leftoverYesterday;
          globalPrefs.setDouble('savings_$_currentProfile', _savings);
        } else {
          // Carry over into general budget pool (automatically reflected via daily calculation)
        }
      }

      // Stamp today as reconciled
      globalPrefs.setString('lastReconciledDate_$_currentProfile', todayStr);
    }
  }
  void _showAddProfileDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text("Create New Profile", style: TextStyle(color: themeController.ledger)),
        content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), autofocus: true, decoration: const InputDecoration(hintText: "Enter Name", hintStyle: TextStyle(color: Colors.white54))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.ledger),
            onPressed: () {
              String name = ctrl.text.trim();
              if (name.isNotEmpty && !_profiles.contains(name)) {
                _profiles.add(name);
                globalPrefs.setString('ledger_profiles', json.encode(_profiles));
                Navigator.pop(context);
                _switchProfile(name);
              }
            }, child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _loadState() { 
    _checkDailyRollover();
    _savings = globalPrefs.getDouble('savings_$_currentProfile') ?? 0.0; 
    _monthlyAllowance = globalPrefs.getDouble('monthlyAllowance_$_currentProfile') ?? 0.0; 
    _monthlyExpendLimit = globalPrefs.getDouble('monthlyExpendLimit_$_currentProfile') ?? 0.0; 
    _cycleEndDate = globalPrefs.getString('cycleEndDate_$_currentProfile');
    
    String? storedTxns = globalPrefs.getString('ledger_transactions_$_currentProfile'); 
    if (storedTxns != null) { _transactions = List<Map<String, dynamic>>.from(json.decode(storedTxns)); } else { _transactions = []; }
    
    _needsCycleSetup = false;
    _reconcileTimeProgression();
    setState(() {}); 
    // THE FIX: PostFrameCallback removed so it does not auto-spawn on the Home Screen
  } 

  void _reconcileTimeProgression() { 
    if (_cycleEndDate == null) { 
      _needsCycleSetup = true; 
      return; 
    }
    
    DateTime localNow = _getLocalTime(); 
    DateTime endDate = DateTime.parse(_cycleEndDate!);
    DateTime todayDate = DateTime(localNow.year, localNow.month, localNow.day);
    DateTime cycleEndOnly = DateTime(endDate.year, endDate.month, endDate.day);

    if (todayDate.isAfter(cycleEndOnly)) {
      double spendThisCycle = _transactions.where((t) {
        DateTime txDate = DateTime.parse(t['date']);
        DateTime txDayOnly = DateTime(txDate.year, txDate.month, txDate.day);
        return (txDayOnly.isBefore(cycleEndOnly) || txDayOnly.isAtSameMomentAs(cycleEndOnly)) && t['type'] == 'spend_budget';
      }).fold(0.0, (sum, t) => sum + t['amount']);

      double depositThisCycle = _transactions.where((t) {
        DateTime txDate = DateTime.parse(t['date']);
        DateTime txDayOnly = DateTime(txDate.year, txDate.month, txDate.day);
        return (txDayOnly.isBefore(cycleEndOnly) || txDayOnly.isAtSameMomentAs(cycleEndOnly)) && t['type'] == 'deposit_budget';
      }).fold(0.0, (sum, t) => sum + t['amount']);
      
      double netSpent = spendThisCycle - depositThisCycle;
      double remaining = _monthlyExpendLimit - netSpent;
      
      if (remaining > 0) { 
        _savings += remaining; 
        globalPrefs.setDouble('savings_$_currentProfile', _savings); 
      }
      
      _needsCycleSetup = true; 
    }
  }

  void _saveTransactions() { 
    globalPrefs.setString('ledger_transactions_$_currentProfile', json.encode(_transactions)); 
    globalPrefs.setDouble('savings_$_currentProfile', _savings); 
    setState(() {}); 
  } 
  
  Future<void> _addTransaction() async { 
    if (_amountController.text.isEmpty || _descController.text.isEmpty) return; 
    double amt = double.tryParse(_amountController.text) ?? 0.0; 
    if (amt <= 0) return; 
    
    if (_txType == 'spend_savings') { 
      if (amt > _savings) return; 
      _savings -= amt; 
    } else if (_txType == 'deposit_savings') { 
      _savings += amt; 
    } 
    
    HapticFeedback.mediumImpact(); 
    final newTxn = { "id": DateTime.now().millisecondsSinceEpoch, "amount": amt, "description": _descController.text, "type": _txType, "date": _getLocalTime().toIso8601String() }; 
    _transactions.insert(0, newTxn); 
    _saveTransactions(); 
    _amountController.clear(); 
    _descController.clear(); 
    FocusScope.of(context).unfocus(); 
  } 

  void _deleteTransaction(int index) {
    HapticFeedback.mediumImpact();
    final tx = _transactions[index];
    
    if (tx['type'] == 'spend_savings') {
      _savings += tx['amount'];
    } else if (tx['type'] == 'deposit_savings') {
      _savings -= tx['amount'];
    }
    
    _transactions.removeAt(index);
    _saveTransactions();
  }

  void _showCycleSetupDialog() { 
    final allowCtrl = TextEditingController(); 
    final expendCtrl = TextEditingController(); 
    DateTime? selectedEnd;

    showDialog( 
      context: context, barrierDismissible: false, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog( 
              backgroundColor: const Color(0xFF1E1E20), 
              title: Text("Create New Cycle", style: TextStyle(color: themeController.ledger)), 
              content: SingleChildScrollView( 
                child: Column( 
                  mainAxisSize: MainAxisSize.min, 
                  children: [ 
                    TextField(
                      controller: allowCtrl, 
                      keyboardType: TextInputType.number, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Total Allowance (₹)", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())
                    ), 
                    const SizedBox(height: 12), 
                    TextField(
                      controller: expendCtrl, 
                      keyboardType: TextInputType.number, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Max Expenditure (₹)", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())
                    ), 
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: themeController.ledger.withValues(alpha: 0.2), padding: const EdgeInsets.symmetric(vertical: 12)),
                        icon: Icon(Icons.calendar_month, color: themeController.ledger),
                        label: FittedBox(child: Text(selectedEnd == null ? "Select Expiration Date" : "Ends: ${selectedEnd!.toString().split(' ')[0]}", style: TextStyle(color: themeController.ledger, fontWeight: FontWeight.bold))),
                        onPressed: () async {
                          DateTime now = _getLocalTime();
                          final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 7)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
                          if (d != null) setDialogState(() => selectedEnd = d);
                        }
                      ),
                    )
                  ], 
                ), 
              ),
              actions: [ 
                ElevatedButton( 
                  style: ElevatedButton.styleFrom(backgroundColor: themeController.ledger), 
                  onPressed: () { 
                    double allow = double.tryParse(allowCtrl.text) ?? 0.0; 
                    double expend = double.tryParse(expendCtrl.text) ?? 0.0; 
                    if (allow <= 0 || expend <= 0 || selectedEnd == null || expend > allow) return; 

                    DateTime now = _getLocalTime();
                    globalPrefs.setString('cycleStartDate_$_currentProfile', now.toIso8601String());
                    globalPrefs.setString('cycleEndDate_$_currentProfile', selectedEnd!.toIso8601String()); 
                    globalPrefs.setDouble('monthlyAllowance_$_currentProfile', allow); 
                    globalPrefs.setDouble('monthlyExpendLimit_$_currentProfile', expend); 
                    
                    double unallocated = allow - expend; _savings += unallocated; 
                    globalPrefs.setDouble('savings_$_currentProfile', _savings); 
          
                    if (_currentProfile == 'Primary') themeController.updateAllowance(allow); 
                    Navigator.pop(context); _needsCycleSetup = false; _loadState(); 
                  }, child: const Text("Solidify", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
                ), 
              ], 
            ); 
          }
        );
      }, 
    ); 
  }

  Widget _buildFilterChip(String value, String label, Color color) { 
    bool isSelected = _txType == value; 
    return Padding( 
      padding: const EdgeInsets.only(right: 8.0), 
      child: ChoiceChip( 
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)), 
        selected: isSelected, 
        selectedColor: color, 
        backgroundColor: Colors.transparent, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.white24)), 
        onSelected: (bool selected) { if (selected) { HapticFeedback.selectionClick(); setState(() => _txType = value); } }, 
      ), 
    ); 
  } 

  @override 
  Widget build(BuildContext context) { 
    DateTime localNow = _getLocalTime(); 
    DateTime todayDate = DateTime(localNow.year, localNow.month, localNow.day);
    
    double spentOverall = _transactions.where((t) => t['type'] == 'spend_budget').fold(0.0, (sum, t) => sum + t['amount']);
    double depositedOverall = _transactions.where((t) => t['type'] == 'deposit_budget').fold(0.0, (sum, t) => sum + t['amount']);
    double netSpentOverall = spentOverall - depositedOverall;

    double remainingOverall = _monthlyExpendLimit - netSpentOverall;
    double progressPercent = _monthlyExpendLimit > 0 ? (netSpentOverall / _monthlyExpendLimit).clamp(0.0, 1.0) : 0.0;
    
    double spentToday = _transactions.where((t) {
      if (t['type'] != 'spend_budget') return false;
      DateTime txDate = DateTime.parse(t['date']);
      return txDate.year == todayDate.year && txDate.month == todayDate.month && txDate.day == todayDate.day;
    }).fold(0.0, (sum, t) => sum + t['amount']);

    double depositedToday = _transactions.where((t) {
      if (t['type'] != 'deposit_budget') return false;
      DateTime txDate = DateTime.parse(t['date']);
      return txDate.year == todayDate.year && txDate.month == todayDate.month && txDate.day == todayDate.day;
    }).fold(0.0, (sum, t) => sum + t['amount']);
    double netSpentToday = spentToday - depositedToday;
    
    int totalCycleDays = 30; 
    if (_cycleEndDate != null) {
      String? startStr = globalPrefs.getString('cycleStartDate_$_currentProfile');
      DateTime startDate = startStr != null ? DateTime.parse(startStr) : todayDate;
      DateTime endDate = DateTime.parse(_cycleEndDate!);
      totalCycleDays = endDate.difference(startDate).inDays + 1;
      if (totalCycleDays <= 0) totalCycleDays = 1; 
    }
    
    double fixedDailyBudget = _monthlyExpendLimit > 0 ? (_monthlyExpendLimit / totalCycleDays) : 0.0; 
    double dailyAvailable = fixedDailyBudget - netSpentToday;
    String endDisplay = _cycleEndDate != null ? DateTime.parse(_cycleEndDate!).toString().split(' ')[0] : "N/A";

    return Scaffold( 
      extendBodyBehindAppBar: true,
      appBar: AppBar( 
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: _manageProfilesDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers, color: themeController.ledger, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(_currentProfile, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
              ],
            ),
          ),
        ),
        actions: [ 
          IconButton(
            icon: Icon(Icons.insights, color: themeController.ledger), 
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsScreen(transactions: _transactions, monthlyExpendLimit: _monthlyExpendLimit)));
            }
          ),
          IconButton(icon: Icon(Icons.edit_calendar, color: themeController.ledger), onPressed: _showCycleSetupDialog) 
        ], 
      ), 
      body: UnifiedBackground( 
        child: SafeArea(
          bottom: false, 
          child: Column( 
            children: [ 
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
                  itemCount: _transactions.length + 1, 
                  itemBuilder: (context, index) {
                    
                    if (index == 0) {
                      // THE FIX: Graceful native card instead of a forced modal
                      if (_needsCycleSetup) {
                        return GlassCard(
                          borderColor: Colors.redAccent, padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              const Text("Temporal Alignment Required", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text("The current financial cycle has concluded or is uninitialized.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: themeController.ledger, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                                onPressed: _showCycleSetupDialog,
                                icon: const Icon(Icons.build, color: Colors.black),
                                label: const Text("Forge New Cycle", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                              )
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          GlassCard(
                            borderColor: Colors.transparent, padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(child: Text("Overall Budget Utilization", style: TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    Text("Ends: $endDisplay", style: TextStyle(fontSize: 13, color: themeController.ledger, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("₹${remainingOverall.toStringAsFixed(0)}", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: remainingOverall >= 0 ? Colors.white : Colors.redAccent)),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Text("${(progressPercent * 100).toStringAsFixed(1)}% Spent", style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: progressPercent, minHeight: 14, backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    valueColor: AlwaysStoppedAnimation<Color>(remainingOverall >= 0 ? themeController.ledger : Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GlassCard(
                                  borderColor: Colors.transparent, padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Strict Daily Limit", style: TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      FittedBox(child: Text("₹${dailyAvailable.toStringAsFixed(0)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dailyAvailable >= 0 ? Colors.white : Colors.redAccent))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassCard(
                                  borderColor: Colors.transparent, padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Vault Reserve", style: TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      FittedBox(child: Text("₹${_savings.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24), 
                        ]
                      );
                    }

                    final txIndex = index - 1;
                    final tx = _transactions[txIndex];
                    String rawType = tx['type'] ?? 'spend_budget';
                    bool isAdd = rawType.contains('deposit');
                    Color txColor = Colors.grey;
                    if (rawType == 'spend_budget') txColor = Colors.redAccent;
                    if (rawType == 'spend_savings') txColor = Colors.orangeAccent;
                    if (rawType == 'deposit_budget') txColor = themeController.ledger;
                    if (rawType == 'deposit_savings') txColor = Colors.cyanAccent;

                    return Dismissible(
                      key: Key(tx['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.centerRight, child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                      onDismissed: (_) => _deleteTransaction(txIndex),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(radius: 16, backgroundColor: txColor.withValues(alpha: 0.2), child: Icon(isAdd ? Icons.arrow_downward : Icons.arrow_upward, color: txColor, size: 16)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx['description'], style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text("${tx['date'].toString().split('T')[0]} • ${rawType.replaceAll('_', ' ')}", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                ],
                              ),
                            ),
                            Text("${isAdd ? '+' : '-'}₹${tx['amount'].toStringAsFixed(0)}", style: TextStyle(color: txColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ), 
              
              Padding(
                padding: const EdgeInsets.only(bottom: 90.0, left: 16, right: 16, top: 12),
                child: GlassCard( 
                  borderColor: Colors.transparent, padding: const EdgeInsets.all(12), 
                  child: Column( 
                    mainAxisSize: MainAxisSize.min, 
                    children: [ 
                      SingleChildScrollView( 
                        scrollDirection: Axis.horizontal, 
                        child: Row( 
                          children: [ 
                            _buildFilterChip('spend_budget', 'Daily Spend', Colors.redAccent), 
                            _buildFilterChip('spend_savings', 'Vault Spend', Colors.orangeAccent), 
                            _buildFilterChip('deposit_budget', 'Daily Deposit', themeController.ledger), 
                            _buildFilterChip('deposit_savings', 'Vault Deposit', Colors.cyanAccent), 
                          ], 
                        ), 
                      ), 
                      const SizedBox(height: 8), 
                      Row( 
                        children: [ 
                          Expanded( 
                            flex: 3, 
                            child: TextField( 
                              controller: _descController, style: const TextStyle(color: Colors.white), 
                              decoration: const InputDecoration(hintText: "Description...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, isDense: true), 
                            ), 
                          ), 
                          Container(height: 24, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)), 
                          Expanded( 
                            flex: 2, 
                            child: TextField( 
                              controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), 
                              decoration: const InputDecoration(hintText: "₹0", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, isDense: true), 
                            ), 
                          ), 
                          Container( 
                            decoration: BoxDecoration(color: themeController.ledger.withValues(alpha: 0.2), shape: BoxShape.circle), 
                            child: IconButton( icon: Icon(Icons.send_rounded, color: themeController.ledger, size: 20), onPressed: _addTransaction, ), 
                          ) 
                        ], 
                      ) 
                    ], 
                  ), 
                ),
              )
            ], 
          ),
        ), 
      ), 
    ); 
  }
}
class AnalyticsScreen extends StatelessWidget { 
  final List<Map<String, dynamic>> transactions; final double monthlyExpendLimit; 
  const AnalyticsScreen({super.key, required this.transactions, required this.monthlyExpendLimit}); 
  @override Widget build(BuildContext context) { 
    DateTime now = DateTime.now(); String currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}"; int daysInMonth = DateTime(now.year, now.month + 1, 0).day; double dailyBudget = daysInMonth > 0 ? (monthlyExpendLimit / daysInMonth) : 0.0; List<Map<String, dynamic>> monthTx = transactions.where((t) => t['date'].toString().startsWith(currentMonth)).toList(); Map<String, double> dailySpends = {}; for (var tx in monthTx) { if (tx['type'] == 'spend_budget' || tx['type'] == 'spend_savings') { String day = tx['date'].toString().split('T')[0]; dailySpends[day] = (dailySpends[day] ?? 0.0) + tx['amount']; } } String maxSpendDay = "N/A"; double maxSpendAmount = 0.0; String maxSaveDay = "N/A"; double maxSaveAmount = 0.0; if (dailySpends.isNotEmpty) { var sortedSpends = dailySpends.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); maxSpendDay = sortedSpends.first.key; maxSpendAmount = sortedSpends.first.value; var sortedSaves = dailySpends.entries.toList()..sort((a, b) => a.value.compareTo(b.value)); maxSaveDay = sortedSaves.first.key; maxSaveAmount = (dailyBudget - sortedSaves.first.value).clamp(0, double.infinity); } List<double> last7DaysSpends = []; double maxChartValue = 1.0; for (int i = 6; i >= 0; i--) { DateTime checkDate = now.subtract(Duration(days: i)); String checkStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}"; double spent = dailySpends[checkStr] ?? 0.0; last7DaysSpends.add(spent); if (spent > maxChartValue) maxChartValue = spent; } 
    return Scaffold( 
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Financial Graph'), backgroundColor: Colors.transparent), 
      body: UnifiedBackground( 
        child: SafeArea(
          child: Padding( 
            padding: const EdgeInsets.all(20.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("Current Cycle Insights", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 24), _buildInsightCard("Day of Greatest Expenditure", maxSpendDay, "₹${maxSpendAmount.toStringAsFixed(0)} spent", Colors.redAccent), const SizedBox(height: 16), _buildInsightCard("Day of Maximum Saving", maxSaveDay, "₹${maxSaveAmount.toStringAsFixed(0)} saved", Colors.greenAccent), const SizedBox(height: 40), Text("7-Day Output Flow", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)), const SizedBox(height: 24), Expanded( child: LayoutBuilder( builder: (context, constraints) { return GlassCard( borderColor: Colors.transparent, padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), child: Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (index) { double heightPercent = (maxChartValue > 0) ? (last7DaysSpends[index] / maxChartValue) : 0; DateTime d = now.subtract(Duration(days: 6 - index)); String dayLabel = ["M", "T", "W", "T", "F", "S", "S"][d.weekday - 1]; return Expanded( child: Column( mainAxisAlignment: MainAxisAlignment.end, children: [ FittedBox(child: Text("₹${last7DaysSpends[index].toStringAsFixed(0)}", style: GoogleFonts.inter(fontSize: 10, color: Colors.white54))), const SizedBox(height: 8), Flexible( child: Container( width: constraints.maxWidth * 0.06, height: (constraints.maxHeight * 0.5) * heightPercent, decoration: BoxDecoration( color: themeController.ledger.withValues(alpha: heightPercent > 0.8 ? 1.0 : 0.6), borderRadius: BorderRadius.circular(6), ), ), ), const SizedBox(height: 12), Text(dayLabel, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)), ], ), ); }), ), ); }, ), ), ], ), ),
        ), 
      ), 
    ); 
  } 
  Widget _buildInsightCard(String title, String date, String detail, Color accentColor) { return GlassCard( borderColor: Colors.transparent, padding: const EdgeInsets.all(20), child: Row( children: [ Icon(Icons.analytics, color: accentColor), const SizedBox(width: 16), Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(title, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)), Text(date, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), Text(detail, style: GoogleFonts.inter(fontSize: 14, color: accentColor, fontWeight: FontWeight.bold)), ], ), ) ], ), ); } 
}
// ==========================================
// 4. TO DO MATRIX (Sleek & Invisible-Text Proof)
// ==========================================

class TaskScreen extends StatefulWidget { const TaskScreen({super.key}); @override State<TaskScreen> createState() => _TaskScreenState(); }

class _TaskScreenState extends State<TaskScreen> { 
  List<Map<String, dynamic>> _tasks = []; 
  final TextEditingController _taskController = TextEditingController(); 
  
  final NotificationOracle _oracle = NotificationOracle.instance;

  @override void initState() { super.initState(); _loadInternalTasks(); } 
  
  void _loadInternalTasks() { 
    String? storedTasks = globalPrefs.getString('internal_tasks'); 
    if (storedTasks != null) { _tasks = List<Map<String, dynamic>>.from(json.decode(storedTasks)); } 
    setState(() {}); 
  } 
  
  void _saveTasks() { globalPrefs.setString('internal_tasks', json.encode(_tasks)); setState(() {}); } 
  
  void _addTask({bool isPriority = false, String? deadline}) { 
    if (_taskController.text.trim().isEmpty) return; 
    HapticFeedback.lightImpact(); 
    _tasks.insert(0, { 
      "id": DateTime.now().millisecondsSinceEpoch, 
      "title": _taskController.text.trim(), 
      "is_completed": false,
      "is_priority": isPriority,
      "deadline": deadline
    }); 
    _saveTasks(); 
    _taskController.clear(); 
    FocusScope.of(context).unfocus(); 
  } 
  
  void _toggleTask(int id) { 
    int index = _tasks.indexWhere((t) => t['id'] == id); 
    if (index != -1) { 
      HapticFeedback.lightImpact(); 
      _tasks[index]['is_completed'] = !_tasks[index]['is_completed']; 
      _saveTasks(); 
    } 
  } 
  
  void _deleteTask(int id) { 
    HapticFeedback.mediumImpact(); 
    var taskIdx = _tasks.indexWhere((t) => t['id'] == id);
    if (taskIdx != -1) {
      var task = _tasks[taskIdx];
      // Slaying the ghost notification
      if (task['notif_id'] != null) {
        _oracle.cancelNotification(task['notif_id']);
      }
      _tasks.removeAt(taskIdx);
      _saveTasks();
    }
  } 

  // Advanced Entry Forge for Custom Deadlines & Priority
  void _openAdvancedForge() async {
    HapticFeedback.selectionClick();
    bool localPriority = false;
    DateTime? localDeadline;
    TimeOfDay? localAlertTime;

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          // DYNAMIC KEYBOARD SHIELD
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), 
          child: SingleChildScrollView( 
            child: Material( 
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF131314), 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), 
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1))
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ADVANCED DIRECTIVE", style: TextStyle(fontSize: 13, color: themeController.todo, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taskController, autofocus: true, 
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      cursorColor: themeController.todo,
                      decoration: InputDecoration(
                        hintText: "Enter objective...", hintStyle: const TextStyle(color: Colors.white38), 
                        filled: true, fillColor: Colors.transparent,
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeController.todo)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // CUSTOM ALERT SCHEDULER
                    GestureDetector(
                      onTap: () async {
                        DateTime now = DateTime.now();
                        DateTime? pickedDate = await showDatePicker(
                          context: ctx, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)),
                          builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: themeController.todo, surface: const Color(0xFF1E1E20))), child: child!),
                        );
                        if (pickedDate != null) {
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0),
                            builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: themeController.todo, surface: const Color(0xFF1E1E20))), child: child!),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              localDeadline = pickedDate;
                              localAlertTime = pickedTime; 
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: localDeadline != null ? themeController.todo : Colors.white54),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                localDeadline != null && localAlertTime != null
                                  ? "${localDeadline!.day}/${localDeadline!.month} @ ${localAlertTime!.hour.toString().padLeft(2,'0')}:${localAlertTime!.minute.toString().padLeft(2,'0')}" 
                                  : "Set Custom Alert", 
                                style: TextStyle(color: localDeadline != null ? Colors.white : Colors.white54, fontSize: 15)
                              ),
                            ),
                            if (localDeadline != null)
                              GestureDetector(
                                onTap: () => setModalState(() { localDeadline = null; localAlertTime = null; }),
                                child: const Icon(Icons.close, color: Colors.white54, size: 20),
                              )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
              
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text("Critical Priority", style: TextStyle(color: localPriority ? Colors.redAccent : Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
                        value: localPriority, activeColor: Colors.redAccent, inactiveTrackColor: Colors.white10,
                        onChanged: (val) => setModalState(() => localPriority = val),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    GestureDetector(
                      onTap: () {
                        if (_taskController.text.trim().isEmpty) return;
                        HapticFeedback.mediumImpact();
                        
                        int taskId = DateTime.now().millisecondsSinceEpoch; 
                        int notifId = (taskId % 100000).toInt(); 

                        if (localAlertTime != null && localDeadline != null) {
                          _oracle.scheduleAlertsUntilDeadline(
                            notifId, 
                            localPriority ? "CRITICAL: Deadline Approaching" : "Routine Deadline", 
                            _taskController.text.trim(), 
                            localAlertTime!,
                            localDeadline!
                          );
                        }

                        _tasks.insert(0, {
                          "id": taskId,
                          "notif_id": notifId,
                          "title": _taskController.text.trim(),
                          "is_completed": false,
                          "is_priority": localPriority,
                          "deadline": localDeadline?.toIso8601String(),
                        });
                        
                        _saveTasks(); 
                        _taskController.clear(); 
                        FocusScope.of(context).unfocus(); 
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: themeController.todo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: themeController.todo.withValues(alpha: 0.4))),
                        child: Center(child: Text("INITIALIZE", style: TextStyle(color: themeController.todo, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2))),
                      ),
                    ),
                  ],
                ),
              ),
            )
          )
        )
      ),
    );
  }

  Widget _buildSleekTaskTile(Map<String, dynamic> task, Color accentColor) { 
    bool isDone = task['is_completed'] ?? false; 
    bool isPriority = task['is_priority'] ?? false;
    String deadlineStr = "";
    bool isOverdue = false;

    if (task['deadline'] != null) {
      DateTime dt = DateTime.parse(task['deadline']);
      deadlineStr = "${dt.day}/${dt.month}";
      if (dt.isBefore(DateTime.now()) && !isDone) isOverdue = true;
    }

    Color displayColor = isPriority ? Colors.redAccent : accentColor;

    return Container( 
      margin: const EdgeInsets.only(bottom: 12), 
      decoration: BoxDecoration( 
        color: isDone ? Colors.transparent : const Color(0xFF161618), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isDone ? Colors.white10 : displayColor.withOpacity(0.3), width: 1.5),
        boxShadow: isDone ? [] : [BoxShadow(color: displayColor.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)],
      ), 
      child: ListTile( 
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), 
        leading: GestureDetector( 
          onTap: () => _toggleTask(task['id']), 
          child: AnimatedContainer( 
            duration: const Duration(milliseconds: 200), width: 26, height: 26, 
            decoration: BoxDecoration( 
              shape: BoxShape.circle, 
              border: Border.all(color: isDone ? Colors.greenAccent : displayColor, width: 2.5), 
              color: isDone ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent 
            ), 
            child: isDone ? const Icon(Icons.check, size: 16, color: Colors.greenAccent) : null, 
          ), 
        ), 
        title: Text( 
          task['title'], 
          style: TextStyle( fontSize: 16, fontWeight: FontWeight.w600, color: isDone ? Colors.white38 : Colors.white, decoration: isDone ? TextDecoration.lineThrough : null ), 
        ), 
        subtitle: (deadlineStr.isNotEmpty || isPriority) 
          ? Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  if (isPriority && !isDone) ...[
                    const Icon(Icons.whatshot, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 4)
                  ],
                  if (deadlineStr.isNotEmpty) 
                    Text(isOverdue && !isDone ? "OVERDUE: $deadlineStr" : "Due: $deadlineStr", 
                         style: TextStyle(color: isDone ? Colors.white24 : (isOverdue ? Colors.redAccent : Colors.white54), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ) 
          : null,
        trailing: IconButton( icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 22), onPressed: () => _deleteTask(task['id']) ), 
      ), 
    ); 
  }

  @override Widget build(BuildContext context) { 
    final activeTasks = _tasks.where((e) => e['is_completed'] == false).toList(); 
    final completedTasks = _tasks.where((e) => e['is_completed'] == true).toList(); 
    
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.transparent),
      child: Scaffold( 
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Directives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1, color: Colors.white)), 
          backgroundColor: Colors.transparent, elevation: 0,
        ), 
        body: UnifiedBackground( 
          child: SafeArea(
            child: Column( 
              children: [ 
                Padding( 
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
                  child: Row( 
                    children: [ 
                      Expanded( 
                        child: GlassCard( 
                          borderColor: Colors.transparent, padding: const EdgeInsets.all(16), 
                          child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("Active Tasks", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text("${activeTasks.length}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeController.todo)), ], ), 
                        ), 
                      ), 
                      const SizedBox(width: 12), 
                      Expanded( 
                        child: GlassCard( 
                          borderColor: Colors.transparent, padding: const EdgeInsets.all(16), 
                          child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("Completed", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text("${completedTasks.length}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)), ], ), 
                        ), 
                      ), 
                    ], 
                  ), 
                ), 
                Expanded( 
                  child: ListView( 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                    children: [ 
                      if (activeTasks.isNotEmpty) ...[ 
                        const Padding( padding: EdgeInsets.only(left: 4, bottom: 8, top: 8), child: Text("Pending", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)), ), 
                        ...activeTasks.map((t) => _buildSleekTaskTile(t, themeController.todo)), 
                      ], 
                      if (completedTasks.isNotEmpty) ...[ 
                        const Padding( padding: EdgeInsets.only(left: 4, bottom: 8, top: 16), child: Text("Completed", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)), ), 
                        ...completedTasks.map((t) => _buildSleekTaskTile(t, Colors.greenAccent)), 
                      ], 
                      const SizedBox(height: 80), 
                    ], 
                  ), 
                ), 
                
                // Sleek Bottom Input Forge
                GlassCard( 
                  borderColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                  child: Row( 
                    children: [ 
                      IconButton(
                        icon: Icon(Icons.tune, color: themeController.todo.withValues(alpha: 0.7)),
                        onPressed: _openAdvancedForge,
                        tooltip: "Advanced Options",
                      ),
                      Expanded( 
                        child: TextField( 
                          controller: _taskController, style: const TextStyle(color: Colors.white, fontSize: 16), 
                          decoration: const InputDecoration( hintText: "Add a new directive...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none ), 
                          onSubmitted: (_) => _addTask(), 
                        ), 
                      ), 
                      Container( 
                        margin: const EdgeInsets.all(4), 
                        decoration: BoxDecoration(color: themeController.todo.withValues(alpha: 0.2), shape: BoxShape.circle), 
                        child: IconButton( icon: Icon(Icons.arrow_upward_rounded, color: themeController.todo, size: 20), onPressed: () => _addTask() ), 
                      ) 
                    ], 
                  ), 
                ) 
              ], 
            ),
          ), 
        ), 
      ),
    ); 
  } 
}



// ==========================================
// 5. INTELLECTUAL VAULT (Masonry Grid & Search Oracle)
// ==========================================
class NotesScreen extends StatefulWidget { const NotesScreen({super.key}); @override State<NotesScreen> createState() => _NotesScreenState(); }
class _NotesScreenState extends State<NotesScreen> { 
  List<Map<String, dynamic>> _allNotes = []; 
  List<Map<String, dynamic>> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  @override void initState() { 
    super.initState(); 
    _loadInternalNotes(); 
    _searchController.addListener(_filterNotes);
  } 
  
  @override void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInternalNotes() { 
    String? storedNotes = globalPrefs.getString('internal_notes'); 
    if (storedNotes != null) {
      _allNotes = List<Map<String, dynamic>>.from(json.decode(storedNotes));
      // Reorder to ensure the freshest insights appear first
      _allNotes.sort((a, b) => b['id'].compareTo(a['id']));
      _filteredNotes = List.from(_allNotes);
    }
    setState(() {}); 
  } 

  // The Search Oracle
  void _filterNotes() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_allNotes);
      } else {
        _filteredNotes = _allNotes.where((note) {
          return note['title'].toString().toLowerCase().contains(query) ||
                 note['content'].toString().toLowerCase().contains(query) ||
                 (note['category'] != null && note['category'].toString().toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  void _openEditor({Map<String, dynamic>? existingNote}) async { 
    HapticFeedback.selectionClick(); 
    await Navigator.push(context, MaterialPageRoute(builder: (context) => NoteEditorScreen(existingNote: existingNote))); 
    _loadInternalNotes(); 
  } 
  
  @override Widget build(BuildContext context) { 
    return Scaffold( 
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Notes'), backgroundColor: Colors.transparent), 
      body: UnifiedBackground( 
        child: SafeArea(
          child: Column(
            children: [
              // Floating Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: themeController.notes.withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: themeController.notes),
                      hintText: "Search records, categories, or keywords...",
                      hintStyle: GoogleFonts.inter(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: _filteredNotes.isEmpty 
                  ? Center( 
                      child: Column( 
                        mainAxisAlignment: MainAxisAlignment.center, 
                        children: [ 
                          Container( padding: const EdgeInsets.all(24), decoration: BoxDecoration( shape: BoxShape.circle, color: themeController.notes.withValues(alpha: 0.05), boxShadow: [BoxShadow(color: themeController.notes.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5)], ), child: Icon(Icons.auto_stories, size: 64, color: themeController.notes), ), 
                          const SizedBox(height: 24), 
                          Text("No Records Found", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), 
                          const SizedBox(height: 8), 
                          Text(_allNotes.isEmpty ? "Tap the + icon to create a new record." : "Thy search yielded no truths.", style: GoogleFonts.inter(color: Colors.white54)), 
                        ], 
                      ), 
                    ) 
                  : MasonryGridView.count( 
                      padding: const EdgeInsets.all(16), 
                      crossAxisCount: 2, 
                      mainAxisSpacing: 16, 
                      crossAxisSpacing: 16, 
                      itemCount: _filteredNotes.length, 
                      itemBuilder: (context, index) { 
                        final note = _filteredNotes[index]; 
                        return GestureDetector( 
                          onTap: () => _openEditor(existingNote: note), 
                          child: GlassCard( 
                            borderColor: themeController.notes, padding: const EdgeInsets.all(16.0), 
                            child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ 
                              Text(note['title'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), 
                              const SizedBox(height: 12), 
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: [
                                  Container( padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: themeController.notes.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(note['date'], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: themeController.notes))),
                                  if (note['category'] != null && note['category'].toString().isNotEmpty)
                                    Container( padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text("#${note['category']}", style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontStyle: FontStyle.italic))),
                                ],
                              ),
                              const SizedBox(height: 16), 
                              Text(note['content'], style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.5), maxLines: 6, overflow: TextOverflow.fade), 
                            ], ), 
                          ), 
                        ); 
                      }, 
                    ),
              ),
            ]
          ), 
        ), 
      ), 
      floatingActionButton: FloatingActionButton( onPressed: () => _openEditor(), backgroundColor: themeController.notes, elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.edit, color: Colors.black) ), 
    ); 
  } 
}
class NoteEditorScreen extends StatefulWidget { final Map<String, dynamic>? existingNote; const NoteEditorScreen({super.key, this.existingNote}); @override State<NoteEditorScreen> createState() => _NoteEditorScreenState(); }
class _NoteEditorScreenState extends State<NoteEditorScreen> { 
  late TextEditingController _titleController; late TextEditingController _contentController; 
  late TextEditingController _categoryCtrl; // PILLAR 3: Category Controller

  @override void initState() { 
    super.initState(); 
    _titleController = TextEditingController(text: widget.existingNote?['title'] ?? ""); 
    _contentController = TextEditingController(text: widget.existingNote?['content'] ?? ""); 
    _categoryCtrl = TextEditingController(text: widget.existingNote?['category'] ?? "General");
  } 
  
  @override void dispose() { _titleController.dispose(); _contentController.dispose(); _categoryCtrl.dispose(); super.dispose(); } 
  int _getWordCount() { String text = _contentController.text.trim(); if (text.isEmpty) return 0; return text.split(RegExp(r'\s+')).length; } 
  
  void _saveAndRetreat() { 
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty) { Navigator.pop(context); return; } 
    List<Map<String, dynamic>> allNotes = []; String? storedNotes = globalPrefs.getString('internal_notes'); if (storedNotes != null) allNotes = List<Map<String, dynamic>>.from(json.decode(storedNotes)); 
    if (widget.existingNote != null) { 
      int index = allNotes.indexWhere((n) => n['id'] == widget.existingNote!['id']); 
      if (index != -1) { 
        allNotes[index]['title'] = _titleController.text.trim().isEmpty ? "Untitled Record" : _titleController.text.trim(); 
        allNotes[index]['content'] = _contentController.text.trim(); 
        allNotes[index]['category'] = _categoryCtrl.text.trim().isEmpty ? "General" : _categoryCtrl.text.trim();
      } 
    } else { 
      allNotes.add({ 
        "id": DateTime.now().millisecondsSinceEpoch, 
        "title": _titleController.text.trim().isEmpty ? "Untitled Record" : _titleController.text.trim(), 
        "content": _contentController.text.trim(), 
        "category": _categoryCtrl.text.trim().isEmpty ? "General" : _categoryCtrl.text.trim(),
        "date": DateTime.now().toIso8601String().split('T')[0], 
      }); 
    } 
    globalPrefs.setString('internal_notes', json.encode(allNotes)); Navigator.pop(context); 
  } 
  
  void _deleteRecord() { if (widget.existingNote != null) { List<Map<String, dynamic>> allNotes = []; String? storedNotes = globalPrefs.getString('internal_notes'); if (storedNotes != null) { allNotes = List<Map<String, dynamic>>.from(json.decode(storedNotes)); allNotes.removeWhere((n) => n['id'] == widget.existingNote!['id']); globalPrefs.setString('internal_notes', json.encode(allNotes)); } } Navigator.pop(context); } 
  
  @override Widget build(BuildContext context) { 
    return Scaffold( 
      extendBodyBehindAppBar: true,
      appBar: AppBar( backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _saveAndRetreat), actions: [ if (widget.existingNote != null) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () { HapticFeedback.mediumImpact(); _deleteRecord(); }), Padding( padding: const EdgeInsets.only(right: 8.0), child: IconButton( icon: Icon(Icons.check_circle, color: themeController.notes, size: 28), onPressed: () { HapticFeedback.lightImpact(); _saveAndRetreat(); } ), ), ], ), 
      body: UnifiedBackground( 
        child: SafeArea( 
          child: Column( children: [ Expanded( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ 
            TextField( controller: _titleController, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white), decoration: InputDecoration( hintText: "Title", hintStyle: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.2)), border: InputBorder.none ), ), 
            // PILLAR 3: Category Input Field
            TextField( controller: _categoryCtrl, style: GoogleFonts.inter(fontSize: 14, color: themeController.notes, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: "Category (e.g., Ideas, Logs)", hintStyle: GoogleFonts.inter(color: themeController.notes.withValues(alpha: 0.5)), border: InputBorder.none, isDense: true ), ),
            Container( width: 60, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 24), decoration: BoxDecoration(color: themeController.notes, borderRadius: BorderRadius.circular(2)), ), 
            Expanded( child: TextField( controller: _contentController, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, height: 1.8), decoration: InputDecoration( hintText: "Begin writing your data...", hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2)), border: InputBorder.none ), onChanged: (_) => setState(() {}), ), ), 
          ], ), ), ), Container( padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), width: double.infinity, decoration: BoxDecoration( color: const Color(0xFF1E1E20).withValues(alpha: 0.5), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))) ), child: Text( "Word Count: ${_getWordCount()}", style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: themeController.notes), textAlign: TextAlign.right, ), ) ], ), 
        ), 
      ), 
    ); 
  } 
}
// ==========================================
// 6. SYSTEM SETTINGS MODULE (INSTANT REACTIVE)
// ==========================================

// ==========================================
// 6. SYSTEM SETTINGS MODULE (GRID SELECTOR)
// ==========================================

class SettingsScreen extends StatefulWidget { 
  const SettingsScreen({super.key}); 
  @override 
  State<SettingsScreen> createState() => _SettingsScreenState(); 
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _surplusAction = 0; 
  int _deficitAction = 0; 
  double _tzOffset = 5.5; 
  late TextEditingController _nameController;

  final Map<String, Color> _availableColors = {
    "Pure White": Colors.white, "Pearl": const Color(0xFFF8F9FA), "Alabaster": const Color(0xFFE5E7EB),
    "Silver": const Color(0xFFD1D5DB), "Storm Grey": const Color(0xFF4F5B66), "Slate": const Color(0xFF334155),
    "Steel": Colors.blueGrey, "Charcoal": const Color(0xFF1c1917), "Obsidian": const Color(0xFF27272a), 
    "Midnight Forge": const Color(0xFF1A1A24), "Twilight": const Color(0xFF393D47),
    "Frost": Colors.lightBlueAccent, "Cyan Mist": const Color(0xFF7CB9B8), "Cerulean": const Color(0xFF007BA7),
    "Azure": const Color(0xFF007FFF), "Cobalt": const Color(0xFF0047AB), "Sapphire": Colors.indigoAccent, 
    "Zaffre": const Color(0xFF0014A8), "Navy Blue": const Color(0xFF000080), "Midnight Blue": const Color(0xFF0f172a),
    "Deep Ocean": const Color(0xFF1e3a8a), "Glacier": const Color(0xFF78B1BF),
    "Mint": Colors.lightGreenAccent, "Seafoam": const Color(0xFF20B2AA), "Emerald": Colors.green,
    "Jade": Colors.greenAccent, "Malachite": const Color(0xFF0BDA51), "Viridian": const Color(0xFF40826D),
    "Olive Drab": const Color(0xFF6B8E23), "Sage": const Color(0xFF9DC183), "Forest Canopy": const Color(0xFF14532d),
    "Hunter Green": const Color(0xFF064e3b), "Neon Green": const Color(0xFF39FF14), "Venom": Colors.limeAccent,
    "Muted Lavender": const Color(0xFF8B82A8), "Rose": Colors.pinkAccent, "Dusty Rose": const Color(0xFFC0848A),
    "Orchid": const Color(0xFFDA70D6), "Amethyst": Colors.purpleAccent, "Violet": const Color(0xFF8A2BE2),
    "Plum": const Color(0xFF8E4585), "Royal Purple": const Color(0xFF7851A9), "Imperial Purple": const Color(0xFF3b0764),
    "Nebula": const Color(0xFF4c1d95), "Deep Indigo": const Color(0xFF4B0082), "Void": Colors.deepPurpleAccent,
    "Gold": Colors.amberAccent, "Pale Gold": const Color(0xFFE6C280), "Flame": Colors.orangeAccent,
    "Burnt Orange": const Color(0xFF7c2d12), "Dark Mustard": const Color(0xFF713f12), "Crimson": Colors.redAccent,
    "Oxblood": const Color(0xFF4c0519), "Blood Moon": const Color(0xFF7f1d1d), "Abyssal Red": const Color(0xFF450a0a),
  };

  @override 
  void initState() { 
    super.initState(); 
    _surplusAction = globalPrefs.getInt('surplusAction') ?? 0; 
    _deficitAction = globalPrefs.getInt('deficitAction') ?? 0; 
    _tzOffset = globalPrefs.getDouble('tzOffset') ?? 5.5; 
    _nameController = TextEditingController(text: themeController.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  List<double> _getValidOffsets() { 
    List<double> offsets = []; 
    for (double i = -12.0; i <= 14.0; i += 1.0) { 
      offsets.add(i); 
      if (i == 3.0) offsets.add(3.5); 
      if (i == 4.0) offsets.add(4.5); 
      if (i == 5.0) offsets.add(5.5); 
      if (i == 9.0) offsets.add(9.5); 
    } 
    return offsets; 
  }
  
  Future<void> _wipeLedger() async { 
    final bool? confirm = await showDialog<bool>( 
      context: context, 
      builder: (context) => AlertDialog( 
        backgroundColor: const Color(0xFF1E1E20), 
        title: const Text("PURGE LEDGER?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)), 
        content: const Text("This cannot be undone.", style: TextStyle(color: Colors.white70, fontSize: 14)), 
        actions: [ 
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ABORT", style: TextStyle(color: Colors.white54))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), 
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("ANNIHILATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
          ), 
        ], 
      ) 
    ); 
    if (confirm == true) { 
      globalPrefs.remove('ledger_transactions'); 
      globalPrefs.setDouble('savings', 0.0); 
      globalPrefs.setDouble('monthlyAllowance', 0.0); 
      globalPrefs.setDouble('monthlyExpendLimit', 0.0); 
      globalPrefs.setDouble('carriedOverBudget', 0.0); 
      globalPrefs.remove('cycleEndDate'); 
      globalPrefs.remove('lastReconciledDate'); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ledger purged.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)); 
    } 
  }

  Widget _buildSectionHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12, left: 4),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 13, color: accent, letterSpacing: 2, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDropdownRow<T>({required String title, required T value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                dropdownColor: const Color(0xFF1E1E20),
                icon: const Icon(Icons.unfold_more, color: Colors.white54, size: 18),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), 
                items: items,
                onChanged: onChanged,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showColorPickerGrid(String title, int index, Color currentColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131314),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select $title Shade", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, crossAxisSpacing: 12, mainAxisSpacing: 12
                  ),
                  itemCount: _availableColors.length,
                  itemBuilder: (context, i) {
                    Color col = _availableColors.values.elementAt(i);
                    bool isSelected = currentColor.value == col.value;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        themeController.updateColor(index, col);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: isSelected ? 3 : 1),
                          boxShadow: [if (isSelected) BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 8)]
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildColorTile(String title, int index, Color currentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          GestureDetector(
            onTap: () => _showColorPickerGrid(title, index, currentColor),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: currentColor, radius: 8),
                  const SizedBox(width: 8),
                  const Icon(Icons.palette, color: Colors.white54, size: 16),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color accentColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: accentColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text("SYSTEM CONFIG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5, color: Colors.white)),
              centerTitle: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            ),
            body: UnifiedBackground(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildSectionHeader("Identity Protocol", themeController.settings),
                    GlassCard(
                      borderColor: themeController.settings, padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        cursorColor: themeController.settings,
                        decoration: const InputDecoration(labelText: "OVERRIDE ALIAS", labelStyle: TextStyle(color: Colors.white54, fontSize: 12), border: InputBorder.none, isDense: true),
                        onSubmitted: (val) { themeController.updateUserName(val); },
                      ),
                    ),

                    _buildSectionHeader("Aesthetic Engine", Colors.white70),
                    GlassCard(
                      borderColor: Colors.transparent, padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDropdownRow<int>(
                            title: "Void Architecture",
                            value: themeController.bgType.clamp(0, 14),
                            items: List.generate(15, (i) => DropdownMenuItem(value: i, child: Text("Theme Mode $i", style: const TextStyle(color: Colors.white)))),
                            onChanged: (val) { if (val != null) themeController.updateBgType(val); }
                          ),
                          const Divider(color: Colors.white12, height: 32),
                          Text("Glass Frosting: ${themeController.glassFrost.toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), activeTrackColor: themeController.settings, inactiveTrackColor: Colors.white12, thumbColor: Colors.white),
                            child: Slider(value: themeController.glassFrost, min: 0, max: 100, onChanged: (val) => themeController.updateGlassFrost(val)),
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader("Subsystem Palette", Colors.white70),
                    GlassCard(
                      borderColor: Colors.transparent, padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildColorTile("Ledger", 0, themeController.ledger), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Directives", 1, themeController.todo), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Sanctum", 2, themeController.sanctum), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Timeline", 3, themeController.timeline), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Notes", 4, themeController.notes), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Settings", 5, themeController.settings), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Pact", 6, themeController.pact), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Bash", 7, themeController.protocols ?? Colors.tealAccent), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Zenspace", 8, themeController.zenspace ?? Colors.blueAccent), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("Attendance", 9, themeController.attendance ?? Colors.blueAccent), const Divider(color: Colors.white12, height: 16),
                          _buildColorTile("GPA", 10, themeController.gpa ?? Colors.blueAccent),
                        ],
                      ),
                    ),

                    _buildSectionHeader("Ledger Parameters", themeController.ledger),
                    GlassCard(
                      borderColor: themeController.ledger, padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildDropdownRow<int>(title: "Surplus Protocol", value: _surplusAction, items: const [DropdownMenuItem(value: 0, child: Text("Carry Over", style: TextStyle(color: Colors.white))), DropdownMenuItem(value: 1, child: Text("To Vault", style: TextStyle(color: Colors.white)))], onChanged: (val) { if (val != null) setState(() { _surplusAction = val; globalPrefs.setInt('surplusAction', val); }); }),
                          const Divider(color: Colors.white12, height: 24),
                          _buildDropdownRow<int>(title: "Deficit Protocol", value: _deficitAction, items: const [DropdownMenuItem(value: 0, child: Text("Deduct Future", style: TextStyle(color: Colors.white))), DropdownMenuItem(value: 1, child: Text("Deduct Vault", style: TextStyle(color: Colors.white)))], onChanged: (val) { if (val != null) setState(() { _deficitAction = val; globalPrefs.setInt('deficitAction', val); }); }),
                          const Divider(color: Colors.white12, height: 24),
                          _buildDropdownRow<double>(title: "Temporal Alignment", value: _tzOffset, items: _getValidOffsets().map((v) => DropdownMenuItem(value: v, child: Text("UTC ${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}", style: const TextStyle(color: Colors.white)))).toList(), onChanged: (val) { if (val != null) setState(() { _tzOffset = val; globalPrefs.setDouble('tzOffset', val); }); }),
                        ],
                      ),
                    ),

                    _buildSectionHeader("Omni-Vault Sync", Colors.blueAccent),
                    _buildActionCard(
                      title: "TRANSMIT FULL BACKUP", icon: Icons.cloud_upload_rounded, accentColor: Colors.blueAccent,
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        if (!await globalGoogleSignIn.isSignedIn()) {
                          final account = await globalGoogleSignIn.signIn();
                          if (account == null) return;
                        }

                        Map<String, dynamic> allData = {};
                        for (String key in globalPrefs.getKeys()) { allData[key] = globalPrefs.get(key); }
                        if (allData.isEmpty) return;
                        
                        String superJson = json.encode(allData);
                        Map<String, String> payload = {"artifact_omni_backup": superJson};

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uplinking to Drive...", style: TextStyle(color: Colors.white))));
                        bool success = await GmailOracle.instance.transmitOmniVault(payload, themeController.userName);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? "Transmission Secure." : "Transmission Failed.", style: const TextStyle(color: Colors.white)), backgroundColor: success ? Colors.green : Colors.red));
                      }
                    ),
                    _buildActionCard(
                      title: "RESTORE FROM VAULT", icon: Icons.cloud_download_rounded, accentColor: Colors.tealAccent,
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        if (!await globalGoogleSignIn.isSignedIn()) {
                          final account = await globalGoogleSignIn.signIn();
                          if (account == null) return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Querying Cloud...", style: TextStyle(color: Colors.white))));
                        Map<String, String>? recovered = await GmailOracle.instance.retrieveOmniVault();
                        if (mounted) {
                          if (recovered != null && recovered.containsKey("artifact_omni_backup")) {
                            Map<String, dynamic> allData = json.decode(recovered["artifact_omni_backup"]!);
                            for (var entry in allData.entries) {
                              if (entry.value is int) globalPrefs.setInt(entry.key, entry.value);
                              else if (entry.value is double) globalPrefs.setDouble(entry.key, entry.value);
                              else if (entry.value is bool) globalPrefs.setBool(entry.key, entry.value);
                              else if (entry.value is String) globalPrefs.setString(entry.key, entry.value);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Overwritten.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restore Failed.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                          }
                        }
                      }
                    ),

                    _buildSectionHeader("Academic Protocols", themeController.attendance ?? Colors.blueAccent),
                    _buildActionCard(
                      title: "RESET ATTENDANCE", icon: Icons.fact_check_rounded, accentColor: Colors.white70,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        String? stored = globalPrefs.getString('attendance_data');
                        if (stored != null) {
                          List<Map<String, dynamic>> subjects = List<Map<String, dynamic>>.from(json.decode(stored));
                          for (var sub in subjects) { sub['attended'] = 0; sub['missed'] = 0; }
                          globalPrefs.setString('attendance_data', json.encode(subjects));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attendance purged.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black));
                        }
                      }
                    ),

                    _buildSectionHeader("Critical Operations", Colors.redAccent),
                    _buildActionCard(title: "PURGE FINANCIAL LEDGER", icon: Icons.delete_forever_rounded, accentColor: Colors.redAccent, onTap: _wipeLedger),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

// ==========================================
// THE PACT (Gemini-Aesthetic Master Build)
// ==========================================
class PactScreen extends StatefulWidget { const PactScreen({super.key}); @override State<PactScreen> createState() => _PactScreenState(); }
class _PactScreenState extends State<PactScreen> {
  List<String> _members = [];
  List<Map<String, dynamic>> _expenses = [];

  @override void initState() { super.initState(); _loadPact(); }

  void _loadPact() {
    String? mData = globalPrefs.getString('pact_members');
    String? eData = globalPrefs.getString('pact_expenses');
    
    if (mData != null) {
      _members = List<String>.from(json.decode(mData));
    } else {
      _members = [themeController.userName, 'Raunit', 'Shubh']; 
      _saveData();
    }
    
    if (eData != null) {
      _expenses = List<Map<String, dynamic>>.from(json.decode(eData));
    }
    setState(() {});
  }

  void _saveData() {
    globalPrefs.setString('pact_members', json.encode(_members));
    globalPrefs.setString('pact_expenses', json.encode(_expenses));
    setState(() {});
  }

  // The Algorithmic Oracle
  List<Map<String, dynamic>> _calculateSettlements() {
    if (_members.isEmpty || _expenses.isEmpty) return [];
    Map<String, double> balances = {for (var m in _members) m: 0.0};
    
    for (var e in _expenses) {
      double amt = e['amount'];
      List<String> inv = List<String>.from(e['involved']);
      if (inv.isEmpty) continue;
      
      double split = amt / inv.length;
      balances[e['payer']] = (balances[e['payer']] ?? 0.0) + amt;
      for (var p in inv) { balances[p] = (balances[p] ?? 0.0) - split; }
    }

    List<MapEntry<String, double>> debtors = balances.entries.where((e) => e.value < -0.01).toList()..sort((a,b) => a.value.compareTo(b.value)); 
    List<MapEntry<String, double>> creditors = balances.entries.where((e) => e.value > 0.01).toList()..sort((a,b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> settlements = [];
    int i = 0, j = 0;
    
    while (i < debtors.length && j < creditors.length) {
      String debtor = debtors[i].key;
      double debtAmt = -debtors[i].value;
      String creditor = creditors[j].key;
      double credAmt = creditors[j].value;

      double settle = min(debtAmt, credAmt);
      settlements.add({ "debtor": debtor, "creditor": creditor, "amount": settle });

      debtors[i] = MapEntry(debtor, -(debtAmt - settle));
      creditors[j] = MapEntry(creditor, credAmt - settle);

      if (debtors[i].value > -0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }
    return settlements;
  }

  // Refined "Gemini-ish" Induct Dialog
  void _addMember() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF09090B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: themeController.pact.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: themeController.pact.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1, color: themeController.pact, size: 40),
              const SizedBox(height: 16),
              Text("Add Member", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Include a New Member to the project", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: ctrl, style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Enter designation...", hintStyle: GoogleFonts.inter(color: Colors.white24),
                  filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(c), child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.white54)))),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: themeController.pact, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () { HapticFeedback.lightImpact(); Navigator.pop(c, ctrl.text.trim()); }, 
                      child: Text("Induct", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold))
                    )
                  ),
                ],
              )
            ],
          ),
        )
      )
    );
    if (name != null && name.isNotEmpty && !_members.contains(name)) {
      _members.add(name);
      _saveData();
    }
  }

  // The Sleek Bottom-Sheet Forge
  void _openExpenseForge({Map<String, dynamic>? existingTx}) async {
    if (_members.isEmpty) return;
    
    final descCtrl = TextEditingController(text: existingTx?['desc'] ?? '');
    final amtCtrl = TextEditingController(text: existingTx != null ? existingTx['amount'].toString() : '');
    String payer = existingTx?['payer'] ?? _members.first;
    List<String> involved = existingTx != null ? List<String>.from(existingTx['involved']) : List.from(_members); 

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: themeController.pact.withValues(alpha: 0.4))),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                      Row(
                        children: [
                          Icon(existingTx == null ? Icons.auto_awesome : Icons.edit_note, color: themeController.pact, size: 28),
                          const SizedBox(width: 12),
                          Text(existingTx == null ? "Enter Project Expense" : "Append Transaction", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      TextField(controller: descCtrl, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20), decoration: InputDecoration(hintText: "What was the toll?", hintStyle: GoogleFonts.inter(color: Colors.white24), border: InputBorder.none)),
                      Container(height: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(vertical: 8)),
                      TextField(controller: amtCtrl, keyboardType: TextInputType.number, style: GoogleFonts.outfit(color: themeController.pact, fontSize: 36, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixText: "₹ ", prefixStyle: GoogleFonts.outfit(color: themeController.pact, fontSize: 36), hintText: "0", hintStyle: GoogleFonts.outfit(color: themeController.pact.withValues(alpha: 0.2)), border: InputBorder.none)),
                      Container(height: 1, color: Colors.white12, margin: const EdgeInsets.only(top: 8, bottom: 24)),
                      
                      Text("Paid By", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: payer, isExpanded: true, dropdownColor: const Color(0xFF1E1E20), style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                            icon: Icon(Icons.keyboard_arrow_down, color: themeController.pact),
                            items: _members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) => setModalState(() => payer = val!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text("Split Among", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: _members.map((m) {
                          bool isSel = involved.contains(m);
                          return GestureDetector(
                            onTap: () { HapticFeedback.lightImpact(); setModalState(() { if (isSel) {
                              involved.remove(m);
                            } else {
                              involved.add(m);
                            } }); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration( color: isSel ? themeController.pact.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSel ? themeController.pact : Colors.white12, width: 1.5), ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isSel ? Icons.check_circle : Icons.circle_outlined, color: isSel ? themeController.pact : Colors.white38, size: 18),
                                  const SizedBox(width: 8),
                                  Text(m, style: GoogleFonts.inter(color: isSel ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: themeController.pact, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          onPressed: () {
                            if (descCtrl.text.isEmpty || amtCtrl.text.isEmpty || involved.isEmpty) return;
                            HapticFeedback.heavyImpact();
                            
                            final newTx = {
                              "id": existingTx?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                              "desc": descCtrl.text.trim(),
                              "amount": double.tryParse(amtCtrl.text) ?? 0.0,
                              "payer": payer,
                              "involved": involved,
                              "date": existingTx?['date'] ?? DateTime.now().toString().split(' ')[0]
                            };

                            if (existingTx != null) {
                              int idx = _expenses.indexWhere((e) => e['id'] == existingTx['id']);
                              if (idx != -1) _expenses[idx] = newTx;
                            } else { _expenses.insert(0, newTx); }
                            
                            _saveData();
                            Navigator.pop(context);
                          },
                          child: Text(existingTx == null ? "Add Transaction" : "Edit Transaction", style: GoogleFonts.outfit(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override Widget build(BuildContext context) {
    List<Map<String, dynamic>> settlements = _calculateSettlements();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('Pact', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1)), 
          backgroundColor: Colors.transparent,
          actions: [ 
            IconButton(icon: Icon(Icons.group_add_rounded, color: themeController.pact, size: 28), onPressed: _addMember),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            indicatorColor: themeController.pact, indicatorWeight: 3,
            labelColor: themeController.pact, unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [ Tab(text: "Transactions"), Tab(text: "Settlements") ],
          ),
        ),
        body: UnifiedBackground(
          child: SafeArea(
            child: TabBarView(
              children: [
                // TAB 1: Transactions (With glowing empty state)
                _expenses.isEmpty 
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: themeController.pact.withValues(alpha: 0.05), boxShadow: [BoxShadow(color: themeController.pact.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 5)]), child: Icon(Icons.receipt_long_rounded, size: 64, color: themeController.pact)),
                        const SizedBox(height: 24),
                        Text("Nothing here!", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final e = _expenses[index];
                        return Dismissible(
                          key: Key(e['id'].toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24)),
                            alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 32),
                          ),
                          onDismissed: (_) { setState(() => _expenses.removeAt(index)); _saveData(); HapticFeedback.mediumImpact(); },
                          child: GestureDetector(
                            onTap: () => _openExpenseForge(existingTx: e),
                            child: GlassCard(
                              borderColor: Colors.transparent, padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Expanded(child: Text(e['desc'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 12),
                                      Text("₹${e['amount'].toStringAsFixed(0)}", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: themeController.pact)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [Icon(Icons.arrow_upward_rounded, size: 16, color: themeController.pact), const SizedBox(width: 8), Text("Covered by ", style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)), Text(e['payer'], style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold))]),
                                        const SizedBox(height: 6),
                                        Row(children: [const Icon(Icons.pie_chart_outline, size: 16, color: Colors.white38), const SizedBox(width: 8), Expanded(child: Text("Split among: ${(e['involved'] as List).join(', ')}", style: GoogleFonts.inter(fontSize: 13, color: Colors.white54), overflow: TextOverflow.ellipsis))]),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                // TAB 2: Dynamic Settlements (With glowing empty state)
                settlements.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withValues(alpha: 0.05), boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 5)]), child: const Icon(Icons.done_all_rounded, size: 64, color: Colors.greenAccent)),
                        const SizedBox(height: 24),
                        Text("No transactions remaining!", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text("All debts are settled!", style: GoogleFonts.inter(color: Colors.white54)),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16), itemCount: settlements.length,
                      itemBuilder: (context, index) {
                        final s = settlements[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [themeController.pact.withValues(alpha: 0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24), border: Border.all(color: themeController.pact.withValues(alpha: 0.2))
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Column(
                                      children: [
                                        CircleAvatar(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), radius: 24, child: const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 20)),
                                        const SizedBox(height: 8),
                                        Text(s['debtor'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    )),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Column(
                                        children: [
                                          Icon(Icons.arrow_forward_rounded, color: themeController.pact, size: 28),
                                          const SizedBox(height: 4),
                                          Text("Owes", style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                                        ],
                                      ),
                                    ),
                                    Expanded(child: Column(
                                      children: [
                                        CircleAvatar(backgroundColor: Colors.greenAccent.withValues(alpha: 0.2), radius: 24, child: const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 20)),
                                        const SizedBox(height: 8),
                                        Text(s['creditor'], style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    )),
                                  ],
                                ),
                                Container(height: 1, color: Colors.white12, margin: const EdgeInsets.symmetric(vertical: 16)),
                                Text("₹${s['amount'].toStringAsFixed(0)}", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: themeController.pact), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
              ],
            ),
          ),
        ),
        // Replace thy current floatingActionButton in pact_screen.dart with this:
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 30.0), // Elevates the button slightly above the bezel
        child: FloatingActionButton(
          backgroundColor: themeController.pact,
          onPressed: _openExpenseForge,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      ),
    );
  }
}

// ==========================================
// 7. ETHEREAL UTILITIES
// ==========================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.borderRadius = 24, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04), 
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor.withValues(alpha: 0.15), width: 1),
      ),
      child: child,
    );
  }
}
class UnifiedBackground extends StatelessWidget {
  final Widget child;
  
  const UnifiedBackground({super.key, required this.child});

  LinearGradient? _getGradient() {
    switch (themeController.bgType) {
      case 0: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF09090B), Color(0xFF09090B)]); 
      case 1: return null; // Ethereal Orbs utilizes the Stack below instead of a base gradient
      case 2: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C1C1E), Color(0xFF09090B)]); 
      case 3: return const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF3f0f0f), Color(0xFF09090B)]); 
      case 4: return const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0f172a), Color(0xFF09090B)]); 
      case 5: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF064e3b), Color(0xFF09090B)]); 
      case 6: return const LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [Color(0xFF3b0764), Color(0xFF09090B)]); 
      case 7: return const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF451a03), Color(0xFF09090B)]); 
      case 8: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF831843), Color(0xFF1e1b4b), Color(0xFF09090B)]); 
      case 9: return const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [Color(0xFF082f49), Color(0xFF09090B)]); 
      case 10: return const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7f1d1d), Color(0xFF09090B)]); 
      case 11: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF134e4a), Color(0xFF022c22), Color(0xFF09090B)]); 
      case 12: return const LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [Color(0xFF4c1d95), Color(0xFF1e1b4b), Color(0xFF09090B)]); 
      case 13: return const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF7c2d12), Color(0xFF450a0a), Color(0xFF09090B)]); 
      case 14: return const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF020617), Color(0xFF000000)]); 
      default: return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C1C1E), Color(0xFF09090B)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF09090B), 
            gradient: _getGradient()
          )
        ),
        if (themeController.bgType == 1) ...[
          Positioned(top: -200, right: -150, child: Container(width: 600, height: 600, decoration: BoxDecoration(shape: BoxShape.circle, color: themeController.sanctum.withValues(alpha: 0.15)))),
          Positioned(bottom: -100, left: -200, child: Container(width: 500, height: 500, decoration: BoxDecoration(shape: BoxShape.circle, color: themeController.timeline.withValues(alpha: 0.15)))),
        ],
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: themeController.glassFrost, sigmaY: themeController.glassFrost), 
            child: Container(color: Colors.transparent)
          )
        ),
        child,
      ],
    );
  }
}
// ==========================================
// 8. TIMETABLE DATA MATRIX
// ==========================================
class TimeBlock {
  final String id; final int dayOfWeek; final String title; final TimeOfDay startTime; final TimeOfDay endTime;
  TimeBlock({required this.id, required this.dayOfWeek, required this.title, required this.startTime, required this.endTime});
  Map<String, dynamic> toMap() => {'id': id, 'dayOfWeek': dayOfWeek, 'title': title, 'startHour': startTime.hour, 'startMinute': startTime.minute, 'endHour': endTime.hour, 'endMinute': endTime.minute};
  factory TimeBlock.fromMap(Map<String, dynamic> map) => TimeBlock(id: map['id'], dayOfWeek: map['dayOfWeek'], title: map['title'], startTime: TimeOfDay(hour: map['startHour'], minute: map['startMinute']), endTime: TimeOfDay(hour: map['endHour'], minute: map['endMinute']));
}





// ==========================================
// 9. TIMETABLE DATA(GDRIVE)
// ==========================================


class SheetSyncService {
  // IMPORTANT: Ensure this link ends in /export?format=csv and NOT /edit
  static const String sheetCsvUrl = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSMa9knjFW7kEDxHR35pJOKl8hNeK4jiA8CEaKpQCHIzKO_pzP-gO1-wyP08i5p2w/pub?output=csv';

  static Future<bool> syncTimetableFromCloud() async {
    try {
      final response = await http.get(Uri.parse(sheetCsvUrl));
      if (response.statusCode == 200) {
        String csvData = response.body;
        
        // THE FIX: Normalizes all invisible line breaks so the rows split perfectly
        String normalizedCsv = csvData.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        List<String> rows = normalizedCsv.split('\n');
        
        Map<int, List<Map<String, String>>> newWeeklyClasses = {
          0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []
        };

        List<String> times = [];
        
        for (int i = 0; i < rows.length; i++) {
          String row = rows[i].trim();
          if (row.isEmpty) continue;

          // Safely splits by comma and removes any rogue quotes
          List<String> cols = row.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
          
          if (times.isEmpty && row.contains('9:00')) {
             times = cols;
             continue;
          }

          if (cols.isNotEmpty && cols[0].isNotEmpty && times.isNotEmpty) {
            String dayStr = cols[0].toLowerCase();
            int dayIndex = -1;
            
            if (dayStr.startsWith('mon')) dayIndex = 0;
            else if (dayStr.startsWith('tue')) dayIndex = 1;
            else if (dayStr.startsWith('wed')) dayIndex = 2;
            else if (dayStr.startsWith('thu')) dayIndex = 3;
            else if (dayStr.startsWith('fri')) dayIndex = 4;
            else if (dayStr.startsWith('sat')) dayIndex = 5;

            if (dayIndex != -1) {
              for (int c = 1; c < cols.length; c++) {
                 String cellData = cols[c];
                 if (cellData.isNotEmpty && cellData.length > 3) {
                    String time = (c < times.length && times[c].isNotEmpty) ? times[c] : "TBD";
                    String title = cellData;
                    String room = "N/A";
                    
                    if (title.contains("(Rn.")) {
                       List<String> parts = title.split("(Rn.");
                       title = parts[0].trim();
                       room = parts[1].replaceAll(")", "").trim();
                    }
                    
                    String type = title.toUpperCase().contains("LAB") ? "Practical" : "Core";
                    
                    newWeeklyClasses[dayIndex]!.add({
                      "title": title, "time": time, "room": room, "type": type,
                    });
                 }
              }
            }
          }
        }

        Map<String, dynamic> toEncode = newWeeklyClasses.map((key, value) => MapEntry(key.toString(), value));
        await globalPrefs.setString('sanctum_timetable', json.encode(toEncode));
        return true; 
      }
      return false;
    } catch (e) {
      debugPrint("Cloud sync failed: $e");
      return false;
    }
  }
}



