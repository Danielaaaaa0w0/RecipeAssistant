import 'package:flutter/material.dart';
import 'screens/welcome_page.dart';     // <--- 導入 WelcomePage

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '心意廚房',
      theme: ThemeData(
        // --- 您的主題設定 ---
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange, // 換個溫暖的色調
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0), // 圓一點的輸入框
            borderSide: BorderSide.none, // 無邊框，靠填充色區分
          ),
          filled: true,
          fillColor: Colors.orange.withOpacity(0.1),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange, // 更深的按鈕顏色
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0), // 圓角按鈕
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: Colors.deepOrange, // 圖示按鈕顏色
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // 白色 AppBar
          foregroundColor: Colors.black87, // 深色文字/圖標
          elevation: 1, // 加一點陰影
          shadowColor: Colors.grey,
          centerTitle: true,
        ),
        // --- 主題設定結束 ---
      ),
      // --- 修改 home 屬性 ---
      home: const WelcomePage(), // <--- 將 WelcomePage 設為初始頁面
      // ---------------------
      debugShowCheckedModeBanner: false,
    );
  }
}
