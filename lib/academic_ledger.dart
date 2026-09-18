import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'main.dart'; 

class AcademicLedgerWidget extends StatefulWidget {
  const AcademicLedgerWidget({super.key});

  @override
  State<AcademicLedgerWidget> createState() => _AcademicLedgerWidgetState();
}

class _AcademicLedgerWidgetState extends State<AcademicLedgerWidget> {
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  void _loadLedger() {
    String? stored = globalPrefs.getString('academic_ledger');
    if (stored != null) {
      _subjects = List<Map<String, dynamic>>.from(json.decode(stored));
    } else {
      _subjects = [
        {"name": "Core Engineering", "attended": 0, "total": 0},
        {"name": "Applied Mathematics", "attended": 0, "total": 0},
      ];
    }
    setState(() {});
  }

  void _saveLedger() {
    globalPrefs.setString('academic_ledger', json.encode(_subjects));
    setState(() {});
  }

  void _updateAttendance(int index, bool attended) {
    HapticFeedback.selectionClick();
    if (attended) {
      _subjects[index]['attended']++;
      _subjects[index]['total']++;
    } else {
      _subjects[index]['total']++;
    }
    _saveLedger();
  }
  
  void _decrementTotal(int index) {
    HapticFeedback.lightImpact();
    if (_subjects[index]['total'] > 0) {
      if (_subjects[index]['attended'] > 0 && _subjects[index]['attended'] == _subjects[index]['total']) {
         _subjects[index]['attended']--; 
      }
      _subjects[index]['total']--;
      _saveLedger();
    }
  }

  // --- DYNAMIC CONTROL METHODS ---
  
  void _showAddSubjectDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.attendance ?? Colors.deepPurpleAccent, width: 0.5)),
        title: const Text("Inscribe New Subject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl, 
          style: const TextStyle(color: Colors.white), 
          autofocus: true,
          decoration: const InputDecoration(hintText: "Subject Name", hintStyle: TextStyle(color: Colors.white38))
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.attendance ?? Colors.deepPurpleAccent, foregroundColor: Colors.black),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() { _subjects.add({"name": nameCtrl.text.trim(), "attended": 0, "total": 0}); });
                _saveLedger();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  void _showEditSubjectDialog(int index) {
    final TextEditingController nameCtrl = TextEditingController(text: _subjects[index]['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.attendance ?? Colors.deepPurpleAccent, width: 0.5)),
        title: const Text("Modify Subject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl, 
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() { _subjects.removeAt(index); });
              _saveLedger();
              Navigator.pop(ctx);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.attendance ?? Colors.deepPurpleAccent, foregroundColor: Colors.black),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() { _subjects[index]['name'] = nameCtrl.text.trim(); });
                _saveLedger();
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    Color accent = themeController.attendance ?? Colors.deepPurpleAccent;

    return Container(
      width: double.infinity,
      // THE OVERFLOW FIX: Constraints ensure it never breaks screen boundaries
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 20 // KEYBOARD SHIELD
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C), // Deep seamless background
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Shrinks gracefully if list is small
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ACADEMIC LEDGER",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 2.0),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: accent, size: 22),
                onPressed: _showAddSubjectDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_subjects.isEmpty)
             const Center(child: Padding(
               padding: EdgeInsets.all(20.0),
               child: Text("No subjects inscribed.", style: TextStyle(color: Colors.white38)),
             ))
          else
            // THE OVERFLOW FIX: Flexible allows the list to scroll seamlessly within constraints
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _subjects.length,
                itemBuilder: (context, idx) {
                  var sub = _subjects[idx];
                  int att = sub['attended'];
                  int tot = sub['total'];
                  double percentage = tot == 0 ? 1.0 : att / tot;
                  bool isDanger = percentage < 0.75 && tot > 0;
                  Color progressColor = isDanger ? Colors.redAccent : accent;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => _showEditSubjectDialog(idx),
                              child: Row(
                                children: [
                                  Text(
                                    sub['name'],
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit, size: 14, color: Colors.white24),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onLongPress: () => _decrementTotal(idx),
                              child: Text(
                                tot == 0 ? "100%" : "${(percentage * 100).toStringAsFixed(1)}%",
                                style: TextStyle(color: progressColor, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$att / $tot Classes",
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _updateAttendance(idx, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text("Miss", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => _updateAttendance(idx, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                                    ),
                                    child: Text("Attend", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}