import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/telsiz_screen.dart';
import 'models/user_model.dart';
import 'utils/push_service.dart';
import 'widgets/tactical_radio_call_overlay.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // OneSignal Başlatma
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("74f25810-49aa-4dd1-938c-c30229368a63");
  OneSignal.Notifications.requestPermission(true);
  
  // Uygulama açıkken de üst bildirimlerin görünmesini sağla (Gemi bildirimleri yalnızca VIP'lere)
  OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
    final notif = event.notification;
    final title = notif.title ?? '';
    final body = notif.body ?? '';
    final data = notif.additionalData ?? {};

    final isGala = title.toUpperCase().contains('GALA') ||
        body.toUpperCase().contains('GALA') ||
        (data['ship']?.toString().toUpperCase().contains('GALA') ?? false);
    if (isGala) {
      event.preventDefault();
      return;
    }

    final isShipRelated = (data['type']?.toString().startsWith('ship') ?? false) ||
        data['ship'] != null ||
        data['shipName'] != null ||
        title.toLowerCase().contains('gemi') ||
        title.toLowerCase().contains('rıhtım') ||
        body.toLowerCase().contains('gemi') ||
        body.toLowerCase().contains('rıhtım');

    final isTelsizRelated = (data['type'] == 'telsiz_channel') ||
        title.toLowerCase().contains('telsiz') ||
        body.toLowerCase().contains('telsiz');

    if (isShipRelated || isTelsizRelated) {
      final prefs = await SharedPreferences.getInstance();
      final isVip = prefs.getBool('isVip') ?? false;
      if (!isVip) {
        event.preventDefault(); // VIP olmayanlara telsiz ve gemi bildirimi gösterilmez!
        return;
      }
    }

    if (isTelsizRelated) {
      final navContext = globalNavigatorKey.currentContext;
      if (navContext != null) {
        final ch = data['channel']?.toString() ?? '1';
        final inviter = data['inviterName']?.toString() ??
            (title.replaceAll(RegExp(r'\[.*?\]'), '').replaceAll('📻', '').trim().isNotEmpty
                ? title.replaceAll(RegExp(r'\[.*?\]'), '').replaceAll('📻', '').trim()
                : 'Taktik Personel');
        const channelNames = {
          '1': {'name': 'İSDEMİR SAHA', 'freq': '148.550 MHz'},
          '2': {'name': 'LİMAN GÜVENLİK', 'freq': '156.800 MHz'},
          '3': {'name': 'RIHTIM & VİNÇ', 'freq': '162.025 MHz'},
        };
        final chInfo = channelNames[ch] ?? {'name': 'KANAL $ch', 'freq': 'VHF FREKANS'};

        TacticalRadioCallOverlay.show(
          context: navContext,
          inviterName: inviter,
          channel: ch,
          channelName: chInfo['name']!,
          freq: chInfo['freq']!,
        );
      }
    }

    event.notification.display();
  });

  // Bildirime tıklandığında telsize doğrudan geçiş (Sadece VIP için)
  OneSignal.Notifications.addClickListener((event) async {
    final data = event.notification.additionalData;
    if (data != null && data['type'] == 'telsiz_channel') {
      final prefs = await SharedPreferences.getInstance();
      final isVip = prefs.getBool('isVip') ?? false;
      if (!isVip) return; // VIP olmayanlara geçiş yok

      final user = await UserModel.load();
      if (user != null && globalNavigatorKey.currentState != null) {
        final channel = data['channel']?.toString();
        globalNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => TelsizScreen(user: user, initialChannel: channel),
          ),
        );
      }
    }
  });

  final prefs = await SharedPreferences.getInstance();
  final cihazId = prefs.getString('cihaz_id');
  final isVip = prefs.getBool('isVip') ?? false;
  if (cihazId != null) {
    OneSignal.login(cihazId);
  }
  PushService.setVipTag(isVip);

  runApp(const MyStarterApp());
}

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class MyStarterApp extends StatelessWidget {
  const MyStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İsdemir OS',
      navigatorKey: globalNavigatorKey,
      scaffoldMessengerKey: globalMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4338CA)),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
      home: const SplashScreen(),
    );
  }
}
