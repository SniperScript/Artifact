import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';
import 'dart:async';
import 'main.dart'; 

class ProtocolsScreen extends StatefulWidget {
  const ProtocolsScreen({super.key});
  @override
  State<ProtocolsScreen> createState() => _ProtocolsScreenState();
}

class _ProtocolsScreenState extends State<ProtocolsScreen> {
  String _host = "";
  String _user = "";
  String _password = "";
  int _port = 22;

  List<Map<String, dynamic>> _commands = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadArray();
  }

  void _loadArray() {
    _host = globalPrefs.getString('ssh_host') ?? "";
    _user = globalPrefs.getString('ssh_user') ?? "";
    _password = globalPrefs.getString('ssh_pass') ?? "";
    _port = globalPrefs.getInt('ssh_port') ?? 22;
    
    String? storedCmds = globalPrefs.getString('ssh_commands');
    if (storedCmds != null) {
      _commands = List<Map<String, dynamic>>.from(json.decode(storedCmds));
    } else {
      _commands = [
        {"title": "Reload Hyprland", "cmd": "hyprctl reload"},
        {"title": "Check Thermals", "cmd": "sensors"},
        {"title": "NVIDIA Status", "cmd": "nvidia-smi"},
        {"title": "System Update", "cmd": "sudo dnf update -y"},
      ];
    }
    setState(() {});
  }

  void _saveArray() {
    globalPrefs.setString('ssh_host', _host);
    globalPrefs.setString('ssh_user', _user);
    globalPrefs.setString('ssh_pass', _password);
    globalPrefs.setInt('ssh_port', _port);
    globalPrefs.setString('ssh_commands', json.encode(_commands));
  }

  Future<void> _executeRune(String command, String title) async {
    if (_host.isEmpty || _user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configure connection credentials first.", style: TextStyle(color: Colors.white))));
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isConnecting = true);

    try {
      debugPrint("Attempting SSH to $_user@$_host:$_port");
      final socket = await SSHSocket.connect(_host, _port, timeout: const Duration(seconds: 10));
      
      final client = SSHClient(
        socket,
        username: _user,
        onPasswordRequest: () {
          debugPrint("SSH requested password.");
          return _password;
        },
      );

      await client.authenticated;
      debugPrint("SSH Authenticated successfully.");

      final result = await client.run(command);
      client.close();
      
      String output = utf8.decode(result).trim();
      if (output.isEmpty) output = "[Command Executed Successfully. No output.]";

      _showOutputDialog(title, output);
    } catch (e) {
      debugPrint("SSH Failure: $e");
      // This dialog will now tell thee EXACTLY why it failed (Timeout, Auth, or Socket)
      _showOutputDialog("Connection Failure", "Diagnostic Error:\n$e\n\nEnsure thy laptop's IP is correct, and port 22 is open on Fedora.");
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _showOutputDialog(String title, String output) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.protocols ?? Colors.tealAccent, width: 0.5)),
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(output, style: GoogleFonts.spaceMono(color: Colors.tealAccent, fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Dismiss", style: GoogleFonts.inter(color: Colors.white54))),
        ],
      ),
    );
  }

  void _showConfigDialog() {
    final hostCtrl = TextEditingController(text: _host);
    final userCtrl = TextEditingController(text: _user);
    final passCtrl = TextEditingController(text: _password);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.protocols ?? Colors.tealAccent, width: 0.5)),
        title: Text("Initiate Connection", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: hostCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Host IP (e.g., 192.168.1.5)", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: userCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Username", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.protocols ?? Colors.tealAccent, foregroundColor: Colors.black),
            onPressed: () {
              setState(() { _host = hostCtrl.text.trim(); _user = userCtrl.text.trim(); _password = passCtrl.text.trim(); });
              _saveArray();
              Navigator.pop(ctx);
            }, 
            child: const Text("Attune")
          )
        ],
      ),
    );
  }

  void _showAddCommandDialog() {
    final titleCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: themeController.protocols ?? Colors.tealAccent, width: 0.5)),
        title: Text("Create a new script", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Tile Name", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: cmdCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Bash Command", labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.protocols ?? Colors.tealAccent, foregroundColor: Colors.black),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && cmdCtrl.text.isNotEmpty) {
                setState(() => _commands.add({"title": titleCtrl.text.trim(), "cmd": cmdCtrl.text.trim()}));
                _saveArray();
                Navigator.pop(ctx);
              }
            }, 
            child: const Text("Write")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color accent = themeController.protocols ?? Colors.tealAccent;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Bash", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)), 
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.settings_input_antenna, color: Colors.white54), onPressed: _showConfigDialog)
        ],
      ),
      body: UnifiedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Sleek, minimal Connection Status HUD
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(_host.isEmpty ? Icons.link_off : Icons.terminal, color: _host.isEmpty ? Colors.redAccent : accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_host.isEmpty ? "System currently Unlinked" : "$_user@$_host", style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13)),
                    ),
                    if (_isConnecting)
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: accent, strokeWidth: 2))
                  ],
                ),
              ),
              
              // Ultra-Thin ListView to eliminate Pixel Overflow forever
              Expanded(
                child: _commands.isEmpty 
                  ? Center(child: Text("No commands written.", style: GoogleFonts.inter(color: Colors.white38)))
                  : ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
                    itemCount: _commands.length,
                    itemBuilder: (context, index) {
                      var cmd = _commands[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: accent, width: 2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(cmd['title'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text(cmd['cmd'], style: GoogleFonts.spaceMono(color: Colors.white38, fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: Colors.white70, size: 22),
                                onPressed: () => _executeRune(cmd['cmd'], cmd['title']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _commands.removeAt(index));
                                  _saveArray();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          backgroundColor: accent, 
          elevation: 0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onPressed: _showAddCommandDialog, 
          child: const Icon(Icons.add, color: Colors.black, size: 24)
        ),
      ),
    );
  }
}