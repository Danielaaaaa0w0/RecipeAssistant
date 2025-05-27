// lib/screens/recommendation_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/recipe_list_item.dart';
import '../models/recipe_details.dart';
import '../utils/image_mappings.dart'; // <--- 導入 image_mappings.dart
import 'package:logging/logging.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // <--- 導入頁面指示器

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
  // final String baseUrl = 'http://YOUR_COMPUTER_LOCAL_IP:8000/api'; // <--- 確認您的IP
  final String baseUrl = 'http://140.116.115.198:8000/api'; // 使用您提供的IP範例

  // --- 新增：用於 PageView 的 Controller ---
  final PageController _detailsPageController = PageController();
  // --------------------------------------

  @override
  void initState() {
    super.initState();
    _log.info("推薦頁收到查詢: '${widget.query}', 分類: ${widget.category ?? '無'}, 心情: ${widget.mood ?? '無'}");
    _fetchRecommendations();
  }

  @override
  void dispose() {
    _detailsPageController.dispose(); // <--- 釋放 PageController
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    // ... (此函數的 API 呼叫和 JSON 解析邏輯保持不變) ...
    if (!mounted) return;
    setState(() { _isLoadingRecipes = true; _recommendedRecipes = []; });
    try {
      Map<String, String> queryParams = {
        if (widget.query.isNotEmpty) 'q': widget.query,
        if (widget.category != null && widget.category!.isNotEmpty) 'category': widget.category!,
        if (widget.mood != null && widget.mood!.isNotEmpty) 'mood': widget.mood!,
      };
      var uri = Uri.parse('$baseUrl/recipes/recommend').replace(queryParameters: queryParams);
      _log.info("Fetching recommendations from: $uri");
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _recommendedRecipes = jsonData.map((data) => RecipeListItem.fromJson(data)).toList();
            _isLoadingRecipes = false;
          });
        }
      } else {
        _log.severe("獲取推薦列表失敗: ${response.statusCode} - ${response.body}");
        if (mounted) { setState(() => _isLoadingRecipes = false); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('獲取推薦列表失敗: ${response.statusCode}')), ); }
      }
    } on TimeoutException catch (e,s) {
      _log.severe("獲取推薦列表超時", e, s);
       if (mounted) { setState(() => _isLoadingRecipes = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('獲取推薦列表超時'))); }
    } catch (e,s) {
      _log.severe("獲取推薦列表時發生錯誤", e, s);
      if (mounted) { setState(() => _isLoadingRecipes = false); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('獲取推薦列表錯誤: $e')), ); }
    }
  }

  Future<void> _handleRecipeTap(RecipeListItem recipeListItem) async {
    // ... (此函數的 API 呼叫和 JSON 解析邏輯保持不變) ...
    if (!mounted || _isFetchingDetails) return;
    setState(() => _isFetchingDetails = true);
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('正在獲取 ${recipeListItem.recipeName} 的詳細資訊...'), duration: const Duration(seconds: 1)), );
    try {
      final detailsUri = Uri.parse('$baseUrl/recipe/${Uri.encodeComponent(recipeListItem.recipeName)}');
      _log.info("Fetching details from: $detailsUri");
      final detailsResponse = await http.get(detailsUri).timeout(const Duration(seconds: 15));
      Map<String, dynamic> detailsJson;
      if (detailsResponse.statusCode == 200) { detailsJson = jsonDecode(utf8.decode(detailsResponse.bodyBytes)); }
      else { throw Exception('無法獲取食譜詳情 (狀態碼: ${detailsResponse.statusCode})'); }
      final stepsUri = Uri.parse('$baseUrl/recipe/${Uri.encodeComponent(recipeListItem.recipeName)}/steps');
      _log.info("Fetching steps from: $stepsUri");
      final stepsResponse = await http.get(stepsUri).timeout(const Duration(seconds: 15));
      List<dynamic> stepsJson;
      if (stepsResponse.statusCode == 200) { stepsJson = jsonDecode(utf8.decode(stepsResponse.bodyBytes)); }
      else { throw Exception('無法獲取食譜步驟 (狀態碼: ${stepsResponse.statusCode})'); }
      final RecipeDetails completeDetails = RecipeDetails.fromCombinedJson(detailsJson, stepsJson);
      if (mounted) { setState(() => _isFetchingDetails = false); _showRecipeDetailsDialog(completeDetails); }
    } on TimeoutException catch(e,s) {
      _log.severe("獲取食譜詳情或步驟超時", e,s);
      if (mounted) { setState(() => _isFetchingDetails = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('獲取食譜資料超時'))); }
    } catch (e,s) {
      _log.severe("獲取食譜詳情或步驟時發生錯誤", e,s);
      if (mounted) { setState(() => _isFetchingDetails = false); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('獲取食譜資料錯誤: $e')), ); }
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
              child: const Text('關閉', style: TextStyle(fontSize: 16)), // 按鈕字體稍大
              onPressed: _isFetchingDetails ? null : () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: _isFetchingDetails
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('開始 AR 步驟！', style: TextStyle(fontSize: 16)), // 按鈕字體稍大
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12) // 調整按鈕 padding
              ),
              onPressed: (_isFetchingDetails || details.steps.isEmpty) ? null : () {
                Navigator.of(context).pop();
                widget.onRecipeSelectedForAR(details);
              },
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
              ? Center( /* ... 無結果提示 ... */ child: Text( "抱歉，找不到符合條件的食譜。\n請試試其他關鍵字或分類。", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600]), ), )
              : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: _recommendedRecipes.length,
                  itemBuilder: (context, index) {
                    final recipeItem = _recommendedRecipes[index];
                    // *** 使用映射表輔助函數獲取本地圖片路徑 ***
                    final String imagePath = getRecipeImagePath(recipeItem.recipeName);
                    // ****************************************

                    return Card(
                      // ... (Card 屬性不變) ...
                      elevation: 2.0, margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          // *** 修改為 Image.asset 並使用 imagePath ***
                          child: Image.asset(
                            imagePath,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              _log.warning("無法載入本地圖片: $imagePath", error, stackTrace);
                              return Container(width: 60, height: 60, color: Colors.grey[200], child: Icon(Icons.restaurant_menu, color: Colors.grey[400]));
                            },
                          ),
                          // **************************************
                        ),
                        title: Text(recipeItem.recipeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          recipeItem.recommendationDescription ?? '點擊查看詳情',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _isFetchingDetails ? const SizedBox(width:24, height:24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                        onTap: _isFetchingDetails ? null : () => _handleRecipeTap(recipeItem),
                      ),
                    );
                  },
                ),
    );
  }
}