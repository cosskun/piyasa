import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'Piyasa - Ticaret & Borsa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: HomeScreen(controller: _controller),
    );
  }
}
