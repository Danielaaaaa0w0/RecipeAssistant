// main.dart (修改後)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/language_preference_service.dart';
import 'services/backend_url_service.dart'; // <--- 導入新的服務
import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化日誌
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.time}: [${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) debugPrint('Error: ${record.error}');
    if (record.stackTrace != null) debugPrint('StackTrace: ${record.stackTrace}');
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguagePreferenceService()),
        ChangeNotifierProvider(create: (_) => BackendUrlService()), // <--- 註冊新的服務
      ],
      child: const MyApp(),
    ),
  );
}