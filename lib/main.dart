import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/episode_info_screen.dart';

import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/widget_updater.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;
  bool _signedIn = false;
  Uri? _pendingWidgetUri;

  @override
  void initState() {
    super.initState();
    _initializeAuth();

    if (!kIsWeb) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      HomeWidget.widgetClicked.listen(_handleWidgetUri);
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.scheme != 'mywatch' || uri.host != 'episode') return;

    if (!_initialized || !_signedIn) {
      _pendingWidgetUri = uri;
      return;
    }

    _navigateToEpisode(uri);
  }

  void _navigateToEpisode(Uri uri) {
    final seriesId = uri.queryParameters['seriesId'];
    final episodeId = uri.queryParameters['episodeId'];

    if (seriesId != null && episodeId != null) {
      _pendingWidgetUri = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => EpisodeInfoScreen(
              seriesId: seriesId,
              episodeId: episodeId,
            ),
          ),
        );
      });
    }
  }

  Future<void> _initializeAuth() async {
    await AuthService.instance.init();
    await SettingsService.instance.init();

    bool signedIn = AuthService.instance.isSignedIn;

    if (signedIn) {
      final ok = await AuthService.instance.ensureAccessToken();
      if (!ok && mounted) {
        signedIn = false;
      }
    }

    setState(() {
      _initialized = true;
      _signedIn = signedIn;
    });

    await WidgetUpdater.initialize(
      intervalMinutes: SettingsService.instance.widgetIntervalMinutes,
    );

    if (_signedIn && _pendingWidgetUri != null) {
      _navigateToEpisode(_pendingWidgetUri!);
    }
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
    });

    if (_pendingWidgetUri != null) {
      _navigateToEpisode(_pendingWidgetUri!);
    }
  }

  Future<void> _onRegister(
    String username,
    String password,
    String siteUrl,
  ) async {
    final errorMessage = await AuthService.instance.register(
      siteUrl,
      username,
      password,
    );

    if (errorMessage != null) {
      if (!mounted) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() {
      _signedIn = true;
    });

    if (_pendingWidgetUri != null) {
      _navigateToEpisode(_pendingWidgetUri!);
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.logout(clearSiteUrl: false);
    setState(() {
      _signedIn = false;
      _pendingWidgetUri = null;
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
          navigatorKey: _navigatorKey,
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
              ? ValueListenableBuilder<bool>(
                  valueListenable: AuthService.instance.authStateNotifier,
                  builder: (context, isAuth, _) {
                    return isAuth
                        ? HomeScreen(
                            username: AuthService.instance.username ?? '',
                            onLogout: _handleLogout,
                          )
                        : LoginScreen(
                            onLogin: _onLogin,
                            onRegister: _onRegister,
                            initialSiteUrl: AuthService.instance.siteUrl,
                          );
                  },
                )
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}
