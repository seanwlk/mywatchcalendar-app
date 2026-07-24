import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/widget_updater.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _initialized = false;
  bool _signedIn = false;
  String _username = '';
  String? _siteUrl;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await AuthService.instance.init();
    await SettingsService.instance.init();

    setState(() {
      _initialized = true;
      _signedIn = AuthService.instance.isSignedIn;
      _username = AuthService.instance.username ?? '';
      _siteUrl = AuthService.instance.siteUrl;
    });

    if (_signedIn) {
      final ok = await AuthService.instance.ensureAccessToken();
      if (!ok && mounted) {
        setState(() {
          _signedIn = false;
          _siteUrl = AuthService.instance.siteUrl;
        });
      }
    }

    await WidgetUpdater.initialize(
      intervalMinutes: SettingsService.instance.widgetIntervalMinutes,
    );
  }

  Future<void> _onLogin(
    String username,
    String password,
    String siteUrl,
  ) async {
    final success = await AuthService.instance.login(
      siteUrl,
      username,
      password,
    );
    if (!success) {
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
      return;
    }
    setState(() {
      _signedIn = true;
      _username = username;
      _siteUrl = siteUrl;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.logout(clearSiteUrl: false);
    setState(() {
      _signedIn = false;
      _username = '';
      _siteUrl = AuthService.instance.siteUrl;
    });
  }

  ThemeData _buildTheme(BuildContext context, AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.amoledRed:
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        );
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.black,
            indicatorColor: Colors.redAccent.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      case AppThemeChoice.amoledBlue:
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.dark,
        );
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.black,
            indicatorColor: Colors.lightBlueAccent.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      case AppThemeChoice.whiteRed:
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        );
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme.copyWith(
            surface: Colors.white,
            primary: Colors.red,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Colors.red.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.black, fontSize: 12),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: Colors.black26,
          ),
        );
      case AppThemeChoice.whiteBlue:
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        );
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme.copyWith(
            surface: Colors.white,
            primary: Colors.lightBlue,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Colors.lightBlue.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.black, fontSize: 12),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: Colors.black26,
          ),
        );
      case AppThemeChoice.materialYou:
        final isSystemDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;

        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: isSystemDark ? Brightness.dark : Brightness.light,
        );
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface,
            elevation: 0,
          ),
          scaffoldBackgroundColor: scheme.surface,
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primaryContainer,
            labelTextStyle: WidgetStateProperty.all(
              TextStyle(color: scheme.onSurface, fontSize: 12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeChoice>(
      valueListenable: SettingsService.instance.themeChoice,
      builder: (context, choice, _) {
        final currentTheme = _buildTheme(context, choice);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MyWatchCalendar',
          theme: currentTheme,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          builder: (context, child) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final responsiveMaxWidth = (screenWidth * 0.45).clamp(
              600.0,
              1200.0,
            );
            return Container(
              color: currentTheme.scaffoldBackgroundColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: responsiveMaxWidth),
                  child: ClipRect(child: child ?? const SizedBox.shrink()),
                ),
              ),
            );
          },
          home: _initialized
              ? (_signedIn
                    ? HomeScreen(username: _username, onLogout: _handleLogout)
                    : LoginScreen(onLogin: _onLogin, initialSiteUrl: _siteUrl))
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}
