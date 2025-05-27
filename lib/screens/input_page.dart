// lib/screens/input_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';
import 'package:video_player/video_player.dart'; // <--- 導入 video_player
import '../utils/image_mappings.dart'; // 確保 chefAvatarPath 在這裡或直接定義

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
  Timer? _replayTimer; // 用於影片播放完畢後的延遲（如果需要）
  // --------------------


  final List<String> _categories = ["家常菜", "甜點", "異國風情", "湯品", "健康輕食"];
  final List<String> _moods = ["隨意", "低落", "刺激", "療癒", "健康"];

  final String whisperBackendUrl = 'http://140.116.115.198:8000/recognize';

  @override
  void initState() {
    super.initState();
    _initializeStage(); // 初始化第一個階段
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _videoController?.dispose(); // <--- 釋放影片控制器
    super.dispose();
  }

  // --- 初始化或切換階段的邏輯 ---
  void _initializeStage() {
    _textController.clear();
    String newDialogue;
    String? newVideoPath;

    switch (_currentStage) {
      case InputStage.askingMood:
        final moodOptionsForSpeech = _moods.join('、');
        newDialogue = "你現在的心情如何呢？\n你可以說：$moodOptionsForSpeech，或按「下一步」跳過";
        newVideoPath = 'assets/videos/asking_mood_avatar.mp4';
        break;
      case InputStage.askingQuery:
        newDialogue = "想做什麼料理呢？\n(可以直接說菜名，或按「下一步」跳過)";
        newVideoPath = 'assets/videos/asking_query_avatar.mp4';
        break;
      case InputStage.askingCategory:
        newDialogue = "有特別偏好哪些類別的料理嗎？\n你可以說：${_categories.join('、')}，或按「下一步」跳過";
        newVideoPath = 'assets/videos/asking_category_avatar.mp4';
        break;
      case InputStage.completed:
        newDialogue = "好的，我來幫你找找！";
        newVideoPath = null;
        if (_videoController?.value.isPlaying ?? false) {
            _videoController?.pause();
        }
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
      _currentVideoPath = newVideoPath;
    } else if (newVideoPath == null && _videoController != null) {
      // 如果沒有新影片路徑，並且當前有影片控制器
      // _videoController?.pause(); // 如果想停在最後一幀
    }
  }
  
  Future<void> _playAvatarVideo(String videoAssetPath) async {
    _log.info("Attempting to play video: $videoAssetPath");
    _replayTimer?.cancel(); // 取消任何之前的重播計時器

    // 先 dispose 舊的 controller (如果有且正在播放不同的影片或未初始化)
    if (_videoController != null) {
        // 移除舊的監聽器，避免在 dispose 後還嘗試呼叫
        _videoController!.removeListener(_videoPlaybackListener);
        await _videoController!.pause();
        await _videoController!.dispose();
        _videoController = null;
        _log.info("Disposed previous video controller.");
    }
    
    if (!mounted) return;

    try {
      _videoController = VideoPlayerController.asset(videoAssetPath);
      await _videoController!.initialize();
      if (!mounted) {
        await _videoController?.dispose();
        return;
      }
      
      await _videoController!.setLooping(false); // <--- 確保只播放一次
      await _videoController!.play();
      
      _videoController!.addListener(_videoPlaybackListener);

      // 這裡的 setState({}) 是為了確保 VideoPlayer Widget 在控制器初始化後重新構建
      // 以便正確顯示影片的第一幀或播放狀態。
      if (mounted) {
        setState(() {});
      }
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
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    // 檢查影片是否播放到結尾且不是循環狀態
    if (_videoController!.value.position >= _videoController!.value.duration && 
        !_videoController!.value.isLooping) {
      _log.info("Video ${_videoController!.dataSource} finished playing.");
      // 影片播放完畢，此時可以讓用戶點擊重播
      // 不需要移除監聽器，因為我們希望用戶可以重複點擊重播
      if (mounted) {
        setState(() {
          // 可以選擇在這裡更新UI，例如顯示一個重播圖示在影片上
        });
      }
    }
  }

  // --- 新增：點擊影片區域時重播 ---
  void _replayCurrentVideo() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.seekTo(Duration.zero); // 回到影片開頭
      _videoController!.play();
      _log.info("Replaying video: ${_videoController!.dataSource}");
    } else if (_currentVideoPath != null) {
      // 如果控制器因故丟失但路徑還在，嘗試重新播放
      _playAvatarVideo(_currentVideoPath!);
    }
  }
  // -------------------------------
  // --- 處理「下一步/完成」按鈕 ---
  void _handleNextOrComplete() {
    FocusScope.of(context).unfocus();
    String currentInput = _textController.text.trim();
    _log.info("Next/Complete pressed. Stage: $_currentStage, Input: '$currentInput', Category: $_selectedCategory, Mood: $_selectedMood, Query: $_currentQueryText");

    setState(() {
      switch (_currentStage) {
        case InputStage.askingMood:
          if (currentInput.isNotEmpty) {
            final matchedMood = _moods.firstWhere(
                (m) => m.toLowerCase() == currentInput.toLowerCase(), // 直接比較
                orElse: () => "");
            if (matchedMood.isNotEmpty) _selectedMood = matchedMood;
          } else {
            _selectedMood ??= null;
          }
          _log.info("階段1 (心情) 確認: $_selectedMood (文字輸入: '$currentInput')");
          _currentStage = InputStage.askingQuery; // 進入下一階段
          break;
        case InputStage.askingQuery:
          _currentQueryText = currentInput; // 可以為空，代表跳過
          _log.info("階段2 (菜名/關鍵字) 確認: '$_currentQueryText'");
          _currentStage = InputStage.askingCategory;
          break;
        case InputStage.askingCategory:
          if (currentInput.isNotEmpty) {
            final matchedCategory = _categories.firstWhere(
                (cat) => cat.toLowerCase() == currentInput.toLowerCase(),
                orElse: () => "");
            if (matchedCategory.isNotEmpty) _selectedCategory = matchedCategory;
          } else {
            _selectedCategory ??= null;
          }
          _log.info("階段3 (分類) 確認: $_selectedCategory (文字輸入: '$currentInput')");
          _currentStage = InputStage.completed;
          break;
        case InputStage.completed:
          // 已經是完成階段，理論上按鈕文字是「完成搜尋」，再次點擊也是提交
          break;
      }
      _initializeStage(); // 更新對話、影片，並在 completed 時觸發 _submit
    });
  }
  // -----------------------------

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

  // --- 分類和心情的 Chips UI (條件顯示，Chip 點擊邏輯調整) ---
  Widget _buildMoodChips() {
    if (_currentStage != InputStage.askingMood) return const SizedBox.shrink();
    return Column( /* ... Chip UI ... */
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
              onSelected: (selected) { setState(() { _selectedMood = selected ? mood : null; }); }, // 點擊 Chip 直接設定狀態
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

  Widget _buildCategoryChips() {
    if (_currentStage != InputStage.askingCategory) return const SizedBox.shrink();
    return Column( /* ... Chip UI ... */
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
              onSelected: (selected) { setState(() { _selectedCategory = selected ? category : null; }); }, // 點擊 Chip 直接設定狀態
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
  // --- 結束 Chips UI ---

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
                   // --- Avatar 影片區域 ---
                   // --- Avatar 影片區域，加入 GestureDetector ---
                   GestureDetector( // <--- 新增 GestureDetector
                     onTap: _replayCurrentVideo, // <--- 點擊時呼叫重播
                     child: SizedBox(
                       width: 200,
                       height: 200,
                       child: _videoController != null && _videoController!.value.isInitialized
                           ? AspectRatio(
                               aspectRatio: _videoController!.value.aspectRatio,
                               child: VideoPlayer(_videoController!),
                             )
                           : Container(
                               width: 100, height: 100,
                               decoration: BoxDecoration(
                                 color: Colors.grey[200],
                                 borderRadius: BorderRadius.circular(15.0),
                               ),
                               child: Image.asset(
                                 chefAvatarPath, // 使用靜態圖片作為備用
                                 width: 100, height: 100, fit: BoxFit.cover,
                                 errorBuilder: (ctx, err, st) => Icon(Icons.person_rounded, size: 60, color: Colors.grey[400]),
                               )
                             ),
                     ),
                   ),
                   // ---------------------------------------
                   const SizedBox(height: 10),
                   // --- 對話泡泡 ---
                   _buildDialogueBubble(_avatarDialogue),
                   const SizedBox(height: 20),

                   // --- 根據階段顯示對應的 Chips ---
                   if (_currentStage == InputStage.askingMood) _buildMoodChips(),
                   if (_currentStage == InputStage.askingCategory) _buildCategoryChips(),
                   // 如果是詢問菜名階段，可以不顯示 Chips，或顯示一個通用提示
                   if (_currentStage == InputStage.askingQuery)
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
                   ElevatedButton(
                     onPressed: _handleNextOrComplete,
                     style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold) ),
                     child: Text(_currentStage == InputStage.askingCategory ? '完成搜尋' : '下一步'),
                   ),
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