// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/language_preference_service.dart';
import 'package:logging/logging.dart';
// import 'utils/haptic_feedback_utils.dart'; // 不再需要在 main 中 init

void main() { // 不再需要 async
  WidgetsFlutterBinding.ensureInitialized(); // 確保 Flutter 綁定已初始化

  // 初始化日誌 (保持不變)
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.time}: [${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) debugPrint('Error: ${record.error}');
    if (record.stackTrace != null) debugPrint('StackTrace: ${record.stackTrace}');
  });

  // await AppHaptics.init(); // <--- 移除這一行

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguagePreferenceService()),
      ],
      child: const MyApp(),
    ),
  );
}