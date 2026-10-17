import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'services/notification_service.dart';
import 'services/save_service.dart';
import 'services/firebase_service.dart';
import 'services/audit_log_service.dart';
import 'views/home_screen.dart';
import 'views/auth_screen.dart';
import 'views/game_loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init hatası: $e');
  }

  try {
    await FirebaseService().initialize();
  } catch (e) {
    debugPrint('FirebaseService init hatası: $e');
  }

  try {
    await AuditLogService().initialize();
  } catch (e) {
    debugPrint('AuditLogService init hatası: $e');
  }

  final controller = GameController();
  if (FirebaseService().isAuthenticated) {
    try {
      await controller.loadFromStorage(playerId: FirebaseService().playerId);
      await AuditLogService().initializeForPlayer(FirebaseService().playerId);
    } catch (e) {
      debugPrint('GameController loadFromStorage hatası: $e');
    }
  } else {
    try {
      final hasLocal = await SaveService().hasAnyLocalSave();
      if (hasLocal) {
        await controller.loadFromStorage();
      } else {
        controller.resetToNewGame();
      }
    } catch (e) {
      controller.resetToNewGame();
    }
  }

  runApp(PiyasaApp(controller: controller));
}

class PiyasaApp extends StatefulWidget {
  final GameController? controller;
  final bool? skipAuthForTesting;
  final bool? skipLoadingForTesting;

  const PiyasaApp({
    super.key,
    this.controller,
    this.skipAuthForTesting,
    this.skipLoadingForTesting,
  });

  @override
  State<PiyasaApp> createState() => _PiyasaAppState();
}

class _PiyasaAppState extends State<PiyasaApp> with WidgetsBindingObserver {
  late final GameController _controller;
  bool _createdInternally = false;
  late bool _isAuthenticated;
  bool _isLoadingGame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _createdInternally = true;
      _controller = GameController();
      if (FirebaseService().isAuthenticated) {
        _controller.loadFromStorage(playerId: FirebaseService().playerId);
      } else {
        SaveService().hasAnyLocalSave().then((hasLocal) {
          if (hasLocal) {
            _controller.loadFromStorage();
          } else {
            _controller.resetToNewGame();
          }
        });
      }
    }
    _isAuthenticated = widget.skipAuthForTesting ?? FirebaseService().isAuthenticated;
    NotificationService().setAppInForeground(true);
    if (_isAuthenticated) {
      FirebaseService().setPlayerOnlineStatus(isOnline: true);
      if (widget.skipLoadingForTesting != true) {
        _isLoadingGame = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().setAppInForeground(true);
      FirebaseService().setPlayerOnlineStatus(isOnline: true);
      _controller.resumeGameLoop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      NotificationService().setAppInForeground(false);
      FirebaseService().setPlayerOnlineStatus(isOnline: false);
      _controller.pauseGameLoop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().setAppInForeground(false);
    FirebaseService().setPlayerOnlineStatus(isOnline: false);
    _controller.saveState();
    if (_createdInternally) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.themeModeNotifier,
      builder: (context, isDarkTheme, _) {
        return MaterialApp(
          title: 'Piyasa - Ticaret & Borsa',
          debugShowCheckedModeBanner: false,
          themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
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
          home: _isLoadingGame
              ? GameLoadingScreen(
                  controller: _controller,
                  onLoaded: () {
                    setState(() {
                      _isLoadingGame = false;
                      _isAuthenticated = true;
                    });
                  },
                )
              : (_isAuthenticated
                  ? HomeScreen(
                      controller: _controller,
                      onLoggedOut: () {
                        _controller.resetToNewGame();
                        AuditLogService().clearInProcess();
                        setState(() {
                          _isAuthenticated = false;
                          _isLoadingGame = false;
                        });
                      },
                    )
                  : AuthScreen(
                      controller: _controller,
                      onAuthenticated: () {
                        if (widget.skipLoadingForTesting == true) {
                          final pid = FirebaseService().playerId;
                          _controller.loadFromStorage(playerId: pid);
                          AuditLogService().initializeForPlayer(pid);
                          setState(() {
                            _isAuthenticated = true;
                          });
                        } else {
                          setState(() {
                            _isLoadingGame = true;
                          });
                        }
                      },
                    )),
        );
      },
    );
  }
}
