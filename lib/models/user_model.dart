import 'package:shared_preferences/shared_preferences.dart';

class JobDetails {
  final double baseSalary;
  final double normalMesaiRate;
  final double bayramMesaiRate;
  final double unpaidLeaveRate;

  const JobDetails(this.baseSalary, this.normalMesaiRate, this.bayramMesaiRate, this.unpaidLeaveRate);
}

class UserModel {
  String firstName;
  String lastName;
  String jobTitle;
  String? photoPath;
  bool isVip;
  bool telsizYetkisi;

  static const Map<String, JobDetails> jobRates = {
    'Liman İşçisi A': JobDetails(37500.0, 864.0, 2166.0, 1083.0),
    'Liman İşçisi B': JobDetails(37500.0, 866.0, 2166.0, 1000.0),
    'Liman İşçisi C': JobDetails(34250.0, 780.0, 1950.0, 1000.0),
    'Lashing Serdümen': JobDetails(40500.0, 946.0, 2366.0, 1183.0),
  };

  UserModel({
    required this.firstName,
    required this.lastName,
    required this.jobTitle,
    this.photoPath,
    this.isVip = false,
    this.telsizYetkisi = false,
  });

  JobDetails get currentJobDetails => jobRates[jobTitle] ?? jobRates['Liman İşçisi A']!;

  String get id => '${firstName}_$lastName'.trim().toLowerCase().replaceAll(' ', '_');
  String get fullName => '$firstName $lastName'.trim();

  // Load from SharedPreferences
  static Future<UserModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isRegistered = prefs.getBool('isRegistered') ?? false;
    if (!isRegistered) return null;

    return UserModel(
      firstName: prefs.getString('firstName') ?? '',
      lastName: prefs.getString('lastName') ?? '',
      jobTitle: prefs.getString('jobTitle') ?? 'Liman İşçisi A',
      photoPath: prefs.getString('photoPath'),
      isVip: prefs.getBool('isVip') ?? false,
      telsizYetkisi: prefs.getBool('telsizYetkisi') ?? false,
    );
  }

  // Save to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRegistered', true);
    await prefs.setString('firstName', firstName);
    await prefs.setString('lastName', lastName);
    await prefs.setString('jobTitle', jobTitle);
    await prefs.setBool('isVip', isVip);
    await prefs.setBool('telsizYetkisi', telsizYetkisi);
    if (photoPath != null) {
      await prefs.setString('photoPath', photoPath!);
    }
  }

  // Logout (Clear)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
