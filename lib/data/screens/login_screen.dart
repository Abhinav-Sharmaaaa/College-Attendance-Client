import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/auth_interceptor.dart';
import '../screens/dashboard_screen.dart';
import '../../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthInterceptorService();
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _checkingSession = false;
  bool _webViewReady = false;
  bool _refreshing = false;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _entranceFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );

  late final Animation<Offset> _entranceSlide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation(WebUri? url) async {
    if (_checkingSession) return;
    _checkingSession = true;
    try {
      final captured = await _authService.processCookies(url);
      if (captured && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }
    } finally {
      _checkingSession = false;
    }
  }

  Future<void> _reload() async {
    setState(() => _refreshing = true);
    await _controller?.reload();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('College Portal Login'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance,
            builder: (context, mode, child) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Switch to light' : 'Switch to dark',
                onPressed: ThemeController.instance.toggle,
                icon: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                ),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _refreshing ? 1 : 0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 6.28318,
                child: child,
              );
            },
            child: IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: _progress < 1 ? 3 : 0,
            child: ClipRect(
              child: AnimatedOpacity(
                opacity: _progress < 1 ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 3,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(AuthInterceptorService.loginUrl),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        cacheEnabled: true,
                        thirdPartyCookiesEnabled: true,
                      ),
                      onWebViewCreated: (controller) =>
                          _controller = controller,
                      onProgressChanged: (controller, progress) {
                        setState(() => _progress = progress / 100);
                      },
                      onLoadStop: (controller, url) async {
                        _handleNavigation(url);
                        if (!_webViewReady) {
                          setState(() => _webViewReady = true);
                        }
                      },
                      onUpdateVisitedHistory: (controller, url, isReload) =>
                          _handleNavigation(url),
                    ),
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _webViewReady ? 0 : 1,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        child: Container(
                          color: colorScheme.surface,
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.8, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: child,
                                );
                              },
                              child: CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}