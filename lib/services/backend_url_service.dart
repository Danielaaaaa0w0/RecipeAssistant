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
  
  // --- 修改：提供一個初始預設值，而不是 late ---
  String _currentUrl = '[http://172.20.10.5:8000](http://172.20.10.5:8000)'; // 我手機
  // String _currentUrl = '[http://140.116.115.198:8000](http://140.116.115.198:8000)'; // 宿網
  bool _isInitialized = false;
  // ------------------------------------------

  String get currentUrl => _currentUrl;
  bool get isInitialized => _isInitialized;

  BackendUrlService() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 從本地存儲讀取 URL，如果沒有，則保持初始設定的預設值
      _currentUrl = prefs.getString(_urlKey) ?? presetUrls.first;
      _log.info("Loaded backend URL: $_currentUrl");
    } catch (e, s) {
      _log.severe("Failed to load backend URL, using default.", e, s);
      // 如果載入失敗，_currentUrl 仍然是我們初始設定的預設值
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