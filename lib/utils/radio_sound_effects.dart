import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// US Military AN/PRC-152 Falcon III & Motorola APX Taktik Telsiz Ses Motoru
class RadioSoundEffects {
  static bool _initialized = false;
  static bool _isInitializing = false;
  static AudioPlayer? _player;
  static Directory? _tempDir;

  static File? _squelchInFile;
  static File? _rogerSquelchTailFile;
  static File? _callAlertFile;

  static int _lastRogerTimestamp = 0;

  /// Ses motorunu tamamen asenkron, UI'yi asla dondurmayacak şekilde arka planda hazırlar
  static Future<void> init() async {
    if (_initialized || _isInitializing) return;
    _isInitializing = true;

    try {
      _tempDir = await getTemporaryDirectory();

      _player = AudioPlayer();
      try {
        await _player!.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
      await _player!.setVolume(1.0);

      // Dosyaları arka planda hazırla (main thread'i bloklamaz)
      Future.microtask(() async {
        try {
          _squelchInFile = await _getOrGenerateFile('us_military_squelch_in_v2', _generateUsMilitarySquelchInWav);
          _rogerSquelchTailFile = await _getOrGenerateFile('us_military_roger_tail_v2', _generateUsMilitaryRogerSquelchTailWav);
          _callAlertFile = await _getOrGenerateFile('us_military_selcall_alert_v2', _generateTacticalCallAlertWav);
          _initialized = true;
          debugPrint('RadioSoundEffects: US Military AN/PRC-152 Taktik Ses Motoru Hazır.');
        } catch (e) {
          debugPrint('RadioSoundEffects dosya hazırlama hatası: $e');
        }
      });
    } catch (e) {
      debugPrint('RadioSoundEffects init hatası: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Telsiz mandalına basıldığında: Mekanik PTT switch + Harris Kripto Senkronizasyon Talk-Permit + RF Hışırtısı
  static Future<void> playSquelchIn() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.heavyImpact();
      if (_squelchInFile != null && _squelchInFile!.existsSync()) {
        _playFile(_squelchInFile);
      } else {
        final file = await _getOrGenerateFile('us_military_squelch_in_v2', _generateUsMilitarySquelchInWav);
        _playFile(file);
      }
    } catch (_) {}
  }

  /// MANDAL BIRAKILDIĞINDA (HEM KONUŞANA HEM DİNLEYENE):
  /// Amerikan Askeri Efsanevi Roger Beep + "K-ŞŞŞT" / "K-CHHHHK" Taktik Squelch Tail Patlaması
  static Future<void> playRogerBeep() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Çift tetiklenmeyi (Agora sessizlik + Socket.io anonsu) önlemek için 500ms debounce
    if (now - _lastRogerTimestamp < 500) return;
    _lastRogerTimestamp = now;

    try {
      HapticFeedback.mediumImpact();
      if (_rogerSquelchTailFile != null && _rogerSquelchTailFile!.existsSync()) {
        _playFile(_rogerSquelchTailFile);
      } else {
        final file = await _getOrGenerateFile('us_military_roger_tail_v2', _generateUsMilitaryRogerSquelchTailWav);
        _playFile(file);
      }
    } catch (_) {}
  }

  /// Karşı taraf sustuğunda veya kanal sessizliğe geçtiğinde çalınacak kapanış efekti
  static Future<void> playSquelchTail() async {
    await playRogerBeep();
  }

  /// Telsiz Çağrısı / Daveti Geldiğinde: 2-Tonlu Taktik Selcall / Paging Alarmı
  static Future<void> playTacticalCallAlert() async {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 160), () {
        HapticFeedback.heavyImpact();
      });

