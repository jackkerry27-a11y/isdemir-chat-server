import 'dart:io';

void main() {
  String kahvalti = '''31 Ağustos Pazartesi: Mercimek Çorba, Krem Peynir, Yeşil Zeytin, Bal, Menemen, Fırın Patates, Tereyağı, Meyve Suyu, Çay/Ekmek
1 Ağustos Cumartesi: Şehriye Çorba, Krem Peynir, Yeşil Zeytin, Fındık Ezmesi, H.Yumurta, Poğaça, Tereyağı, Meyve Suyu, Çay/Ekmek
2 Ağustos Pazar: Ezogelin Çorba, Kaşar Peynir, Siyah Zeytin, Tahin Pekmez, Omlet, Domates-Salatalık, Tereyağı, Süt, Çay/Ekmek
3 Ağustos Pazartesi: Yayla Çorba, Beyaz Peynir, Biberli Zeytin, Bal, H.Yumurta, Ispanaklı Kol Böreği, Tereyağı, Meyve Suyu, Çay/Ekmek
4 Ağustos Salı: Mercimek Çorba, Krem Peynir, Siyah Zeytin, Reçel, Sucuklu Yumurta, Karpuz, Tereyağı, Süt, Çay/Ekmek
5 Ağustos Çarşamba: Şehriye Çorba, Kaşar Peynir, Biberli Zeytin, Fındık Ezmesi, H.Yumurta, Biberli Ekmek, Tereyağı, Meyve Suyu, Çay/Ekmek
6 Ağustos Perşembe: Ezogelin Çorba, Beyaz Peynir, Siyah Zeytin, Tahin Pekmez, Omlet, Domates-Salatalık, Tereyağı, Süt, Çay/Ekmek
7 Ağustos Cuma: Domates Çorba, Krem Peynir, Yeşil Zeytin, Bal, H.Yumurta, Üzümlü Kek, Tereyağı, Meyve Suyu, Çay/Ekmek
8 Ağustos Cumartesi: Mercimek Çorba, Kaşar Peynir, Siyah Zeytin, Reçel, Menemen, Fırın Patates, Tereyağı, Süt, Çay/Ekmek
9 Ağustos Pazar: Şehriye Çorba, Beyaz Peynir, Biberli Zeytin, H.Yumurta, Zeytinli Açma, Tereyağı, Meyve Suyu, Çay/Ekmek
10 Ağustos Pazartesi: Ezogelin Çorba, Krem Peynir, Siyah Zeytin, Tahin Pekmez, Omlet, Domates-Salatalık, Tereyağı, Süt, Çay/Ekmek
11 Ağustos Salı: Yayla Çorba, Kaşar Peynir, Biberli Zeytin, Bal, H.Yumurta, Simit, Tereyağı, Meyve Suyu, Çay/Ekmek
12 Ağustos Çarşamba: Mercimek Çorba, Beyaz Peynir, Siyah Zeytin, Reçel, Menemen, Patates Kızartması, Tereyağı, Süt, Çay/Ekmek
13 Ağustos Perşembe: Ezogelin Çorba, Krem Peynir, Yeşil Zeytin, Fındık Ezmesi, H.Yumurta, Peynirli Kol Böreği, Tereyağı, Meyve Suyu, Çay/Ekmek
14 Ağustos Cuma: Şehriye Çorba, Kaşar Peynir, Siyah Zeytin, Tahin Pekmez, Omlet, Kavun, Tereyağı, Süt, Çay/Ekmek
15 Ağustos Cumartesi: Mercimek Çorba, Beyaz Peynir, Biberli Zeytin, Bal, H.Yumurta, Poğaça, Tereyağı, Meyve Suyu, Çay/Ekmek
16 Ağustos Pazar: Ezogelin Çorba, Krem Peynir, Siyah Zeytin, Reçel, Sucuklu Yumurta, Fırın Patates, Tereyağı, Süt, Çay/Ekmek
17 Ağustos Pazartesi: Yayla Çorba, Kaşar Peynir, Biberli Zeytin, Fındık Ezmesi, Omlet, Domates-Salatalık, Tereyağı, Meyve Suyu, Çay/Ekmek
18 Ağustos Salı: Mercimek Çorba, Beyaz Peynir, Siyah Zeytin, Tahin Pekmez, H.Yumurta, Havuçlu Kek, Tereyağı, Süt, Çay/Ekmek
19 Ağustos Çarşamba: Ezogelin Çorba, Krem Peynir, Yeşil Zeytin, Bal, Omlet, Karpuz, Tereyağı, Meyve Suyu, Çay/Ekmek
20 Ağustos Perşembe: Şehriye Çorba, Kaşar Peynir, Siyah Zeytin, Reçel, H.Yumurta, Pizza, Tereyağı, Süt, Çay/Ekmek
21 Ağustos Cuma: Mercimek Çorba, Beyaz Peynir, Biberli Zeytin, Fındık Ezmesi, Menemen, Fırın Patates, Tereyağı, Meyve Suyu, Çay/Ekmek
22 Ağustos Cumartesi: Domates Çorba, Krem Peynir, Siyah Zeytin, Tahin Pekmez, H.Yumurta, Peynirli Kol Böreği, Tereyağı, Süt, Çay/Ekmek
23 Ağustos Pazar: Ezogelin Çorba, Kaşar Peynir, Biberli Zeytin, Bal, Omlet, Domates-Salatalık, Tereyağı, Meyve Suyu, Çay/Ekmek
24 Ağustos Pazartesi: Şehriye Çorba, Beyaz Peynir, Siyah Zeytin, Reçel, Sucuklu Yumurta, Patates Kızartması, Tereyağı, Süt, Çay/Ekmek
25 Ağustos Salı: Mercimek Çorba, Krem Peynir, Yeşil Zeytin, Fındık Ezmesi, H.Yumurta, Zeytinli Açma, Tereyağı, Meyve Suyu, Çay/Ekmek
26 Ağustos Çarşamba: Ezogelin Çorba, Kaşar Peynir, Siyah Zeytin, Tahin Pekmez, Omlet, Domates-Salatalık, Tereyağı, Süt, Çay/Ekmek
27 Ağustos Perşembe: Domates Çorba, Beyaz Peynir, Biberli Zeytin, Bal, H.Yumurta, Biberli Ekmek, Tereyağı, Meyve Suyu, Çay/Ekmek
28 Ağustos Cuma: Şehriye Çorba, Krem Peynir, Siyah Zeytin, Reçel, Menemen, Karpuz, Tereyağı, Süt, Çay/Ekmek
29 Ağustos Cumartesi: Ezogelin Çorba, Kaşar Peynir, Biberli Zeytin, Fındık Ezmesi, H.Yumurta, Havuçlu Kek, Tereyağı, Meyve Suyu, Çay/Ekmek
30 Ağustos Pazar: Domates Çorba, Beyaz Peynir, Siyah Zeytin, Tahin Pekmez, H.Yumurta, Domates-Salatalık, Tereyağı, Süt, Çay/Ekmek''';

  String salata = '''31 Ağustos Pazartesi: Rus Salatası, Fırın Mücver, Soğan Söğüş, Turşu
1 Ağustos Cumartesi: Ayranaşı, Kısır, Aysberg, Marineli Beyaz Lahana
2 Ağustos Pazar: Cacık, Humus, Domates Söğüş, Havuç Rende
3 Ağustos Pazartesi: Mevsim Salata, Fırın Patates, Sumaklı Soğan, Turşu
4 Ağustos Salı: Yoğ.Makarna, Fırın Mücver, Biber Söğüş, Marineli Kırmızı Lahana
5 Ağustos Çarşamba: Mevsim Salata, Pancarlı Şehriye Salatası, Domates Söğüş, Salatalık Söğüş
6 Ağustos Perşembe: Çoban Salata, Yoğ.Patlıcan, Soğan Söğüş, Turşu
7 Ağustos Cuma: Mevsim Salata, Rus Salatası, Fırın Biber, Marineli Beyaz Lahana
8 Ağustos Cumartesi: Cacık, Kısır, Aysberg, Domates Söğüş
9 Ağustos Pazar: Mevsim Salata, Zy.Taze Fasulye, Fırın Soğan, Turşu
10 Ağustos Pazartesi: Pancar Turşusu, Yoğ.Kabak, Havuç Rende, Salatalık Söğüş
11 Ağustos Salı: Mevsim Salata, Ayranaşı, Domates Söğüş, Biber Söğüş
12 Ağustos Çarşamba: Çoban Salata, Havuç Tarator, Marineli Kırmızı Lahana, Turşu
13 Ağustos Perşembe: Domates Söğüş, Aysberg, Soğan Piyazı, Kornişon Turşu
14 Ağustos Cuma: Yoğ.Makarna, Kısır, Aysberg, Salatalık Söğüş
15 Ağustos Cumartesi: Mevsim Salata, Pembe Sultan, Biber Söğüş, Domates Söğüş
16 Ağustos Pazar: Ayranaşı, Humus, Havuç Rende, Turşu
17 Ağustos Pazartesi: Mevsim Salata, Rus Salatası, Domates Söğüş, Fırın Biber
18 Ağustos Salı: Fırın Mücver, Yoğ.Semizotu, Soğan Söğüş, Turşu
19 Ağustos Çarşamba: Mevsim Salata, Zy.Taze Fasulye, Marineli Beyaz Lahana, Salatalık Söğüş
20 Ağustos Perşembe: Cacık, Kısır, Aysberg, Biber Söğüş
21 Ağustos Cuma: Çoban Salata, Ayranaşı, Havuç Rende, Marineli Kırmızı Lahana
22 Ağustos Cumartesi: Yoğ.Makarna, Sebze Buketi, Soğan Söğüş, Turşu
23 Ağustos Pazar: Mevsim Salata, Yoğ.Kabak, Domates Söğüş, Salatalık Söğüş
24 Ağustos Pazartesi: Cacık, Humus, Biber Söğüş, Marineli Beyaz Lahana
25 Ağustos Salı: Mevsim Salata, Zy.Mantar, Sumaklı Soğan, Turşu
26 Ağustos Çarşamba: Pancar Turşusu, Zy.Ispanak, Domates Söğüş, Havuç Rende
27 Ağustos Perşembe: Mevsim Salata, Yoğ.Semizotu, Fırın Biber, Fırın Soğan
28 Ağustos Cuma: Yoğ.Makarna, Kısır, Aysberg, Turşu
29 Ağustos Cumartesi: Çoban Salata, Ayranaşı, Fırın Soğan, Marineli Kırmızı Lahana
30 Ağustos Pazar: Cacık, Mevsim Salata, Biber Söğüş, Domates Söğüş''';

  String ana = '''31 Ağustos Pazartesi (≈1.306): Ezogelin Çorba 268, Etli Nohut Yahni 389, Pirinç/Bulgur Pilavı 370, Dondurma 200, Yoğurt 81
1 Ağustos Cumartesi (≈1.514): Şehriye Çorba 246, Patates Musakka 468, Pirinç/Esmer Bulgur Pilavı 370, Browni 349, Yoğurt 81
2 Ağustos Pazar (≈1.403): Mercimek Çorba 275, Etli Biber Dolma 461, Barbunya Pilaki 363, Komposto 223, Yoğurt 81
3 Ağustos Pazartesi (≈1.383): Anadolu Çorba 269, Et Döner 432, Pirinç Pilavı 394, Dondurma 200, Ayran 88
4 Ağustos Salı (≈1.617): Ezogelin Çorba 268, Etli Taze Fasulye 374, Pirinç/Bulgur Pilavı 370, Yoğurt Tatlısı 524, Yoğurt 81
5 Ağustos Çarşamba (≈1.217): Yayla Çorba 234, Sebzeli Tavuk Kebabı 425, Pirinç/Soslu Bulgur Pilavı 370, Meyve 100, Ayran 88
6 Ağustos Perşembe (≈1.357): Mercimek Çorba 275, Etli Nohut Yahni 389, Pirinç/Esmer Bulgur Pilavı 370, Sütlaç 242, Yoğurt 81
7 Ağustos Cuma (≈1.245): Şehriye Çorba 246, Hasanpaşa Köfte 441, Pirinç/Bulgur Pilavı 370, Meyve 100, Ayran 88
8 Ağustos Cumartesi (≈1.681): Ezogelin Çorba 268, Etli Türlü 445, Pirinç/Bulgur Pilavı 370, Şam Tatlısı 517, Yoğurt 81
9 Ağustos Pazar (≈1.461): Mercimek Çorba 275, Yoğ.Orman Kebabı 386, Pirinç/Soslu Bulgur Pilavı 370, Supangle 349, Yoğurt 81
10 Ağustos Pazartesi (≈1.235): Şehriye Çorba 246, Çökertme Kebabı 431, Pirinç/Bulgur Pilavı 370, Meyve 100, Ayran 88
11 Ağustos Salı (≈1.277): Ezogelin Çorba 268, Piliç Fırın 451, Pirinç/Bulgur Pilavı 370, Meyve 100, Ayran 88
12 Ağustos Çarşamba (≈1.248): Yayla Çorba 234, Gemici Kuru Fasulye 363, Pirinç/Bulgur Pilavı 370, Dondurma 200, Yoğurt 81
13 Ağustos Perşembe (≈1.363): Mercimek Çorba 275, Hamburger 530, Patates Kızartması 312, Meyve 100, Ayran 88
14 Ağustos Cuma (≈1.603): Ezogelin Çorba 268, Etli Bezelye 342, Pirinç/Bulgur Pilavı 370, Baklava 542, Yoğurt 81
15 Ağustos Cumartesi (≈1.229): Şehriye Çorba 246, Çoban Kavurma 432, Pirinç/Soslu Bulgur Pilavı 370, Meyve 100, Yoğurt 81
16 Ağustos Pazar (≈1.485): Mercimek Çorba 275, Mitide Köfte 445, Pirinç/Bulgur Pilavı 370, Muhallebili Tel Kadayıf 314, Yoğurt 81
17 Ağustos Pazartesi (≈1.269): Ezogelin Çorba 268, Fırınağzı 443, Pirinç/Bulgur Pilavı 370, Meyve 100, Ayran 88
18 Ağustos Salı (≈1.511): Şehriye Çorba 246, Etli Nohut Yahni 389, Pirinç/Esmer Bulgur Pilavı 370, Kıbrıs Tatlısı 425, Ayran 88
19 Ağustos Çarşamba (≈1.321): Mercimek Çorba 275, Piliç Izgara 388, Pirinç/Soslu Bulgur Pilavı 370, Dondurma 200, Ayran 88
20 Ağustos Perşembe (≈1.507): Ezogelin Çorba 268, Patlıcan Musakka 412, Pirinç/Bulgur Pilavı 370, Aşure 376, Yoğurt 81
21 Ağustos Cuma (≈1.247): Yayla Çorba 234, Kasap Köfte 455, Pirinç/Soslu Bulgur Pilavı 370, Meyve 100, Ayran 81
22 Ağustos Cumartesi (≈1.402): Şehriye Çorba 246, Etli Kuru Fasulye 389, Pirinç/Bulgur Pilavı 370, Tiramisu 316, Yoğurt 81
23 Ağustos Pazar (≈1.284): Mercimek Çorba 275, Piliç Baget 451, Pirinç/Bulgur Pilavı 370, Meyve 100, Yoğurt 88
24 Ağustos Pazartesi (≈1.373): Ezogelin Çorba 268, Patlıcan Güveç 412, Nohutlu Pirinç/Nohutlu Bulgur Pilavı 370, Sütlaç 242, Yoğurt 81
25 Ağustos Salı (≈1.283): Tutmaç Çorbası 269, Et Döner 432, Pirinç Pilavı 394, Meyve 100, Ayran 88
26 Ağustos Çarşamba (≈1.440): Şehriye Çorba 246, Terbiyeli Köfte 416, Pirinç/Soslu Bulgur Pilavı 370, Mozaik Pasta 327, Yoğurt 81
27 Ağustos Perşembe: Ezogelin Çorba 268, Piliç Izgara 388, Pirinç/Esmer Bulgur Pilavı 370, Meyve 100, Ayran 81
28 Ağustos Cuma (≈1.548): Mercimek Çorba 275, Etli Patates 450, Pirinç/Bulgur Pilavı 370, Turunç Tatlısı 372, Yoğurt 81
29 Ağustos Cumartesi (≈1.247): Yayla Çorba 234, Kayseri Köfte 455, Pirinç/Bulgur Pilavı 370, Meyve 100, Ayran 88
30 Ağustos Pazar (≈1.672): Şehriye Çorba 246, Karnıyarık 451, Pirinç/Bulgur Pilavı 370, Yoğurt Tatlısı 524, Yoğurt 81''';

  Map<int, Map<String, dynamic>> days = {};

  void process(String text, String keyType) {
    text = text.replaceAll('\r', '');
    var lines = text.split('\n');
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      var parts = line.split(':');
      if (parts.length < 2) continue;
      var dayStr = parts[0].trim();
      var dayNum = int.parse(dayStr.split(' ')[0]);
      var items = parts[1].split(',').map((e) => e.trim()).toList();
      
      days.putIfAbsent(dayNum, () => {});
      days[dayNum]!['dateText'] = dayStr;
      
      if (keyType == 'breakfast' || keyType == 'salad') {
        List<String> listItems = [];
        for(var item in items) {
          listItems.add("'" + item + "'");
        }
        days[dayNum]![keyType] = listItems;
      } else if (keyType == 'main') {
        String totalCal = '';
        if (dayStr.contains('(')) {
          totalCal = dayStr.split('(')[1].split(')')[0].replaceAll('≈', '').trim();
          days[dayNum]!['dateText'] = dayStr.split('(')[0].trim();
        }
        days[dayNum]!['totalCal'] = totalCal;
        
        List<String> mainCourse = [];
        for (var raw in items) {
          raw = raw.trim();
          var parts2 = raw.split(' ');
          if (parts2.length > 1 && int.tryParse(parts2.last) != null) {
            var cal = parts2.last;
            var name = parts2.sublist(0, parts2.length - 1).join(' ');
            mainCourse.add("MealItem('" + name + "', '" + cal + "')");
          } else {
            mainCourse.add("MealItem('" + raw + "', '')");
          }
        }
        days[dayNum]!['mainCourse'] = mainCourse;
      }
    }
  }

  process(kahvalti, 'breakfast');
  process(salata, 'salad');
  process(ana, 'main');

  File outputFile = File('lib/models/menu_data.dart');
  var out = StringBuffer();
  out.writeln("class MealItem {");
  out.writeln("  final String name;");
  out.writeln("  final String calories;");
  out.writeln("  const MealItem(this.name, [this.calories = '']);");
  out.writeln("}");
  out.writeln("");
  out.writeln("class DailyMenu {");
  out.writeln("  final String dateText;");
  out.writeln("  final List<String> breakfast;");
  out.writeln("  final List<String> salad;");
  out.writeln("  final List<MealItem> mainCourse;");
  out.writeln("  final String totalCalories;");
  out.writeln("  const DailyMenu({required this.dateText, required this.breakfast, required this.salad, required this.mainCourse, required this.totalCalories});");
  out.writeln("}");
  out.writeln("");
  out.writeln("class MenuData {");
  out.writeln("  static const Map<int, DailyMenu> augustMenu = {");
  
  for (int i = 1; i <= 31; i++) {
    if (!days.containsKey(i)) continue;
    var d = days[i]!;
    out.writeln("    " + i.toString() + ": DailyMenu(");
    out.writeln("      dateText: '" + d['dateText'] + "',");
    out.writeln("      breakfast: const [" + (d['breakfast'] as List).join(', ') + "],");
    out.writeln("      salad: const [" + (d['salad'] as List).join(', ') + "],");
    out.writeln("      totalCalories: '" + d['totalCal'] + "',");
    out.writeln("      mainCourse: const [" + (d['mainCourse'] as List).join(', ') + "],");
    out.writeln("    ),");
  }
  
  out.writeln("  };");
  out.writeln("}");
  
  outputFile.writeAsStringSync(out.toString());
  print("menu_data.dart generated successfully with NO string interpolations!");
}
