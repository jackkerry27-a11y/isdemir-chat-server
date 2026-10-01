import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/noctra_ai_service.dart';

// ─────────────────────────────────────────────────────────────
// 1. SEMANTİK KAMUFLAJ: NÖRAL DE-MASK HOLOGRAFİK DİYALOĞU
// ─────────────────────────────────────────────────────────────
class SemanticDeMaskModal extends StatefulWidget {
  final CamouflagePayload payload;
  final VoidCallback onReMask;

  const SemanticDeMaskModal({
    super.key,
    required this.payload,
    required this.onReMask,
  });

  @override
  State<SemanticDeMaskModal> createState() => _SemanticDeMaskModalState();
}

class _SemanticDeMaskModalState extends State<SemanticDeMaskModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _glitchController;
  bool _isUnveiled = false;
  String _displayText = '';
  Timer? _scrambleTimer;

  final String _matrixChars = '01#%&*+-=@~ABCDEFGHJKLMNPQRSTUVWXYZ';

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _displayText = widget.payload.decoyText;

    // 600ms siber tarama ve karakter karıştırma (matrix scramble)
    int step = 0;
    _scrambleTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      step++;
      final random = math.Random();
      if (step < 18) {
        setState(() {
          _displayText = List.generate(
            widget.payload.secretText.length.clamp(12, 36),
            (_) => _matrixChars[random.nextInt(_matrixChars.length)],
          ).join();
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _displayText = widget.payload.secretText;
            _isUnveiled = true;
          });
          _glitchController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrambleTimer?.cancel();
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C070A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _isUnveiled
                    ? const Color(0xFFE50914).withValues(alpha: 0.7)
                    : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isUnveiled ? const Color(0xFFE50914) : const Color(0xFF00E5FF))
                      .withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık & Durum Rozeti
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE50914)),
                      ),
                      child: const Icon(Icons.masks_rounded, color: Color(0xFFE50914), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Semantik Kamuflaj AI',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _isUnveiled ? 'Nöral Deşifre Tamamlandı' : 'Matris Karıştırıcı Çözülüyor...',
                            style: GoogleFonts.inter(
                              color: _isUnveiled ? const Color(0xFF00E5FF) : const Color(0xFFFFB300),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Kamuflaj (Sahte / Masum) Metin Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.visibility_off_outlined, color: Colors.white54, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Kamuflaj (Dışarıya Görünen Yüz)',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.payload.decoyText,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB5A7B3),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gerçek Çözülen Gizli Mesaj Kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E0A10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isUnveiled ? const Color(0xFFE50914) : const Color(0xFF00E5FF),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isUnveiled ? Icons.lock_open_rounded : Icons.sync_rounded,
                            color: _isUnveiled ? const Color(0xFFE50914) : const Color(0xFF00E5FF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isUnveiled ? 'GERÇEK GİZLİ MESAJ' : 'ŞİFRE ÇÖZÜLÜYOR...',
                            style: GoogleFonts.outfit(
                              color: _isUnveiled ? const Color(0xFFE50914) : const Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _displayText,
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onReMask();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Tekrar Maskele'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. VISUAL SENTINEL AI: OMUZ DİKİZLEME ACİL SAVAŞ KAMUFLAJ EKRANI
// ─────────────────────────────────────────────────────────────
class SentinelThreatOverlay extends StatelessWidget {
  final VoidCallback onDismissThreat;

  const SentinelThreatOverlay({
    super.key,
    required this.onDismissThreat,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          color: const Color(0xFF080406).withValues(alpha: 0.92),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Yanıp Sönen Kırmızı Tehdit Rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'SENTINEL AI: OMUZ GÖZETLEMESİ TESPİT EDİLDİ!',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFE50914),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sahte / Masum Kamuflaj Dokümanı (Ekrana bakan kişi bunu görür)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141018),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'İSDEMİR KALİTE KONTROL FÖYÜ',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text('REV-2026/09', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      _buildDummyRow('Haddehane Çelik Bobin Kalınlığı:', '2.45 mm (Nominal)'),
                      const SizedBox(height: 6),
                      _buildDummyRow('Yüksek Fırın Çıkış Sıcaklığı:', '1480 °C (Stabil)'),
                      const SizedBox(height: 6),
                      _buildDummyRow('Soğutma Kulesi Basınç Değeri:', '6.8 Bar (Normal)'),
                      const SizedBox(height: 6),
                      _buildDummyRow('Vardiya Sorumlusu İmzası:', 'M. Şahin - Sicil #44821'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Gözetleme riski nedeniyle konuşmalar gizlendi.\nGüvenli alandaysanız kilidi açın.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFF9E929B), fontSize: 13),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: onDismissThreat,
                  icon: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                  label: const Text('GÜVENLİ (KİLİDİ ÇÖZ)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildDummyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
        Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3. AURA-VOICE AI MODÜLATÖR KAYIT VE DİNLEME DİYALOĞU
// ─────────────────────────────────────────────────────────────
class AuraVoiceModal extends StatefulWidget {
  final Function(String voicePath, AuraVoiceProfile profile, String duration) onSendVoice;

  const AuraVoiceModal({super.key, required this.onSendVoice});

  @override
  State<AuraVoiceModal> createState() => _AuraVoiceModalState();
}

class _AuraVoiceModalState extends State<AuraVoiceModal> with TickerProviderStateMixin {
  AuraVoiceProfile _selectedProfile = AuraVoiceProfile.ghostFrequency;
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _recordTimer;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      _recordTimer?.cancel();
      setState(() => _isRecording = false);
    } else {
      setState(() {
        _isRecording = true;
        _seconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF120C10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFE50914), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Aura-Voice AI: Nöral Ses Maskeleme',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Profil Seçimi Kapsülleri
            Wrap(
              spacing: 8,
              children: AuraVoiceProfile.values.map((p) {
                final isSelected = _selectedProfile == p;
                String label;
                switch (p) {
                  case AuraVoiceProfile.ghostFrequency:
                    label = '👻 Ghost (85Hz Sub-Bass)';
                    break;
                  case AuraVoiceProfile.cyberSynthesizer:
                    label = '🤖 Cyber Synthesizer';
                    break;
                  case AuraVoiceProfile.quantumVocoder:
                    label = '⚡ Quantum Formant';
                    break;
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedProfile = p);
                  },
                  selectedColor: const Color(0xFFE50914),
                  backgroundColor: const Color(0xFF1E151B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Canlı Spektrogram Dalga Görselleştirici
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final bars = NoctraAiService().generateSpectrogramWaveform(barCount: 20);
                return SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bars.map((heightFactor) {
                      final h = (_isRecording ? heightFactor : 0.2) * 44;
                      return Container(
                        width: 5,
                        height: h.clamp(6.0, 44.0),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _isRecording ? const Color(0xFFE50914) : const Color(0xFF4A3B45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            Text(
              _isRecording ? 'Kayıt: 00:${_seconds.toString().padLeft(2, '0')}' : 'Kayda başlamak için mikrofona dokunun',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Mikrofon ve Gönder Düğmeleri
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.white : const Color(0xFFE50914),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? const Color(0xFFE50914) : Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                if (_seconds > 0) ...[
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSendVoice(
                        'voice_${DateTime.now().millisecondsSinceEpoch}',
                        _selectedProfile,
                        '00:${_seconds.toString().padLeft(2, '0')}',
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Şifrele & Gönder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. NÖRAL STEGANOGRAFİ: GÖRSEL SEÇİM VE PAKETLEME DİYALOĞU
// ─────────────────────────────────────────────────────────────
class NeuralStegoComposerModal extends StatefulWidget {
  final Function(String coverId, String secretText) onSendStego;

  const NeuralStegoComposerModal({super.key, required this.onSendStego});

  @override
  State<NeuralStegoComposerModal> createState() => _NeuralStegoComposerModalState();
}

class _NeuralStegoComposerModalState extends State<NeuralStegoComposerModal> {
  final TextEditingController _secretController = TextEditingController();
  String _selectedCoverId = 'dock_pier';

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covers = NoctraAiService().availableStegoCovers;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF120C10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hide_image_rounded, color: Color(0xFF00E5FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nöral Steganografi: Görsele Veri Göm',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Masum bir fabrika görseli seçin. Şifreli mesajınız fotoğrafın görünmez mikro-gürültü katmanına gömülecektir.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Taşıyıcı Görsel Seçici
              ...covers.map((c) {
                final isSelected = _selectedCoverId == c.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCoverId = c.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? c.accentColor.withValues(alpha: 0.15) : const Color(0xFF1A1318),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? c.accentColor : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.icon, color: c.accentColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(c.subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: c.accentColor, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Gizlenecek Metin
              Text('Görsel İçine Gömülecek Gizli Mesaj:', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1318),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _secretController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Gizlemek istediğiniz kritik operasyonel mesajı buraya yazın...',
                    hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Gönder Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = _secretController.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(context);
                    widget.onSendStego(_selectedCoverId, text);
                  },
                  icon: const Icon(Icons.fingerprint_rounded, size: 18),
                  label: const Text('NÖRAL PİKSEL KATMANINA GÖM & GÖNDER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
