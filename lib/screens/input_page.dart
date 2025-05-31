// lib/screens/input_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math'; // <--- 導入 dart:math 以使用 Random
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'package:video_player/video_player.dart'; // <--- 導入 video_player
import '../utils/image_mappings.dart'; // 確保 chefAvatarPath 在這裡或直接定義
import '../utils/keyword_mappings.dart'; // <--- 導入關鍵字映射

final _log = Logger('InputPage');

enum InputStage {
  askingMood,     // 階段 1: 詢問心情
  askingQuery,    // 階段 2: 詢問料理名稱/關鍵字
  askingCategory, // 階段 3: 詢問菜色分類
  completed
}

class InputPage extends StatefulWidget {
  final Function(String query, String? category, String? mood) onComplete;
  const InputPage({required this.onComplete, super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController _textController = TextEditingController();
  final _audioRecorder = Record();
  bool _isListening = false;
  String? _audioPath;

  InputStage _currentStage = InputStage.askingMood; // <--- 初始階段改為 askingMood
  String _avatarDialogue = "";
  String _currentQueryText = "";
  String? _selectedCategory;
  String? _selectedMood;

  // --- Video Player ---
  VideoPlayerController? _videoController;
  String? _currentVideoPath; // 目前播放的影片路徑
  // Timer? _replayTimer; // 用於影片播放完畢後的延遲（如果需要）
  // --------------------

  // --- 使用 keyword_mappings.dart 中的標準列表 ---
  final List<String> _categories = standardCategories;
  final List<String> _moods = standardMoods; // ["低落", "疲憊", "放鬆", "快樂", "焦慮", "懷舊", "忙碌"]
  // ---------------------------------------------

  // --- 新增：預設的菜名列表 (已移除 "的做法" 後綴) ---
  final List<String> _presetRecipeNames = [
    "奶油蘑菇濃湯", "咖啡椰奶凍", "草莓冰淇淋", "蒜香花椰菜", "蛋炒飯",
    "美式炒蛋", "番茄牛肉蛋花湯", "涼拌小黃瓜", "日式肥牛丼飯", "番茄炒蛋"
  ];
  // -------------------------------------------------

  // --- 新增：用於儲存隨機選出的菜名 ---
  List<String> _randomizedRecipeNames = [];
  final Random _random = Random(); // 用於產生隨機數
  // ------------------------------------

  final String whisperBackendUrl = 'http://172.20.10.5:8000/recognize';

  @override
  void initState() {
    super.initState();
    _log.info("InputPage initState: Initializing first stage.");
    _initializeStage(_currentStage);
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _videoController?.dispose();
    _log.info("InputPage disposed.");
    super.dispose();
  }

  // --- 新增：隨機選取菜名的方法 ---
  void _updateRandomizedRecipeNames() {
    if (_presetRecipeNames.length <= 5) {
      // 如果總數少於等於5，則全部顯示
      _randomizedRecipeNames = List.from(_presetRecipeNames);
    } else {
      // 隨機選取5個不重複的菜名
      List<String> tempList = List.from(_presetRecipeNames); // 複製一份以進行操作
      tempList.shuffle(_random); // 打亂列表
      _randomizedRecipeNames = tempList.sublist(0, 5); // 取前5個
    }
    _log.info("Randomized recipe names for chips: $_randomizedRecipeNames");
  }
  // --------------------------------

  void _initializeStage(InputStage stage) {
    _log.info("Initializing stage: $stage");
    // _textController.clear(); // 在切換到 askingQuery 時，如果 Chips 選擇了，不清空
    String newDialogue;
    String? newVideoPath;

    _currentStage = stage;

    switch (_currentStage) {
      case InputStage.askingMood:
        newDialogue = "你今天的心情如何呢？";
        newVideoPath = 'assets/videos/asking_mood_avatar.mp4';
        _textController.clear();
        break;
      case InputStage.askingQuery:
        _updateRandomizedRecipeNames(); // <--- 在進入此階段時，更新隨機菜名列表
        newDialogue = "今天你想要做什麼料理？";
        newVideoPath = 'assets/videos/asking_query_avatar.mp4';
        // 如果 _currentQueryText 有值，不清空 _textController，以便用戶看到之前的選擇或輸入
        if (_currentQueryText.isEmpty) {
          _textController.clear();
        } else {
          _textController.text = _currentQueryText; // 如果是返回或之前有值，保留
          _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
        }
        break;
      case InputStage.askingCategory:
        newDialogue = "有特別偏好哪些類別的料理嗎？";
        newVideoPath = 'assets/videos/asking_category_avatar.mp4';
        _textController.clear();
        break;
      case InputStage.completed:
        newDialogue = "好的，我來幫你找找！";
        newVideoPath = null;
        _videoController?.pause();
        _log.info("Input completed, submitting...");
        _submit();
        break;
    }

    if (mounted) {
      setState(() {
        _avatarDialogue = newDialogue;
      });
    }

    if (newVideoPath != null && newVideoPath != _currentVideoPath) {
      _playAvatarVideo(newVideoPath);
    } else if (newVideoPath == null && _videoController != null) {
      _videoController?.dispose().then((_) {
         if (mounted) setState(() => _videoController = null);
      });
    }
    // _currentVideoPath 的更新移到 _playAvatarVideo 成功播放後
  }

  Future<void> _playAvatarVideo(String videoAssetPath) async {
    _log.info("Attempting to play video: $videoAssetPath");
    if (_videoController?.dataSource == videoAssetPath && _videoController!.value.isInitialized) {
        await _videoController!.seekTo(Duration.zero);
        await _videoController!.play();
        if (mounted) setState(() { _currentVideoPath = videoAssetPath;}); // 確保更新
        return;
    }
    await _videoController?.dispose();
    _videoController = null;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    try {
      _videoController = VideoPlayerController.asset(videoAssetPath);
      await _videoController!.initialize();
      if (!mounted) { await _videoController?.dispose(); return; }
      await _videoController!.setLooping(false);
      await _videoController!.play();
      _videoController!.addListener(_videoPlaybackListener);
      if (mounted) setState(() { _currentVideoPath = videoAssetPath; }); // 更新 Key
      _log.info("Video playing (once): $videoAssetPath");
    } catch (error, stackTrace) {
      _log.severe("Error initializing video: $videoAssetPath", error, stackTrace);
      if (mounted) {
        setState(() {
          _currentVideoPath = null;
          _avatarDialogue = "抱歉，引導動畫載入失敗了！\n但您仍然可以繼續操作。";
        });
      }
    }
  }

  // 影片播放監聽邏輯
  void _videoPlaybackListener() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (_videoController!.value.position >= _videoController!.value.duration &&
        !_videoController!.value.isLooping &&
        _videoController!.value.isPlaying) {
      _log.info("Video ${_videoController!.dataSource} finished playing.");
      if (mounted) {
        // 影片播放完畢
      }
    }
  }

  // --- 新增：點擊影片區域時重播 ---
  void _replayCurrentVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.seekTo(Duration.zero);
      _videoController!.play();
      _log.info("Replaying video: ${_videoController!.dataSource}");
    } else if (_currentVideoPath != null) {
      _playAvatarVideo(_currentVideoPath!); // 嘗試重新播放
    }
  }
  // -------------------------------

  // --- 修改：處理「下一步/完成」按鈕，加入關鍵字提取 ---
  void _handleNextOrComplete() {
    FocusScope.of(context).unfocus();
    String currentInputFromTextField = _textController.text.trim();
    _log.info("Next/Complete pressed. Stage: $_currentStage, TextField Input: '$currentInputFromTextField', Query: '$_currentQueryText', Category: $_selectedCategory, Mood: $_selectedMood");

    InputStage nextStage = _currentStage;

    switch (_currentStage) {
      case InputStage.askingMood:
        // 優先使用 TextField 的輸入進行匹配，如果為空再看 Chip 的選擇
        if (currentInputFromTextField.isNotEmpty) {
          String? extractedMood = extractKeyword(currentInputFromTextField, moodKeywords, _moods);
          if (extractedMood != null) {
            _selectedMood = extractedMood;
            _log.info("心情階段：透過文字輸入 '$currentInputFromTextField' 匹配到標準心情: '$_selectedMood'");
          } else {
            // 如果文字輸入不匹配任何關鍵字，但用戶可能之前點選過 Chip，則保留 Chip 的選擇
            // 如果 Chip 也沒選，則視為跳過
            _log.info("心情階段：文字輸入 '$currentInputFromTextField' 未匹配，將依賴 Chip 選擇或視為跳過。");
             _selectedMood ??= null; // 強調跳過
          }
        } else if (_selectedMood == null) { // 文字框為空，Chip 也沒選
          _selectedMood = null;
          _log.info("心情階段：輸入為空，且未點選 Chip，跳過。");
        }
        // _selectedMood 可能已透過 Chip 點擊設定
        _log.info("階段1 (心情) 確認: $_selectedMood");
        nextStage = InputStage.askingQuery;
        break;

      case InputStage.askingQuery:
        // 菜名/關鍵字直接使用 TextField 的最終內容
        _currentQueryText = currentInputFromTextField;
        _log.info("階段2 (菜名/關鍵字) 確認: '$_currentQueryText'");
        nextStage = InputStage.askingCategory;
        break;

      case InputStage.askingCategory:
        if (currentInputFromTextField.isNotEmpty) {
          String? extractedCategory = extractKeyword(currentInputFromTextField, categoryKeywords, _categories);
          if (extractedCategory != null) {
            _selectedCategory = extractedCategory;
            _log.info("分類階段：透過文字輸入 '$currentInputFromTextField' 匹配到標準分類: '$_selectedCategory'");
          } else {
            _selectedCategory ??= null;
            _log.info("分類階段：文字輸入 '$currentInputFromTextField' 未匹配，將依賴 Chip 選擇或視為跳過。");
          }
        } else if (_selectedCategory == null) {
          _selectedCategory = null;
          _log.info("分類階段：輸入為空，且未點選 Chip，跳過。");
        }
        _log.info("階段3 (分類) 確認: $_selectedCategory");
        nextStage = InputStage.completed;
        break;
      case InputStage.completed:
        break;
    }
    _initializeStage(nextStage);
  }
  // ---------------------------------------------------

  void _submit() {
    _log.info("最終提交：心情='$_selectedMood', 菜名='$_currentQueryText', 分類='$_selectedCategory'");
    widget.onComplete(_currentQueryText, _selectedCategory, _selectedMood);
  }

  // --- 錄音、權限、網路請求相關函數 (保持不變) ---
  void _toggleRecording() async {
    if (_isListening) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }
  Future<bool> _requestPermission() async {
     var status = await Permission.microphone.request();
     if (!status.isGranted) _log.warning("麥克風權限被拒絕");
     return status.isGranted;
  }
  Future<void> _startRecording() async {
    bool hasPermission = await _requestPermission();
    if (!hasPermission) { _showSnackBar("需要麥克風權限才能進行語音輸入"); return; }
    try {
      if (await _audioRecorder.isRecording()) { _log.info("錄音器已經在錄音中"); return; }
      final Directory tempDir = await getTemporaryDirectory();
      _audioPath = '${tempDir.path}/temp_audio.wav';
      final file = File(_audioPath!);
      if (await file.exists()){ await file.delete(); _log.info("舊的臨時錄音檔已刪除: $_audioPath"); }
      await _audioRecorder.start( path: _audioPath!, encoder: AudioEncoder.wav, );
      _log.info("錄音開始，儲存至: $_audioPath");
      bool isRecording = await _audioRecorder.isRecording();
      if (isRecording && mounted) { setState(() => _isListening = true); _showSnackBar("正在錄音...再次點擊麥克風停止");
      } else if (!isRecording && mounted){ _log.warning("無法開始錄音"); _showSnackBar("無法開始錄音"); }
    } catch (e, stackTrace) { _log.severe("錄音時發生錯誤", e, stackTrace); _showSnackBar("錄音失敗: $e"); if (mounted) setState(() => _isListening = false); }
  }
  Future<void> _stopRecordingAndSend() async {
     if (!_isListening || !mounted) return;
     setState(() => _isListening = false); _log.info("嘗試停止錄音...");
    try {
      await _audioRecorder.stop(); _log.info("錄音已停止。");
      if (_audioPath == null || _audioPath!.isEmpty) { _log.warning("錄音路徑為空"); _showSnackBar("無法獲取錄音檔案"); return; }
      _log.info("錄音檔案位於: $_audioPath");
      _showSnackBar("錄音結束，正在上傳辨識...");
      await _sendAudioToBackend(_audioPath!);
    } catch (e, stackTrace) { _log.severe("停止錄音或發送時發生錯誤", e, stackTrace); _showSnackBar("處理錄音失敗: $e"); }
  }
  Future<void> _sendAudioToBackend(String filePath) async {
    final audioFile = File(filePath);
    if (!await audioFile.exists() || await audioFile.length() == 0) { _showSnackBar("錄音檔案無效"); _log.severe("錄音檔案無效: $filePath"); return; }
    _log.info("準備上傳音訊檔案: $filePath 到 $whisperBackendUrl");
    try {
      var request = http.MultipartRequest('POST', Uri.parse(whisperBackendUrl));
      request.files.add(await http.MultipartFile.fromPath( 'audio_file', filePath, ));
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);
      _log.info("後端回應狀態碼: ${response.statusCode}");
      _log.info("後端回應內容 (前 500 字元): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");
      if (response.statusCode == 200) {
         try {
           final Map<String, dynamic> data = jsonDecode(response.body);
           if (mounted && data.containsKey('text')) {
             setState(() { _textController.text = data['text']; });
             _showSnackBar("辨識完成！請確認或修改後按下一步。");
           } else { _log.warning("後端回應 JSON 中缺少 'text' 欄位"); _showSnackBar("收到無法解析的回應 (缺少 'text')"); }
         } catch (e, stackTrace) { _log.severe("解析後端回應 JSON 失敗", e, stackTrace); _showSnackBar("無法解析辨識結果"); }
      } else {
         String errorMessage = "辨識失敗 (錯誤碼: ${response.statusCode})";
          try { final Map<String, dynamic> errorData = jsonDecode(response.body); if (errorData.containsKey('description')) { errorMessage = "辨識失敗: ${errorData['description']}"; } else if (errorData.containsKey('detail')) { errorMessage = "辨識失敗: ${errorData['detail']}"; } else if (errorData.containsKey('message')) { errorMessage = "辨識失敗: ${errorData['message']}"; } else { _log.warning("後端錯誤回應無詳細內容: ${response.body}"); errorMessage += "\n${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}..."; }
          } catch (_) { _log.warning("無法解析後端錯誤回應 JSON: ${response.body}"); errorMessage += "\n${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}..."; }
         _showSnackBar(errorMessage);
      }
    } on TimeoutException catch (e, stackTrace) { _log.severe("連接後端超時", e, stackTrace); _showSnackBar("連接伺服器超時，請稍後再試");
    } on SocketException catch (e, stackTrace) { _log.severe("網路/Socket 錯誤", e, stackTrace); _showSnackBar("網路連線錯誤，請檢查網路或伺服器地址/端口");
    } on http.ClientException catch (e, stackTrace) { _log.severe("HTTP 客戶端錯誤", e, stackTrace); _showSnackBar("無法連接到伺服器: $e");
    } catch (e, stackTrace) { _log.severe("發送到後端時發生未知錯誤", e, stackTrace); _showSnackBar("發生未知錯誤: $e"); }
  }
  void _showSnackBar(String message) {
     if (mounted) { ScaffoldMessenger.of(context).removeCurrentSnackBar(); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(message), duration: const Duration(seconds: 3)), ); }
  }

  // --- 修改 Chips 區域的構建方法 ---
  // --- 修改 Mood Chips，點選時更新 TextField ---
  Widget _buildMoodChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 8.0, top: 15.0),
          child: Text('請選擇或說出您的心情：', style: TextStyle(fontSize: 16, color: Colors.grey[700]))
        ),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: _moods.map((mood) {
            bool isSelected = _selectedMood == mood;
            return ChoiceChip(
              label: Text(mood),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedMood = selected ? mood : null;
                  _textController.text = selected ? mood : ""; // <--- 點選 Chip 時更新 TextField
                  if (selected) _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length)); // 將光標移到最後
                });
              },
              selectedColor: Colors.blue[100], checkmarkColor: Colors.blue[800],
              labelStyle: TextStyle(color: isSelected ? Colors.blue[800] : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0), side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!)),
              backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            );
          }).toList(),
        ),
      ],
    );
  }
  // --- 結束 Mood Chips 修改 ---

  // --- 修改 Category Chips，點選時更新 TextField ---
  Widget _buildCategoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 8.0, top: 15.0),
          child: Text('請選擇或說出一個分類：', style: TextStyle(fontSize: 16, color: Colors.grey[700]))
        ),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: _categories.map((category) {
            bool isSelected = _selectedCategory == category;
            return ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                  _textController.text = selected ? category : ""; // <--- 點選 Chip 時更新 TextField
                  if (selected) _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
                });
              },
              selectedColor: Colors.orange[100], checkmarkColor: Colors.deepOrange,
              labelStyle: TextStyle(color: isSelected ? Colors.deepOrange : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0), side: BorderSide(color: isSelected ? Colors.deepOrange : Colors.grey[300]!)),
              backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            );
          }).toList(),
        ),
      ],
    );
  }
  // --- 結束 Category Chips 修改 ---

  // --- 修改：Recipe Name Chips UI 使用 _randomizedRecipeNames ---
  Widget _buildRecipeNameChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 8.0, top: 15.0),
          child: Text('或直接選擇一道菜：', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _randomizedRecipeNames.map((recipeName) { // <--- 使用 _randomizedRecipeNames
            bool isSelected = _textController.text == recipeName;
            return ChoiceChip(
              label: Text(recipeName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _textController.text = recipeName;
                    // _currentQueryText = recipeName; // _currentQueryText 在 _handleNextOrComplete 中從 _textController 獲取
                    _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
                  } else {
                    if (_textController.text == recipeName) {
                      _textController.clear();
                      // _currentQueryText = ""; // 同上
                    }
                  }
                });
              },
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[800],
              labelStyle: TextStyle(
                color: isSelected ? Colors.green[800] : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide(
                  color: isSelected ? Colors.green : Colors.grey[300]!,
                )
              ),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            );
          }).toList(),
        ),
      ],
    );
  }
  // --- 結束 Recipe Name Chips UI 修改 ---
  // --- 結束 Chips UI 修改 ---

  Widget _buildDialogueBubble(String text) { /* ... 同之前版本 ... */
    return Container( margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), decoration: BoxDecoration( color: Colors.orange[50], borderRadius: BorderRadius.circular(15), boxShadow: [ BoxShadow( color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2), ), ], ), child: Text( text, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Colors.deepOrange[800], height: 1.5), ), );
  }


