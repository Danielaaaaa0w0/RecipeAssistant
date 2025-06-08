// lib/screens/ar_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/recipe_details.dart';
import '../models/recipe_step.dart';
import '../utils/image_mappings.dart';
import '../services/language_preference_service.dart';
import '../utils/haptic_feedback_utils.dart';

final _log = Logger('ARPage');

class ARPage extends StatefulWidget {
  final RecipeDetails? selectedRecipe;
  const ARPage({super.key, this.selectedRecipe});

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> with AutomaticKeepAliveClientMixin<ARPage> {
  @override
  bool get wantKeepAlive => true;

  // UI & State
  bool _showDialogue = false;
  String _dialogueText = "";
  int _currentStepIndex = 0;
  List<RecipeStep> _steps = [];
  Timer? _dialogueHideTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Unity & Audio
  UnityWidgetController? _unityWidgetController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompletionSubscription;

  // --- 新的狀態變數，用於控制流程 ---
  bool _isTablePlaced = false; // Unity 是否已回報 "table"
  bool _isUnityReadyForNextCommand = false; // Unity 是否已回報 "end"，允許下一個指令
  bool _initialStepSent = false; // 第一個步驟指令是否已發送
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _log.info("ARPage initState called. Recipe: ${widget.selectedRecipe?.recipeName}");
    _setupAudioPlayerListeners();
    _initializeRecipeState();
  }

  @override
  void didUpdateWidget(covariant ARPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _log.info("ARPage didUpdateWidget called.");
    // 檢查傳入的食譜是否真的改變了
    if (widget.selectedRecipe != null &&
        oldWidget.selectedRecipe?.recipeName != widget.selectedRecipe!.recipeName) {
      _log.info("ARPage: New recipe selected ('${widget.selectedRecipe!.recipeName}' from '${oldWidget.selectedRecipe?.recipeName}'). Resetting state and Unity scene.");
      // 1. 食譜已更改，發送重置 Unity 場景的指令
      if (_unityWidgetController != null) {
        String cleanedName = _cleanRecipeName(widget.selectedRecipe!.recipeName);
        _sendMessageToUnityWrapper('CallUnity', "$cleanedName -1");
      }
      // 2. 使用新食譜數據重置 Flutter 端狀態
      _initializeRecipeState();
    } else {
      _log.info("ARPage didUpdateWidget: Recipe unchanged (e.g., returning from another page). State is kept.");
    }
  }

