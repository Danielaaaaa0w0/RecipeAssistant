// lib/screens/main_controller_page.dart
import 'package:flutter/material.dart';
import 'input_page.dart';
import 'recommendation_page.dart';
import 'ar_page.dart';
import 'settings_page.dart';
import '../models/recipe_details.dart'; // <--- 導入模型
import 'package:logging/logging.dart';

final _log = Logger('MainControllerPage');

class MainControllerPage extends StatefulWidget {
  const MainControllerPage({super.key});

  @override
  State<MainControllerPage> createState() => _MainControllerPageState();
}

class _MainControllerPageState extends State<MainControllerPage> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  String _currentQuery = "";
  String? _currentCategory;
  String? _currentMood;

  // --- 新增：儲存要傳遞給 ARPage 的食譜詳情 (包含步驟) ---
  RecipeDetails? _recipeForAR;
  // ----------------------------------------------------

  final List<String> _pageTitles = ['查詢食譜', '為您推薦', 'AR 食譜步驟', '設定']; // AR 頁標題更新
  bool _isPageViewScrollable = false;

  // 從 InputPage 收集查詢條件，並跳轉到 RecommendationPage
  void _handleSearchSubmitted(String query, String? category, String? mood) {
    _log.info("Search submitted: Query='$query', Category='$category', Mood='$mood'");
    setState(() {
      _currentQuery = query;
      _currentCategory = category;
      _currentMood = mood;
      _recipeForAR = null; // 清除之前的 AR 食譜數據
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        1, // RecommendationPage 的索引
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) { // 確保在 frame 結束後更新
        if (mounted) {
           setState(() {
             _currentPageIndex = 1;
             _isPageViewScrollable = false; // 到推薦頁後，先禁止左右滑動 (點擊觸發去AR)
           });
        }
      });
    }
  }

  // --- 新增：從 RecommendationPage 接收選中的食譜，並跳轉到 ARPage ---
  void _handleStartAR(RecipeDetails recipeDetails) {
    _log.info("Starting AR for recipe: ${recipeDetails.recipeName}");
    setState(() {
      _recipeForAR = recipeDetails; // 儲存食譜數據
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        2, // ARPage 的索引
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           setState(() {
             _currentPageIndex = 2;
             _isPageViewScrollable = true; // 進入 AR 頁後，允許與 Settings 頁滑動
           });
        }
      });
    }
  }
  // --------------------------------------------------------------


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget? appBar;
    if (_currentPageIndex == 0) {
      appBar = AppBar( title: Text(_pageTitles[_currentPageIndex]), );
    } else if (_currentPageIndex == 1) { // RecommendationPage
       appBar = AppBar(
         title: Text(_pageTitles[_currentPageIndex]),
         leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) { setState(() { _currentPageIndex = 0; _isPageViewScrollable = false; }); }});
            },
          ),
        );
    } else if (_currentPageIndex == 2) { // ARPage
      appBar = AppBar(
         // title: Text(_recipeForAR?.recipeName ?? _pageTitles[_currentPageIndex]), // 可以動態顯示菜名
         title: Text(_pageTitles[_currentPageIndex]), // 或者保持固定標題
         backgroundColor: Colors.transparent,
         elevation: 0,
         leading: IconButton( // 從 AR 頁返回推薦頁
            icon: Icon(Icons.arrow_back, color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white70),
            onPressed: () {
              _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) { setState(() { _currentPageIndex = 1; _isPageViewScrollable = false; }); }});
            },
          ),
       );
    } else { // SettingsPage
       appBar = AppBar( title: Text(_pageTitles[_currentPageIndex]), automaticallyImplyLeading: false, );
    }

    ScrollPhysics pageViewPhysics;
    if (_currentPageIndex <= 1) { // InputPage, RecommendationPage 禁止左右滑動
      pageViewPhysics = const NeverScrollableScrollPhysics();
    } else { // ARPage, SettingsPage 允許左右滑動
      pageViewPhysics = const PageScrollPhysics();
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      body: PageView(
        controller: _pageController,
        physics: pageViewPhysics,
        onPageChanged: (index) {
          if (index > 1 && _isPageViewScrollable) { // 只在 AR 和 Settings 之間滑動時更新
             setState(() { _currentPageIndex = index; });
          }
        },
        children: <Widget>[
          InputPage(onComplete: _handleSearchSubmitted),
          RecommendationPage(
            query: _currentQuery,
            category: _currentCategory,
            mood: _currentMood,
            onRecipeSelectedForAR: _handleStartAR, // <--- 傳遞新的回呼
          ),
          ARPage(selectedRecipe: _recipeForAR), // <--- 傳遞選中的食譜數據
          const SettingsPage(),
        ],
      ),
    );
  }
}