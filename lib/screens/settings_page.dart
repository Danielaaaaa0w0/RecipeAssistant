// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_preference_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('SettingsPage');

class SettingsPage extends StatelessWidget { // 可以是 StatelessWidget 因為狀態由 Provider 管理
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 來獲取 LanguagePreferenceService 並在其變化時重建相關部分
    return Consumer<LanguagePreferenceService>(
      builder: (context, langService, child) {
        _log.info("SettingsPage rebuilding. Current language: ${langService.currentLanguage}");
        return Scaffold(
          // AppBar 通常由 MainControllerPage 控制，這裡可以不用，除非您希望它有獨立的 AppBar
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '語音播放設定',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SwitchListTile(
                title: const Text('語音語言', style: TextStyle(fontSize: 17)),
                subtitle: Text(
                  langService.currentLanguage == PreferredLanguage.mandarin
                      ? '目前選擇：國語'
                      : '目前選擇：台語',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                value: langService.currentLanguage == PreferredLanguage.taiwanese, // true 代表台語, false 代表國語
                onChanged: (bool value) {
                  PreferredLanguage newLanguage =
                      value ? PreferredLanguage.taiwanese : PreferredLanguage.mandarin;
                  _log.info("Language switch toggled. New preference: $newLanguage");
                  langService.setLanguage(newLanguage);
                },
                activeColor: Theme.of(context).colorScheme.primary,
                secondary: Icon(
                  langService.currentLanguage == PreferredLanguage.mandarin
                      ? Icons.speaker_notes // 國語圖示 (範例)
                      : Icons.chat_bubble_outline_rounded, // 台語圖示 (範例)
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Divider(height: 30, thickness: 1),
              ListTile(
                leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
                title: const Text('關於 App', style: TextStyle(fontSize: 17)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('關於 食譜 AR 助手'),
                      content: const Text('版本: 1.0.0\n一個使用 Flutter, Unity, Neo4j 和 Whisper 製作的料理小幫手。'),
                      actions: [
                        TextButton(
                          child: const Text('確定'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // 您可以在這裡加入其他的設定項...
            ],
          ),
        );
      },
    );
  }
}