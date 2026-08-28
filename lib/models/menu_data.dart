class MealItem {
  final String name;
  final String calories;
  const MealItem(this.name, [this.calories = '']);
}

class DailyMenu {
  final String dateText;
  final List<String> breakfast;
  final List<String> salad;
  final List<MealItem> mainCourse;
  final String totalCalories;
  const DailyMenu({required this.dateText, required this.breakfast, required this.salad, required this.mainCourse, required this.totalCalories});
}

class MenuData {
  static const Map<int, DailyMenu> augustMenu = {
    1: DailyMenu(
      dateText: '1 Ağustos Cumartesi',
      breakfast: const ['Şehriye Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Fındık Ezmesi', 'H.Yumurta', 'Poğaça', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Ayranaşı', 'Kısır', 'Aysberg', 'Marineli Beyaz Lahana'],
      totalCalories: '1.514',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Patates Musakka', '468'), MealItem('Pirinç/Esmer Bulgur Pilavı', '370'), MealItem('Browni', '349'), MealItem('Yoğurt', '81')],
    ),
    2: DailyMenu(
      dateText: '2 Ağustos Pazar',
      breakfast: const ['Ezogelin Çorba', 'Kaşar Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Cacık', 'Humus', 'Domates Söğüş', 'Havuç Rende'],
      totalCalories: '1.403',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Etli Biber Dolma', '461'), MealItem('Barbunya Pilaki', '363'), MealItem('Komposto', '223'), MealItem('Yoğurt', '81')],
    ),
    3: DailyMenu(
      dateText: '3 Ağustos Pazartesi',
      breakfast: const ['Yayla Çorba', 'Beyaz Peynir', 'Biberli Zeytin', 'Bal', 'H.Yumurta', 'Ispanaklı Kol Böreği', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Fırın Patates', 'Sumaklı Soğan', 'Turşu'],
      totalCalories: '1.383',
      mainCourse: const [MealItem('Anadolu Çorba', '269'), MealItem('Et Döner', '432'), MealItem('Pirinç Pilavı', '394'), MealItem('Dondurma', '200'), MealItem('Ayran', '88')],
    ),
    4: DailyMenu(
      dateText: '4 Ağustos Salı',
      breakfast: const ['Mercimek Çorba', 'Krem Peynir', 'Siyah Zeytin', 'Reçel', 'Sucuklu Yumurta', 'Karpuz', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Yoğ.Makarna', 'Fırın Mücver', 'Biber Söğüş', 'Marineli Kırmızı Lahana'],
      totalCalories: '1.617',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Etli Taze Fasulye', '374'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Yoğurt Tatlısı', '524'), MealItem('Yoğurt', '81')],
    ),
    5: DailyMenu(
      dateText: '5 Ağustos Çarşamba',
      breakfast: const ['Şehriye Çorba', 'Kaşar Peynir', 'Biberli Zeytin', 'Fındık Ezmesi', 'H.Yumurta', 'Biberli Ekmek', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Pancarlı Şehriye Salatası', 'Domates Söğüş', 'Salatalık Söğüş'],
      totalCalories: '1.217',
      mainCourse: const [MealItem('Yayla Çorba', '234'), MealItem('Sebzeli Tavuk Kebabı', '425'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    6: DailyMenu(
      dateText: '6 Ağustos Perşembe',
      breakfast: const ['Ezogelin Çorba', 'Beyaz Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Çoban Salata', 'Yoğ.Patlıcan', 'Soğan Söğüş', 'Turşu'],
      totalCalories: '1.357',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Etli Nohut Yahni', '389'), MealItem('Pirinç/Esmer Bulgur Pilavı', '370'), MealItem('Sütlaç', '242'), MealItem('Yoğurt', '81')],
    ),
    7: DailyMenu(
      dateText: '7 Ağustos Cuma',
      breakfast: const ['Domates Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Bal', 'H.Yumurta', 'Üzümlü Kek', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Rus Salatası', 'Fırın Biber', 'Marineli Beyaz Lahana'],
      totalCalories: '1.245',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Hasanpaşa Köfte', '441'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    8: DailyMenu(
      dateText: '8 Ağustos Cumartesi',
      breakfast: const ['Mercimek Çorba', 'Kaşar Peynir', 'Siyah Zeytin', 'Reçel', 'Menemen', 'Fırın Patates', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Cacık', 'Kısır', 'Aysberg', 'Domates Söğüş'],
      totalCalories: '1.681',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Etli Türlü', '445'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Şam Tatlısı', '517'), MealItem('Yoğurt', '81')],
    ),
    9: DailyMenu(
      dateText: '9 Ağustos Pazar',
      breakfast: const ['Şehriye Çorba', 'Beyaz Peynir', 'Biberli Zeytin', 'H.Yumurta', 'Zeytinli Açma', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Zy.Taze Fasulye', 'Fırın Soğan', 'Turşu'],
      totalCalories: '1.461',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Yoğ.Orman Kebabı', '386'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Supangle', '349'), MealItem('Yoğurt', '81')],
    ),
    10: DailyMenu(
      dateText: '10 Ağustos Pazartesi',
      breakfast: const ['Ezogelin Çorba', 'Krem Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Pancar Turşusu', 'Yoğ.Kabak', 'Havuç Rende', 'Salatalık Söğüş'],
      totalCalories: '1.235',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Çökertme Kebabı', '431'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    11: DailyMenu(
      dateText: '11 Ağustos Salı',
      breakfast: const ['Yayla Çorba', 'Kaşar Peynir', 'Biberli Zeytin', 'Bal', 'H.Yumurta', 'Simit', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Ayranaşı', 'Domates Söğüş', 'Biber Söğüş'],
      totalCalories: '1.277',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Piliç Fırın', '451'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    12: DailyMenu(
      dateText: '12 Ağustos Çarşamba',
      breakfast: const ['Mercimek Çorba', 'Beyaz Peynir', 'Siyah Zeytin', 'Reçel', 'Menemen', 'Patates Kızartması', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Çoban Salata', 'Havuç Tarator', 'Marineli Kırmızı Lahana', 'Turşu'],
      totalCalories: '1.248',
      mainCourse: const [MealItem('Yayla Çorba', '234'), MealItem('Gemici Kuru Fasulye', '363'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Dondurma', '200'), MealItem('Yoğurt', '81')],
    ),
    13: DailyMenu(
      dateText: '13 Ağustos Perşembe',
      breakfast: const ['Ezogelin Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Fındık Ezmesi', 'H.Yumurta', 'Peynirli Kol Böreği', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Domates Söğüş', 'Aysberg', 'Soğan Piyazı', 'Kornişon Turşu'],
      totalCalories: '1.363',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Hamburger', '530'), MealItem('Patates Kızartması', '312'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    14: DailyMenu(
      dateText: '14 Ağustos Cuma',
      breakfast: const ['Şehriye Çorba', 'Kaşar Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'Omlet', 'Kavun', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Yoğ.Makarna', 'Kısır', 'Aysberg', 'Salatalık Söğüş'],
      totalCalories: '1.603',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Etli Bezelye', '342'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Baklava', '542'), MealItem('Yoğurt', '81')],
    ),
    15: DailyMenu(
      dateText: '15 Ağustos Cumartesi',
      breakfast: const ['Mercimek Çorba', 'Beyaz Peynir', 'Biberli Zeytin', 'Bal', 'H.Yumurta', 'Poğaça', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Pembe Sultan', 'Biber Söğüş', 'Domates Söğüş'],
      totalCalories: '1.229',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Çoban Kavurma', '432'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Yoğurt', '81')],
    ),
    16: DailyMenu(
      dateText: '16 Ağustos Pazar',
      breakfast: const ['Ezogelin Çorba', 'Krem Peynir', 'Siyah Zeytin', 'Reçel', 'Sucuklu Yumurta', 'Fırın Patates', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Ayranaşı', 'Humus', 'Havuç Rende', 'Turşu'],
      totalCalories: '1.485',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Mitide Köfte', '445'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Muhallebili Tel Kadayıf', '314'), MealItem('Yoğurt', '81')],
    ),
    17: DailyMenu(
      dateText: '17 Ağustos Pazartesi',
      breakfast: const ['Yayla Çorba', 'Kaşar Peynir', 'Biberli Zeytin', 'Fındık Ezmesi', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Rus Salatası', 'Domates Söğüş', 'Fırın Biber'],
      totalCalories: '1.269',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Fırınağzı', '443'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    18: DailyMenu(
      dateText: '18 Ağustos Salı',
      breakfast: const ['Mercimek Çorba', 'Beyaz Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'H.Yumurta', 'Havuçlu Kek', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Fırın Mücver', 'Yoğ.Semizotu', 'Soğan Söğüş', 'Turşu'],
      totalCalories: '1.511',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Etli Nohut Yahni', '389'), MealItem('Pirinç/Esmer Bulgur Pilavı', '370'), MealItem('Kıbrıs Tatlısı', '425'), MealItem('Ayran', '88')],
    ),
    19: DailyMenu(
      dateText: '19 Ağustos Çarşamba',
      breakfast: const ['Ezogelin Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Bal', 'Omlet', 'Karpuz', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Zy.Taze Fasulye', 'Marineli Beyaz Lahana', 'Salatalık Söğüş'],
      totalCalories: '1.321',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Piliç Izgara', '388'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Dondurma', '200'), MealItem('Ayran', '88')],
    ),
    20: DailyMenu(
      dateText: '20 Ağustos Perşembe',
      breakfast: const ['Şehriye Çorba', 'Kaşar Peynir', 'Siyah Zeytin', 'Reçel', 'H.Yumurta', 'Pizza', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Cacık', 'Kısır', 'Aysberg', 'Biber Söğüş'],
      totalCalories: '1.507',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Patlıcan Musakka', '412'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Aşure', '376'), MealItem('Yoğurt', '81')],
    ),
    21: DailyMenu(
      dateText: '21 Ağustos Cuma',
      breakfast: const ['Mercimek Çorba', 'Beyaz Peynir', 'Biberli Zeytin', 'Fındık Ezmesi', 'Menemen', 'Fırın Patates', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Çoban Salata', 'Ayranaşı', 'Havuç Rende', 'Marineli Kırmızı Lahana'],
      totalCalories: '1.247',
      mainCourse: const [MealItem('Yayla Çorba', '234'), MealItem('Kasap Köfte', '455'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '81')],
    ),
    22: DailyMenu(
      dateText: '22 Ağustos Cumartesi',
      breakfast: const ['Domates Çorba', 'Krem Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'H.Yumurta', 'Peynirli Kol Böreği', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Yoğ.Makarna', 'Sebze Buketi', 'Soğan Söğüş', 'Turşu'],
      totalCalories: '1.402',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Etli Kuru Fasulye', '389'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Tiramisu', '316'), MealItem('Yoğurt', '81')],
    ),
    23: DailyMenu(
      dateText: '23 Ağustos Pazar',
      breakfast: const ['Ezogelin Çorba', 'Kaşar Peynir', 'Biberli Zeytin', 'Bal', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Yoğ.Kabak', 'Domates Söğüş', 'Salatalık Söğüş'],
      totalCalories: '1.284',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Piliç Baget', '451'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Yoğurt', '88')],
    ),
    24: DailyMenu(
      dateText: '24 Ağustos Pazartesi',
      breakfast: const ['Şehriye Çorba', 'Beyaz Peynir', 'Siyah Zeytin', 'Reçel', 'Sucuklu Yumurta', 'Patates Kızartması', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Cacık', 'Humus', 'Biber Söğüş', 'Marineli Beyaz Lahana'],
      totalCalories: '1.373',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Patlıcan Güveç', '412'), MealItem('Nohutlu Pirinç/Nohutlu Bulgur Pilavı', '370'), MealItem('Sütlaç', '242'), MealItem('Yoğurt', '81')],
    ),
    25: DailyMenu(
      dateText: '25 Ağustos Salı',
      breakfast: const ['Mercimek Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Fındık Ezmesi', 'H.Yumurta', 'Zeytinli Açma', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Zy.Mantar', 'Sumaklı Soğan', 'Turşu'],
      totalCalories: '1.283',
      mainCourse: const [MealItem('Tutmaç Çorbası', '269'), MealItem('Et Döner', '432'), MealItem('Pirinç Pilavı', '394'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    26: DailyMenu(
      dateText: '26 Ağustos Çarşamba',
      breakfast: const ['Ezogelin Çorba', 'Kaşar Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'Omlet', 'Domates-Salatalık', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Pancar Turşusu', 'Zy.Ispanak', 'Domates Söğüş', 'Havuç Rende'],
      totalCalories: '1.440',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Terbiyeli Köfte', '416'), MealItem('Pirinç/Soslu Bulgur Pilavı', '370'), MealItem('Mozaik Pasta', '327'), MealItem('Yoğurt', '81')],
    ),
    27: DailyMenu(
      dateText: '27 Ağustos Perşembe',
      breakfast: const ['Domates Çorba', 'Beyaz Peynir', 'Biberli Zeytin', 'Bal', 'H.Yumurta', 'Biberli Ekmek', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Mevsim Salata', 'Yoğ.Semizotu', 'Fırın Biber', 'Fırın Soğan'],
      totalCalories: '',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Piliç Izgara', '388'), MealItem('Pirinç/Esmer Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '81')],
    ),
    28: DailyMenu(
      dateText: '28 Ağustos Cuma',
      breakfast: const ['Şehriye Çorba', 'Krem Peynir', 'Siyah Zeytin', 'Reçel', 'Menemen', 'Karpuz', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Yoğ.Makarna', 'Kısır', 'Aysberg', 'Turşu'],
      totalCalories: '1.548',
      mainCourse: const [MealItem('Mercimek Çorba', '275'), MealItem('Etli Patates', '450'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Turunç Tatlısı', '372'), MealItem('Yoğurt', '81')],
    ),
    29: DailyMenu(
      dateText: '29 Ağustos Cumartesi',
      breakfast: const ['Ezogelin Çorba', 'Kaşar Peynir', 'Biberli Zeytin', 'Fındık Ezmesi', 'H.Yumurta', 'Havuçlu Kek', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Çoban Salata', 'Ayranaşı', 'Fırın Soğan', 'Marineli Kırmızı Lahana'],
      totalCalories: '1.247',
      mainCourse: const [MealItem('Yayla Çorba', '234'), MealItem('Kayseri Köfte', '455'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Meyve', '100'), MealItem('Ayran', '88')],
    ),
    30: DailyMenu(
      dateText: '30 Ağustos Pazar',
      breakfast: const ['Domates Çorba', 'Beyaz Peynir', 'Siyah Zeytin', 'Tahin Pekmez', 'H.Yumurta', 'Domates-Salatalık', 'Tereyağı', 'Süt', 'Çay/Ekmek'],
      salad: const ['Cacık', 'Mevsim Salata', 'Biber Söğüş', 'Domates Söğüş'],
      totalCalories: '1.672',
      mainCourse: const [MealItem('Şehriye Çorba', '246'), MealItem('Karnıyarık', '451'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Yoğurt Tatlısı', '524'), MealItem('Yoğurt', '81')],
    ),
    31: DailyMenu(
      dateText: '31 Ağustos Pazartesi',
      breakfast: const ['Mercimek Çorba', 'Krem Peynir', 'Yeşil Zeytin', 'Bal', 'Menemen', 'Fırın Patates', 'Tereyağı', 'Meyve Suyu', 'Çay/Ekmek'],
      salad: const ['Rus Salatası', 'Fırın Mücver', 'Soğan Söğüş', 'Turşu'],
      totalCalories: '1.306',
      mainCourse: const [MealItem('Ezogelin Çorba', '268'), MealItem('Etli Nohut Yahni', '389'), MealItem('Pirinç/Bulgur Pilavı', '370'), MealItem('Dondurma', '200'), MealItem('Yoğurt', '81')],
    ),
  };
}
