import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'services/notification_service.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const PiyasaApp());
}

class PiyasaApp extends StatefulWidget {
  const PiyasaApp({super.key});

  @override
  State<PiyasaApp> createState() => _PiyasaAppState();
}

class _PiyasaAppState extends State<PiyasaApp> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Piyasa - Ticaret & Borsa',
          debugShowCheckedModeBanner: false,
          themeMode: _controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          // === AÇIK RENK TEMA (Modern, Temiz, Şık) ===
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Yumuşak açık gri/buz beyazı
            primaryColor: const Color(0xFF0F766E), // Zümrüt yeşili
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F766E),
              secondary: Color(0xFFD97706),
              surface: Colors.white,
              background: Color(0xFFF1F5F9),
            ),
            fontFamily: 'Segoe UI',
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 1.5,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          // === KOYU RENK TEMA (Dark Mode) ===
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F131D),
            primaryColor: Colors.amberAccent,
            colorScheme: ColorScheme.dark(
              primary: Colors.amberAccent,
              secondary: Colors.greenAccent[400]!,
              surface: const Color(0xFF161C2C),
              background: const Color(0xFF0F131D),
            ),
            fontFamily: 'Segoe UI',
            cardTheme: CardThemeData(
              color: const Color(0xFF1B2234),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          home: HomeScreen(controller: _controller),
        );
      },
    );
  }
}
