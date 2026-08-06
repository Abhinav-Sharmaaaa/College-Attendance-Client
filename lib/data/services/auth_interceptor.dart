import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:http/http.dart' as http;

class AuthInterceptorService {
  final _storage = const FlutterSecureStorage();
  final CookieManager _cookieManager = CookieManager.instance();

  static const String loginUrl =
      'https://online.uktech.ac.in/ums/Student/Account/Login';

  Future<bool> processCookies(WebUri? url) async {
    if (url == null) return false;

    if (url.toString().contains('/Student/User/')) {
      List<Cookie> cookies = await _cookieManager.getCookies(url: url);

      if (cookies.isNotEmpty) {
        String fullCookieString =
            cookies.map((c) => '\${c.name}=\${c.value}').join('; ');
        await _storage.write(key: 'session_cookie', value: fullCookieString);
        return true;
      }
    }
    return false;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    String? cookie = await _storage.read(key: 'session_cookie');
    return {
      'Cookie': cookie ?? '',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    };
  }

  Future<void> clearSession() async {
    await _cookieManager.deleteAllCookies();
    await _storage.delete(key: 'session_cookie');
  }

  // -----------------------------------------------------------------
  // NEW: Perform a credential‑based login and persist the session cookie.
  // -----------------------------------------------------------------
  // This mirrors what the old WebView flow did, but uses a native POST
  // request so that the credentials can be supplied by Google Password
  // Manager (Smart‑Lock).
  Future<void> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(loginUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/121.0.0.0',
      },
      body: {
        'UserName': username,
        'Password': password,
        // Add any hidden fields (e.g. __RequestVerificationToken) if
        // the portal requires them.
      },
    );

    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) {
      throw Exception('Login failed – server did not return a session cookie.');
    }

    final sessionCookie = setCookie.split(';').first.trim();
    await _storage.write(key: 'session_cookie', value: sessionCookie);
  }
}