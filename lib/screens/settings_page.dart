// lib/screens/settings_page.dart (修改後)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_preference_service.dart';
import '../services/backend_url_service.dart'; // <--- 導入後端 URL 服務
import '../utils/haptic_feedback_utils.dart'; // 導入觸覺回饋
import 'package:logging/logging.dart';

final _log = Logger('SettingsPage');

class SettingsPage extends StatefulWidget { // 改為 StatefulWidget 以管理 TextEditingController
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _urlController;
  late BackendUrlService _backendUrlService;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    // 使用 addPostFrameCallback 確保 Provider 已準備好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 監聽 Provider 的變化來更新 TextField
      _backendUrlService = Provider.of<BackendUrlService>(context, listen: false);
      _urlController.text = _backendUrlService.currentUrl;
      // 當 service 中的 URL 改變時 (例如，如果其他地方改了它)，也更新 controller
      _backendUrlService.addListener(_updateTextField);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    // 移除監聽器
    if (mounted) {
      // 這是一個技巧，確保在 dispose 時 context 仍然有效
      // 但更安全的方式是在 initState 中獲取 service 後，在 dispose 中移除監聽
    }
    // _backendUrlService.removeListener(_updateTextField); // 理想的移除方式
    super.dispose();
  }

  void _updateTextField() {
    if (mounted) {
      _urlController.text = _backendUrlService.currentUrl;
    }
  }

  void _saveNewUrl() {
    AppHaptics.mediumImpact();
    String newUrl = _urlController.text.trim();
    if (newUrl.isNotEmpty) {
      // 呼叫服務來設定新的 URL
      Provider.of<BackendUrlService>(context, listen: false).setUrl(newUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('後端 URL 已儲存！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      FocusScope.of(context).unfocus(); // 收起鍵盤
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL 不能為空。'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 來獲取服務並在狀態變化時重建 UI
    return Consumer<LanguagePreferenceService>(
      builder: (context, langService, child) {
        final backendUrlService = Provider.of<BackendUrlService>(context);
        // 如果 TextField 尚未被初始化，則用 provider 的值初始化
        if (_urlController.text.isEmpty && backendUrlService.currentUrl.isNotEmpty) {
             _urlController.text = backendUrlService.currentUrl;
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              // --- 語言偏好設定 (保持不變) ---
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
                value: langService.currentLanguage == PreferredLanguage.taiwanese,
                onChanged: (bool value) {
                  AppHaptics.lightClick();
                  PreferredLanguage newLanguage =
                      value ? PreferredLanguage.taiwanese : PreferredLanguage.mandarin;
                  langService.setLanguage(newLanguage);
                },
                activeColor: Theme.of(context).colorScheme.primary,
                secondary: Icon(
                  langService.currentLanguage == PreferredLanguage.mandarin
                      ? Icons.speaker_notes
                      : Icons.chat_bubble_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Divider(height: 30, thickness: 1),

              // --- 新增：後端伺服器設定 ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '後端伺服器設定',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: '當前伺服器 URL',
                  hintText: '例如: http://192.168.1.100:8000',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: '儲存 URL',
                    onPressed: _saveNewUrl,
                  )
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _saveNewUrl(),
              ),
              const SizedBox(height: 12),
              const Text('快速選擇：', style: TextStyle(fontSize: 15, color: Colors.grey)),
              ...backendUrlService.presetUrls.map((url) {
                return RadioListTile<String>(
                  title: Text(url),
                  value: url,
                  groupValue: backendUrlService.currentUrl,
                  onChanged: (String? value) {
                    AppHaptics.lightClick();
                    if (value != null) {
                      _urlController.text = value; // 更新 TextField
                      backendUrlService.setUrl(value); // 直接設定並保存
                    }
                  },
                  dense: true,
                );
              }).toList(),
              // --- 結束新增 ---

              const Divider(height: 30, thickness: 1),
              ListTile(
                leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
                title: const Text('關於 App', style: TextStyle(fontSize: 17)),
                onTap: () {
                  AppHaptics.lightClick();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('關於 心意廚房'),
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