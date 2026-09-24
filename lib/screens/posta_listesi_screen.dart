import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../utils/push_service.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/vip_gate.dart';

class PostaListesiScreen extends StatefulWidget {
  final UserModel user;

  const PostaListesiScreen({super.key, required this.user});

  @override
  State<PostaListesiScreen> createState() => _PostaListesiScreenState();
}

class _PostaListesiScreenState extends State<PostaListesiScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isVip = false;
  bool _isCheckingVip = true;

  @override
  void initState() {
    super.initState();
    _verifyVipAccess();
  }

  Future<void> _verifyVipAccess() async {
    if (widget.user.isVip) {
      if (mounted) {
        setState(() {
          _isVip = true;
          _isCheckingVip = false;
        });
      }
      return;
    }
    final isVip = await VipGate.checkVipStatus(user: widget.user);
    if (mounted) {
      setState(() {
        _isVip = isVip;
        _isCheckingVip = false;
      });
    }
  }

  Future<void> _uploadList() async {
    try {
      final XFile? image = await showDialog<XFile?>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Fotoğraf Seç', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                title: const Text('Kamera (Tam Çözünürlük)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Net ve orijinal kalitede çeker', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  try {
                    final file = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 100,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, file);
                  } catch (e) {
                    debugPrint('Kamera hatası: $e');
                    if (ctx.mounted) Navigator.pop(ctx, null);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                title: const Text('Galeri (Tam Çözünürlük)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Orijinal netlikte yükler', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  try {
                    final file = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 100,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, file);
                  } catch (e) {
                    debugPrint('Galeri hatası: $e');
                    if (ctx.mounted) Navigator.pop(ctx, null);
                  }
                },
              ),
            ],
          ),
        ),
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // Show dialog to ask for the date range/info (optional)
      String tarihAraligi = DateFormat('dd.MM.yyyy').format(DateTime.now());
      
      if (!mounted) return;
      
      final bool? confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final ctrl = TextEditingController(text: tarihAraligi);
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Bilgileri Onayla', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tarih / Vardiya Bilgisi',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
                onPressed: () {
                  tarihAraligi = ctrl.text;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Yükle', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      );

      if (confirm != true) {
        setState(() { _isUploading = false; });
        return;
      }

      // 1. Resim verisini al
      final Uint8List data = await image.readAsBytes();
      String downloadUrl = '';

      try {
        final String fileName = const Uuid().v4();
        final Reference storageRef = FirebaseStorage.instance.ref().child('posta_listeleri').child('$fileName.jpg');
        final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
        
        final UploadTask uploadTask = storageRef.putData(data, metadata);
        final TaskSnapshot snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
      } catch (storageError) {
        debugPrint('Firebase Storage yükleme hatası, base64 yedekleme kullanılıyor: $storageError');
        // Storage henüz konsoldan aktif edilmemiş veya 404 dönüyorsa doğrudan güvenli base64 sakla
        final String base64String = base64Encode(data);
        downloadUrl = 'data:image/jpeg;base64,$base64String';
      }

      // 2. Firestore'a kaydet
      final adSoyad = '${widget.user.firstName} ${widget.user.lastName}';
      
      await FirebaseFirestore.instance.collection('posta_listeleri').add({
        'imageUrl': downloadUrl,
        'tarihAraligi': tarihAraligi,
        'ekleyenKisi': adSoyad,
        'eklenmeTarihi': FieldValue.serverTimestamp(),
      });

      // 3. Bildirim gönder (Sadece VIP kullanıcılara)
      await PushService.sendPushNotification(
        title: '👑 Yeni Posta Listesi (VIP)',
        content: '$adSoyad, $tarihAraligi tarihli posta listesini paylaştı!',
        isVipOnly: true,
      );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liste başarıyla yüklendi!')));
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Widget _buildImageWidget(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image') || url.startsWith('base64:')) {
      final base64Data = url.contains(',')
          ? url.split(',').last
          : (url.startsWith('base64:') ? url.substring(7) : url);
      try {
        return Image.memory(
          base64Decode(base64Data.trim()),
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
          ),
        );
      } catch (e) {
        return const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
        );
      }
    } else {
      return Image.network(
        url,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
        ),
      );
    }
  }

  Future<bool?> _deleteList(String docId, Map<String, dynamic> data) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFE50914), size: 24),
            SizedBox(width: 8),
            Text('Listeyi Sil', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"${data['tarihAraligi'] ?? 'Bu'}" tarihli posta listesini silmek istediğinize emin misiniz?\nBu işlem geri alınamaz.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      // 1. Firestore'dan dokümanı sil
      await FirebaseFirestore.instance.collection('posta_listeleri').doc(docId).delete();

      // 2. Eğer resim Storage'da depolanmışsa Storage'dan da temizle
      final imageUrl = data['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.startsWith('http') && imageUrl.contains('posta_listeleri')) {
        try {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Posta listesi başarıyla silindi.'),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silme işlemi başarısız oldu: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
      return false;
    }
  }

  void _showImageFullScreen(String url, {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(context, MaterialPageRoute(builder: (fullScreenCtx) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Tam Çözünürlüklü Liste', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (docId != null && data != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Listeyi Sil',
              onPressed: () async {
                final deleted = await _deleteList(docId, data);
                if (deleted == true && fullScreenCtx.mounted) {
                  Navigator.pop(fullScreenCtx);
                }
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 12.0,
          clipBehavior: Clip.none,
          child: _buildImageWidget(url, fit: BoxFit.contain),
        ),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingVip) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F13),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    if (!_isVip) {
      return VipRestrictedView(
        user: widget.user,
        onAuthorized: () {
          setState(() {
            _isVip = true;
          });
        },
        onBack: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C22),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'POSTA LİSTELERİ',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👑 VIP', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('posta_listeleri').orderBy('eklenmeTarihi', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PostaListSkeleton();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Henüz yüklenmiş bir liste yok.', style: TextStyle(color: Colors.white54)));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final dateData = data['eklenmeTarihi'];
                  DateTime date = DateTime.now();
                  if (dateData is Timestamp) {
                    date = dateData.toDate();
                  }
                  
                  final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(date);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE50914).withValues(alpha: 0.2),
                                child: const Icon(Icons.person, color: Color(0xFFE50914)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['ekleyenKisi'] ?? 'Bilinmiyor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('Yeni Liste', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => _deleteList(docs[index].id, data),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Tarih / Vardiya: ${data['tarihAraligi'] ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ),
                        const SizedBox(height: 12),
                        
                        if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: GestureDetector(
                              onTap: () => _showImageFullScreen(
                                data['imageUrl'],
                                docId: docs[index].id,
                                data: data,
                              ),
                              child: Container(
                                width: double.infinity,
                                height: 300,
                                color: Colors.black,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildImageWidget(data['imageUrl'], fit: BoxFit.cover),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      alignment: Alignment.bottomCenter,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('HD', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 6),
                                          const Text('Tam Çözünürlük & Yakınlaştırma İçin Dokun', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // Bottom corner radius fix for the image
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.82),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 3.5),
                    SizedBox(height: 20),
                    Text('Tam Çözünürlüklü Liste Yükleniyor...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Fotoğraf orijinal kalitesinde işleniyor', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE50914),
        onPressed: _isUploading ? null : _uploadList,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Liste Yükle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
