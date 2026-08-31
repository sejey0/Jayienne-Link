import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/voice_note_model.dart';
import '../services/supabase_voice_note_service.dart';

class VoiceNotesProvider extends ChangeNotifier {
  final SupabaseVoiceNoteService _service;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _coupleId;
  List<VoiceNoteModel> _voiceNotes = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  // Recording State
  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;
  final int _maxDurationSeconds = 10; // Exactly 10-second limit as requested

  // Playback State
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerPositionSubscription;
  StreamSubscription? _playerDurationSubscription;
  StreamSubscription? _playerCompleteSubscription;

  VoiceNotesProvider({SupabaseVoiceNoteService? service})
      : _service = service ?? SupabaseVoiceNoteService() {
    _initPlayerListeners();
  }

  // Getters
  List<VoiceNoteModel> get voiceNotes => _voiceNotes;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  bool get isRecording => _isRecording;
  int get recordDurationSeconds => _recordDurationSeconds;
  int get maxDurationSeconds => _maxDurationSeconds;
  String? get recordedFilePath => _recordedFilePath;

  String? get currentlyPlayingId => _currentlyPlayingId;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  void _initPlayerListeners() {
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _playerPositionSubscription = _player.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });

    _playerDurationSubscription = _player.onDurationChanged.listen((dur) {
      _totalDuration = dur;
      notifyListeners();
    });

    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _currentlyPlayingId = null;
      notifyListeners();
    });
  }

  /// Initialize provider with couple ID and subscribe to realtime updates
  Future<void> init(String coupleId) async {
    _coupleId = coupleId;
    await fetchVoiceNotes();

    _service.subscribeToVoiceNotes(
      coupleId,
      onUpdate: () {
        fetchVoiceNotes(isSilent: true);
      },
    );
  }

  /// Fetch all voice notes for the couple
  Future<void> fetchVoiceNotes({bool isSilent = false}) async {
    if (_coupleId == null) return;
    if (!isSilent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _voiceNotes = await _service.getVoiceNotes(_coupleId!);
      _error = null;
    } catch (e) {
      debugPrint('[VoiceNotesProvider] fetchVoiceNotes error: $e');
      _error = 'Unable to load voice messages.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Recording Controls ───────────────────────────────────────────────────

  /// Start recording with 10-second automatic countdown
  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          _error = 'Microphone permission is required to record voice notes.';
          notifyListeners();
          return false;
        }
      }

      await stopAudio(); // Stop any active playback

      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(
        tempDir.path,
        'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _isRecording = true;
      _recordedFilePath = filePath;
      _recordDurationSeconds = 0;
      _error = null;
      notifyListeners();

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordDurationSeconds++;
        notifyListeners();

        // Automatically stop at exactly 10 seconds
        if (_recordDurationSeconds >= _maxDurationSeconds) {
          stopRecording();
        }
      });

      return true;
    } catch (e) {
      debugPrint('[VoiceNotesProvider] startRecording error: $e');
      _error = 'Failed to start recording: $e';
      _isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop recording and finalize audio file
  Future<String?> stopRecording() async {
    if (!_isRecording) return _recordedFilePath;

    _recordTimer?.cancel();
    _recordTimer = null;
    _isRecording = false;

    try {
      final path = await _recorder.stop();
      _recordedFilePath = path ?? _recordedFilePath;
      notifyListeners();
      return _recordedFilePath;
    } catch (e) {
      debugPrint('[VoiceNotesProvider] stopRecording error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Cancel and delete current recording
  Future<void> cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    _isRecording = false;

    try {
      await _recorder.stop();
      if (_recordedFilePath != null) {
        final file = File(_recordedFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    _recordedFilePath = null;
    _recordDurationSeconds = 0;
    notifyListeners();
  }

  /// Upload and send the recorded voice note
  Future<bool> sendRecordedVoiceNote({
    required String coupleId,
    required String senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? title,
  }) async {
    if (_recordedFilePath == null) return false;

    final file = File(_recordedFilePath!);
    if (!await file.exists()) {
      _error = 'Recorded file not found.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final audioUrl = await _service.uploadAudio(
        audioSource: file,
        coupleId: coupleId,
        fileName: fileName,
      );

      final durationSecs = _recordDurationSeconds > 0 ? _recordDurationSeconds : 10;

      final newNote = VoiceNoteModel(
        id: '',
        coupleId: coupleId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        audioUrl: audioUrl,
        durationSeconds: durationSecs,
        title: title,
        isListened: false,
        createdAt: DateTime.now(),
      );

      final created = await _service.sendVoiceNote(newNote);
      _voiceNotes.insert(0, created);

      // Clean up local temp file
      try {
        await file.delete();
      } catch (_) {}

      _recordedFilePath = null;
      _recordDurationSeconds = 0;
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[VoiceNotesProvider] sendRecordedVoiceNote error: $e');
      _error = 'Failed to upload voice note. Please try again.';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Playback Controls ────────────────────────────────────────────────────

  /// Play or toggle playback of a specific voice note
  Future<void> playAudio(String noteId, String url) async {
    try {
      if (_currentlyPlayingId == noteId && _isPlaying) {
        await _player.pause();
        _isPlaying = false;
        notifyListeners();
        return;
      }

      if (_currentlyPlayingId == noteId && !_isPlaying) {
        await _player.resume();
        _isPlaying = true;
        notifyListeners();
        return;
      }

      await _player.stop();
      _currentlyPlayingId = noteId;
      _isPlaying = true;
      _currentPosition = Duration.zero;
      notifyListeners();

      await _player.play(UrlSource(url));

      // Mark as listened in database
      markAsListened(noteId);
    } catch (e) {
      debugPrint('[VoiceNotesProvider] playAudio error: $e');
      _isPlaying = false;
      _currentlyPlayingId = null;
      notifyListeners();
    }
  }

  /// Pause current playback
  Future<void> pauseAudio() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (_) {}
  }

  /// Stop current playback
  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentlyPlayingId = null;
      _currentPosition = Duration.zero;
      notifyListeners();
    } catch (_) {}
  }

  /// Seek within currently playing audio
  Future<void> seekAudio(Duration position) async {
    try {
      await _player.seek(position);
    } catch (_) {}
  }

  /// Mark note as listened locally and in Supabase
  Future<void> markAsListened(String noteId) async {
    final index = _voiceNotes.indexWhere((n) => n.id == noteId);
    if (index != -1 && !_voiceNotes[index].isListened) {
      _voiceNotes[index] = _voiceNotes[index].copyWith(isListened: true);
      notifyListeners();
      await _service.markAsListened(noteId);
    }
  }

  /// Delete voice note
  Future<bool> deleteVoiceNote(String noteId, {String? audioUrl}) async {
    try {
      if (_currentlyPlayingId == noteId) {
        await stopAudio();
      }

      _voiceNotes.removeWhere((n) => n.id == noteId);
      notifyListeners();

      await _service.deleteVoiceNote(noteId, audioUrl: audioUrl);
      return true;
    } catch (e) {
      debugPrint('[VoiceNotesProvider] deleteVoiceNote error: $e');
      await fetchVoiceNotes(isSilent: true);
      return false;
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playerStateSubscription?.cancel();
    _playerPositionSubscription?.cancel();
    _playerDurationSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _player.dispose();
    _recorder.dispose();
    _service.unsubscribe();
    super.dispose();
  }
}