      if (_callAlertFile != null && _callAlertFile!.existsSync()) {
        _playFile(_callAlertFile);
      } else {
        final file = await _getOrGenerateFile('us_military_selcall_alert_v2', _generateTacticalCallAlertWav);
        _playFile(file);
      }
    } catch (_) {}
  }

  static Future<File> _getOrGenerateFile(String key, Uint8List Function() generator) async {
    _tempDir ??= await getTemporaryDirectory();
    final file = File('${_tempDir!.path}/$key.wav');
    if (!file.existsSync()) {
      final bytes = generator();
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  static void _playFile(File? file) {
    if (file == null) return;
    Future(() async {
      try {
        _player ??= AudioPlayer();
        if (file.existsSync()) {
          await _player!.stop();
          await _player!.play(DeviceFileSource(file.path));
        }
      } catch (e) {
        debugPrint('RadioSoundEffects play error: $e');
      }
    });
  }

  // =========================================================================
  // 44.1 kHz 16-BIT PCM WAV ASKERİ SES SENTEZLEYİCİLERİ
  // =========================================================================

  /// AMERİKAN ASKERİ AN/PRC-152 FALCON III & MOTOROLA TALK-PERMIT AÇILIŞ SESİ
  /// - 1. Aşama: Ağır mekanik Peltor PTT switch darbesi ("K-LICK", 0 - 35ms)
  /// - 2. Aşama: Harris kripto senkronizasyon tonları (930 Hz -> 1240 Hz -> 1580 Hz yükselen askeri sinyal)
  /// - 3. Aşama: Taşıyıcı analog RF squelch burst (140 - 420ms)
  static Uint8List _generateUsMilitarySquelchInWav() {
    const sampleRate = 44100;
    const durationMs = 430;
    final totalSamples = (sampleRate * durationMs / 1000).round();
    final pcmData = Int16List(totalSamples);
    final random = Random();

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sample = 0.0;

      // 1. Ağır Mekanik PTT Switch Klik Darbesi (0 - 35 ms)
      if (t < 0.035) {
        final clickEnv = exp(-t * 200);
        final click = sin(2 * pi * 680 * t) + 0.65 * sin(2 * pi * 1360 * t);
        sample += click * clickEnv * 0.98;
      }

      // 2. US Army 3'lü Taktiksel Kripto Kilit Bip Sinyalleri:
      // Ton 1: 930 Hz (35ms - 68ms)
      if (t >= 0.035 && t < 0.068) {
        final localT = t - 0.035;
        final env = sin(pi * (localT / 0.033));
        sample += sin(2 * pi * 930 * localT) * 0.88 * env;
      }
      // Ton 2: 1240 Hz (72ms - 105ms)
      else if (t >= 0.072 && t < 0.105) {
        final localT = t - 0.072;
        final env = sin(pi * (localT / 0.033));
        sample += sin(2 * pi * 1240 * localT) * 0.88 * env;
      }
      // Ton 3: 1580 Hz (110ms - 150ms)
      else if (t >= 0.110 && t < 0.150) {
        final localT = t - 0.110;
        final env = sin(pi * (localT / 0.040));
        sample += sin(2 * pi * 1580 * localT) * 0.92 * env;
      }

      // 3. Taşıyıcı Analog RF Squelch Burst (145ms - 430ms)
      if (t >= 0.145) {
        final localT = t - 0.145;
        final rem = (1.0 - (localT / (0.430 - 0.145))).clamp(0.0, 1.0);
        final env = pow(rem, 1.4);
        final whiteNoise = (random.nextDouble() * 2 - 1);
        final carrierHum = sin(2 * pi * 1150 * t) * 0.20;
        sample += (whiteNoise * 0.82 + carrierHum) * env * 0.72;
      }

      pcmData[i] = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return _createWav(pcmData, sampleRate);
  }

  /// AMERİKAN ASKERİ EFSANEVİ ROGER BEEP & "K-CHHHHK" / "K-ŞŞŞT" SQUELCH TAIL SESİ
  /// (Hem konuşan mandala basıp bıraktığında, hem karşı taraf dinlerken konuşma bittiğinde çalar)
  /// - 1. Aşama: Çift kristal taktik Roger Beep tonu (1820 Hz -> 1220 Hz, 0 - 130ms)
  /// - 2. Aşama: Tok ve çıtırdayan RF squelch patlaması ("K-CHHHHK!", 130 - 430ms)
  /// - 3. Aşama: Ani analog susturucu gürültü kapısı kesintisi (Sharp Gated Squelch Cutoff)
  /// - 4. Aşama: Mekanik buton bırakma yay tıklaması (430 - 470ms)
  static Uint8List _generateUsMilitaryRogerSquelchTailWav() {
    const sampleRate = 44100;
    const durationMs = 480;
    final totalSamples = (sampleRate * durationMs / 1000).round();
    final pcmData = Int16List(totalSamples);
    final random = Random();

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sample = 0.0;

      // 1. Kristal Askeri Roger Tonları (0 - 130ms):
      // Ton 1: 1820 Hz (0 - 65ms)
      if (t < 0.065) {
        final env = sin(pi * (t / 0.065));
        final tone = sin(2 * pi * 1820 * t) + 0.28 * sin(2 * pi * 3640 * t);
        sample += tone * 0.88 * env;
      }
      // Ton 2: 1220 Hz (65ms - 130ms)
      else if (t >= 0.065 && t < 0.130) {
        final localT = t - 0.065;
        final env = sin(pi * (localT / 0.065));
        final tone = sin(2 * pi * 1220 * localT) + 0.25 * sin(2 * pi * 2440 * localT);
        sample += tone * 0.92 * env;
      }

      // 2. O Meşhur Tok ve Çıtırdayan "K-CHHHHK" / "K-ŞŞŞT" Taktik Squelch Tail Patlaması (130ms - 430ms):
      if (t >= 0.130 && t < 0.430) {
        final localT = t - 0.130;
        final rem = (1.0 - (localT / 0.300)).clamp(0.0, 1.0);
        // Doğrusal olmayan üstel sönümleme - ilk darbede çok sert patlar sonra hızla kesilir
        final env = pow(rem, 0.75);

        final white = (random.nextDouble() * 2 - 1);
        final subRumble = sin(2 * pi * 180 * t) * (random.nextDouble() * 2 - 1);
        final highCrackle = (random.nextDouble() > 0.85 ? 1.0 : -1.0) * (random.nextDouble());

        final squelchBurst = (white * 0.75 + subRumble * 0.35 + highCrackle * 0.30) * env * 0.92;
        sample += squelchBurst;
      }

      // 3. Mekanik Buton Bırakma Tıklaması (430ms - 480ms)
      if (t >= 0.430) {
        final localT = t - 0.430;
        final clickEnv = exp(-localT * 220);
        sample += sin(2 * pi * 880 * localT) * 0.65 * clickEnv;
      }

      pcmData[i] = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return _createWav(pcmData, sampleRate);
  }

  /// 2-TONLU TAKTİK SELCALL ÇAĞRI UYARISI (Motorola Quick-Call II / Paging Formatı)
  /// - 1. Ton: 1050 Hz (180 ms)
  /// - Boşluk: 30 ms
  /// - 2. Ton: 1450 Hz (280 ms)
  /// - Squelch burst: Analog RF taşıyıcı hışırtısı (140 ms)
  static Uint8List _generateTacticalCallAlertWav() {
    const sampleRate = 44100;
    const durationMs = 630;
    final totalSamples = (sampleRate * durationMs / 1000).round();
    final pcmData = Int16List(totalSamples);
    final random = Random();

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sample = 0.0;

      // 1. Ton: 1050 Hz (0 - 180 ms)
      if (t < 0.180) {
        final env = sin(pi * (t / 0.180));
        sample += sin(2 * pi * 1050 * t) * 0.90 * env;
      }
      // 2. Ton: 1450 Hz (210 ms - 490 ms)
      else if (t >= 0.210 && t < 0.490) {
        final localT = t - 0.210;
        final env = sin(pi * (localT / 0.280));
        sample += sin(2 * pi * 1450 * localT) * 0.92 * env;
      }
      // Taşıyıcı Squelch Burst (490 ms - 630 ms)
      else if (t >= 0.490) {
        final localT = t - 0.490;
        final env = pow((1.0 - (localT / 0.140)).clamp(0.0, 1.0), 1.2);
        final white = (random.nextDouble() * 2 - 1) * 0.7;
        final hum = sin(2 * pi * 1200 * t) * 0.2;
        sample += (white + hum) * env;
      }

      pcmData[i] = (sample.clamp(-1.0, 1.0) * 32767).toInt();
    }
    return _createWav(pcmData, sampleRate);
  }

  /// Standart RIFF PCM WAV derleyici
  static Uint8List _createWav(Int16List pcmData, int sampleRate) {
    final byteCount = pcmData.length * 2;
    final buffer = ByteData(44 + byteCount);

    void writeString(ByteData b, int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        b.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(buffer, 0, 'RIFF');
    buffer.setUint32(4, 36 + byteCount, Endian.little);
    writeString(buffer, 8, 'WAVE');
    writeString(buffer, 12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM
    buffer.setUint16(22, 1, Endian.little); // Mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    buffer.setUint16(32, 2, Endian.little); // Block align
    buffer.setUint16(34, 16, Endian.little); // 16-bit
    writeString(buffer, 36, 'data');
    buffer.setUint32(40, byteCount, Endian.little);

    for (int i = 0; i < pcmData.length; i++) {
      buffer.setInt16(44 + (i * 2), pcmData[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }
}
