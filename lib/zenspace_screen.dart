import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'main.dart'; 

class ZenspaceScreen extends StatefulWidget {
  const ZenspaceScreen({super.key});
  @override
  State<ZenspaceScreen> createState() => _ZenspaceScreenState();
}

class _ZenspaceScreenState extends State<ZenspaceScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedNoise = 'None';
  bool _isPlaying = false;
  bool _isFetching = false;
  
  final String _googleApiKey = "YOUR_API_KEY_HERE"; 
  
  List<Map<String, dynamic>> _drivePlaylist = [];
  int _currentDriveIndex = 0;
  bool _isDrivePlaylist = false;
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<String> _noises = ['None', 'Rainfall', 'Fireplace', 'White Noise', '+ Custom Link'];

  @override
  void initState() {
    super.initState();
    
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        
        if (state.processingState == ProcessingState.completed) {
          if (_isDrivePlaylist && _drivePlaylist.isNotEmpty) {
            _playNextDriveSong();
          } else if (_selectedNoise != 'None' && !_isDrivePlaylist) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    HapticFeedback.mediumImpact();
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _handleNoiseSelection(String noise) async {
    HapticFeedback.selectionClick();

    if (noise == '+ Custom Link') {
      _showCustomAudioDialog();
      return;
    }

    if (_selectedNoise == noise) {
      _togglePlayPause();
      return;
    }

    setState(() { 
      _selectedNoise = noise; 
      _isDrivePlaylist = false; 
      _position = Duration.zero; 
      _duration = Duration.zero;
    });
    
    await _audioPlayer.stop();

    if (noise != 'None') {
      await _audioPlayer.setLoopMode(LoopMode.one);
      String rawFileName = '${noise.toLowerCase().replaceAll(' ', '_')}.mp3';
      
      try {
        final source = AudioSource.uri(
          Uri.parse('asset:///assets/audio/$rawFileName'),
          tag: MediaItem(
            id: noise, 
            title: noise, 
            album: "Zenspace Ambience",
            artUri: Uri.parse("https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?q=80&w=500&auto=format&fit=crop"), // <--- INSIDE MediaItem
          ),
        );
        await _audioPlayer.setAudioSource(source);
        await _audioPlayer.play(); 
      } catch (e) { 
        debugPrint("Audio Error for $rawFileName: $e"); 
      }
    }
  }

  Future<void> _processCustomLink(String url) async {
    await _audioPlayer.stop();
    setState(() => _isFetching = true);
    
    String? folderId;
    var match = RegExp(r'[-\w]{25,}').firstMatch(url);
    if (match != null) folderId = match.group(0);

    if (folderId != null) {
      List<Map<String, dynamic>> allExtractedFiles = [];
      String? pageToken;
      
      try {
        do {
          String query = Uri.encodeQueryComponent("'$folderId' in parents");
          String apiUrl = "https://www.googleapis.com/drive/v3/files?q=$query&fields=nextPageToken,files(id,name,mimeType)&key=$_googleApiKey";
          if (pageToken != null) apiUrl += "&pageToken=$pageToken";
          var response = await http.get(Uri.parse(apiUrl));
          
          if (response.statusCode == 200) {
            var data = json.decode(response.body);
            if (data['files'] != null) allExtractedFiles.addAll(List<Map<String, dynamic>>.from(data['files']));
            pageToken = data['nextPageToken'];
          } else break;
        } while (pageToken != null);
        
        _drivePlaylist = allExtractedFiles.where((file) {
          String name = (file['name'] ?? '').toString().toLowerCase();
          String mime = (file['mimeType'] ?? '').toString().toLowerCase();
          return mime.contains('audio') || name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.m4a');
        }).toList();

        if (_drivePlaylist.isNotEmpty) {
          _isDrivePlaylist = true;
          _currentDriveIndex = 0;
          await _audioPlayer.setLoopMode(LoopMode.off); 
          _playCurrentDriveSong();
        } 
      } catch (e) {
        debugPrint("Link parsing error: $e");
      }
    }
    if (mounted) setState(() => _isFetching = false);
  }

  Future<void> _playCurrentDriveSong() async {
    if (_drivePlaylist.isEmpty) return;
    try {
      await _audioPlayer.stop(); 
      String fileId = _drivePlaylist[_currentDriveIndex]['id'];
      String trackName = _drivePlaylist[_currentDriveIndex]['name'];

      setState(() {
        _selectedNoise = trackName;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      final source = AudioSource.uri(
        Uri.parse("https://www.googleapis.com/drive/v3/files/$fileId?alt=media&key=$_googleApiKey"),
        tag: MediaItem(
          id: fileId, 
          title: trackName, 
          album: "Drive Stream",
          artUri: Uri.parse("https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=500&auto=format&fit=crop"), // <--- INSIDE MediaItem
        ),
      );

      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
    } catch (e) {
      _playNextDriveSong();
    }
  }

  void _playNextDriveSong() {
    if (_drivePlaylist.isEmpty) return;
    _currentDriveIndex = (_currentDriveIndex + 1) % _drivePlaylist.length;
    _playCurrentDriveSong();
  }

  void _playPreviousDriveSong() {
    if (_drivePlaylist.isEmpty) return;
    _currentDriveIndex = _currentDriveIndex - 1 < 0 ? _drivePlaylist.length - 1 : _currentDriveIndex - 1;
    _playCurrentDriveSong();
  }

  void _stopCompletely() async {
    HapticFeedback.heavyImpact();
    await _audioPlayer.stop();
    setState(() { _selectedNoise = 'None'; _position = Duration.zero; _duration = Duration.zero; });
  }

  void _showCustomAudioDialog() {
    final TextEditingController urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131314),
        title: const Text("Custom Audio Stream", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(controller: urlCtrl, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeController.zenspace, foregroundColor: Colors.black),
            onPressed: () {
              String url = urlCtrl.text.trim();
              Navigator.pop(ctx); 
              if (url.isNotEmpty) _processCustomLink(url);
            },
            child: const Text("Stream"),
          )
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Widget _buildReactor(bool isZen, Color accent, double screenWidth, double screenHeight, bool isLandscape) {
    bool reactorActive = isZen || _isPlaying || _isFetching;
    double maxAvailableWidth = isLandscape ? screenWidth * 0.45 : screenWidth * 0.8;
    double maxAvailableHeight = isLandscape ? screenHeight * 0.75 : screenHeight * 0.4;
    double reactorSize = min(maxAvailableWidth, maxAvailableHeight);
    
    if (isZen) reactorSize = min(isLandscape ? screenWidth * 0.6 : screenWidth * 0.85, isLandscape ? screenHeight * 0.85 : screenHeight * 0.6);

    return GestureDetector(
      onTap: () { HapticFeedback.heavyImpact(); themeController.toggleZenMode(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
        width: reactorSize, height: reactorSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withOpacity(isZen ? 0.05 : 0.3), width: isZen ? 1 : 2),
          boxShadow: [BoxShadow(color: accent.withOpacity(reactorActive ? 0.15 : 0.0), blurRadius: reactorActive ? 120 : 40)],
        ),
        child: Center(
          child: _isFetching 
            ? SizedBox(width: reactorSize * 0.3, height: reactorSize * 0.3, child: CircularProgressIndicator(color: accent, strokeWidth: 2))
            : AnimatedIconData(isZen: isZen, isPlaying: _isPlaying, currentSong: _selectedNoise, accent: accent, size: reactorSize * 0.3),
        ),
      ),
    );
  }

  Widget _buildControls(bool isZen, Color accent) {
    return AnimatedOpacity(
      opacity: isZen ? 0.0 : 1.0, duration: const Duration(milliseconds: 300),
      child: isZen ? const SizedBox.shrink() : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_selectedNoise, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          
          if (_selectedNoise != 'None' && _duration.inSeconds > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14), activeTrackColor: accent, inactiveTrackColor: Colors.white12, thumbColor: accent),
                    child: Slider(
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (val) => _audioPlayer.seek(Duration(seconds: val.toInt())),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position), style: const TextStyle(fontFamily: 'monospace', color: Colors.white54, fontSize: 11)),
                      Text(_formatDuration(_duration), style: const TextStyle(fontFamily: 'monospace', color: Colors.white54, fontSize: 11)),
                    ],
                  )
                ],
              ),
            ),
          
          if (_selectedNoise != 'None')
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDrivePlaylist) IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), iconSize: 36, onPressed: _playPreviousDriveSong),
                  const SizedBox(width: 16),
                  IconButton(icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: accent), iconSize: 56, onPressed: _togglePlayPause),
                  const SizedBox(width: 16),
                  if (_isDrivePlaylist) IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), iconSize: 36, onPressed: _playNextDriveSong),
                  if (!_isDrivePlaylist) IconButton(icon: const Icon(Icons.stop_circle, color: Colors.white38), iconSize: 36, onPressed: _stopCompletely),
                ],
              ),
            ),
          
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: _noises.map((noise) {
                bool isSelected = _selectedNoise == noise || (_isDrivePlaylist && noise == '+ Custom Link');
                return GestureDetector(
                  onTap: () => _handleNoiseSelection(noise),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: isSelected ? accent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? accent : Colors.white12)),
                    child: Text(noise, style: TextStyle(color: isSelected ? accent : Colors.white70, fontSize: 14)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color accent = themeController.zenspace ?? Colors.blueAccent; 
    bool isZen = themeController.isZenMode;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: UnifiedBackground(
        child: SafeArea(
          child: isLandscape 
            ? (isZen ? Center(child: _buildReactor(isZen, accent, screenWidth, screenHeight, true)) : Row(children: [ Expanded(child: Center(child: _buildReactor(isZen, accent, screenWidth, screenHeight, true))), Expanded(child: Center(child: SingleChildScrollView(child: _buildControls(isZen, accent))))]))
            : Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ _buildReactor(isZen, accent, screenWidth, screenHeight, false), const SizedBox(height: 32), _buildControls(isZen, accent) ]))),
        ),
      ),
    );
  }
}

class AnimatedIconData extends StatelessWidget {
  final bool isZen;
  final bool isPlaying;
  final String currentSong;
  final Color accent;
  final double size;
  
  const AnimatedIconData({ super.key, required this.isZen, required this.isPlaying, required this.currentSong, required this.accent, required this.size });

  IconData _getIcon() {
    if (!isPlaying && !isZen) return Icons.spa_rounded;
    if (!isPlaying && isZen) return Icons.self_improvement_rounded;

    String lower = currentSong.toLowerCase();
    if (lower.contains('rain')) return Icons.water_drop_rounded;
    if (lower.contains('fire')) return Icons.local_fire_department_rounded;
    if (lower.contains('white') || lower.contains('static')) return Icons.waves_rounded;
    return Icons.self_improvement_rounded; 
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Icon(_getIcon(), key: ValueKey<String>("${isPlaying}_${isZen}_$currentSong"), size: size, color: (isPlaying || isZen) ? accent : Colors.white24),
    );
  }
}