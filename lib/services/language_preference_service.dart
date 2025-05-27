// lib/services/language_preference_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

final _log = Logger('LanguagePreferenceService');

enum PreferredLanguage {
  mandarin, // 國語
  taiwanese // 台語
}

String preferredLanguageToString(PreferredLanguage lang) {
  return lang.toString().split('.').last;
}

PreferredLanguage preferredLanguageFromString(String? langString) {
  if (langString == preferredLanguageToString(PreferredLanguage.taiwanese)) {
    return PreferredLanguage.taiwanese;
  }
  return PreferredLanguage.mandarin; // 預設為國語
}

class LanguagePreferenceService with ChangeNotifier {
  static const String _languageKey = 'preferred_language_v2'; // 使用新 key 避免與舊版衝突
  PreferredLanguage _currentLanguage = PreferredLanguage.mandarin;

  PreferredLanguage get currentLanguage => _currentLanguage;

  LanguagePreferenceService() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langString = prefs.getString(_languageKey);
      if (langString != null) {
        _currentLanguage = preferredLanguageFromString(langString);
      }
      _log.info("Loaded language preference: $_currentLanguage");
    } catch (e,s) {
      _log.severe("Failed to load language preference", e, s);
    }
    // 即使載入失敗，也通知一次，讓監聽者獲得初始（預設）值
    notifyListeners();
  }

  Future<void> setLanguage(PreferredLanguage language) async {
    if (_currentLanguage == language && await _isPreferenceSet()) return; // 如果語言未改變且已設定，則不執行

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, preferredLanguageToString(language));
      _currentLanguage = language;
      _log.info("Language preference changed to: $language");
      notifyListeners();
    } catch (e,s) {
       _log.severe("Failed to save language preference", e, s);
    }
  }

  // 輔助函數檢查是否已設定過偏好
  Future<bool> _isPreferenceSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_languageKey);
  }
}