@override
Widget build(BuildContext context) {
  final Color? defaultIconForegroundColor = Theme.of(context).iconButtonTheme.style?.foregroundColor?.resolve({});
  return GestureDetector(
     onTap: () => FocusScope.of(context).unfocus(),
     child: Scaffold(
       body: SafeArea(
         child: Center(
           child: SingleChildScrollView(
             padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.center,
               children: <Widget>[
                 // --- Avatar 影片區域，移除 AnimatedSwitcher ---
                 GestureDetector(
                   // key: ValueKey<String?>(_currentVideoPath ?? 'no_video_avatar'), // 如果沒有 AnimatedSwitcher，這個 key 的作用減小，但保留也無妨
                   onTap: _replayCurrentVideo,
                   child: SizedBox(
                     width: 200,
                     height: 200,
                     child: _videoController != null && _videoController!.value.isInitialized
                         ? AspectRatio(
                             aspectRatio: _videoController!.value.aspectRatio,
                             child: VideoPlayer(_videoController!),
                           )
                         : Container( // 影片載入中、失敗或無影片時的佔位符
                             width: 100, height: 100,
                             decoration: BoxDecoration(
                               color: Colors.grey[200],
                               borderRadius: BorderRadius.circular(15.0),
                             ),
                             child: Image.asset(
                               chefAvatarPath, // 靜態備用圖片
                               width: 100, height: 100, fit: BoxFit.cover,
                               errorBuilder: (ctx, err, st) => Icon(Icons.person_rounded, size: 60, color: Colors.grey[400]),
                             )
                           ),
                   ),
                 ),
                 // --- 結束 Avatar 影片區域修改 ---
                 const SizedBox(height: 10),

                 // 對話泡泡 (保持 AnimatedSwitcher)
                 AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Container(
                      key: ValueKey<String>(_avatarDialogue),
                      child: _buildDialogueBubble(_avatarDialogue),
                    )
                 ),
                 const SizedBox(height: 20),

                  // --- 根據階段顯示對應的 Chips ---
                  if (_currentStage == InputStage.askingMood) _buildMoodChips(),
                  if (_currentStage == InputStage.askingQuery) _buildRecipeNameChips(), // <--- 呼叫 _buildRecipeNameChips
                  if (_currentStage == InputStage.askingCategory) _buildCategoryChips(),
                  // ----------------------------------
                  // 如果是詢問菜名階段，並且菜名 Chips 已顯示，則不再顯示額外的提示文字
                  if (_currentStage == InputStage.askingQuery && _randomizedRecipeNames.isEmpty) // 如果沒有隨機菜名 (理論上不會，除非 _presetRecipeNames 為空)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15.0),
                      child: Text("您可以直接說出菜名，或留空按下一步", style: TextStyle(color: Colors.grey[600])),
                    ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: _currentStage == InputStage.askingMood
                                  ? '請說出或選擇心情...'
                                  : _currentStage == InputStage.askingQuery
                                      ? '請說出或輸入想做的料理...'
                                      : '請說出或選擇分類...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            ),
                            textInputAction: _currentStage == InputStage.askingCategory ? TextInputAction.done : TextInputAction.next,
                            onSubmitted: (_) => _handleNextOrComplete(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic_rounded),
                          iconSize: 32,
                          tooltip: _isListening ? '停止錄音' : '開始語音輸入',
                          onPressed: _toggleRecording,
                          style: IconButton.styleFrom(foregroundColor: _isListening ? Colors.redAccent : defaultIconForegroundColor, backgroundColor: _isListening ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.15), padding: const EdgeInsets.all(15), shape: const CircleBorder()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  // --- 下一步/完成按鈕，可以考慮為按鈕本身或其文字加入動畫 ---
                  ElevatedButton(
                    onPressed: _handleNextOrComplete,
                    style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold) ),
                    // 按鈕文字也用 AnimatedSwitcher
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
                      },
                      child: Text(
                        _currentStage == InputStage.askingCategory ? '完成搜尋' : '下一步',
                        key: ValueKey<String>(_currentStage == InputStage.askingCategory ? '完成搜尋' : '下一步'), // Key 基於文字內容
                      ),
                    )
                  ),
                  // ----------------------------------------------------
                  const SizedBox(height: 30),
               ],
             ),
           ),
         ),
       ),
     ),
   );
}

}