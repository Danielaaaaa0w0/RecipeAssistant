// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/language_preference_service.dart';
import 'package:logging/logging.dart';

void main() {
  // 日誌設定
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
      ],
      child: const MyApp(),
    ),
  );
}