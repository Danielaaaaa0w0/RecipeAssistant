// lib/screens/ar_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'dart:async'; // 用於 TimeoutException 和 Timer
import 'package:logging/logging.dart'; // 日誌套件
import 'package:provider/provider.dart'; // <--- 導入 Provider
import 'package:audioplayers/audioplayers.dart'; // <--- 導入 audioplayers
import '../models/recipe_details.dart'; // 導入模型
import '../models/recipe_step.dart';   // 導入模型
import '../utils/image_mappings.dart'; // 導入 chefAvatarPath
import '../services/language_preference_service.dart'; // <--- 導入語言服務


// 為此頁面創建 Logger 實例
final _log = Logger('ARPage');

class ARPage extends StatefulWidget {
  final RecipeDetails? selectedRecipe; // 從 MainControllerPage 傳入

  const ARPage({super.key, this.selectedRecipe });

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> with AutomaticKeepAliveClientMixin<ARPage> {
  // --- 新增：實作 wantKeepAlive ---
  @override
  bool get wantKeepAlive => true; // <--- 告訴 PageView 保持此頁面的狀態
  // ---------------------------------

  bool _showDialogue = false;
  String _dialogueText = "";
  UnityWidgetController? _unityWidgetController;
  // final TextEditingController _messageController = TextEditingController(); // 已按要求註解

  int _currentStepIndex = 0;
  List<RecipeStep> _steps = [];
  bool _initialStepTriggeredByUser = false; // 追蹤用戶是否已點擊 "開始播放"

  Timer? _dialogueHideTimer; // 用於手動管理對話泡泡的隱藏計時器

  // --- 新增 AudioPlayer 實例 ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState? _playerState; // 用於追蹤播放器狀態
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompletionSubscription; // 用於監聽播放完成
  StreamSubscription? _playerErrorSubscription; // 用於監聽播放器錯誤
  // ---------------------------

  @override
  void initState() {
    super.initState();
    _log.info("ARPage initState called. Recipe: ${widget.selectedRecipe?.recipeName}");
    _setupAudioPlayerListeners();
    _initializeRecipeState(isInitialLoad: true);
  }

  @override
  void dispose() {
    _log.info("ARPage dispose called.");
    _unityWidgetController?.dispose(); // 只有在 ARPage 被永久銷毀時才釋放
    _dialogueHideTimer?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompletionSubscription?.cancel();
    _audioPlayer.release();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ARPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _log.info("ARPage didUpdateWidget called.");
    if (widget.selectedRecipe != null &&
        oldWidget.selectedRecipe?.recipeName != widget.selectedRecipe!.recipeName) {
      _log.info("ARPage: New recipe selected ('${widget.selectedRecipe!.recipeName}' from '${oldWidget.selectedRecipe?.recipeName}'). Resetting state and Unity scene.");
      // 食譜已更改，發送重置 Unity 場景的指令
      if (_unityWidgetController != null && widget.selectedRecipe != null) {
        String cleanedName = _cleanRecipeName(widget.selectedRecipe!.recipeName);
        _sendMessageToUnityWrapper('CallUnity', "$cleanedName -1"); // DishName -1
      }
      _initializeRecipeState(isInitialLoad: false); // 使用新食譜數據重置 Flutter 端狀態
    } else {
      _log.info("ARPage didUpdateWidget: Recipe unchanged or no recipe.");
    }
  }

  void _setupAudioPlayerListeners() {
    _playerStateSubscription?.cancel(); // 先取消舊的，以防 initState 重複調用
    _playerCompletionSubscription?.cancel();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if(mounted) setState(() => _playerState = s);
      _log.info('AudioPlayer current state: $s');
    });
    _playerCompletionSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      _log.info("AudioPlayer onPlayerComplete event");
    });
  }

  void _initializeRecipeState({required bool isInitialLoad}) {
    // 重置 AR 頁面狀態
    _currentStepIndex = 0;
    _initialStepTriggeredByUser = false; // 每次新食譜或重置時，都需要用戶重新點擊開始
    _steps = []; // 清空舊步驟

    if (widget.selectedRecipe != null) {
      _steps = widget.selectedRecipe!.steps;
      if (_steps.isNotEmpty) {
        _log.info("ARPage: Recipe '${widget.selectedRecipe!.recipeName}' has steps. Ready for user to start.");
        _avatarSpeak(
            "AR場景為「${_cleanRecipeName(widget.selectedRecipe!.recipeName)}」準備中...\n第一個步驟是: \"${_steps[_currentStepIndex].stepInstruction}\"\n請在場景載入後點擊「開始播放步驟」。",
            autoHide: !isInitialLoad, // 首次載入時提示久一點，切換食譜時可以快一點
            autoHideDuration: isInitialLoad ? const Duration(seconds: 10) : const Duration(seconds: 5)
        );
      } else {
        _log.warning("食譜 '${widget.selectedRecipe!.recipeName}' 沒有步驟可以顯示。");
        _avatarSpeak("這個食譜目前沒有步驟可以顯示。", autoHide: true, autoHideDuration: const Duration(seconds: 7));
      }
    } else {
      _log.severe("錯誤：selectedRecipe is null during state initialization!");
      _avatarSpeak("沒有選擇食譜，請返回選擇。", autoHide: true, autoHideDuration: const Duration(seconds: 7));
    }
    if (mounted) {
      setState(() {}); // 觸發 UI 更新以顯示新的初始狀態 (例如 "開始播放步驟" 按鈕)
    }
  }


  void _onUnityCreated(controller) {
    _log.info('Unity Widget _onUnityCreated');
    _unityWidgetController = controller;
    _log.info('Unity Controller is ready.');
    _avatarSpeak("AR 場景已連接。", autoHide: true, autoHideDuration: const Duration(seconds: 5));

    // 當 ARPage 首次創建或食譜改變，且 Unity 控制器也準備好時，
    // 如果是食譜改變 (didUpdateWidget 中已發送 -1)，Unity 會重置。
    // 如果是首次載入，且有食譜，Unity 也需要知道初始狀態。
    // 這裡不再自動發送第一個步驟，等待用戶點擊 "開始播放步驟"
    // 但如果食譜已選定，可以發送一個初始化指令（如果 Unity 需要）
    if (widget.selectedRecipe != null && !_initialStepTriggeredByUser) { // 確保只在未開始時
        String cleanedName = _cleanRecipeName(widget.selectedRecipe!.recipeName);
        // 如果 Unity 在收到 "DishName -1" 後會自動準備好對應食譜，則這裡可能不需要再發送
        // 如果需要明確告知 Unity 當前食譜（即使是重置後的），可以發送一個不帶步驟號的訊息
        // _sendMessageToUnityWrapper('CallUnity', "$cleanedName 0"); // 例如步驟0代表食譜概覽
         _log.info("Unity created, AR page has recipe. User needs to press start.");
    }
  }

  void _onUnityMessage(message) {
    _log.info('Received message from Unity: ${message.toString()}');
    _avatarSpeak("Unity 回應: ${message.toString()}", autoHide: true, autoHideDuration: const Duration(seconds: 7));
  }

  // _avatarSpeak 方法，包含 autoHide 和 autoHideDuration 參數
  void _avatarSpeak(String text, {bool autoHide = true, Duration autoHideDuration = const Duration(seconds: 5)}) {
    if (!mounted) return;

    _dialogueHideTimer?.cancel(); // 取消任何正在運行的舊計時器

    setState(() {
      _dialogueText = text;
      _showDialogue = true;
      _log.info("Avatar speaking: '$text', AutoHide: $autoHide, Duration: ${autoHideDuration.inSeconds}s");
    });

    if (autoHide && autoHideDuration.inMicroseconds > 0) {
      _dialogueHideTimer = Timer(autoHideDuration, () {
        if (mounted) {
          setState(() {
            _showDialogue = false;
            _log.info("對話泡泡自動隱藏: $_dialogueText");
          });
        }
      });
    } else if (!autoHide) {
       _log.info("對話泡泡將持續顯示 (autoHide=false): $_dialogueText");
    }
  }

  void _sendMessageToUnityWrapper(String methodName, String messagePayload) {
    if (_unityWidgetController == null) {
      _log.warning("Unity controller is not available for method $methodName.");
      _showSnackBar("AR 場景控制器尚未就緒。");
      return;
    }
    const String gameObjectName = 'XR Origin'; // 已確認
    _unityWidgetController!.postMessage(gameObjectName, methodName, messagePayload);
    _log.info("Sent message to Unity: GameObject='$gameObjectName', Method='$methodName', Message='$messagePayload'");
  }

  String _cleanRecipeName(String recipeName) {
    return recipeName.endsWith("的做法")
        ? recipeName.substring(0, recipeName.length - 3)
        : recipeName;
  }

  Future<void> _playStepAudio(RecipeStep step) async {
    await _audioPlayer.stop(); // 先停止當前播放

    final langService = Provider.of<LanguagePreferenceService>(context, listen: false);
    String? audioPath;

    if (langService.currentLanguage == PreferredLanguage.mandarin) {
      audioPath = step.audioPathMandarin;
      _log.info("選擇播放國語語音: $audioPath");
    } else {
      audioPath = step.audioPathTaiwanese;
      _log.info("選擇播放台語語音: $audioPath");
    }

    if (audioPath != null && audioPath.isNotEmpty) {
      // AssetSource 的路徑通常是相對於 assets/ 資料夾的，並且不需要開頭的 "assets/"
      // 例如，如果完整路徑是 "assets/audio/recipe_steps/...", AssetSource 裡用 "audio/recipe_steps/..."
      String assetSourcePath = audioPath.startsWith("assets/")
          ? audioPath.substring("assets/".length)
          : audioPath;

      _log.info("Attempting to play asset: $assetSourcePath");
      try {
        // Source audioSource; // v6 的寫法
        // audioSource = AssetSource(assetSourcePath); // v6 的寫法
        // await _audioPlayer.play(audioSource); // v6 的寫法

        // --- 針對 audioplayers ^5.2.1 的 API ---
        // v5 版本直接傳遞路徑字串給 Source.asset
        await _audioPlayer.play(AssetSource(assetSourcePath));
        // 或者，對於某些 v5 的子版本，可能是：
        // await _audioPlayer.play(DeviceFileSource(filePath)); // 如果是絕對檔案路徑
        // await _audioPlayer.setSource(AssetSource(assetSourcePath));
        // await _audioPlayer.resume();

        _log.info("開始播放語音: $assetSourcePath (路徑相對於 assets)");
      } catch (e, s) {
        _log.severe("播放語音失敗: $assetSourcePath", e, s);
        // *** 在 catch 中打印更詳細的錯誤，而不是只顯示 SnackBar ***
        _showSnackBar("抱歉，無法播放此步驟的語音。錯誤: $e");
      }
    } else {
      _log.warning("步驟 ${step.stepOrder} 找不到對應的 ${langService.currentLanguage} 語音檔路徑。");
      _showSnackBar("此步驟沒有 ${langService.currentLanguage == PreferredLanguage.mandarin ? '國語' : '台語'} 語音。");
    }
  }

  void _sendStepDataToUnity(RecipeStep step) {
     if (widget.selectedRecipe == null) {
       _log.warning("_sendStepDataToUnity called but selectedRecipe is null.");
       return;
     }
     if (_unityWidgetController == null) {
       _log.warning("_sendStepDataToUnity called but Unity controller is null.");
       _showSnackBar("AR 場景控制器尚未就緒。");
       return;
     }

     String recipeNameForUnity = _cleanRecipeName(widget.selectedRecipe!.recipeName);
     String messagePayload = "$recipeNameForUnity ${step.stepOrder}";
     _sendMessageToUnityWrapper('CallUnity', messagePayload);
     // SnackBar 可以移到觸發此函數的按鈕 onPressed 中，以避免在 _onUnityCreated 中過早顯示
     // _showSnackBar("步驟 ${step.stepOrder} 指令 ('${messagePayload}') 已發送至 CallUnity");
  }

  // 更新 Avatar 對話，並決定是否發送指令給 Unity
  void _updateAvatarDialogueAndSendToUnity(int stepIndex, {bool sendToUnity = true}) {
    if (stepIndex >= 0 && stepIndex < _steps.length) {
      final RecipeStep currentStep = _steps[stepIndex];
      // *** 步驟對話預設不自動隱藏 ***
      _avatarSpeak("步驟 ${currentStep.stepOrder}: ${currentStep.stepInstruction}", autoHide: false);
      _playStepAudio(currentStep); // <--- 新增播放語音

      if (sendToUnity) {
        if (_unityWidgetController != null) { // 確保控制器已就緒
            _sendStepDataToUnity(currentStep);
        } else {
            _log.info("Unity controller not ready in _updateAvatarDialogueAndSendToUnity, message for step ${currentStep.stepOrder} will not be sent now.");
        }
      }
    } else {
      _log.warning("步驟索引超出範圍: $stepIndex");
    }
  }

  // 「開始播放」按鈕的處理邏輯
  void _handleStartPlayback() {
    if (_unityWidgetController == null) {
      _showSnackBar("AR 場景尚未完全連接，請稍候。");
      return;
    }
    if (widget.selectedRecipe != null && _steps.isNotEmpty && !_initialStepTriggeredByUser) {
      _log.info("用戶點擊開始播放，發送初始步驟 ${_steps[_currentStepIndex].stepOrder} 至 Unity。");
      _updateAvatarDialogueAndSendToUnity(_currentStepIndex, sendToUnity: true);
      _showSnackBar("步驟 ${_steps[_currentStepIndex].stepOrder} 指令已發送"); // 在用戶操作後顯示 SnackBar
      if (mounted) {
        setState(() {
          _initialStepTriggeredByUser = true;
        });
      }
    } else if (_initialStepTriggeredByUser) {
      _showSnackBar("已經開始播放步驟了。");
    } else {
      _showSnackBar("沒有步驟可以開始。");
    }
  }

  // --- 控制按鈕邏輯 ---
  void _goToNextStep() {
    if (!_initialStepTriggeredByUser) { _showSnackBar("請先點擊「開始播放」"); return; }
    if (_currentStepIndex < _steps.length - 1) {
      setState(() { _currentStepIndex++; });
      _updateAvatarDialogueAndSendToUnity(_currentStepIndex, sendToUnity: true);
    } else {
      _avatarSpeak("這已經是最後一個步驟了！", autoHide: true, autoHideDuration: const Duration(seconds: 7));
      _showSnackBar("已是最後一步");
    }
  }

  void _goToPreviousStep() {
    if (!_initialStepTriggeredByUser) { _showSnackBar("請先點擊「開始播放」"); return; }
    if (_currentStepIndex > 0) {
      setState(() { _currentStepIndex--; });
      _updateAvatarDialogueAndSendToUnity(_currentStepIndex, sendToUnity: true);
    } else {
      _avatarSpeak("這已經是第一個步驟了。", autoHide: true, autoHideDuration: const Duration(seconds: 7));
      _showSnackBar("已是第一步");
    }
  }

