import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_model.dart';
import '../widgets/glass_widgets.dart';

enum TrackerEngine { byteTrack, botSort }
enum YoloModelVariant { yolo11x, yolo11Pose, yoloWorld }

class TrackedEntity {
  final int id;
  final String label;
  final String category; // 'worker', 'hazard', 'vehicle', 'crane'
  final double confidence;
  final Color color;
  final Rect normalizedRect;
  final String speed;
  final List<Offset> trajectory;
  final Offset velocityVector;
  final bool isHazard;
  final String hazardDetail;
  final String reidVector;

  const TrackedEntity({
    required this.id,
    required this.label,
    required this.category,
    required this.confidence,
    required this.color,
    required this.normalizedRect,
    required this.speed,
    required this.trajectory,
    required this.velocityVector,
    this.isHazard = false,
    this.hazardDetail = '',
    this.reidVector = '[0.214, -0.482, 0.771, 0.054, ...]',
  });
}

class CameraSector {
  final String id;
  final String name;
  final String code;
  final String location;
  final String resolution;
  final double fps;
  final String rtspUrl;
  final List<TrackedEntity> objects;
  final String zoneStatus;

  const CameraSector({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    required this.resolution,
    required this.fps,
    required this.rtspUrl,
    required this.objects,
    required this.zoneStatus,
  });
}

class OperasyonAiScreen extends StatefulWidget {
  final UserModel? user;

  const OperasyonAiScreen({super.key, this.user});

  @override
  State<OperasyonAiScreen> createState() => _OperasyonAiScreenState();
}

