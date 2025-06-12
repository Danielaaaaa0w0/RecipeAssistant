// lib/services/backend_url_service.dart (最終修正版)
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

final _log = Logger('BackendUrlService');

class BackendUrlService with ChangeNotifier {
  static const String _urlKey = 'backend_url';
  
  // 您的常用 IP 預設列表
  final List<String> presetUrls = const [
    'http://140.116.115.198:8000', // <--- 將這個設為第一個，作為預設
    'http://172.20.10.5:8000',
  ];
  
  // --- 核心修改：移除 late 並提供一個初始預設值 ---
  // App 啟動時將立即使用此 URL。
  String _currentUrl = 'http://140.116.115.198:8000'; // 直接設定您想要的預設值
  bool _isInitialized = false;
  // ----------------------------------------------

  String get currentUrl => _currentUrl;
  bool get isInitialized => _isInitialized;

  BackendUrlService() {
    _loadUrl();
  }

  /// 從本地存儲異步載入之前保存的 URL。
  /// 如果成功，它會覆蓋初始的預設值。
  Future<void> _loadUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_urlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _currentUrl = savedUrl;
      } else {
        // 如果 SharedPreferences 中沒有儲存過，則確保 _currentUrl 是 presetUrls 的第一個
        _currentUrl = presetUrls.first;
      }
      _log.info("Loaded backend URL: $_currentUrl");
    } catch (e, s) {
      _log.severe("Failed to load backend URL, using default.", e, s);
      // 如果載入失敗，_currentUrl 仍然是我們在上面初始設定的預設值
    } finally {
      _isInitialized = true;
      notifyListeners(); // 通知監聽者（例如 SettingsPage UI）更新為從本地儲存載入的值
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