void _repeatStep() {
    if (!_initialStepTriggeredByUser) { _showSnackBar("請先點擊「開始播放」"); return; }
    if (_steps.isNotEmpty && _currentStepIndex < _steps.length) {
      _log.info("Repeating step: ${_steps[_currentStepIndex].stepOrder}");
      // 呼叫 _updateAvatarDialogueAndSendToUnity 會處理對話、語音和 Unity 指令
      _updateAvatarDialogueAndSendToUnity(_currentStepIndex, sendToUnity: true); // 確保也發送 Unity 指令
      _showSnackBar("重播步驟 ${_steps[_currentStepIndex].stepOrder}"); // 可以在這裡給提示
    } else {
       _showSnackBar("沒有步驟可以重播");
    }
  }

  void _showSnackBar(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).removeCurrentSnackBar();
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
       );
     }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets mediaQueryPadding = MediaQuery.of(context).padding;
    final double appBarHeight = Scaffold.maybeOf(context)?.appBarMaxHeight ?? 0;
    const double avatarSize = 70.0;
    const double avatarPadding = 15.0;
    const double dialoguePaddingRight = avatarPadding + avatarSize + 10.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Positioned.fill(
            child: UnityWidget(
               onUnityCreated: _onUnityCreated,
               onUnityMessage: _onUnityMessage,
               useAndroidViewSurface: true, // 保持您範例中的設定
               fullscreen: false, // 必須為 false 以便疊加 Flutter UI
               enablePlaceholder: false, // <--- 根據您的要求，移除 placeholder
               // placeholder: Container(...), // 已移除
               printSetupLog: true, // 建議在除錯階段開啟
            ),
          ),

          // 根據狀態顯示「開始播放」按鈕或「步驟控制」按鈕
          if (!_initialStepTriggeredByUser && _steps.isNotEmpty)
            Positioned(
              bottom: mediaQueryPadding.bottom + 20,
              left: 20,
              right: 20,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text("開始播放步驟"),
                onPressed: _handleStartPlayback, // <--- 呼叫新的處理函數
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            )
          else if (_initialStepTriggeredByUser && _steps.isNotEmpty) // 如果已開始播放且有步驟
            Positioned(
              bottom: mediaQueryPadding.bottom + 20, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(icon: Icons.arrow_back_ios, label: '上一步', onPressed: _goToPreviousStep),
                    _buildControlButton(icon: Icons.replay_outlined, label: '重播一次', onPressed: _repeatStep),
                    _buildControlButton(icon: Icons.arrow_forward_ios, label: '下一步', onPressed: _goToNextStep),
                  ],
                ),
              ),
            ),

          /* // 測試用手動輸入框已註解掉
          Positioned(
            bottom: mediaQueryPadding.bottom + 80,
            left: 15,
            right: 15,
            child: Material(
              // ...
            ),
          ),
          */

          // Avatar
          Positioned(
             top: mediaQueryPadding.top + appBarHeight + 10, right: avatarPadding,
             child: ClipRRect(
               borderRadius: BorderRadius.circular(12.0),
               child: Container(
                 width: avatarSize, height: avatarSize, color: Colors.deepOrange[100],
                 child: Image.asset(
                   chefAvatarPath, // 使用 utils/image_mappings.dart 中的路徑
                   fit: BoxFit.cover,
                   errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.person_outline, color: Colors.white, size: 40))
                 ),
               ),
             ),
          ),
          // 對話泡泡
          Positioned(
             top: mediaQueryPadding.top + appBarHeight + 20, left: 15, right: dialoguePaddingRight,
             child: AnimatedOpacity(
               opacity: _showDialogue ? 1.0 : 0.0,
               duration: const Duration(milliseconds: 300),
               child: Material(
                 elevation: 4,
                 borderRadius: BorderRadius.circular(15.0),
                 color: Colors.white,
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                   child: Text(
                     _dialogueText,
                     style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                   ),
                 ),
               ),
             ),
          ),
        ],
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
