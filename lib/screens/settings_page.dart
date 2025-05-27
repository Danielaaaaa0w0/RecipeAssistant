// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_preference_service.dart'; // 導入服務
import 'package:logging/logging.dart';

final _log = Logger('SettingsPage');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 來獲取 LanguagePreferenceService 並在其變化時重建相關部分
    return Consumer<LanguagePreferenceService>(
      builder: (context, langService, child) {
        _log.info("SettingsPage rebuilding. Current language: ${langService.currentLanguage}");
        return Scaffold(
          // AppBar 由 MainControllerPage 控制，這裡可以不用
          // appBar: AppBar(title: const Text('設定')),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              Text(
                '語音偏好設定',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              RadioListTile<PreferredLanguage>(
                title: const Text('國語 (Mandarin)'),
                value: PreferredLanguage.mandarin,
                groupValue: langService.currentLanguage,
                onChanged: (PreferredLanguage? value) {
                  if (value != null) {
                    _log.info("Setting language to Mandarin");
                    langService.setLanguage(value);
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              RadioListTile<PreferredLanguage>(
                title: const Text('台語 (Taiwanese)'),
                value: PreferredLanguage.taiwanese,
                groupValue: langService.currentLanguage,
                onChanged: (PreferredLanguage? value) {
                  if (value != null) {
                     _log.info("Setting language to Taiwanese");
                    langService.setLanguage(value);
                  }
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const Divider(height: 30, thickness: 1),
              // 您可以在這裡加入其他的設定項...
              ListTile(
                leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
                title: const Text('關於 App'),
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
            ],
          ),
        );
      },
    );
  }
}