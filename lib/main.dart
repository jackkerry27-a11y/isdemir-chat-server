import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';

import 'screens/splash_screen.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Supabase URL bilginizi buraya girin (Örn: https://xyz.supabase.co)
  const supabaseUrl = 'https://ivgqfrokdyknchcgteuj.supabase.co';
  const supabaseKey = 'sb_publishable_0wieB0QJcdIR8uccjoLP4w_hR1vaETl';

  if (supabaseUrl != 'YOUR_SUPABASE_URL') {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  // OneSignal Başlatma
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("74f25810-49aa-4dd1-938c-c30229368a63");
  OneSignal.Notifications.requestPermission(true);
  // Uygulama açıkken de üst bildirimlerin görünmesini sağla
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    event.notification.display();
  });

  runApp(const MyStarterApp());
}

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyStarterApp extends StatelessWidget {
  const MyStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İsdemir OS',
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
