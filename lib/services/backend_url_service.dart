// lib/services/backend_url_service.dart (新建檔案)
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

final _log = Logger('BackendUrlService');

class BackendUrlService with ChangeNotifier {
  static const String _urlKey = 'backend_url';
  // 您的常用 IP 預設列表
  final List<String> presetUrls = const [
    'http://172.20.10.5:8000',
    'http://140.116.115.198:8000',
  ];
  
  // 預設 URL，例如第一個常用 IP
  late String _currentUrl;
  bool _isInitialized = false;

  String get currentUrl => _currentUrl;
  bool get isInitialized => _isInitialized;

  BackendUrlService() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUrl = prefs.getString(_urlKey) ?? presetUrls.first;
      _log.info("Loaded backend URL: $_currentUrl");
    } catch (e, s) {
      _log.severe("Failed to load backend URL, using default.", e, s);
      _currentUrl = presetUrls.first;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setUrl(String newUrl) async {
    final trimmedUrl = newUrl.trim();
    if (trimmedUrl.isEmpty) {
      _log.warning("Attempted to set an empty URL. Operation aborted.");
      return;
    }
    if (_currentUrl == trimmedUrl) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlKey, trimmedUrl);
      _currentUrl = trimmedUrl;
      _log.info("Backend URL changed to: $trimmedUrl");
      notifyListeners();
    } catch (e, s) {
       _log.severe("Failed to save backend URL", e, s);
    }
  }
}