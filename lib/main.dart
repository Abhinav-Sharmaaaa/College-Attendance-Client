import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'data/screens/dashboard_screen.dart';
import 'data/services/auth_interceptor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('College Portal Login')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(AuthInterceptorService.loginUrl),
        ),
        onLoadStop: (controller, url) async {
          bool captured = await AuthInterceptorService().processCookies(url);

          if (captured && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (c) => const DashboardScreen(),
              ),
            );
          }
        },
      ),
    );
  }
}