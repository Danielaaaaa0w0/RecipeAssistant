// lib/screens/recommendation_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart'; // <--- 導入 Provider
import '../services/backend_url_service.dart'; // <--- 導入後端 URL 服務
import '../models/recipe_list_item.dart';
import '../models/recipe_details.dart';
import '../utils/image_mappings.dart'; // <--- 導入 image_mappings.dart
import 'package:logging/logging.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // <--- 導入頁面指示器
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // <--- 導入交錯動畫套件
import '../utils/haptic_feedback_utils.dart'; // <--- 導入
import 'dart:io'; // <--- 為了使用 SocketException

final _log = Logger('RecommendationPage');

class RecommendationPage extends StatefulWidget {
  final String query;
  final String? category;
  final String? mood;
  final Function(RecipeDetails recipeDetails) onRecipeSelectedForAR;

  const RecommendationPage({
    super.key,
    required this.query,
    this.category,
    this.mood,
    required this.onRecipeSelectedForAR,
  });

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  List<RecipeListItem> _recommendedRecipes = [];
  bool _isLoadingRecipes = true;
  bool _isFetchingDetails = false;
  final PageController _detailsPageController = PageController();

  @override
  void initState() {
    super.initState();
    _log.info("RecommendationPage initState: query='${widget.query}', category='${widget.category}', mood='${widget.mood}'");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchRecommendations();
    });
  }

  @override
  void didUpdateWidget(covariant RecommendationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.category != widget.category ||
        oldWidget.mood != widget.mood) {
      _log.info("Query parameters changed in didUpdateWidget. Fetching new recommendations.");
      _fetchRecommendations();
    } else {
      _log.info("Query parameters have not changed. Skipping fetch in didUpdateWidget.");
    }
  }

  @override
  void dispose() {
    _detailsPageController.dispose(); // <--- 釋放 PageController
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    if (!mounted) return;
    setState(() { _isLoadingRecipes = true; _recommendedRecipes = []; });

    final backendUrlService = Provider.of<BackendUrlService>(context, listen: false);
    if (!backendUrlService.isInitialized || backendUrlService.currentUrl.isEmpty) {
        _showErrorSnackBar("錯誤：後端 URL 未設定。請至設定頁面設定。");
        if(mounted) setState(() => _isLoadingRecipes = false);
        return;
    }
    final String baseUrl = '${backendUrlService.currentUrl}/api';
    
    try {
      Map<String, String> queryParams = {
        'q': widget.query, // 即使為空也傳遞，讓後端判斷
        if (widget.category != null) 'category': widget.category!,
        if (widget.mood != null) 'mood': widget.mood!,
      };

      var uri = Uri.parse('$baseUrl/recipes/recommend').replace(queryParameters: queryParams);
      _log.info("Fetching recommendations with params from: $uri");
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _recommendedRecipes = jsonData.map((data) => RecipeListItem.fromJson(data)).toList();
          });
        }
      } else {
         _log.severe("獲取推薦列表失敗: ${response.statusCode} - ${response.body}");
         _showErrorSnackBar('獲取推薦列表失敗: ${response.statusCode}');
      }
    } on SocketException catch(e, s) {
      _log.severe("網路連線錯誤 (SocketException): $e", s);
      _showErrorSnackBar("網路連線錯誤，請檢查 URL 是否正確或伺服器是否運行。");
    } catch (e, s) {
      _log.severe("獲取推薦列表時發生錯誤", e, s);
      _showErrorSnackBar('獲取推薦列表錯誤: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRecipes = false);
    }
  }

  // --- 在 _handleRecipeTap 中加入詳細日誌 ---
  Future<void> _handleRecipeTap(RecipeListItem recipeListItem) async {
    if (!mounted || _isFetchingDetails) return;
    setState(() => _isFetchingDetails = true);
    _log.info("--- Starting _handleRecipeTap for: ${recipeListItem.recipeName} ---");

    final backendUrlService = Provider.of<BackendUrlService>(context, listen: false);
    if (!backendUrlService.isInitialized || backendUrlService.currentUrl.isEmpty) {
        _showErrorSnackBar("錯誤：後端 URL 未設定。請至設定頁面設定。");
        if(mounted) setState(() => _isFetchingDetails = false);
        return;
    }
    final String baseUrl = '${backendUrlService.currentUrl}/api';

    try {
      // 1. 獲取食譜詳情
      final detailsUri = Uri.parse('$baseUrl/recipe/${Uri.encodeComponent(recipeListItem.recipeName)}');
      _log.info("Fetching details from: $detailsUri");
      final detailsResponse = await http.get(detailsUri).timeout(const Duration(seconds: 15));
      _log.info("Details API response status: ${detailsResponse.statusCode}");

      if (detailsResponse.statusCode != 200) {
        throw Exception('無法獲取食譜詳情 (狀態碼: ${detailsResponse.statusCode})');
      }
      final Map<String, dynamic> detailsJson = jsonDecode(utf8.decode(detailsResponse.bodyBytes));
      _log.info("Details JSON parsed successfully.");

      // 2. 獲取食譜步驟
      final stepsUri = Uri.parse('$baseUrl/recipe/${Uri.encodeComponent(recipeListItem.recipeName)}/steps');
      _log.info("Fetching steps from: $stepsUri");
      final stepsResponse = await http.get(stepsUri).timeout(const Duration(seconds: 15));
      _log.info("Steps API response status: ${stepsResponse.statusCode}");

      if (stepsResponse.statusCode != 200) {
        throw Exception('無法獲取食譜步驟 (狀態碼: ${stepsResponse.statusCode})');
      }
      final List<dynamic> stepsJson = jsonDecode(utf8.decode(stepsResponse.bodyBytes));
      _log.info("Steps JSON parsed successfully. Step count: ${stepsJson.length}");

      // 3. 組合數據並顯示彈窗
      final RecipeDetails completeDetails = RecipeDetails.fromCombinedJson(detailsJson, stepsJson);
      _log.info("RecipeDetails object created. Ready to show dialog.");
      
      if (mounted) {
        _showRecipeDetailsDialog(completeDetails);
      }
    } catch (e, s) {
      _log.severe("獲取食譜詳情或步驟時發生錯誤", e, s);
      if (mounted) {
        _showErrorSnackBar('獲取食譜資料時出錯: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingDetails = false);
        _log.info("--- Finished _handleRecipeTap ---");
      }
    }
  }

  // 新增一個顯示錯誤 SnackBar 的輔助方法
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent)
      );
    }
  }

  // --- 修改：顯示食譜詳情彈窗的方法 (使用 PageView) ---
  Future<void> _showRecipeDetailsDialog(RecipeDetails details) async {
    // 收集需要展示的資訊卡片
    List<Widget> detailPages = [];

    if (details.difficultyText != null && details.difficultyText!.isNotEmpty) {
      detailPages.add(_buildInfoCardPage("烹飪難度", details.difficultyText!));
    }
    if (details.requiredItemsText != null && details.requiredItemsText!.isNotEmpty) {
      detailPages.add(_buildInfoCardPage("必備原料和工具", details.requiredItemsText!));
    }
    if (details.calculationsText != null && details.calculationsText!.isNotEmpty) {
      detailPages.add(_buildInfoCardPage("精確用量 (計算)", details.calculationsText!));
    }
    if (details.notesText != null && details.notesText!.isNotEmpty) {
      detailPages.add(_buildInfoCardPage("附加內容/小提示", details.notesText!));
    }
    
    if (detailPages.isEmpty) {
        // 如果沒有任何詳細信息可以顯示（不太可能發生），可以給個提示然後返回
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('此食譜暫無詳細資訊可供展示。'))
        );
        // 檢查是否有步驟，如果沒有步驟，也不應讓用戶點擊“開始 AR”
        if (details.steps.isEmpty) return;

        // 如果只是沒有額外文字信息但有步驟，可以直接觸發 AR
        widget.onRecipeSelectedForAR(details);
        return;
    }


    return showDialog<void>(
      context: context,
      barrierDismissible: !_isFetchingDetails,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(details.recipeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), // 標題字體稍大
          contentPadding: const EdgeInsets.all(0), // 移除預設 padding，由內部控制
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9, // 對話框寬度
            height: MediaQuery.of(context).size.height * 0.5, // <--- 設定 PageView 的高度 (可調整)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: PageView(
                    controller: _detailsPageController,
                    children: detailPages,
                  ),
                ),
                if (detailPages.length > 1) // 只有多於一頁時才顯示指示器
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: SmoothPageIndicator(
                      controller: _detailsPageController,
                      count: detailPages.length,
                      effect: WormEffect( // 或其他效果如 ScrollingDotsEffect
                        dotHeight: 10,
                        dotWidth: 10,
                        activeDotColor: Theme.of(context).colorScheme.primary,
                        dotColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
              ],
            )
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween, // 按鈕左右分佈
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: <Widget>[
            TextButton(
              onPressed: _isFetchingDetails ? null : () {
                AppHaptics.lightClick(); // <---
                Navigator.of(context).pop();
              },
              child: const Text('關閉', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12) // 調整按鈕 padding
              ),
              onPressed: (_isFetchingDetails || details.steps.isEmpty) ? null : () {
                AppHaptics.mediumImpact(); // <--- 重要操作用中等強度
                Navigator.of(context).pop();
                widget.onRecipeSelectedForAR(details);
              },
              child: _isFetchingDetails
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('開始 AR 步驟！', style: TextStyle(fontSize: 16)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    ).then((_) {
        // 對話框關閉後，重置 PageController 到第一頁，以便下次打開時是第一頁
        // 需要判斷 _detailsPageController 是否還在被使用
        if (_detailsPageController.hasClients) {
             _detailsPageController.jumpToPage(0);
        }
    });
  }

  // --- 新增：建立資訊卡片頁面的輔助方法 ---
  Widget _buildInfoCardPage(String title, String content) {
    return Padding(
      padding: const EdgeInsets.all(16.0), // 給每張卡片頁面內部一些邊距
      child: SingleChildScrollView( // 確保內容過長時可以滾動
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 讓 Column 包裹內容
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.deepOrange[700]), // 標題字體加大
            ),
            const SizedBox(height: 8.0),
            Text(
              content,
              style: const TextStyle(fontSize: 17, height: 1.5), // 內容字體加大，調整行高
            ),
          ],
        ),
      ),
    );
  }
  // --------------------------------------


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingRecipes
          ? const Center(child: CircularProgressIndicator())
          : _recommendedRecipes.isEmpty
              ? Center( child: Text( "抱歉，找不到符合條件的食譜。\n請試試其他關鍵字或分類。", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600]), ), )
              
              : AnimationLimiter( // <--- 加入 AnimationLimiter 包裹 ListView
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                    itemCount: _recommendedRecipes.length,
                    itemBuilder: (context, index) {
                      final recipeItem = _recommendedRecipes[index];
                      final String imagePath = getRecipeImagePath(recipeItem.recipeName);

                      // --- 用 AnimationConfiguration 包裹每個列表項 ---
                      return AnimationConfiguration.staggeredList(
                        position: index, // 列表項的索引
                        duration: const Duration(milliseconds: 375), // 動畫時長
                        child: SlideAnimation( // 可以選擇滑動動畫
                          verticalOffset: 50.0, // 垂直滑動的偏移量
                          child: FadeInAnimation( // 也可以疊加淡入動畫
                            child: Card( // 您原本的 Card Widget
                              elevation: 3.0,
                              margin: const EdgeInsets.only(bottom: 16.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: _isFetchingDetails ? null : () => _handleRecipeTap(recipeItem),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 左側圖片 (不變)
                                      SizedBox(
                                        width: 100, height: 100,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: Image.asset(
                                            imagePath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              _log.warning("無法載入本地圖片: $imagePath", error, stackTrace);
                                              return Container(color: Colors.grey[200], child: Icon(Icons.restaurant_menu, color: Colors.grey[400], size: 40,));
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      // 右側文字資訊 (使用 Expanded 填滿剩餘空間)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recipeItem.recipeName, // 保持食譜名稱
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17, // 食譜名稱字體稍大
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6.0), // 名稱和描述/難度之間的間距

                                            // --- 修改：將難度和分類放在一行或相鄰顯示 ---
                                            Row( // 使用 Row 並排顯示難度和第一個分類 (如果有的話)
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                if (recipeItem.difficultyStars != null && recipeItem.difficultyStars!.isNotEmpty)
                                                  Text(
                                                    "難度: ${recipeItem.difficultyStars!}",
                                                    style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                                                  ),
                                                if (recipeItem.difficultyStars != null && recipeItem.difficultyStars!.isNotEmpty && recipeItem.categories.isNotEmpty)
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                                                    child: Text("·", style: TextStyle(fontSize: 14, color: Colors.grey)), // 分隔符號
                                                  ),
                                                if (recipeItem.categories.isNotEmpty)
                                                  Flexible( // 使用 Flexible 避免文字過長溢出
                                                    child: Text(
                                                      // 如果有多個分類，只顯示第一個，或用 Chip 顯示全部
                                                      // 這裡先簡單顯示第一個分類
                                                      recipeItem.categories.first,
                                                      style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            
                                            // --- 結束修改 ---

                                            // --- 修改：心情標籤的 Chip 樣式 ---
                                            if (recipeItem.moods.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Wrap(
                                                  spacing: 6.0,
                                                  runSpacing: 4.0,
                                                  children: recipeItem.moods.map((mood) {
                                                    return Chip(
                                                      label: Text(mood, style: const TextStyle(fontSize: 12, color: Colors.indigo)), // 深藍色文字
                                                      backgroundColor: Colors.indigo.withOpacity(0.1), // 非常淡的藍色背景
                                                      side: BorderSide(color: Colors.indigo.withOpacity(0.2)), // 柔和的邊框
                                                      labelPadding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0),
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      visualDensity: VisualDensity.compact,
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            // --- 結束修改 ---
                                            
                                          ],
                                        ),
                                      ),
                                      // 右側的載入指示器或箭頭 (保持不變)
                                      if (_isFetchingDetails && mounted) // 確保 mounted
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: SizedBox(width:24, height:24, child: CircularProgressIndicator(strokeWidth: 2))
                                        )
                                      else
                                        const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      // --- 動畫包裹結束 ---
                    },
                  ),
                ),
    );
  }
}