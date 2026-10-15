import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'services/notification_service.dart';
import 'services/save_service.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  final controller = GameController();
  await SaveService().load(controller);
  runApp(PiyasaApp(controller: controller));
}

class PiyasaApp extends StatefulWidget {
  final GameController? controller;

  const PiyasaApp({super.key, this.controller});

  @override
  State<PiyasaApp> createState() => _PiyasaAppState();
}

class _PiyasaAppState extends State<PiyasaApp> with WidgetsBindingObserver {
  late final GameController _controller;
  bool _createdInternally = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _createdInternally = true;
      _controller = GameController();
      _controller.loadFromStorage();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _controller.saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.saveState();
    if (_createdInternally) {
      _controller.dispose();
    }
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
