import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; 

class GpaPredictorScreen extends StatefulWidget {
  const GpaPredictorScreen({super.key});
  @override
  State<GpaPredictorScreen> createState() => _GpaPredictorScreenState();
}

class _GpaPredictorScreenState extends State<GpaPredictorScreen> {
  final List<Map<String, dynamic>> _courses = [];

  void _showAddCourseDialog() {
    final nameCtrl = TextEditingController(); 
    final credCtrl = TextEditingController(); 
    final gradeCtrl = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20), 
        title: Text("Add Course Data", style: GoogleFonts.outfit(color: Colors.purpleAccent, fontWeight: FontWeight.bold)), 
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Course ID", labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)), 
              const SizedBox(height: 12),
              TextField(controller: credCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Credits (e.g. 3)", labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)), 
              const SizedBox(height: 12),
              TextField(controller: gradeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Expected Grade (e.g. 9)", labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white))
            ]
          )
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () { 
              if(nameCtrl.text.isNotEmpty && credCtrl.text.isNotEmpty) { 
                setState(() { 
                  _courses.add({"name": nameCtrl.text, "credits": double.tryParse(credCtrl.text) ?? 0, "grade": double.tryParse(gradeCtrl.text) ?? 0}); 
                }); 
                Navigator.pop(c); 
              }
            }, child: Text("Append", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCredits = 0; 
    double totalPoints = 0;
    for(var c in _courses) { 
      totalCredits += c['credits']; 
      totalPoints += (c['credits'] * c['grade']); 
    }
    double sgpa = totalCredits == 0 ? 0.0 : totalPoints / totalCredits;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text("Academic Predictor", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0),
      body: UnifiedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                GlassCard(
                  borderColor: Colors.purpleAccent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text("Projected SGPA", style: GoogleFonts.inter(color: Colors.white54)),
                      const SizedBox(height: 8),
                      Text(sgpa.toStringAsFixed(2), style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                      const SizedBox(height: 8),
                      Text("Total Credits: ${totalCredits.toInt()}", style: GoogleFonts.inter(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _courses.isEmpty ? Center(child: Text("Matrix empty. Append course data.", style: GoogleFonts.inter(color: Colors.white38))) : ListView.builder(
                    itemCount: _courses.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                      child: ListTile(
                        title: Text(_courses[i]['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text("Credits: ${_courses[i]['credits'].toInt()} | Target Grade: ${_courses[i]['grade'].toInt()}", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _courses.removeAt(i))),
                      ),
                    )
                  ),
                ),
              ],
            ),
          ),
        )
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.purpleAccent,
        onPressed: _showAddCourseDialog,
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text("Add Course", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}