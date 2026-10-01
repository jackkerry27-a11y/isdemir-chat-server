import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_data.dart';

class FoodInfo {
  final String imageUrl;
  final String subtitle;
  final String badge1; // e.g. "🥩 10g protein"
  final String badge2; // e.g. "🌿 Yüksek Lif"
  final String badge3; // e.g. "🛡️ Bağışıklık Dostu"

  const FoodInfo({
    required this.imageUrl,
    required this.subtitle,
    required this.badge1,
    required this.badge2,
    required this.badge3,
  });
}

class YemekScreen extends StatefulWidget {
  const YemekScreen({super.key});

  @override
  State<YemekScreen> createState() => _YemekScreenState();
}

class _YemekScreenState extends State<YemekScreen> with SingleTickerProviderStateMixin {
  int selectedDay = 1;
  int selectedMealTab = 0; // 0: Ana Menü, 1: Kahvaltı, 2: Salata & Yan, 3: NutriShift AI
  int userRating = 5; // Default to 5 filled stars
  final ScrollController _dateScrollController = ScrollController();
  final ScrollController _contentScrollController = ScrollController();

  // ── Executive Gastronomi Design Tokens ──
  static const Color darkBg = Color(0xFF090C12);
  static const Color cardBg = Color(0xFF121622);
  static const Color cardBgElevated = Color(0xFF171D2D);
  static const Color cardBorder = Color(0xFF1F283C);
  static const Color primaryRed = Color(0xFFE11D48);
  static const Color goldAmber = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFDE68A);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDay = (now.day >= 1 && now.day <= 31) ? now.day : 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dateScrollController.hasClients) {
        final targetOffset = ((selectedDay - 2).clamp(0, 31)) * 66.0;
        _dateScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  DailyMenu _getMenu(int day) {
    return MenuData.octoberMenu[day] ??
        MenuData.septemberMenu[day] ??
        MenuData.augustMenu[day] ??
        MenuData.octoberMenu[1]!;
  }

  // ── Canlı Servis Durumu Hesaplayıcı ──
  String _getCurrentMealServiceStatus() {
    final hour = DateTime.now().hour;
    final minute = DateTime.now().minute;
    final totalMinutes = hour * 60 + minute;

    if (totalMinutes >= 390 && totalMinutes <= 570) {
      return 'Sabah Kahvaltısı Serviste';
    } else if (totalMinutes >= 690 && totalMinutes <= 870) {
      return 'Öğle Tabildotu Serviste';
    } else if (totalMinutes >= 1050 && totalMinutes <= 1230) {
      return 'Akşam Yemeği Serviste';
    } else if (totalMinutes >= 1410 || totalMinutes <= 150) {
      return 'Gece Vardiya Yemeği Serviste';
    } else {
      return 'Mutfak Hazırlıkta • Açık Büfe';
    }
  }

  // ── Curated Real Food Photography & Nutrition Metadata ──
  static String _normalizeTurkish(String s) {
    return s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .toLowerCase()
        .trim();
  }

  static const Map<String, String> _foodAssetMap = {
    // Çorbalar
    'ezogelin': 'assets/images/food/ezogelin_corbasi.jpg',
    'mercimek': 'assets/images/food/mercimekcorbasi.jpg',
    'yayla': 'assets/images/food/yayla_corbasi.jpg',
    'sehriye': 'assets/images/food/sehriye_corbasi.jpg',
    'tutmac': 'assets/images/food/tutmac_corbasi.jpg',
    'anadolu': 'assets/images/food/anadolu_corbasi.jpg',
    'ascibasi': 'assets/images/food/ascibasi_corbasi.jpg',
    'domates corba': 'assets/images/food/domates_corbasi.jpg',
    'ayranasi': 'assets/images/food/ayran_asi_corbasi.jpg',

    // Et / Tavuk / Balık Yemekleri
    'tas kebap': 'assets/images/food/tas_kebap.jpg',
    'doner': 'assets/images/food/et_doner.jpg',
    'et doner': 'assets/images/food/et_doner.jpg',
    'et kavurma': 'assets/images/food/et_kavurma.jpg',
    'et haslama': 'assets/images/food/et_haslama.jpg',
    'etli turlu': 'assets/images/food/etli_turlu.jpg',
    'etli patates': 'assets/images/food/etli_patates.jpg',
    'etli bezelye': 'assets/images/food/etli_bezelye.jpg',
    'etli nohut': 'assets/images/food/etli_nohut_yahni.jpg',
    'etli kuru fasulye': 'assets/images/food/etli_kuru_fasulye.jpg',
    'gemici kuru fasulye': 'assets/images/food/gemici_kuru_fasulye.jpg',
    'karniyarik': 'assets/images/food/karniyarik.jpg',
    'patlican guvec': 'assets/images/food/patlican_guvec.jpg',
    'patlican musakka': 'assets/images/food/patlican_musakka.webp',
    'kabak kalye': 'assets/images/food/kabak_kalye.jpg',
    'firin balik': 'assets/images/food/firin_balik.jpg',
    'hamburger': 'assets/images/food/hamburger.jpg',
    'kadinbudu': 'assets/images/food/kadinbudu_kofte.jpg',
    'rosto kofte': 'assets/images/food/pureli_rosto_kofte.jpg',
    'izmir kofte': 'assets/images/food/izmir_kofte.jpg',
    'mitide kofte': 'assets/images/food/mitide_kofte.jpg',
    'terbiyeli kofte': 'assets/images/food/terbiyeli_kofte.jpg',
    'pilic firin': 'assets/images/food/pilic_firin.jpg',
    'pilic izgara': 'assets/images/food/pilic_izgara.jpg',
    'pilic topkapi': 'assets/images/food/pilic_topkapi.jpg',
    'mantarli tavuk': 'assets/images/food/mantarli_tavuk_sote.jpg',
    'sebzeli tavuk': 'assets/images/food/sebzeli_tavuk_kebabi.jpg',

    // Pilav, Makarna & Börek
    'pirinc pilav': 'assets/images/food/pirinc_pilavi.jpg',
    'bulgur pilav': 'assets/images/food/bulgur_pilavi.jpg',
    'soslu bulgur': 'assets/images/food/bulgur_pilavi.jpg',
    'esmer bulgur': 'assets/images/food/bulgur_pilavi.jpg',
    'noh.pirinc': 'assets/images/food/bulgur_pilavi.jpg',
    'ic pilav': 'assets/images/food/ic_pilav.jpg',
    'firin makarna': 'assets/images/food/firin_makarna.jpg',
    'yog.makarna': 'assets/images/food/yogurtlu_makarna.jpg',
    'kiymali borek': 'assets/images/food/kiymali_borek.jpg',
    'ispanakli kol boregi': 'assets/images/food/peynirli_kol_boregi.jpg',
    'peynirli kol boregi': 'assets/images/food/peynirli_kol_boregi.jpg',
    'pizza': 'assets/images/food/pizza.jpg',
    'pogaca': 'assets/images/food/pogaca.jpg',
    'simit': 'assets/images/food/simit.jpg',
    'zeytinli acma': 'assets/images/food/zeytinli_acma.jpg',
    'biberli ekmek': 'assets/images/food/pogaca.jpg',
    'patates kizartmasi': 'assets/images/food/patates_kizartmasi.jpg',
    'firin patates': 'assets/images/food/firin_patates.jpg',
    'patates sote': 'assets/images/food/patates_sote.jpg',

    // Zeytinyağlılar & Bakliyat
    'barbunya pilaki': 'assets/images/food/barbunya_pilaki.jpg',
    'zy.taze fasulye': 'assets/images/food/zeytinyagli_taze_fasulye.jpg',
    'zy.ispanak': 'assets/images/food/zeytinyagli_ispanak.jpg',
    'zy.kereviz': 'assets/images/food/zeytinyagli_kereviz.jpg',

    // Kahvaltılıklar
    'h.yumurta': 'assets/images/food/haslanmis_yumurta.jpg',
    'haslanmis yumurta': 'assets/images/food/haslanmis_yumurta.jpg',
    'omlet': 'assets/images/food/omlet.jpg',
    'menemen': 'assets/images/food/menemen.jpg',
    'sucuklu yumurta': 'assets/images/food/omlet.jpg',
    'kasar': 'assets/images/food/kasar.jpg',
    'beyaz peynir': 'assets/images/food/beyaz_peynir.jpg',
    'krem peynir': 'assets/images/food/krem_peynir.jpg',
    'siyah zeytin': 'assets/images/food/siyah_zeytin.jpg',
    'yesil zeytin': 'assets/images/food/yesil_zeytin.jpg',
    'biberli zeytin': 'assets/images/food/biberli_zeytin.jpg',
    'bal': 'assets/images/food/bal.jpg',
    'recel': 'assets/images/food/recel.jpg',
    'findik ezmesi': 'assets/images/food/findik_ezmesi.jpg',
    'tahin pekmez': 'assets/images/food/tahin_pekmez.jpg',
    'pekmez': 'assets/images/food/pekmez.jpg',
    'tereyagi': 'assets/images/food/tereyagi.jpg',
    'cay/ekmek': 'assets/images/food/cay.jpg',
    'cay': 'assets/images/food/cay.jpg',
    'sut': 'assets/images/food/sut.jpg',
    'meyve suyu': 'assets/images/food/meyve_suyu.jpg',
    'domates-salatalik': 'assets/images/food/domates_salatalik_tabagi.jpg',
    'uzumlu kek': 'assets/images/food/uzumlu_kek.jpg',
    'havuclu kek': 'assets/images/food/havuclu_kek.jpg',

    // Salatalar & Mezeler
    'mevsim salata': 'assets/images/food/mevsim_salata.jpg',
    'coban salata': 'assets/images/food/coban_salata.jpg',
    'roka salatasi': 'assets/images/food/roka_salatasi.jpg',
    'rus salatasi': 'assets/images/food/rus_salatasi.jpg',
    'acili kasik salata': 'assets/images/food/acili_kasik_salata.jpg',
    'pembe sultan': 'assets/images/food/pembe_sultan_salatasi.jpg',
    'pancarli sehriye salatasi': 'assets/images/food/pancarli_sehriye_salatasi.jpg',
    'humus': 'assets/images/food/humus.jpg',
    'kisir': 'assets/images/food/kisir.jpg',
    'cacik': 'assets/images/food/cacik.jpg',
    'saksuka': 'assets/images/food/saksuka.jpg',
    'mutebbel': 'assets/images/food/mutebbel.jpg',
    'firin mucver': 'assets/images/food/firin_mucver.jpg',
    'firin karnabahar': 'assets/images/food/firin_karnabahar.jpg',
    'karisik kizartma': 'assets/images/food/karisik_kizartma.jpg',
    'yog.semizotu': 'assets/images/food/yogurtlu_semizotu.jpg',
    'yog.biber': 'assets/images/food/yogurtlu_biber.jpg',
    'yog.patlican': 'assets/images/food/yogurtlu_patlican.jpg',
    'yog.kabak': 'assets/images/food/yogurtlu_kabak.jpg',
    'yog.kereviz': 'assets/images/food/yogurtlu_kereviz.jpg',
    'pancar tursusu': 'assets/images/food/pancar_tursusu.jpg',
    'kornison tursu': 'assets/images/food/kornison_tursusu.jpg',
    'tursu': 'assets/images/food/tursu_karisik.jpg',
    'havuc rende': 'assets/images/food/havuc_rende.jpg',
    'havuc tarator': 'assets/images/food/havuc_tarator.jpg',
    'sebze buketi': 'assets/images/food/sebze_buketi.jpg',
    'sogan piyazi': 'assets/images/food/sogan_piyazi.jpg',
    'sumakli sogan': 'assets/images/food/sumakli_sogan.jpg',
    'sogan sogus': 'assets/images/food/sogan_sogus.jpg',
    'firin sogan': 'assets/images/food/sogan_sogus.jpg',
    'domates sogus': 'assets/images/food/domates.jpg',
    'salatalik sogus': 'assets/images/food/salatalik.jpg',
    'biber sogus': 'assets/images/food/biber.jpg',
    'firin biber': 'assets/images/food/biber.jpg',
    'aysberg': 'assets/images/food/salatalik.jpg',
    'marineli beyaz lahana': 'assets/images/food/marineli_lahana.jpg',
    'marineli kirmizi lahana': 'assets/images/food/marineli_lahana.jpg',

    // Tatlılar, Meyve & İçecekler
    'meyve': 'assets/images/food/meyve_tabagi.jpg',
    'baklava': 'assets/images/food/baklava.jpg',
    'tulumba': 'assets/images/food/tulumba.jpg',
    'tulumba tatlisi': 'assets/images/food/tulumba.jpg',
    'sam tatli': 'assets/images/food/sam_tatlisi.png',
    'browni': 'assets/images/food/browni.jpg',
    'kibris tatlisi': 'assets/images/food/kibris_tatlisi.jpg',
    'irmik helva': 'assets/images/food/irmik_helva.jpg',
    'tiramisu': 'assets/images/food/tiramsu.jpg',
    'yogurt tatlisi': 'assets/images/food/yogurttatlisi.jpg',
    'supangle': 'assets/images/food/supangle.jpg',
    'mozaik pasta': 'assets/images/food/mozaikpasta.jpg',
    'turunc tatlisi': 'assets/images/food/turunc_tatlisi.jpg',
    'muhallebili tel kadayif': 'assets/images/food/muhalebi_tel_kadayif.jpg',
    'sutlac': 'assets/images/food/sutlac.jpg',
    'asure': 'assets/images/food/asure.jpg',
    'ayran': 'assets/images/food/ayran.jpg',
    'yogurt': 'assets/images/food/yogurt.jpg',
    'salgam': 'assets/images/food/salgam.jpg',
  };

  static String _getFoodImagePath(String foodName) {
    final n = _normalizeTurkish(foodName);
    if (_foodAssetMap.containsKey(n)) {
      return _foodAssetMap[n]!;
    }
    for (final entry in _foodAssetMap.entries) {
      if (n.contains(entry.key) || entry.key.contains(n)) {
        return entry.value;
      }
    }
    return 'assets/images/food/mevsim_salata.jpg';
  }

  FoodInfo _getFoodDetails(String foodName) {
    final image = _getFoodImagePath(foodName);
    final lower = foodName.toLowerCase();

    // Çorbalar
    if (lower.contains('ezogelin')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Sıcak Başlangıç • Sinir & Mide Dostu',
        badge1: '10g protein',
        badge2: 'Yüksek Lif',
        badge3: 'Bağışıklık Güçlendirici',
      );
    } else if (lower.contains('mercimek')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Sıcak Çorba • B Vitamini Deposu',
        badge1: '11g protein',
        badge2: 'Yüksek Lif',
        badge3: 'Sindirim Dostu',
      );
    } else if (lower.contains('yayla')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Yoğurtlu & Naneli Ferahlatıcı Başlangıç',
        badge1: '9g protein',
        badge2: 'Doğal Probiyotik',
        badge3: 'Mide Koruyucu',
      );
    } else if (lower.contains('şehriye') || lower.contains('anadolu') || lower.contains('çorba') || lower.contains('tutmaç') || lower.contains('aşçıbaşı')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Usta Çorbası • Ağır Ateşte Pişmiş',
        badge1: '8g protein',
        badge2: 'Hafif & Besleyici',
        badge3: 'Mide Koruyucu',
      );
    }

    // Ana Et ve Tavuk Yemekleri
    if (lower.contains('taş kebap') || lower.contains('kebap')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Diyetisyen Kontrollü • Ağır Sanayi Enerjisi',
        badge1: '28g protein',
        badge2: 'Yüksek Protein',
        badge3: 'Dengeli Kas Yakıtı',
      );
    } else if (lower.contains('köfte')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Özel İskenderun Harçlı • Köz Tadında Izgara',
        badge1: '26g protein',
        badge2: 'Yüksek Demir',
        badge3: 'Hücre Onarımı',
      );
    } else if (lower.contains('döner')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Yaprak Et Döner • Yüksek Enerji',
        badge1: '30g protein',
        badge2: 'Yüksek Enerji',
        badge3: 'Güç Desteği',
      );
    } else if (lower.contains('tavuk') || lower.contains('piliç')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Özel Fırın Marinasyonu • Kolay Sindirilebilir',
        badge1: '28g protein',
        badge2: 'B6 Vitamini',
        badge3: 'Düşük Doymuş Yağ',
      );
    } else if (lower.contains('kavurma') || lower.contains('musakka') || lower.contains('güveç') || lower.contains('türlü') || lower.contains('haşlama')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Fırın Güveci • Sebze & Et Dengesi',
        badge1: '24g protein',
        badge2: 'Sebzeli Lif',
        badge3: 'Uzun Süre Tokluk',
      );
    } else if (lower.contains('fasulye') || lower.contains('nohut') || lower.contains('barbunya') || lower.contains('bezelye')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Toprak Güveçte Pişmiş • Zengin Bitkisel Protein',
        badge1: '18g protein',
        badge2: 'Bitkisel Protein',
        badge3: 'Uzun Tokluk',
      );
    } else if (lower.contains('balık')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Akdeniz Taze Balık • Doğal Omega 3 Kaynağı',
        badge1: '25g protein',
        badge2: 'Omega 3',
        badge3: 'Kalp Dostu',
      );
    } else if (lower.contains('hamburger')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Özel Şef Burger • Çıtır Garnitür Eşliğinde',
        badge1: '22g protein',
        badge2: 'Yüksek Enerji',
        badge3: 'Doyurucu',
      );
    }

    // Pilav & Makarna
    if (lower.contains('bulgur') || lower.contains('pirinç') || lower.contains('pilav')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Tereyağlı Tane Tane • Kompleks Karbonhidrat',
        badge1: '10g protein',
        badge2: 'Kompleks Karbonhidrat',
        badge3: 'Kararlı Kan Şekeri',
      );
    } else if (lower.contains('makarna')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Fırınlanmış Soslu Makarna • Hızlı Enerji',
        badge1: '12g protein',
        badge2: 'Hızlı Enerji',
        badge3: 'Glikojen Desteği',
      );
    }

    // Meyve
    if (lower.contains('meyve') || lower.contains('karpuz') || lower.contains('kavun')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Taze Mevsim Meyvesi • Doğal C Vitamini',
        badge1: '2g protein',
        badge2: 'C Vitamini',
        badge3: 'Antioksidan Kaynağı',
      );
    }

    // İçecek & Yoğurt
    if (lower.contains('ayran')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Yayık Ayranı • Elektrolit & Mineral',
        badge1: '6g protein',
        badge2: 'Doğal Probiyotik',
        badge3: 'Kalsiyum & Serinletici',
      );
    } else if (lower.contains('şalgam')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Doğal Fermante Şalgam Suyu • Sindirim Dostu',
        badge1: '1g protein',
        badge2: 'Sindirim Enzimleri',
        badge3: 'Elektrolit Dengesi',
      );
    } else if (lower.contains('yoğurt') || lower.contains('cacık')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Köy Tipi Doğal Yoğurt • Probiyotik Deposu',
        badge1: '8g protein',
        badge2: 'Canlı Probiyotik',
        badge3: 'Kemik Gücü',
      );
    }

    // Tatlılar
    if (lower.contains('baklava') || lower.contains('tatlı') || lower.contains('kadayıf') || lower.contains('helva') || lower.contains('tulumba') || lower.contains('aşure')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Geleneksel Şerbetli Tatlı • Enerji ve Keyif İkramı',
        badge1: '6g protein',
        badge2: 'Hızlı Enerji',
        badge3: 'Moral Deposu',
      );
    } else if (lower.contains('sütlaç') || lower.contains('muhallebi') || lower.contains('supangle') || lower.contains('dondurma') || lower.contains('browni') || lower.contains('pasta') || lower.contains('tiramisu')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Fırınlanmış Hafif Sütlü Tatlı • Dengeli Şeker',
        badge1: '7g protein',
        badge2: 'Kalsiyum',
        badge3: 'Hafif Tatlı',
      );
    }

    // Kahvaltı / Salata Genel
    if (lower.contains('yumurta') || lower.contains('omlet') || lower.contains('menemen')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Taze Çırpılmış Sıcak Kahvaltı • Kolin & B12',
        badge1: '14g protein',
        badge2: 'Kolin & B12',
        badge3: 'Zihinsel Odaklanma',
      );
    } else if (lower.contains('börek') || lower.contains('poğaça') || lower.contains('simit') || lower.contains('açma') || lower.contains('pizza') || lower.contains('ekmek') || lower.contains('kek')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Fırından Yeni Çıkmış Çıtır Hamur İşi',
        badge1: '8g protein',
        badge2: 'Sabah Enerjisi',
        badge3: 'Doyurucu Lezzet',
      );
    } else if (lower.contains('peynir') || lower.contains('kaşar')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Doğal Olgunlaştırılmış Yayık Peyniri',
        badge1: '12g protein',
        badge2: 'Yüksek Kalsiyum',
        badge3: 'Kemik Gücü',
      );
    } else if (lower.contains('zeytin')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Hatay ve Ege Hasadı Doğal Zeytin',
        badge1: '2g protein',
        badge2: 'E Vitamini',
        badge3: 'Sağlıklı Yağ Asitleri',
      );
    } else if (lower.contains('bal') || lower.contains('reçel') || lower.contains('ezme') || lower.contains('pekmez')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Doğal Karbonhidrat & Enerji Verici',
        badge1: '1g protein',
        badge2: 'Saf Karbonhidrat',
        badge3: 'Hızlı Enerji',
      );
    } else if (lower.contains('salata') || lower.contains('söğüş') || lower.contains('kısır') || lower.contains('humus') || lower.contains('turşu') || lower.contains('meze')) {
      return FoodInfo(
        imageUrl: image,
        subtitle: 'Bahçe Hasadı Taze Sebzeler • Zeytinyağlı',
        badge1: '4g protein',
        badge2: 'Zengin Lif',
        badge3: 'Hücre Yenileyici',
      );
    }

    // Varsayılan
    return FoodInfo(
      imageUrl: image,
      subtitle: 'Diyetisyen Onaylı Gastronomi Menüsü',
      badge1: '10g protein',
      badge2: 'Dengeli Besin',
      badge3: 'Günlük Enerji',
    );
  }

  // ── Akıllı Görsel Oluşturucu ──
  Widget _buildFoodImage(
    String pathOrUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget;
    if (pathOrUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        pathOrUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: const Color(0xFF1E2433),
          child: const Center(
            child: Icon(Icons.restaurant_rounded, color: Colors.white38, size: 28),
          ),
        ),
      );
    } else if (pathOrUrl.startsWith('http')) {
      imageWidget = Image.network(
        pathOrUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFF1E2433),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: const Color(0xFF1E2433),
          child: const Center(
            child: Icon(Icons.restaurant_rounded, color: Colors.white38, size: 28),
          ),
        ),
      );
    } else {
      imageWidget = Container(
        width: width,
        height: height,
        color: const Color(0xFF1E2433),
        child: const Center(
          child: Icon(Icons.restaurant_rounded, color: Colors.white38, size: 28),
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: imageWidget);
    }
    return imageWidget;
  }

  @override
  Widget build(BuildContext context) {
    final menu = _getMenu(selectedDay);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // ── 1. ÜST EXECUTIVE GASTRONOMİ BARI ──
            _buildGastronomiTopBar(),

            // ── 2. KAYAN TAKVİM ŞERİDİ (1 Per, 2 Cum, 3 Cmt, ...) ──
            _buildDateCarousel(),

            // ── 3. ÖĞÜN KATEGORİ SEKMELERİ ──
            _buildMealCategoryTabs(),

            // ── 4. KAYDIRILABİLİR İÇERİK ──
            Expanded(
              child: SingleChildScrollView(
                controller: _contentScrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedMealTab == 0) _buildMainCourseSection(menu),
                    if (selectedMealTab == 1) _buildBreakfastSection(menu),
                    if (selectedMealTab == 2) _buildSaladSection(menu),
                    if (selectedMealTab == 3) _buildNutriShiftAiSection(menu),

                    const SizedBox(height: 20),

                    // Günün Tabildotunu Puanla Kartı
                    _buildChefRatingCard(),

                    const SizedBox(height: 24),

                    // Gastronomi Footer
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'İSDEMİR Destek Hizmetleri • Diyetisyen & Baş Aşçı Onaylı',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tüm gıdalar ISO 22000 Gıda Güvenliği Standartlarında hazırlanmaktadır.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Modern Gastronomi Üst Barı ──
  Widget _buildGastronomiTopBar() {
    final statusText = _getCurrentMealServiceStatus();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: darkBg,
        border: Border(
          bottom: BorderSide(color: cardBorder.withValues(alpha: 0.5), width: 0.8),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Circular Back Button
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF831843), Color(0xFFBE123C)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('👨‍🍳', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  'EXECUTIVE GASTRONOMİ',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live Pulsating Indicator
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: accentEmerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'CANLI',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: accentEmerald,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'İSDEMİR Mutfak Menüsü',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bugün Butonu
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final today = DateTime.now().day.clamp(1, 31);
                  setState(() => selectedDay = today);
                  if (_dateScrollController.hasClients) {
                    _dateScrollController.animateTo(
                      ((today - 2).clamp(0, 31)) * 66.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2B161B),
                        const Color(0xFF1B1422),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryRed.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFFFCA5A5), size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'BUGÜN',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Alt Servis Barı (Canlı Servis Durumu)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1420),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: goldAmber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: goldLight,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ekim 2026 Menüsü',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Kayan Tarih Şeridi (1 Per, 2 Cum, 3 Cmt, ...) ──
  Widget _buildDateCarousel() {
    final todayDay = DateTime.now().day;

    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: 31,
        itemBuilder: (context, index) {
          final day = index + 1;
          final isSelected = day == selectedDay;
          final isToday = day == todayDay;
          final date = DateTime(2026, 10, day);
          final daysShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
          final dayName = daysShort[date.weekday - 1];

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => selectedDay = day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE11D48), Color(0xFFF59E0B)],
                      )
                    : null,
                color: isSelected ? null : const Color(0xFF131724),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isToday ? goldAmber.withValues(alpha: 0.6) : cardBorder),
                  width: isToday && !isSelected ? 1.2 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryRed.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: goldAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'BUGÜN',
                        style: GoogleFonts.inter(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: goldAmber,
                        ),
                      ),
                    ),
                  Text(
                    day.toString().padLeft(2, '0'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? Colors.white : textMuted,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 3. Öğün Kategori Sekmeleri ──
  Widget _buildMealCategoryTabs() {
    final tabs = [
      {'label': 'Ana Menü', 'icon': Icons.restaurant_rounded, 'tag': 'Tabildot'},
      {'label': 'Kahvaltı', 'icon': Icons.coffee_rounded, 'tag': 'Sabah'},
      {'label': 'Salata & Meze', 'icon': Icons.eco_rounded, 'tag': 'Büfe'},
      {'label': 'NutriShift™ AI', 'icon': Icons.auto_awesome_rounded, 'tag': 'Diyetisyen'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isSelected = selectedMealTab == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => selectedMealTab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (i == 3 ? const Color(0xFF7C3AED) : primaryRed)
                        : const Color(0xFF131724),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : cardBorder,
                      width: 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (i == 3 ? const Color(0xFF7C3AED) : primaryRed).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tabs[i]['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : (i == 3 ? const Color(0xFFA78BFA) : textMuted),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[i]['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── 4. Ana Menü Kartları (Öğle & Akşam Tabildotu) ──
  Widget _buildMainCourseSection(DailyMenu menu) {
    // Determine the hero main dish (usually index 1)
    final heroDish = menu.mainCourse.length > 1 ? menu.mainCourse[1] : menu.mainCourse[0];
    final heroInfo = _getFoodDetails(heroDish.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Günlük Başlık & Kalori / Protein Rozeti
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF151A27), Color(0xFF0F1420)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🗓️', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        menu.dateText,
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Öğle & Akşam Vardiyası Tabildotu',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26180E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: goldAmber.withValues(alpha: 0.6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${menu.totalCalories} kcal',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: goldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D251D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentEmerald.withValues(alpha: 0.6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🥩', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          menu.totalProtein.isNotEmpty ? menu.totalProtein : '45g',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── GÜNÜN İMZASI: PANORAMİK ŞEF SHOWCASE KARTI ──
        _buildChefSignatureHeroCard(heroDish, heroInfo),

        const SizedBox(height: 18),

        // Başlık: Tabildot Kursları
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
          child: Row(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '5 Kursluk Tabildot Menü Kalemleri',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Food Items List with Course Badges
        ...menu.mainCourse.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isHero = idx == 1;
          final info = _getFoodDetails(item.name);
          final courseNames = [
            '1. Kurs • Sıcak Başlangıç',
            '2. Kurs • Şefin Ana Yemeği',
            '3. Kurs • Tamamlayıcı Lezzet',
            '4. Kurs • Tatlı & İkram',
            '5. Kurs • Soğuk İçecek & Fermente'
          ];
          final courseName = idx < courseNames.length ? courseNames[idx] : 'Tabildot İkramı';

          return _buildGastronomiFoodCard(
            name: item.name,
            calories: item.calories.isNotEmpty ? '${item.calories} kcal' : '300 kcal',
            courseTag: courseName,
            info: info,
            isHero: isHero,
          );
        }),
      ],
    );
  }

  // ── Panoramik Şef İmzası Hero Kartı ──
  Widget _buildChefSignatureHeroCard(MealItem dish, FoodInfo info) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showFoodDetailSheet(dish.name, '${dish.calories} kcal', info);
      },
      child: Container(
        height: 195,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: goldAmber.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: goldAmber.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Photo
              _buildFoodImage(info.imageUrl, fit: BoxFit.cover),

              // Gradient Scrim Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.5),
                      const Color(0xFF090C12).withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // Top Floating Tags
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        'ŞEFİN GÜNLÜK İMZASI',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Text(
                    '${dish.calories} kcal',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: goldLight,
                    ),
                  ),
                ),
              ),

              // Bottom Dish Details
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dish.name,
                            style: GoogleFonts.inter(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            info.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildMicroBadge(text: '🥩 ${info.badge1}', textColor: const Color(0xFFFCA5A5)),
                              const SizedBox(width: 6),
                              _buildMicroBadge(text: '🌿 ${info.badge2}', textColor: const Color(0xFF86EFAC)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: goldAmber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: goldAmber.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                      ),
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

  // ── Gastronomi Food Card (Kurs Etiketli & Modern) ──
  Widget _buildGastronomiFoodCard({
    required String name,
    required String calories,
    required String courseTag,
    required FoodInfo info,
    bool isHero = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showFoodDetailSheet(name, calories, info);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHero ? const Color(0xFF1A1320) : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHero ? goldAmber.withValues(alpha: 0.8) : cardBorder,
            width: isHero ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 88x88 High-End Food Photography with subtle frame
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHero ? goldAmber.withValues(alpha: 0.5) : cardBorder,
                  width: 1,
                ),
              ),
              child: _buildFoodImage(
                info.imageUrl,
                width: 86,
                height: 86,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(15),
              ),
            ),

            const SizedBox(width: 13),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Tag Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHero
                          ? goldAmber.withValues(alpha: 0.2)
                          : const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      courseTag,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isHero ? goldLight : textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  Text(
                    info.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 7),

                  // Micro-Attribute Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMicroBadge(text: '🥩 ${info.badge1}', textColor: const Color(0xFFFCA5A5)),
                        const SizedBox(width: 6),
                        _buildMicroBadge(text: '🌿 ${info.badge2}', textColor: const Color(0xFF86EFAC)),
                        const SizedBox(width: 6),
                        _buildMicroBadge(text: '🛡️ ${info.badge3}', textColor: const Color(0xFFFDE047)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Calorie Pill & Chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221A10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: goldAmber.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Text(
                    calories,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Kahvaltı Menüsü Bölümü ──
  Widget _buildBreakfastSection(DailyMenu menu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Staples Header Banner (Tereyağı & Çay/Ekmek)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E192B), Color(0xFF141926)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🌅', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Açık Büfe Kahvaltı Servisi',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '≈ 650 kcal',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Her gün taze açık büfe: Doğal Tereyağı, Taze Demleme Çay ve Fırın Ekmeği sınırsız sunulmaktadır.',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.35),
              ),
            ],
          ),
        ),

        ...menu.breakfast.map((item) {
          final info = _getFoodDetails(item);
          return _buildGastronomiFoodCard(
            name: item,
            calories: '120-240 kcal',
            courseTag: 'Kahvaltı Lezzeti',
            info: info,
          );
        }),
      ],
    );
  }

  // ── 6. Salata & Meze Menüsü ──
  Widget _buildSaladSection(DailyMenu menu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2420), Color(0xFF0E1A24)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentEmerald.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🥗', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Salata, Meze & Zeytinyağlı Barı',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Her gün taze 4 çeşit açık büfe soğuk ikram',
                    style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2436),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.6), width: 0.8),
                ),
                child: Text(
                  'Taze Büfe',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
        ),

        ...menu.salad.map((item) {
          final info = _getFoodDetails(item);
          return _buildGastronomiFoodCard(
            name: item,
            calories: '80-160 kcal',
            courseTag: 'Soğuk Meze & Salata',
            info: info,
          );
        }),
      ],
    );
  }

  // ── 7. NutriShift™ AI Bölümü ──
  Widget _buildNutriShiftAiSection(DailyMenu menu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA78BFA), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NutriShift™ Akıllı Beslenme Analizi',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  'Ağır Sanayi Vardiyası Biyometrik Dengelemesi',
                  style: GoogleFonts.inter(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Besin Değeri Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroItem('KALORİ', '${menu.totalCalories} kcal', Icons.local_fire_department_rounded, goldAmber),
                  _buildMacroItem('PROTEİN', menu.totalProtein.isNotEmpty ? menu.totalProtein : '48g', Icons.fitness_center_rounded, accentEmerald),
                  _buildMacroItem('LİF', '14g', Icons.eco_rounded, const Color(0xFF38BDF8)),
                  _buildMacroItem('ENERJİ PUANI', '%92', Icons.bolt_rounded, const Color(0xFFA855F7)),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.85,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF38BDF8), Color(0xFF10B981)]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu menü, 8 saatlik çelikhane/liman saha eforunun ~%85 enerjisini karşılar.',
                style: GoogleFonts.inter(fontSize: 10.5, color: textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded, color: goldAmber, size: 16),
                  const SizedBox(width: 7),
                  Text(
                    'Vardiya Hekimi & AI Diyetisyen Tavsiyesi',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bugünkü tabildotta sunulan protein ve kompleks karbonhidrat dengesi, yüksek ısı ve ağır saha operasyonlarında kan şekerini stabil tutarak 8 saatlik vardiyada odaklanmayı maksimize eder.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 0.5)),
      ],
    );
  }

  // ── 8. Şefe Puan Ver & Değerlendirme Kartı ──
  Widget _buildChefRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.star_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugünkü Tabildotu Puanlayın',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        'Geri bildiriminiz mutfak ekibine doğrudan iletilir',
                        style: GoogleFonts.inter(fontSize: 10.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: goldAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$userRating / 5',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: goldAmber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isFilled = starIndex <= userRating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => userRating = starIndex);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Teşekkürler! Puanınız ($starIndex/5) kaydedildi.'),
                      backgroundColor: primaryRed,
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFilled ? goldAmber : Colors.white24,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── 9. Lüks Gastronomi Detay Modal Penceresi ──
  void _showFoodDetailSheet(String name, String calories, FoodInfo info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // 200px High Hero Dish Photo
              _buildFoodImage(
                info.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(18),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B1D12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: goldAmber, width: 1),
                    ),
                    child: Text(
                      calories,
                      style: GoogleFonts.inter(color: goldLight, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),
              Text(info.subtitle, style: GoogleFonts.inter(fontSize: 13, color: textMuted)),

              const SizedBox(height: 16),

              // Macro Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: darkBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildModalMacro('PROTEİN', info.badge1, const Color(0xFFFCA5A5)),
                    _buildModalMacro('BESİN LİFİ', info.badge2, const Color(0xFF86EFAC)),
                    _buildModalMacro('SAĞLIK ETKİSİ', info.badge3, const Color(0xFFFDE047)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDetailChip('🌾 %100 Doğal Malzemeler'),
                  _buildDetailChip('👨‍🍳 Günlük Taze Pişirim'),
                  _buildDetailChip('🛡️ Diyetisyen Onaylı'),
                  _buildDetailChip('🧂 Düşük Sodyum Standardı'),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Kapat', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalMacro(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMicroBadge({required String text, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder, width: 0.6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