  void _setupAudioPlayerListeners() {
    _playerStateSubscription?.cancel();
    _playerCompletionSubscription?.cancel();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((s) {
      _log.info('AudioPlayer current state: $s');
    });
    _playerCompletionSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _log.info("AudioPlayer onPlayerComplete event");
    });
  }

  void _initializeRecipeState() {
    // 重置 AR 頁面所有相關狀態
    _currentStepIndex = 0;
    _initialStepSent = false;
    _isTablePlaced = false;
    _isUnityReadyForNextCommand = false; // 初始時，Unity 不處於可接收步驟指令的狀態
    _steps = [];
    _audioPlayer.stop();

    if (widget.selectedRecipe != null) {
      _steps = widget.selectedRecipe!.steps;
      _avatarSpeak("AR場景準備中... 請先在您的空間中放置桌子。", autoHide: false);
    } else {
      _avatarSpeak("沒有選擇食譜，請返回選擇。", autoHide: true);
    }
    // 觸發 UI 更新以反映新的初始狀態
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _log.info("ARPage dispose called.");
    _unityWidgetController?.dispose();
    _dialogueHideTimer?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompletionSubscription?.cancel();
    _audioPlayer.release();
    super.dispose();
  }

  void _onUnityCreated(controller) {
    _log.info('Unity Widget _onUnityCreated');
    _unityWidgetController = controller;
    _log.info('Unity Controller is ready. Waiting for user to place the table...');
    // Avatar 的提示已在 _initializeRecipeState 中設定
  }

  void _onUnityMessage(message) {
    String messageStr = message.toString().trim();
    _log.info('Received message from Unity: "$messageStr"');

    if (messageStr == "table") {
      _log.info("Unity 'table' signal received. Enabling start button.");
      if (mounted) {
        setState(() {
          _isTablePlaced = true;
          _isUnityReadyForNextCommand = true; // 此時可以接收第一個指令了
        });
        _avatarSpeak("桌子已放置！請點擊「開始步驟」", autoHide: false);
      }
    } else if (messageStr == "end") {
      _log.info("Unity 'end' signal received. Ready for next command.");
      if (mounted) {
        setState(() {
          _isUnityReadyForNextCommand = true; // 解鎖按鈕
        });
        // 收到 end 後不更新對話泡泡，以保持當前步驟說明
        // _avatarSpeak("步驟完成！請選擇下一步操作。", autoHide: true);
      }
    } else {
      _avatarSpeak("Unity 回應: $messageStr", autoHide: true);
    }
  }

  void _avatarSpeak(String text, {bool autoHide = true, Duration autoHideDuration = const Duration(seconds: 5)}) {
    if (!mounted) return;
    _dialogueHideTimer?.cancel();
    setState(() { _dialogueText = text; _showDialogue = true; });
    if (autoHide) {
      _dialogueHideTimer = Timer(autoHideDuration, () {
        if (mounted) setState(() => _showDialogue = false);
      });
    }
  }

  void _sendMessageToUnityWrapper(String methodName, String messagePayload) {
    if (_unityWidgetController == null) {
      _log.warning("Unity controller not available for method $methodName.");
      _showSnackBar("AR 場景控制器尚未就緒。");
      return;
    }
    const String gameObjectName = 'XR Origin';
    _unityWidgetController!.postMessage(gameObjectName, methodName, messagePayload);
    _log.info("Sent message to Unity: GameObject='$gameObjectName', Method='$methodName', Message='$messagePayload'");
  }

  String _cleanRecipeName(String recipeName) {
    return recipeName.endsWith("的做法") ? recipeName.substring(0, recipeName.length - 3) : recipeName;
  }

  Future<void> _playStepAudio(RecipeStep step) async {
    await _audioPlayer.stop();
    final langService = Provider.of<LanguagePreferenceService>(context, listen: false);
    String? audioPath = langService.currentLanguage == PreferredLanguage.mandarin
        ? step.audioPathMandarin
        : step.audioPathTaiwanese;
    _log.info("Attempting to play for ${langService.currentLanguage}: $audioPath");
    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        String assetSourcePath = audioPath.startsWith("assets/") ? audioPath.substring("assets/".length) : audioPath;
        await _audioPlayer.play(AssetSource(assetSourcePath));
        _log.info("開始播放語音: $assetSourcePath");
      } catch (e, s) {
        _log.severe("播放語音失敗: $audioPath", e, s);
        _showSnackBar("抱歉，無法播放此步驟的語音。錯誤: $e");
      }
    } else {
      _log.warning("步驟 ${step.stepOrder} 找不到對應的 ${langService.currentLanguage} 語音檔路徑。");
      _showSnackBar("此步驟沒有 ${langService.currentLanguage == PreferredLanguage.mandarin ? '國語' : '台語'} 語音。");
    }
  }

  void _sendStepDataToUnity(RecipeStep step) {
     if (widget.selectedRecipe == null || _unityWidgetController == null) return;
     if (!_isUnityReadyForNextCommand) {
       _log.warning("Attempted to send step data while Unity is not ready.");
       _showSnackBar("請等待目前動畫播放完畢。");
       return;
     }
     if (mounted) {
       setState(() { _isUnityReadyForNextCommand = false; });
     }
     String recipeNameForUnity = _cleanRecipeName(widget.selectedRecipe!.recipeName);
     String messagePayload = "$recipeNameForUnity ${step.stepOrder}";
     _sendMessageToUnityWrapper('CallUnity', messagePayload);
  }

  void _updateAvatarDialogueAndAudioAndSendToUnity(int stepIndex, {bool sendToUnity = true}) {
    if (stepIndex >= 0 && stepIndex < _steps.length) {
      final RecipeStep currentStep = _steps[stepIndex];
      _avatarSpeak("步驟 ${currentStep.stepOrder}: ${currentStep.stepInstruction}", autoHide: false);
      _playStepAudio(currentStep);
      if (sendToUnity && _unityWidgetController != null) {
        _sendStepDataToUnity(currentStep);
      }
    }
  }

  void _handleStartPlayback() {
    AppHaptics.mediumImpact();
    if (!_isTablePlaced) { _showSnackBar("請先在 AR 場景中放置桌子。"); return; }
    if (_unityWidgetController == null) { _showSnackBar("AR 場景尚未完全連接。"); return; }
    if (widget.selectedRecipe != null && _steps.isNotEmpty && !_initialStepSent) {
      _log.info("用戶點擊開始播放，發送初始步驟 ${_steps[_currentStepIndex].stepOrder}");
      _updateAvatarDialogueAndAudioAndSendToUnity(_currentStepIndex, sendToUnity: true);
      _showSnackBar("步驟 ${_steps[_currentStepIndex].stepOrder} 指令已發送");
      if (mounted) {
        setState(() { _initialStepSent = true; });
      }
    }
  }

  void _goToNextStep() {
    AppHaptics.lightClick();
    if (!_isUnityReadyForNextCommand) { _showSnackBar("請等待目前動畫播放完畢。"); return; }
    if (_currentStepIndex < _steps.length - 1) {
      setState(() { _currentStepIndex++; });
      _updateAvatarDialogueAndAudioAndSendToUnity(_currentStepIndex, sendToUnity: true);
    } else {
      _avatarSpeak("這已經是最後一個步驟了！", autoHide: true);
      _showSnackBar("已是最後一步");
    }
  }

  void _goToPreviousStep() {
    AppHaptics.lightClick();
    if (!_isUnityReadyForNextCommand) { _showSnackBar("請等待目前動畫播放完畢。"); return; }
    if (_currentStepIndex > 0) {
      setState(() { _currentStepIndex--; });
      _updateAvatarDialogueAndAudioAndSendToUnity(_currentStepIndex, sendToUnity: true);
    } else {
      _avatarSpeak("這已經是第一個步驟了。", autoHide: true);
      _showSnackBar("已是第一步");
    }
  }

  void _repeatStep() {
    AppHaptics.lightClick();
    if (!_isUnityReadyForNextCommand) { _showSnackBar("請等待目前動畫播放完畢。"); return; }
    if (_steps.isNotEmpty && _currentStepIndex < _steps.length) {
      _log.info("Repeating step: ${_steps[_currentStepIndex].stepOrder}");
      _updateAvatarDialogueAndAudioAndSendToUnity(_currentStepIndex, sendToUnity: true);
      _showSnackBar("重播步驟 ${_steps[_currentStepIndex].stepOrder}");
    } else {
       _showSnackBar("沒有步驟可以重播");
    }
  }

  void _showSnackBar(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).removeCurrentSnackBar();
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
     }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final EdgeInsets mediaQueryPadding = MediaQuery.of(context).padding;
    final langService = Provider.of<LanguagePreferenceService>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_cleanRecipeName(widget.selectedRecipe?.recipeName ?? "AR 食譜"), style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.black54: Colors.white70)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.light ? Colors.black54: Colors.white70),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: const Text('AR 設定', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            SwitchListTile(
              title: const Text('語音語言'),
              subtitle: Text(langService.currentLanguage == PreferredLanguage.mandarin ? '目前: 國語' : '目前: 台語'),
              value: langService.currentLanguage == PreferredLanguage.taiwanese,
              onChanged: (bool value) {
                AppHaptics.lightClick();
                PreferredLanguage newLanguage = value ? PreferredLanguage.taiwanese : PreferredLanguage.mandarin;
                langService.setLanguage(newLanguage);
                if(_initialStepSent && _steps.isNotEmpty) {
                    _updateAvatarDialogueAndAudioAndSendToUnity(_currentStepIndex, sendToUnity: false);
                }
              },
              secondary: Icon(langService.currentLanguage == PreferredLanguage.mandarin ? Icons.speaker_notes : Icons.chat_bubble_outline_rounded),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: UnityWidget(
                 onUnityCreated: _onUnityCreated,
                 onUnityMessage: _onUnityMessage,
                 useAndroidViewSurface: true,
                 fullscreen: false,
                 enablePlaceholder: false,
                 printSetupLog: true,
              ),
            ),
            if (!_initialStepSent && _steps.isNotEmpty)
              Positioned(
                bottom: mediaQueryPadding.bottom + 20, left: 20, right: 20,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text("開始步驟"),
                  onPressed: _isTablePlaced ? _handleStartPlayback : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTablePlaced ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              )
            else if (_initialStepSent && _steps.isNotEmpty)
              Positioned(
                bottom: mediaQueryPadding.bottom + 20, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(icon: Icons.arrow_back_ios, label: '上一步', onPressed: _isUnityReadyForNextCommand ? _goToPreviousStep : null),
                      _buildControlButton(icon: Icons.replay_outlined, label: '重播一次', onPressed: _isUnityReadyForNextCommand ? _repeatStep : null),
                      _buildControlButton(icon: Icons.arrow_forward_ios, label: '下一步', onPressed: _isUnityReadyForNextCommand ? _goToNextStep : null),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: mediaQueryPadding.top, right: 15.0,
              child: ClipRRect(
                 borderRadius: BorderRadius.circular(12.0),
                 child: Container(
                   width: 70, height: 70, color: Colors.deepOrange[100],
                   child: Image.asset(chefAvatarPath, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.person_outline, color: Colors.white, size: 40))),
                 ),
               ),
            ),
            Positioned(
              top: mediaQueryPadding.top + 10, left: 15, right: 15.0 + 70.0 + 10.0,
              child: AnimatedOpacity(
                opacity: _showDialogue ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Material(
                  elevation: 4, borderRadius: BorderRadius.circular(15.0), color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    child: Text(_dialogueText, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required VoidCallback? onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.85),
        foregroundColor: Colors.deepOrange,
        disabledBackgroundColor: Colors.white.withOpacity(0.5),
        disabledForegroundColor: Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        textStyle: const TextStyle(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
      ),
    );
  }
}