class _OperasyonAiScreenState extends State<OperasyonAiScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  TrackerEngine _selectedEngine = TrackerEngine.byteTrack;
  YoloModelVariant _selectedModel = YoloModelVariant.yolo11x;
  int _selectedCameraIndex = 0;

  bool _showBoundingBoxes = true;
  bool _showTrajectories = true;
  bool _showExclusionZones = true;
  bool _showVelocityVectors = true;
  double _confidenceThreshold = 0.65;
  String _selectedEventFilter = 'Tümü';
  TrackedEntity? _inspectedEntity;

  // ── 📱 Cihaz Kamerası (Gerçek Canlı Kamera Akışı) ──
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _cameraErrorMessage = '';
  int _selectedCameraLensIndex = 0; // 0: arka, 1: ön
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _isFullscreen = false;

  late List<CameraSector> _sectors;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initSectors();
    _initDeviceCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initDeviceCamera() async {
    if (mounted) {
      setState(() {
        _isCameraError = false;
        _cameraErrorMessage = '';
        _isCameraInitialized = false;
      });
    }

    try {
      // 1. Cihaz Kameralarını Sorgula
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        await _startCamera(_availableCameras[_selectedCameraLensIndex % _availableCameras.length]);
      } else {
        if (mounted) {
          setState(() {
            _isCameraError = true;
            _cameraErrorMessage = 'Cihazda fiziksel kamera donanımı tespit edilemedi. Simülasyon moduna geçebilirsiniz.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'Kamera başlatılamadı ($e). Simülasyon modunda devam edebilirsiniz.';
        });
      }
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    try {
      await _cameraController?.dispose();
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _cameraController = controller;
      await controller.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraError = false;
          _cameraErrorMessage = '';
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraError = true;
          if (e.code == 'cameraPermissionNotGranted') {
            _cameraErrorMessage = 'Kamera erişim izni onaylanmadı.';
          } else {
            _cameraErrorMessage = 'Kamera hatası (${e.code}): ${e.description ?? e.toString()}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraError = true;
          _cameraErrorMessage = 'Kamera başlatılamadı: $e';
        });
      }
    }
  }

  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraLensIndex = (_selectedCameraLensIndex + 1) % _availableCameras.length;
    });
    await _startCamera(_availableCameras[_selectedCameraLensIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('Flaş hatası: $e');
    }
  }

  Future<void> _takeSnapshot() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isCapturing) return;
    HapticFeedback.heavyImpact();
    setState(() => _isCapturing = true);
    try {
      final file = await _cameraController!.takePicture();
      if (mounted) {
        _showSnapshotResultModal(file.path);
      }
    } catch (e) {
      debugPrint('Fotoğraf çekme hatası: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _showSnapshotResultModal(String imagePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF12141F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOLOv11 Optik Kare Analizi',
                    style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Kaydedildi', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Kare başarıyla yakalandı ve nesne tespit katmanı işlendi.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF34D399)),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Analizi Tamamla', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _initSectors() {
    _sectors = [
      // 0. Canlı Telefon Kamerası (Varsayılan)
      CameraSector(
        id: 'LENS-CANLI',
        name: '📱 Telefon Kamerası',
        code: 'DEVICE-OPTIC-REALTIME',
        location: 'Canlı Telefon Kamerası Sensörü (Ön / Arka)',
        resolution: '1080p FHD @ 60FPS',
        fps: 60.0,
        rtspUrl: 'camera://device/sensor_stream',
        zoneStatus: '🟢 Canlı Optik Sensör Aktif',
        objects: [
          TrackedEntity(
            id: 101,
            label: 'Canlı Hedef (Personel)',
            category: 'worker',
            confidence: 0.985,
            color: const Color(0xFF10B981),
            normalizedRect: const Rect.fromLTWH(0.28, 0.22, 0.26, 0.52),
            speed: '0.4 m/s',
            trajectory: const [
              Offset(0.41, 0.50),
              Offset(0.41, 0.48),
              Offset(0.41, 0.46),
            ],
            velocityVector: const Offset(0.01, -0.01),
            reidVector: '[0.381, 0.210, -0.741, 0.442, 0.081]',
          ),
          TrackedEntity(
            id: 88,
            label: 'İSG Nesnesi (Baret / Kask)',
            category: 'worker',
            confidence: 0.965,
            color: const Color(0xFF00F0FF),
            normalizedRect: const Rect.fromLTWH(0.58, 0.32, 0.22, 0.38),
            speed: '0.0 m/s',
            trajectory: const [
              Offset(0.69, 0.51),
              Offset(0.69, 0.51),
            ],
            velocityVector: const Offset(0.0, 0.0),
            reidVector: '[-0.104, 0.812, 0.440, 0.129, 0.655]',
          ),
        ],
      ),
      // 1. Rıhtım STS Vinç Sahası
      CameraSector(
        id: 'CAM-01',
        name: 'Rıhtım STS Vinç & Konteyner',
        code: 'SEC-DOCK-01',
        location: 'Payas Rıhtım Sahası 1-2 No\'lu İskele',
        resolution: '4K 3840x2160',
        fps: 60.0,
        rtspUrl: 'rtsp://10.12.4.101:554/live/sts_gantry',
        zoneStatus: '⚠️ 1 Aktif İSG İhlali',
        objects: [
          TrackedEntity(
            id: 104,
            label: 'Personel (Kask+Yelek)',
            category: 'worker',
            confidence: 0.984,
            color: const Color(0xFF10B981),
            normalizedRect: const Rect.fromLTWH(0.22, 0.46, 0.09, 0.24),
            speed: '1.2 m/s',
            trajectory: const [
              Offset(0.18, 0.58),
              Offset(0.20, 0.57),
              Offset(0.22, 0.56),
              Offset(0.24, 0.55),
              Offset(0.26, 0.55),
            ],
            velocityVector: const Offset(0.04, -0.01),
            reidVector: '[0.412, -0.119, 0.884, 0.321, 0.044]',
          ),
          TrackedEntity(
            id: 73,
            label: 'İHK İHLALİ: Baretsiz Şahıs',
            category: 'hazard',
            confidence: 0.948,
            color: const Color(0xFFEF4444),
            normalizedRect: const Rect.fromLTWH(0.48, 0.52, 0.10, 0.25),
            speed: '0.8 m/s',
            trajectory: const [
              Offset(0.55, 0.62),
              Offset(0.53, 0.60),
              Offset(0.51, 0.58),
              Offset(0.49, 0.56),
            ],
            velocityVector: const Offset(-0.03, -0.02),
            isHazard: true,
            hazardDetail: 'Baret takılmamış • STS-01 asılı yük klerans bölgesi!',
            reidVector: '[-0.781, 0.224, 0.551, -0.310, 0.912]',
          ),
          TrackedEntity(
            id: 219,
            label: 'Forklift-04 (Liman)',
            category: 'vehicle',
            confidence: 0.972,
            color: const Color(0xFFF59E0B),
            normalizedRect: const Rect.fromLTWH(0.68, 0.40, 0.18, 0.22),
            speed: '18 km/s',
            trajectory: const [
              Offset(0.85, 0.45),
              Offset(0.80, 0.44),
              Offset(0.75, 0.43),
              Offset(0.70, 0.42),
            ],
            velocityVector: const Offset(-0.05, -0.01),
            reidVector: '[0.115, 0.912, -0.401, 0.623, 0.155]',
          ),
          TrackedEntity(
            id: 308,
            label: 'STS-01 Spreader (Yük: 32T)',
            category: 'crane',
            confidence: 0.996,
            color: const Color(0xFF00F0FF),
            normalizedRect: const Rect.fromLTWH(0.38, 0.16, 0.26, 0.18),
            speed: '0.4 m/s (İniş)',
            trajectory: const [
              Offset(0.48, 0.10),
              Offset(0.48, 0.14),
              Offset(0.48, 0.18),
            ],
            velocityVector: const Offset(0.0, 0.03),
            reidVector: '[0.003, 0.998, 0.142, -0.051, 0.612]',
          ),
        ],
      ),

      // 2. Sıcak Haddehane & Kütük Döküm Sahası
      CameraSector(
        id: 'CAM-02',
        name: 'Sıcak Haddehane & Kütük Döküm',
        code: 'SEC-STEEL-02',
        location: 'Haddehane No: 2 • Sürekli Döküm Hattı',
        resolution: '4K 3840x2160',
        fps: 60.0,
        rtspUrl: 'rtsp://10.12.4.102:554/live/mill_furnace',
        zoneStatus: '✅ Güvenli Operasyon',
        objects: [
          TrackedEntity(
            id: 112,
            label: 'Haddehane Vinç Operatörü',
            category: 'worker',
            confidence: 0.988,
            color: const Color(0xFF10B981),
            normalizedRect: const Rect.fromLTWH(0.20, 0.42, 0.08, 0.22),
            speed: '0.9 m/s',
            trajectory: const [
              Offset(0.16, 0.50),
              Offset(0.18, 0.49),
              Offset(0.20, 0.48),
            ],
            velocityVector: const Offset(0.02, -0.01),
            reidVector: '[0.334, -0.210, 0.771, 0.540, -0.105]',
          ),
          TrackedEntity(
            id: 405,
            label: 'Sıcak Kütük Rulo Arabası #02',
            category: 'vehicle',
            confidence: 0.991,
            color: const Color(0xFFF59E0B),
            normalizedRect: const Rect.fromLTWH(0.42, 0.48, 0.24, 0.20),
            speed: '8 km/s',
            trajectory: const [
              Offset(0.30, 0.54),
              Offset(0.36, 0.53),
              Offset(0.42, 0.52),
            ],
            velocityVector: const Offset(0.04, -0.01),
            reidVector: '[0.655, 0.122, -0.344, 0.812, 0.021]',
          ),
          TrackedEntity(
            id: 520,
            label: 'Tavan Gezer Vinç Kancası',
            category: 'crane',
            confidence: 0.995,
            color: const Color(0xFF00F0FF),
            normalizedRect: const Rect.fromLTWH(0.55, 0.18, 0.18, 0.16),
            speed: '0.2 m/s',
            trajectory: const [
              Offset(0.52, 0.18),
              Offset(0.54, 0.18),
              Offset(0.56, 0.18),
            ],
            velocityVector: const Offset(0.02, 0.0),
            reidVector: '[0.012, 0.944, -0.210, 0.450, 0.311]',
          ),
        ],
      ),

      // 3. Çelik Servis & Forklift Koridoru
      CameraSector(
        id: 'CAM-03',
        name: 'Çelik Servis & Forklift Koridoru',
        code: 'SEC-LOG-03',
        location: 'Açık Stok Sahası & Forklift Ana Koridoru',
        resolution: '1080p 1920x1080',
        fps: 60.0,
        rtspUrl: 'rtsp://10.12.4.103:554/live/forklift_corridor',
        zoneStatus: '⚠️ Hız Aşımı Riski',
        objects: [
          TrackedEntity(
            id: 219,
            label: 'Forklift-04 (HIZ UYARISI)',
            category: 'hazard',
            confidence: 0.978,
            color: const Color(0xFFF59E0B),
            normalizedRect: const Rect.fromLTWH(0.32, 0.44, 0.20, 0.24),
            speed: '22 km/s (Limit: 15)',
            trajectory: const [
              Offset(0.55, 0.52),
              Offset(0.48, 0.50),
              Offset(0.40, 0.48),
              Offset(0.34, 0.46),
            ],
            velocityVector: const Offset(-0.06, -0.02),
            isHazard: true,
            hazardDetail: 'Forklift yaya geçiş bölgesinde 22 km/s hıza ulaştı.',
            reidVector: '[0.115, 0.912, -0.401, 0.623, 0.155]',
          ),
          TrackedEntity(
            id: 119,
            label: 'Yaya Personel (Kask+Yelek)',
            category: 'worker',
            confidence: 0.982,
            color: const Color(0xFF10B981),
            normalizedRect: const Rect.fromLTWH(0.72, 0.48, 0.08, 0.22),
            speed: '1.1 m/s',
            trajectory: const [
              Offset(0.70, 0.56),
              Offset(0.72, 0.55),
              Offset(0.74, 0.54),
            ],
            velocityVector: const Offset(0.02, -0.01),
            reidVector: '[0.512, -0.322, 0.665, 0.120, 0.404]',
          ),
        ],
      ),

      // 4. Liman Kapı & Ağır Vasıta Girişi
      CameraSector(
        id: 'CAM-04',
        name: 'Liman Kapı & Ağır Vasıta Girişi',
        code: 'SEC-GATE-04',
        location: 'Ana Kontrol Kapısı & Kantar 1-2',
        resolution: '4K 3840x2160',
        fps: 60.0,
        rtspUrl: 'rtsp://10.12.4.104:554/live/gate_trucks',
        zoneStatus: '✅ Akıcı Trafik',
        objects: [
          TrackedEntity(
            id: 812,
            label: 'Treyler Tır [31 K 4412]',
            category: 'vehicle',
            confidence: 0.986,
            color: const Color(0xFF38BDF8),
            normalizedRect: const Rect.fromLTWH(0.24, 0.40, 0.32, 0.28),
            speed: '12 km/s',
            trajectory: const [
              Offset(0.12, 0.48),
              Offset(0.18, 0.46),
              Offset(0.24, 0.44),
            ],
            velocityVector: const Offset(0.04, -0.01),
            reidVector: '[0.881, 0.412, -0.104, 0.771, -0.224]',
          ),
          TrackedEntity(
            id: 133,
            label: 'Güvenlik & Saha Görevlisi',
            category: 'worker',
            confidence: 0.990,
            color: const Color(0xFF10B981),
            normalizedRect: const Rect.fromLTWH(0.68, 0.46, 0.08, 0.22),
            speed: '0.2 m/s',
            trajectory: const [
              Offset(0.66, 0.52),
              Offset(0.67, 0.52),
            ],
            velocityVector: const Offset(0.01, 0.0),
            reidVector: '[0.221, 0.812, 0.450, -0.112, 0.334]',
          ),
        ],
      ),
    ];
  }

  void _showInspectModal(TrackedEntity entity) {
    HapticFeedback.mediumImpact();
    setState(() => _inspectedEntity = entity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF12141F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: entity.color.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: entity.color.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Başlık & Tracker Rozeti
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: entity.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: entity.color, width: 1.2),
                        ),
                        child: Icon(
                          entity.isHazard ? Icons.warning_amber_rounded : Icons.track_changes_rounded,
                          color: entity.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRACK ID: #${entity.id}',
                            style: GoogleFonts.orbitron(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            entity.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: entity.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      _selectedEngine == TrackerEngine.byteTrack ? 'ByteTrack' : 'BoT-SORT CMC',
                      style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF00F0FF)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (entity.isHazard) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entity.hazardDetail,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Telemetri Grid
              Row(
                children: [
                  Expanded(
                    child: _buildModalStat('Güvenilirlik', '%${(entity.confidence * 100).toStringAsFixed(1)}', Icons.verified_rounded, const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModalStat('Anlık Hız', entity.speed, Icons.speed_rounded, const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildModalStat('Kategori', entity.category.toUpperCase(), Icons.category_rounded, const Color(0xFF8B5CF6)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ReID Embedding & Kalman Vektör
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BoT-SORT Derin Re-ID Öznitelik Vektörü',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                        ),
                        Text(
                          '512-dim FP16',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF00F0FF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entity.reidVector,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF38BDF8)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kalman Filtresi Durum Tahmini: vx=${entity.velocityVector.dx.toStringAsFixed(3)}, vy=${entity.velocityVector.dy.toStringAsFixed(3)}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFFA1A1AA)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Aksiyon Butonları
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: entity.isHazard ? const Color(0xFFEF4444) : const Color(0xFF00F0FF),
                        foregroundColor: entity.isHazard ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(entity.isHazard ? Icons.notifications_active_rounded : Icons.radio_button_checked_rounded, size: 18),
                      label: Text(
                        entity.isHazard ? 'Sahayı Sirenle Uyar' : 'Takip Kilidi (Lock)',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _triggerFieldAlert(entity);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E2433),
                          content: Text('ID #${entity.id} için anlık optik kare yakalandı ve arşive kaydedildi.', style: GoogleFonts.inter(color: Colors.white)),
                        ),
                      );
                    },
                    child: const Icon(Icons.camera_alt_outlined, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _triggerFieldAlert(TrackedEntity entity) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🚨 İSDEMİR Saha Alarmı: [ID: ${entity.id}] için telsiz ve optik siren ikazı iletildi!',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSector = _sectors[_selectedCameraIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F18),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2433),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'OPERASYON AI MERKEZİ',
                  style: GoogleFonts.orbitron(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'YOLOv11',
                    style: GoogleFonts.orbitron(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF00F0FF)),
                  ),
                ),
              ],
            ),
            Text(
              'Ultralytics YOLO + ByteTrack / BoT-SORT Multi-Object Tracking',
              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFA1A1AA)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  'CANLI',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Canlı Telemetri & GPU/NPU Metrik Şeridi
            _buildLiveMetricsRibbon(),

            const SizedBox(height: 12),

            // 2. Kamera & Sektör Seçici (Tabs)
            _buildCameraSectorTabs(),

            const SizedBox(height: 12),

            // 3. Canlı Optik Görüş Alanı (HUD Viewport)
            _buildLiveVisionViewport(currentSector),

            const SizedBox(height: 16),

            // 4. Tracker & Algoritma Motoru Seçimi (ByteTrack vs. BoT-SORT)
            _buildTrackerEngineSelector(),

            const SizedBox(height: 16),

            // 5. Görselleştirme & Filtre Ayarları
            _buildVisionFilterControls(),

            const SizedBox(height: 16),

            // 6. Canlı İSG & Operasyon Olay Günlüğü (Event Stream)
            _buildLiveEventStream(currentSector),

            const SizedBox(height: 20),

            // 7. Hızlı İSG Müdahale ve Raporlama Paneli
            _buildQuickInterventionPanel(),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // 1. Canlı Telemetri Metrik Şeridi
  Widget _buildLiveMetricsRibbon() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricColumn('INFERENCE', '3.4 ms', 'TensorRT FP16', const Color(0xFF00F0FF)),
          _buildMetricDivider(),
          _buildMetricColumn('FPS', '60.4', 'Real-Time Edge', const Color(0xFF10B981)),
          _buildMetricDivider(),
          _buildMetricColumn('TRACK COUNT', '${_sectors[_selectedCameraIndex].objects.length} Nesne', 'Aktif Kalman', const Color(0xFFF59E0B)),
          _buildMetricDivider(),
          _buildMetricColumn('ENGINE', _selectedEngine == TrackerEngine.byteTrack ? 'ByteTrack' : 'BoT-SORT', 'Re-ID + CMC', const Color(0xFFA78BFA)),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String main, String sub, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.orbitron(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(main, style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 1),
        Text(sub, style: GoogleFonts.inter(fontSize: 8.5, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 28, color: const Color(0xFF334155));
  }

  // 2. Kamera & Sektör Seçici
  Widget _buildCameraSectorTabs() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sectors.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = _sectors[index];
          final isSelected = index == _selectedCameraIndex;
          return BouncyTap(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCameraIndex = index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00F0FF).withValues(alpha: 0.18) : const Color(0xFF12141F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF262A38),
                  width: isSelected ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 15,
                    color: isSelected ? const Color(0xFF00F0FF) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.id,
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.name.split(' ').first,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isSelected ? const Color(0xFF7DD3FC) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. Canlı Optik Görüş Alanı (HUD Viewport)
  Widget _buildLiveVisionViewport(CameraSector sector) {
    final isDeviceCamera = sector.id == 'LENS-CANLI';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF07080D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: _isFullscreen ? (9 / 14) : (16 / 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 3.0 GERÇEK TELEFON KAMERASI VİDEO ÖNİZLEMESİ
              if (isDeviceCamera) ...[
                if (_isCameraInitialized && _cameraController != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 1920,
                      height: _cameraController!.value.previewSize?.width ?? 1080,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                else if (_isCameraError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off_rounded, color: Color(0xFFEF4444), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Kamera Açılamadı',
                            style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cameraErrorMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00F0FF),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(Icons.videocam_rounded, size: 16),
                                label: Text('Kamerayı Başlat (İzin İste)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _initDeviceCamera,
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFA78BFA),
                                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.settings_rounded, size: 14),
                                label: Text('Ayarları Aç', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => Geolocator.openAppSettings(),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                icon: const Icon(Icons.sensors_rounded, size: 14),
                                label: Text('Simülasyona Geç', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  setState(() => _selectedCameraIndex = 1);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00F0FF)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Telefon Kamerası Başlatılıyor...',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF00F0FF), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],

              // 3.1 Canlı Çizim & Simülasyon Tuvali
              // 3.1 Canlı Çizim & Simülasyon Tuvali (Yalnızca kamera aktifken veya simülasyonda göster)
              if (!isDeviceCamera || (_isCameraInitialized && !_isCameraError)) ...[
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: YoloVisionPainter(
                        progress: _animController.value,
                        sector: sector,
                        engine: _selectedEngine,
                        showBoundingBoxes: _showBoundingBoxes,
                        showTrajectories: _showTrajectories,
                        showExclusionZones: _showExclusionZones,
                        showVelocityVectors: _showVelocityVectors,
                        confidenceThreshold: _confidenceThreshold,
                        inspectedEntity: _inspectedEntity,
                        isRealCameraFeed: isDeviceCamera,
                      ),
                    );
                  },
                ),

                // 3.2 Tıklanabilir Bounding Box Katmanı
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;

                    return Stack(
                      children: sector.objects.map((entity) {
                        if (entity.confidence < _confidenceThreshold) return const SizedBox.shrink();

                        final rect = Rect.fromLTWH(
                          entity.normalizedRect.left * w,
                          entity.normalizedRect.top * h,
                          entity.normalizedRect.width * w,
                          entity.normalizedRect.height * h,
                        );

                        return Positioned(
                          left: rect.left,
                          top: rect.top,
                          width: rect.width,
                          height: rect.height,
                          child: GestureDetector(
                            onTap: () => _showInspectModal(entity),
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],

              // 3.3 Üst OSD Bilgi Katmanı (Camera HUD - Taşma korumalı)
              Positioned(
                top: 8,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              children: [
                                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                const SizedBox(width: 3),
                                Text('REC', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isDeviceCamera ? '📱 LENS-01' : sector.id,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDeviceCamera ? 'FHD 60FPS' : sector.resolution.split(' ').first,
                          style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF00F0FF)),
                        ),
                        const SizedBox(width: 6),
                        BouncyTap(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isFullscreen = !_isFullscreen);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2433).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3.4 TELEFON KAMERASI KONTROL BUTONLARI (Flaş, Flip, Shutter - Yalnızca kamera açıkken)
              if (isDeviceCamera && _isCameraInitialized && !_isCameraError)
                Positioned(
                  right: 12,
                  bottom: 30,
                  child: Column(
                    children: [
                      _buildCameraCircleBtn(
                        icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isFlashOn ? const Color(0xFFFBBF24) : Colors.white70,
                        onTap: _toggleFlash,
                      ),
                      const SizedBox(height: 8),
                      _buildCameraCircleBtn(
                        icon: Icons.flip_camera_ios_rounded,
                        color: const Color(0xFF00F0FF),
                        onTap: _flipCamera,
                      ),
                      const SizedBox(height: 8),
                      _buildCameraCircleBtn(
                        icon: _isCapturing ? Icons.hourglass_top_rounded : Icons.camera_alt_rounded,
                        color: Colors.white,
                        bgColor: const Color(0xFFEF4444),
                        onTap: _takeSnapshot,
                      ),
                    ],
                  ),
                ),

              // 3.5 Alt OSD Durum ve Kılavuz (Taşma Korumalı)
              Positioned(
                bottom: 6,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'KONUM: ${sector.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 8.5, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDeviceCamera ? 'Dokun: Analiz' : 'Dokun: Olay',
                      style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFFA78BFA)),
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

  Widget _buildCameraCircleBtn({
    required IconData icon,
    required Color color,
    Color? bgColor,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor ?? const Color(0xFF141722).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // 4. Tracker & Algoritma Motoru Seçimi (ByteTrack vs BoT-SORT)
  Widget _buildTrackerEngineSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12141F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262A38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFF00F0FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ÇOKLU NESNE TAKİP ALGORİTMASI',
                    style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Text(
                'GitHub: ultralytics',
                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // ByteTrack Seçeneği
              Expanded(
                child: _buildEngineOption(
                  title: 'ByteTrack',
                  engine: TrackerEngine.byteTrack,
                  badge: '60+ FPS • Ultra Hızlı',
                  badgeColor: const Color(0xFF10B981),
                  desc: 'Tüm tespit kutularını (düşük skorlu dahil) Kalman filtresiyle ilişkilendirir.',
                ),
              ),
              const SizedBox(width: 10),
              // BoT-SORT Seçeneği
              Expanded(
                child: _buildEngineOption(
                  title: 'BoT-SORT',
                  engine: TrackerEngine.botSort,
                  badge: 'CMC + ReID Derin Eşleme',
                  badgeColor: const Color(0xFF8B5CF6),
                  desc: 'Kamera hareket dengelemesi (CMC) ve görünüm ReID vektörleri ile hatasız takip.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'YOLO SİNİR AĞI MİMARİSİ',
            style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModelChip('YOLOv11x (Detection)', YoloModelVariant.yolo11x),
                const SizedBox(width: 8),
                _buildModelChip('YOLOv11-Pose (KKD İSG)', YoloModelVariant.yolo11Pose),
                const SizedBox(width: 8),
                _buildModelChip('YOLO-World (Açık Lugat)', YoloModelVariant.yoloWorld),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelChip(String label, YoloModelVariant variant) {
    final isSel = _selectedModel == variant;
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedModel = variant);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF00F0FF).withValues(alpha: 0.18) : const Color(0xFF090A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? const Color(0xFF00F0FF) : const Color(0xFF262A38),
            width: isSel ? 1.2 : 0.9,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineOption({
    required String title,
    required TrackerEngine engine,
    required String badge,
    required Color badgeColor,
    required String desc,
  }) {
    final isSelected = _selectedEngine == engine;

    return BouncyTap(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _selectedEngine = engine);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withValues(alpha: 0.15) : const Color(0xFF090A10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? badgeColor : const Color(0xFF262A38),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected ? badgeColor : Colors.white24,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Görselleştirme & Filtre Ayarları
  Widget _buildVisionFilterControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12141F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262A38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF00F0FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'HUD GÖRSELLEŞTİRME KATMANLARI',
                    style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Text(
                'Eşik: %${(_confidenceThreshold * 100).toInt()}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hızlı Switch Butonları
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterToggle('Sınır Kutuları', _showBoundingBoxes, () {
                setState(() => _showBoundingBoxes = !_showBoundingBoxes);
              }),
              _buildFilterToggle('Kalman İzleri', _showTrajectories, () {
                setState(() => _showTrajectories = !_showTrajectories);
              }),
              _buildFilterToggle('Yasak Bölge Çiti', _showExclusionZones, () {
                setState(() => _showExclusionZones = !_showExclusionZones);
              }),
              _buildFilterToggle('Hız Vektörleri', _showVelocityVectors, () {
                setState(() => _showVelocityVectors = !_showVelocityVectors);
              }),
            ],
          ),

          const SizedBox(height: 12),

          // Slider
          Row(
            children: [
              Text('Güven Eşiği:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF00F0FF),
                    inactiveTrackColor: const Color(0xFF1E2433),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _confidenceThreshold,
                    min: 0.30,
                    max: 0.95,
                    onChanged: (val) {
                      setState(() => _confidenceThreshold = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle(String label, bool isActive, VoidCallback onTap) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00F0FF).withValues(alpha: 0.15) : const Color(0xFF090A10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF00F0FF) : const Color(0xFF262A38),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 14,
              color: isActive ? const Color(0xFF00F0FF) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Canlı İSG & Operasyon Olay Günlüğü
  Widget _buildLiveEventStream(CameraSector sector) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12141F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262A38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stream_rounded, color: Color(0xFF00F0FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'CANLI OLAY & İHLAL GÜNLÜĞÜ',
                    style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('1 Kritik Uyarı', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Tümü', 'İSG İhlalleri', 'Araçlar', 'Vinç & Yük'].map((f) {
                final isSel = _selectedEventFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedEventFilter = f);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF00F0FF).withValues(alpha: 0.18) : const Color(0xFF090A10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? const Color(0xFF00F0FF) : const Color(0xFF262A38)),
                      ),
                      child: Text(
                        f,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (_selectedEventFilter == 'Tümü' || _selectedEventFilter == 'İSG İhlalleri') ...[
            _buildEventTile(
              time: '15:37:44',
              level: 'CRITICAL',
              levelColor: const Color(0xFFEF4444),
              title: '[ID: 073] BARETSİZ PERSONEL TESPİT EDİLDİ',
              desc: 'STS-01 kule vinci asılı yük klerans sahasına girildi. BoT-SORT ReID tetiklendi.',
            ),
            const Divider(color: Color(0xFF222634), height: 16),
          ],
          if (_selectedEventFilter == 'Tümü' || _selectedEventFilter == 'İSG İhlalleri' || _selectedEventFilter == 'Araçlar') ...[
            _buildEventTile(
              time: '15:37:12',
              level: 'WARNING',
              levelColor: const Color(0xFFF59E0B),
              title: '[ID: 219] FORKLİFT HIZ LİMİTİ AŞILDI',
              desc: 'Rıhtım koridorunda ölçülen hız: 18 km/s (Azami İSG sınırı: 15 km/s).',
            ),
            const Divider(color: Color(0xFF222634), height: 16),
          ],
          if (_selectedEventFilter == 'Tümü') ...[
            _buildEventTile(
              time: '15:36:50',
              level: 'INFO',
              levelColor: const Color(0xFF10B981),
              title: '[ID: 104] PERSONEL GÜVENLİ KORİDORDA',
              desc: 'Kask ve fosforlu yelek tam. Güvenli yaya yolunda seyrediyor.',
            ),
            const Divider(color: Color(0xFF222634), height: 16),
          ],
          if (_selectedEventFilter == 'Tümü' || _selectedEventFilter == 'Vinç & Yük') ...[
            _buildEventTile(
              time: '15:36:05',
              level: 'INFO',
              levelColor: const Color(0xFF00F0FF),
              title: '[ID: 308] STS-01 VİNÇ YÜK BAĞLANTISI',
              desc: '32 Ton rulo sac kilitlendi. Güvenlik sensörleri onay verdi.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventTile({
    required String time,
    required String level,
    required Color levelColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(level, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: levelColor)),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFA1A1AA))),
            ],
          ),
        ),
      ],
    );
  }

  // 7. Hızlı İSG Müdahale ve Raporlama Paneli
  Widget _buildQuickInterventionPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B182E), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İSDEMİR ANLIK İSG MÜDAHALE',
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    'Optik YOLO tespitleri üzerinden sahaya anons ve telsiz uyarısı',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text('Tüm Sahaya Siren', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFEF4444),
                        content: Text('⚠️ Payas Rıhtım STS sahasına 95dB İSG tahliye uyarısı yayınlandı!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00F0FF),
                    side: const BorderSide(color: Color(0xFF00F0FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Tracker Reset', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _initSectors();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E2433),
                        content: Text('Kalman filtresi ve nesne kimlikleri (IDs) yeniden başlatıldı.', style: GoogleFonts.inter(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎨 YoloVisionPainter - Canlı Optik HUD, Bounding Box ve Kalman İzleri
class YoloVisionPainter extends CustomPainter {
  final double progress;
  final CameraSector sector;
  final TrackerEngine engine;
  final bool showBoundingBoxes;
  final bool showTrajectories;
  final bool showExclusionZones;
  final bool showVelocityVectors;
  final double confidenceThreshold;
  final TrackedEntity? inspectedEntity;
  final bool isRealCameraFeed;

  YoloVisionPainter({
    required this.progress,
    required this.sector,
    required this.engine,
    required this.showBoundingBoxes,
    required this.showTrajectories,
    required this.showExclusionZones,
    required this.showVelocityVectors,
    required this.confidenceThreshold,
    this.inspectedEntity,
    this.isRealCameraFeed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Endüstriyel Kamera Arka Plan Çizimi (Gerçek kamerada şeffaf katman)
    if (!isRealCameraFeed) {
      _drawIndustrialBackground(canvas, size);
    }

    // 2. İSG Yasak Bölge Çiti (Exclusion Zone)
    if (showExclusionZones) {
      _drawExclusionZone(canvas, size);
    }

    // 3. Taranan Canlı Scanline Efekti
    final scanY = (progress * h * 1.5) % h;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF00F0FF).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 30, w, 60));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, w, 60), scanPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, scanY), Offset(w, scanY), linePaint);

    // 4. Optik Hedef ve Grid Çizimi
    _drawCameraGrid(canvas, size);

    // 5. Takip Edilen Nesneler (Ultralytics YOLO + ByteTrack / BoT-SORT)
    for (final entity in sector.objects) {
      if (entity.confidence < confidenceThreshold) continue;

      // Kalman hareketi simülasyonu (hafif salınım)
      final offsetX = math.sin((progress * 2 * math.pi) + (entity.id * 1.5)) * 4.0;
      final offsetY = math.cos((progress * 2 * math.pi) + (entity.id * 1.5)) * 2.0;

      final rect = Rect.fromLTWH(
        (entity.normalizedRect.left * w) + offsetX,
        (entity.normalizedRect.top * h) + offsetY,
        entity.normalizedRect.width * w,
        entity.normalizedRect.height * h,
      );

      // 5.1 Kalman Breadcrumb Trajectory Trail
      if (showTrajectories && entity.trajectory.isNotEmpty) {
        _drawTrajectory(canvas, entity, size, offsetX, offsetY);
      }

      // 5.2 Hız Vektörü Oku
      if (showVelocityVectors) {
        _drawVelocityVector(canvas, rect, entity);
      }

      // 5.3 Bounding Box & HUD Etiketi
      if (showBoundingBoxes) {
        _drawBoundingBox(canvas, rect, entity);
      }
    }
  }

  void _drawIndustrialBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0C0E17);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Rıhtım / Zemin Perspektif Çizgileri
    final groundPaint = Paint()
      ..color = const Color(0xFF161A28)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.40), Offset(size.width, size.height * 0.40), groundPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), groundPaint);

    // Sarı Emniyet Yaya Çizgileri (Hatching)
    final safetyPaint = Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.12)
      ..strokeWidth = 2.0;
    for (double i = 0; i < size.width; i += 28) {
      canvas.drawLine(
        Offset(i, size.height * 0.75),
        Offset(i + 14, size.height * 0.85),
        safetyPaint,
      );
    }
  }

  void _drawExclusionZone(Canvas canvas, Size size) {
    // STS Asılı Yük Altı Yasak Bölge
    final zoneRect = Rect.fromLTWH(size.width * 0.42, size.height * 0.38, size.width * 0.28, size.height * 0.44);

    final zoneFill = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(zoneRect, zoneFill);

    final zoneBorder = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(zoneRect, zoneBorder);

    // Çapraz çizgiler (Hatched)
    final hatchPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (double x = zoneRect.left; x < zoneRect.right; x += 18) {
      canvas.drawLine(Offset(x, zoneRect.top), Offset(x + 20, zoneRect.bottom), hatchPaint);
    }
  }

  void _drawCameraGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    // Yatay & Dikey referanslar
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), gridPaint);

    // 4 Köşe Reticle Köşebentleri
    final cornerPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const cornerLen = 14.0;
    // Sol Üst
    canvas.drawLine(const Offset(8, 8), const Offset(8 + cornerLen, 8), cornerPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(8, 8 + cornerLen), cornerPaint);
    // Sağ Üst
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8 - cornerLen, 8), cornerPaint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8, 8 + cornerLen), cornerPaint);
    // Sol Alt
    canvas.drawLine(Offset(8, size.height - 8), Offset(8 + cornerLen, size.height - 8), cornerPaint);
    canvas.drawLine(Offset(8, size.height - 8), Offset(8, size.height - 8 - cornerLen), cornerPaint);
    // Sağ Alt
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8 - cornerLen, size.height - 8), cornerPaint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8, size.height - 8 - cornerLen), cornerPaint);
  }

  void _drawTrajectory(Canvas canvas, TrackedEntity entity, Size size, double ox, double oy) {
    final trailPaint = Paint()
      ..color = entity.color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = entity.color
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < entity.trajectory.length; i++) {
      final pt = Offset(entity.trajectory[i].dx * size.width + ox, entity.trajectory[i].dy * size.height + oy);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawCircle(pt, 2.5, dotPaint);
    }
    canvas.drawPath(path, trailPaint);
  }

  void _drawVelocityVector(Canvas canvas, Rect rect, TrackedEntity entity) {
    final center = rect.center;
    final target = center + (entity.velocityVector * 350.0);

    final vecPaint = Paint()
      ..color = entity.color.withValues(alpha: 0.8)
      ..strokeWidth = 1.4;

    canvas.drawLine(center, target, vecPaint);
    canvas.drawCircle(target, 2.5, Paint()..color = entity.color);
  }

  void _drawBoundingBox(Canvas canvas, Rect rect, TrackedEntity entity) {
    // 1. Dolgu (Hafif saydam)
    final fillPaint = Paint()
      ..color = entity.color.withValues(alpha: entity.isHazard ? 0.22 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // 2. Ana Kutu Çerçevesi
    final strokePaint = Paint()
      ..color = entity.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = entity.isHazard ? 1.8 : 1.2;
    canvas.drawRect(rect, strokePaint);

    // 3. Köşe Vurguları (Cyber Reticles)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const len = 7.0;
    // Sol üst
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), cornerPaint);
    // Sağ üst
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), cornerPaint);
    // Sol alt
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), cornerPaint);
    // Sağ alt
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -len), cornerPaint);

    // 4. Üst Etiket Plaketi (Label Badge)
    final labelText = '#${entity.id} ${entity.label} %${(entity.confidence * 100).toInt()}';
    final tp = TextPainter(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(rect.left, rect.top - 16, tp.width + 8, 16);
    final badgePaint = Paint()..color = entity.color.withValues(alpha: 0.95);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), badgePaint);

    tp.paint(canvas, Offset(rect.left + 4, rect.top - 14));

    // 5. Seçili Nesne Kilit Halka Efekti (Lock Target Reticle)
    if (inspectedEntity?.id == entity.id) {
      final lockPaint = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(rect.center, math.max(rect.width, rect.height) * 0.65, lockPaint);
    }
  }

  @override
  bool shouldRepaint(covariant YoloVisionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sector != sector ||
        oldDelegate.engine != engine ||
        oldDelegate.showBoundingBoxes != showBoundingBoxes ||
        oldDelegate.showTrajectories != showTrajectories ||
        oldDelegate.confidenceThreshold != confidenceThreshold ||
        oldDelegate.inspectedEntity != inspectedEntity ||
        oldDelegate.isRealCameraFeed != isRealCameraFeed;
  }
}
