import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Türkçe karakter destekli PDF Font Yöneticisi
/// PDF oluşturulurken Roboto TrueType fontlarını yükler ve eksik glif sorununu (kutu kutu görünme) çözer.
class PdfFontHelper {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;
  static bool _isLoading = false;

  /// Fontları assetlerden yükler ve önbelleğe alır
  static Future<void> initFonts() async {
    if (_cachedRegular != null && _cachedBold != null) return;
    if (_isLoading) return;
    _isLoading = true;

    try {
      final regData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _cachedRegular = pw.Font.ttf(regData);
      _cachedBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('PdfFontHelper: TTF font yüklenirken hata oluştu: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// PDF Document için Türkçe destekli pw.ThemeData döner
  static Future<pw.ThemeData?> getTheme() async {
    await initFonts();
    if (_cachedRegular != null && _cachedBold != null) {
      return pw.ThemeData.withFont(
        base: _cachedRegular!,
        bold: _cachedBold!,
      );
    }
    return null;
  }

  /// Normal Font (Doğrudan stil tanımlamak için)
  static pw.Font? get regularFont => _cachedRegular;

  /// Kalın Font (Doğrudan stil tanımlamak için)
  static pw.Font? get boldFont => _cachedBold;

  /// Metin içindeki PDF standart fontlarında sorun çıkarabilecek karakterleri güvenli hale getirir.
  /// TTF font yüklüyse metni olduğu gibi Türkçe karakterleriyle (İ, ı, Ş, ş, Ğ, ğ, Ü, ü, Ö, ö, Ç, ç) bırakır.
  /// Sadece özel tire (—, –) ve tırnak işaretleri gibi standart dışı unicode sembolleri temizler.
  /// Eğer TTF font yüklenememişse (fallback durumunda) kutu kutu görünmemesi için Türkçe harfleri ASCII'ye dönüştürür.
  static String sanitize(String? text) {
    if (text == null || text.isEmpty) return '';

    // Standart dışı tire ve tırnakları düzelt (her zaman)
    String cleaned = text
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('•', '*');

    // Eğer Türkçe destekli font başarıyla yüklendiyse, Türkçe harfleri aynen koru!
    if (_cachedRegular != null) {
      return cleaned;
    }

    // Font yüklenemediyse kutu (box) çıkmaması için ASCII fallback uygula
    return cleaned
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }
}
