enum ShiftType {
  sabah,
  gece,
  aksam,
  tatil,
}

enum VardiyaGunu {
  sali,
  carsamba,
  cumartesi,
}

class ShiftLogic {
  static ShiftType getShiftType(DateTime date, {VardiyaGunu vardiyaGunu = VardiyaGunu.sali}) {
    if (vardiyaGunu == VardiyaGunu.cumartesi) {
      // Cumartesi günleri her zaman hafta tatili
      if (date.weekday == DateTime.saturday) {
        return ShiftType.tatil;
      }

      DateTime target = DateTime(date.year, date.month, date.day);
      DateTime ref = DateTime(2026, 8, 30); // 30 Ağustos 2026 Pazar (Gece vardiyası referans haftası)
      int diffDays = target.difference(ref).inDays;
      int weekIndex = (diffDays / 7).floor();
      int cycle = (weekIndex % 3 + 3) % 3;

      if (cycle == 0) return ShiftType.gece;
      if (cycle == 1) return ShiftType.aksam;
      return ShiftType.sabah;
    } else if (vardiyaGunu == VardiyaGunu.sali) {
      // Salı günleri her zaman hafta tatili
      if (date.weekday == DateTime.tuesday) {
        return ShiftType.tatil;
      }

      DateTime target = DateTime(date.year, date.month, date.day);
      DateTime ref = DateTime(2026, 8, 5); // 5 Ağustos 2026 Çarşamba (Sabah vardiyası referans)
      int diffDays = target.difference(ref).inDays;
      int weekIndex = (diffDays / 7).floor();
      int cycle = (weekIndex % 3 + 3) % 3;

      if (cycle == 0) return ShiftType.sabah;
      if (cycle == 1) return ShiftType.gece;
      return ShiftType.aksam;
    } else {
      // Çarşamba günleri her zaman hafta tatili
      if (date.weekday == DateTime.wednesday) {
        return ShiftType.tatil;
      }

      DateTime target = DateTime(date.year, date.month, date.day);
      DateTime ref = DateTime(2026, 8, 6); // 6 Ağustos 2026 Perşembe (İlk Gece vardiyası referans)
      int diffDays = target.difference(ref).inDays;
      int weekIndex = (diffDays / 7).floor();
      int cycle = (weekIndex % 3 + 3) % 3;

      if (cycle == 0) return ShiftType.gece;
      if (cycle == 1) return ShiftType.aksam;
      return ShiftType.sabah;
    }
  }

  static String getShiftTime(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return "09:30 - 16:30";
      case ShiftType.gece:
        return "00:30 - 09:30";
      case ShiftType.aksam:
        return "16:30 - 24:30";
      case ShiftType.tatil:
        return "Hafta Tatili";
    }
  }

  static String getShiftName(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return "Gündüz Vardiyası";
      case ShiftType.gece:
        return "Gece Vardiyası";
      case ShiftType.aksam:
        return "Akşam Vardiyası";
      case ShiftType.tatil:
        return "İzin Günü";
    }
  }
}

class HolidayLogic {
  static String? getHolidayName(DateTime date) {
    // Sabit Resmi Bayramlar ve Tatiller
    if (date.month == 1 && date.day == 1) return "Yılbaşı";
    if (date.month == 4 && date.day == 23) return "Ulusal Egemenlik ve Çocuk Bayramı";
    if (date.month == 5 && date.day == 1) return "Emek ve Dayanışma Günü";
    if (date.month == 5 && date.day == 19) return "Atatürk'ü Anma, Gençlik ve Spor Bayramı";
    if (date.month == 7 && date.day == 15) return "Demokrasi ve Milli Birlik Günü";
    if (date.month == 8 && date.day == 30) return "Zafer Bayramı";
    if (date.month == 10 && date.day == 29) return "Cumhuriyet Bayramı";

    // Hareketli Dini Bayramlar (2026 Yılı Tahmini)
    if (date.year == 2026) {
      if (date.month == 3 && (date.day >= 20 && date.day <= 22)) return "Ramazan Bayramı";
      if (date.month == 5 && (date.day >= 27 && date.day <= 30)) return "Kurban Bayramı";
    }

    // Hareketli Dini Bayramlar (2027 Yılı Tahmini)
    if (date.year == 2027) {
      if (date.month == 3 && (date.day >= 9 && date.day <= 11)) return "Ramazan Bayramı";
      if (date.month == 5 && (date.day >= 16 && date.day <= 19)) return "Kurban Bayramı";
    }

    return null;
  }
}
