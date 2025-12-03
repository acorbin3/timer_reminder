import 'package:audioplayers/audioplayers.dart';

class AlarmSoundService {
  static final AlarmSoundService instance = AlarmSoundService._init();

  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isStarting = false; // Prevent race conditions

  AlarmSoundService._init();

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm() async {
    print('[ALARM SOUND] playAlarm() called, isPlaying: $_isPlaying, isStarting: $_isStarting');

    // Prevent multiple simultaneous start attempts
    if (_isPlaying || _isStarting) {
      print('[ALARM SOUND] Already playing or starting, skipping');
      return;
    }

    _isStarting = true;

    try {
      // Dispose any existing player first
      if (_player != null) {
        print('[ALARM SOUND] Disposing existing player...');
        await _player!.dispose();
        _player = null;
      }

      print('[ALARM SOUND] Creating AudioPlayer...');
      _player = AudioPlayer();

      // Set audio context for alarm - plays through alarm channel
      print('[ALARM SOUND] Setting audio context...');
      await _player!.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ));

      // Listen to player state changes for debugging
      _player!.onPlayerStateChanged.listen((state) {
        print('[ALARM SOUND] Player state changed: $state');
        if (state == PlayerState.playing) {
          _isPlaying = true;
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          _isPlaying = false;
        }
      });

      _player!.onLog.listen((log) {
        print('[ALARM SOUND] Player log: $log');
      });

      print('[ALARM SOUND] Setting release mode to loop...');
      await _player!.setReleaseMode(ReleaseMode.loop);

      print('[ALARM SOUND] Setting volume to 1.0...');
      await _player!.setVolume(1.0);

      print('[ALARM SOUND] Playing asset...');
      await _player!.play(AssetSource('sounds/alarm.mp3'));

      _isPlaying = true;
      _isStarting = false;
      print('[ALARM SOUND] ✓ Started playing alarm successfully');
    } catch (e, stackTrace) {
      print('[ALARM SOUND] ✗ Error playing alarm: $e');
      print('[ALARM SOUND] Stack trace: $stackTrace');
      _isPlaying = false;
      _isStarting = false;
    }
  }

  Future<void> stopAlarm() async {
    print('[ALARM SOUND] stopAlarm() called, isPlaying: $_isPlaying');

    if (_player == null) {
      print('[ALARM SOUND] No player to stop');
      _isPlaying = false;
      _isStarting = false;
      return;
    }

    try {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
      _isPlaying = false;
      _isStarting = false;
      print('[ALARM SOUND] ✓ Stopped alarm');
    } catch (e) {
      print('[ALARM SOUND] Error stopping alarm: $e');
      _isPlaying = false;
      _isStarting = false;
    }
  }

  Future<void> dispose() async {
    await stopAlarm();
  }
}
