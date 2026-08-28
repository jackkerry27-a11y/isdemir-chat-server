class ShipData {
  final String kategori;
  final String gemiAdi;
  final String tarihStr;
  final String firmaUlke;
  final String yukCinsi;
  final String islem;
  final int miktar;
  final DateTime sortDate;

  const ShipData({
    required this.kategori,
    required this.gemiAdi,
    required this.tarihStr,
    required this.firmaUlke,
    required this.yukCinsi,
    required this.islem,
    required this.miktar,
    required this.sortDate,
  });

  static List<ShipData> getAllShips() {
    return [
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'NAVIOS KOYO', tarihStr: '07.08 (17:42)', firmaUlke: 'BHP/Avustralya', yukCinsi: 'Komur', islem: 'Tahliye', miktar: 169147, sortDate: DateTime(2026, 8, 7, 17, 42)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'NINA PETRAKIS', tarihStr: '09.08 (12:00)', firmaUlke: 'Peabody/Avustralya', yukCinsi: 'Komur', islem: 'Tahliye', miktar: 80671, sortDate: DateTime(2026, 8, 9, 12, 0)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'METIN IMAMOGLU', tarihStr: '14-15.08', firmaUlke: 'Erdemir', yukCinsi: 'Kok Tozu', islem: 'Tahliye', miktar: 4000, sortDate: DateTime(2026, 8, 14)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'TAHSIN KALKAVAN', tarihStr: '13.08', firmaUlke: 'Erdemir', yukCinsi: 'Kok Tozu', islem: 'Tahliye', miktar: 2850, sortDate: DateTime(2026, 8, 13)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'MEHMET IMAMOGLU', tarihStr: '17-18.08', firmaUlke: 'Erdemir', yukCinsi: 'Kok Tozu', islem: 'Tahliye', miktar: 6150, sortDate: DateTime(2026, 8, 17)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'TAMREY S', tarihStr: '08.08 / laycan 13-14.08', firmaUlke: 'Erdemir', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 20000, sortDate: DateTime(2026, 8, 8)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'TAMREY S', tarihStr: '08.08 / laycan 13-14.08', firmaUlke: 'Erdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 3800, sortDate: DateTime(2026, 8, 8)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'TAMREY S', tarihStr: '08.08 / laycan 13-14.08', firmaUlke: 'Erdemir', yukCinsi: 'Kuvarsit', islem: 'Yukleme', miktar: 6000, sortDate: DateTime(2026, 8, 8)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'FWN ANTARCTIC', tarihStr: '08.08 (12:05) / laycan 09-10.08', firmaUlke: 'Laminoirs/Fransa', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 9865, sortDate: DateTime(2026, 8, 8, 12, 5)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'MKK MADRID', tarihStr: '08.08 (09:45) / laycan 05-06.08', firmaUlke: 'Sideral BA/Birlesik Krallik', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 20000, sortDate: DateTime(2026, 8, 8, 9, 45)),
      ShipData(kategori: 'Rihtimdaki', gemiAdi: 'HACI MEHMET KAPTAN', tarihStr: '09.08 (01:40) / laycan 08-09.08', firmaUlke: 'Erdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 3170, sortDate: DateTime(2026, 8, 9, 1, 40)),
      ShipData(kategori: 'Demirdeki', gemiAdi: 'ANNA ROSE', tarihStr: 'laycan 12-13.08', firmaUlke: 'AV Metal/Ukrayna', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 5000, sortDate: DateTime(2026, 8, 12)),
      ShipData(kategori: 'Demirdeki', gemiAdi: 'NEW HARVE', tarihStr: 'Demirde (tarihsiz)', firmaUlke: 'Lemiore/Rusya', yukCinsi: 'Pelet', islem: 'Tahliye', miktar: 75187, sortDate: DateTime(2026, 1, 1)), // Yılın başı veriyoruz ki en üstte çıksın
      ShipData(kategori: 'Beklenen', gemiAdi: 'G1', tarihStr: '13-14.08', firmaUlke: 'G1', yukCinsi: 'HBI', islem: 'Tahliye', miktar: 22000, sortDate: DateTime(2026, 8, 13)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'G2', tarihStr: '17-18.08', firmaUlke: 'G2', yukCinsi: 'HBI', islem: 'Tahliye', miktar: 37500, sortDate: DateTime(2026, 8, 17)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'MINERAL AJISAI', tarihStr: '18.08', firmaUlke: 'Vale/Brezilya', yukCinsi: 'Cevher', islem: 'Tahliye', miktar: 169884, sortDate: DateTime(2026, 8, 18)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'GENCO VIGILANT', tarihStr: '18.08', firmaUlke: 'Milpa/Kolombiya', yukCinsi: 'Met. Kok', islem: 'Tahliye', miktar: 36300, sortDate: DateTime(2026, 8, 18)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'S SAMBA', tarihStr: '19.08', firmaUlke: 'Taqa/Rusya', yukCinsi: 'PCI Komur', islem: 'Tahliye', miktar: 80000, sortDate: DateTime(2026, 8, 19)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'SARE IMAMOGLU', tarihStr: 'laycan 12-13.08', firmaUlke: 'Isdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 4350, sortDate: DateTime(2026, 8, 12)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TAHSIN KALKAVAN', tarihStr: 'laycan ??.08', firmaUlke: 'Isdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 2900, sortDate: DateTime(2026, 8, 31)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'SEVGI IMAMOGLU', tarihStr: 'laycan 17-18.08', firmaUlke: 'Isdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 3150, sortDate: DateTime(2026, 8, 17)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TUGBERK IMAMOGLU', tarihStr: 'laycan 19-20.08', firmaUlke: 'Erdemir', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 4250, sortDate: DateTime(2026, 8, 19)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'MEHMET IMAMOGLU', tarihStr: 'laycan ??.08', firmaUlke: 'Isdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 6250, sortDate: DateTime(2026, 8, 31)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TAHSIN IMAMOGLU', tarihStr: 'laycan 19-20.08', firmaUlke: 'Isdemir', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 4250, sortDate: DateTime(2026, 8, 19)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'CHEMICAL EXPLORER', tarihStr: '17.08 (laycan)', firmaUlke: 'Koppers International', yukCinsi: 'Katran', islem: 'Yukleme', miktar: 11000, sortDate: DateTime(2026, 8, 17)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'YILDIZLAR 5', tarihStr: '11.08 / laycan 10-11.08', firmaUlke: 'OCF', yukCinsi: 'Curuf', islem: 'Yukleme', miktar: 5000, sortDate: DateTime(2026, 8, 11)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan ??.08', firmaUlke: 'VS Trading/Tunus', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 300, sortDate: DateTime(2026, 8, 31)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan ??.08', firmaUlke: 'VS Trading/Tunus', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 150, sortDate: DateTime(2026, 8, 31)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'BARBUR XIN HAI', tarihStr: '27.08', firmaUlke: 'LHG/Uruguay', yukCinsi: 'P.Cevher', islem: 'Tahliye', miktar: 75000, sortDate: DateTime(2026, 8, 27)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'IONIC SPIRIT', tarihStr: '26.08', firmaUlke: 'Milpa/Kolombiya', yukCinsi: 'Met. Kok', islem: 'Tahliye', miktar: 33000, sortDate: DateTime(2026, 8, 26)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 22-23.08', firmaUlke: 'VS Trading/Libya', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 10000, sortDate: DateTime(2026, 8, 22)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 24-25.08', firmaUlke: 'AV Metal/Ukrayna', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 4000, sortDate: DateTime(2026, 8, 24)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 26-27.08', firmaUlke: 'Cargill/Ispanya', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 5000, sortDate: DateTime(2026, 8, 26)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 28-29.08', firmaUlke: 'Cargill/Italya', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 5000, sortDate: DateTime(2026, 8, 28)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 29-30.08', firmaUlke: 'Stemcor/Birlesik Krallik', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 30000, sortDate: DateTime(2026, 8, 29)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 29-30.08', firmaUlke: 'OCF', yukCinsi: '-', islem: 'Yukleme', miktar: 40000, sortDate: DateTime(2026, 8, 29)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'ARIS T', tarihStr: '20-21.09', firmaUlke: 'Alpha/A.B.D', yukCinsi: 'Komur', islem: 'Tahliye', miktar: 80000, sortDate: DateTime(2026, 9, 20)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'ADELHEID BR', tarihStr: '20-22.09', firmaUlke: 'Berry Alloys/Hindistan', yukCinsi: 'Fer.Man+Siliko Man', islem: 'Tahliye', miktar: 7154, sortDate: DateTime(2026, 9, 20)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'VERITAS QUEEN', tarihStr: '18-19.09', firmaUlke: 'Vale/Brezilya', yukCinsi: 'Cevher', islem: 'Tahliye', miktar: 170000, sortDate: DateTime(2026, 9, 18)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'G3', tarihStr: '20-30.09', firmaUlke: 'G3', yukCinsi: '-', islem: 'Tahliye', miktar: 35000, sortDate: DateTime(2026, 9, 20)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'MARAN HORIZAN', tarihStr: '04-05.09', firmaUlke: 'Vale/Brezilya', yukCinsi: 'Cevher', islem: 'Tahliye', miktar: 170000, sortDate: DateTime(2026, 9, 4)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 03-04.09', firmaUlke: 'Erdemir', yukCinsi: 'Slab', islem: 'Yukleme', miktar: 30000, sortDate: DateTime(2026, 9, 3)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'AH STAR', tarihStr: '04-05.09', firmaUlke: 'Milpa/Kolombiya', yukCinsi: 'Met. Kok', islem: 'Tahliye', miktar: 33000, sortDate: DateTime(2026, 9, 4)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'MARCEL', tarihStr: '11-12.09', firmaUlke: 'Nisco/Endonezya', yukCinsi: 'Met. Kok', islem: 'Tahliye', miktar: 50000, sortDate: DateTime(2026, 9, 11)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'LUCY OLDENDORFF', tarihStr: '12.09', firmaUlke: 'Anglo/Avustralya', yukCinsi: 'Komur', islem: 'Tahliye', miktar: 170667, sortDate: DateTime(2026, 9, 12)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 02-03.09', firmaUlke: 'Salzgitter/Hollanda', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 4000, sortDate: DateTime(2026, 9, 2)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 02-03.09', firmaUlke: 'Cargill/Hollanda', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 5000, sortDate: DateTime(2026, 9, 2)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 02-03.09', firmaUlke: 'Duferco/Belcika', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 4000, sortDate: DateTime(2026, 9, 2)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 02-03.09', firmaUlke: 'Stemcor/Belcika', yukCinsi: 'P.Sac', islem: 'Yukleme', miktar: 1125, sortDate: DateTime(2026, 9, 2)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'TBN', tarihStr: 'laycan 05-06.09', firmaUlke: 'Comet Trading/Italya', yukCinsi: 'R.Sac', islem: 'Yukleme', miktar: 8000, sortDate: DateTime(2026, 9, 5)),
      ShipData(kategori: 'Beklenen', gemiAdi: 'GENCO LIBERTY', tarihStr: '07-08.10', firmaUlke: 'Vale/Brezilya', yukCinsi: 'Cevher', islem: 'Tahliye', miktar: 170000, sortDate: DateTime(2026, 10, 7)),
    ];
  }
}
