// lib/screens/welcome_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:audioplayers/audioplayers.dart'; // <--- 導入 audioplayers
import 'main_controller_page.dart';
import '../utils/image_mappings.dart';
import '../widgets/animated_image_wall.dart';
import 'package:vibration/vibration.dart'; // <--- 導入 vibration 套件
import '../utils/haptic_feedback_utils.dart'; // <--- 導入

final _log = Logger('WelcomePage');

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _showLogo = false;
  bool _showAppName = false;
  bool _showSlogan = false;
  bool _showIconRow = false; // 合併小圖示的顯示狀態

  bool _isBackgroundAnimationComplete = false;

  final String appName = "心意廚房";
  final String slogan = "有心意，就能做出好料理 - 心意廚房。";
  Timer? _navigationTimer;

  // --- 新增 AudioPlayer 實例 ---
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  // --------------------------

  final Duration _logoDuration = const Duration(milliseconds: 700);
  final Duration _appNameDuration = const Duration(milliseconds: 600);
  final Duration _sloganDuration = const Duration(milliseconds: 600);
  final Duration _iconsDuration = const Duration(milliseconds: 500);

  final Duration _logoDelay = const Duration(milliseconds: 50); // 背景淡化後更快出現
  final Duration _appNameDelay = const Duration(milliseconds: 300);
  final Duration _sloganDelay = const Duration(milliseconds: 550);
  final Duration _iconsDelay = const Duration(milliseconds: 200);


  @override
  void initState() {
    super.initState();
    _log.info("WelcomePage initState: Background animation will start.");
    _playBackgroundMusic();
    _checkVibrationCapability(); // <--- 檢查設備是否支援震動
  }

  // --- 新增：檢查震動能力 ---
  Future<void> _checkVibrationCapability() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      _log.info("Device has vibrator: $hasVibrator");
      if (hasVibrator == false && mounted) {
        // 可以在此處顯示一個提示，告知用戶設備不支援震動
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("您的設備不支援震動功能。")));
      }
    } catch (e) {
      _log.severe("Error checking vibration capability: $e");
    }
  }
  // ------------------------

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _backgroundMusicPlayer.stop(); // <--- 停止音樂
    _backgroundMusicPlayer.dispose(); // <--- 釋放播放器
    _log.info("WelcomePage disposed.");
    super.dispose();
  }

  // --- 新增：播放背景音樂 ---
  Future<void> _playBackgroundMusic() async {
    try {
      // 確保路徑是 audioplayers AssetSource 接受的格式 (通常是去掉 'assets/')
      await _backgroundMusicPlayer.play(AssetSource('audio/welcome_music.mp3')); // <--- 您的音樂檔案路徑
      // await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop); // 設定循環播放
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.release); // 播放完畢後停止 (v5.x.x 的 API)    
      _log.info("Background music started.");
    } catch (e, s) {
      _log.severe("Error playing background music", e, s);
    }
  }
  // -----------------------

  void _onBackgroundAnimationComplete() {
    _log.info("Background animation complete. Starting foreground animations.");
    if (mounted) {
      setState(() {
        _isBackgroundAnimationComplete = true;
      });
      _startForegroundAnimations();
      _startNavigationTimer();
    }
  }

  void _startForegroundAnimations() {
    if (!_isBackgroundAnimationComplete || !mounted) return;

    Future.delayed(_logoDelay, () {
      if (mounted) {
        setState(() => _showLogo = true);
        AppHaptics.mediumImpact();
      }
    });
    Future.delayed(_appNameDelay, () {
      if (mounted) {
        setState(() => _showAppName = true);
        AppHaptics.lightClick();
      }
    });
    Future.delayed(_sloganDelay, () {
      if (mounted) {
        setState(() => _showSlogan = true);
        AppHaptics.lightClick();
      }
    });
    Future.delayed(_iconsDelay, () {
      if (mounted) {
        setState(() => _showIconRow = true);
        // HapticFeedback.selectionClick(); // 小圖示出現可以用不同的
      }
    });
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(const Duration(seconds: 6, milliseconds: 500), () {
      if (mounted) {
        _log.info("WelcomePage: Navigating to MainControllerPage.");
        // 在跳轉前停止背景音樂
        _backgroundMusicPlayer.stop().then((_) { // 確保音樂停止後再跳轉
            _log.info("Background music stopped before navigation.");
            if(mounted){ // 再次檢查 mounted 狀態
                 Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const MainControllerPage(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 700),
                    ),
                );
            }
        });
      }
    });
  }

  Widget _buildAnimatedItem({
    required bool show,
    required Duration duration,
    required Widget child,
    double initialOffsetY = 25.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: duration,
      curve: curve,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        transform: Matrix4.translationValues(0, show ? 0 : initialOffsetY, 0),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color onBackgroundColor = theme.colorScheme.onBackground;
    final Color pageBackgroundColor = Colors.orange[50] ?? theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: LayoutBuilder( // <--- 使用 LayoutBuilder
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedImageWall(
                imagePaths: allRecipeImagePathsForWall,
                finalWallOpacity: 0.1,
                wallSettleDuration: const Duration(seconds: 2, milliseconds: 0),
                imageFadeInDuration: const Duration(milliseconds: 700),
                wallFadeToPartialOpacityDuration: const Duration(seconds: 1, milliseconds: 0),
                onInitialAnimationComplete: _onBackgroundAnimationComplete,
                // numberOfRows: 7, // 由內部或 targetHeight 計算
                rowHeight: 120.0, // 可以根據喜好調整
                marqueeScrollDuration: const Duration(seconds: 100), // <--- 跑馬燈更慢 (100秒一圈)
                targetHeight: constraints.maxHeight, // <--- 將 LayoutBuilder 的高度傳給 AnimatedImageWall
              ),
          // 前景：Logo, 名稱, Slogan, 圖示
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _buildAnimatedItem(
                    show: _isBackgroundAnimationComplete && _showLogo,
                    duration: _logoDuration,
                    child: Icon(Icons.ramen_dining_outlined, size: 70.0, color: primaryColor), // Logo 可以小一點
                  ),
                  const SizedBox(height: 20),
                  _buildAnimatedItem(
                    show: _isBackgroundAnimationComplete && _showAppName,
                    duration: _appNameDuration,
                    child: Text(appName, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 36), textAlign: TextAlign.center), // AppName 字體調整
                  ),
                  const SizedBox(height: 10),
                  _buildAnimatedItem(
                    show: _isBackgroundAnimationComplete && _showSlogan,
                    duration: _sloganDuration,
                    initialOffsetY: 15.0,
                    child: Text(slogan, style: theme.textTheme.titleMedium?.copyWith(color: onBackgroundColor.withOpacity(0.85), fontStyle: FontStyle.italic, fontSize: 16), textAlign: TextAlign.center), // Slogan 字體調整
                  ),
                  const SizedBox(height: 40),
                  _buildAnimatedItem(
                    show: _isBackgroundAnimationComplete && _showIconRow,
                    duration: _iconsDuration,
                    initialOffsetY: 35.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Icon(Icons.favorite_rounded, size: 30.0, color: primaryColor.withOpacity(0.8)), // 換實心圖示
                        Icon(Icons.auto_stories_rounded, size: 30.0, color: primaryColor.withOpacity(0.8)),
                        Icon(Icons.emoji_food_beverage_rounded, size: 30.0, color: primaryColor.withOpacity(0.8)), // 換個更相關的圖示
                      ],
                    ),
                  ),
                  const SizedBox(height: 60), // 底部留白
                ],
              ),
            ),
          ),
            ],
          );
        }
      ),
    );
  }



}