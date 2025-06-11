// lib/screens/main_controller_page.dart (修改後)
import 'package:flutter/material.dart';
import 'input_page.dart';
import 'recommendation_page.dart';
import 'ar_page.dart';
import 'settings_page.dart';
import '../models/recipe_details.dart';
import 'package:logging/logging.dart';
import '../utils/haptic_feedback_utils.dart'; // 導入觸覺回饋


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
  RecipeDetails? _recipeForAR;

  final List<String> _pageTitles = ['查詢食譜', '為您推薦', 'AR 食譜步驟', '設定'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleSearchSubmitted(String query, String? category, String? mood) {
    _log.info("Search submitted: Query='$query', Category='$category', Mood='$mood'");
    if (!mounted) return;
    setState(() {
      _currentQuery = query;
      _currentCategory = category;
      _currentMood = mood;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _handleStartAR(RecipeDetails recipeDetails) {
    _log.info("Starting AR for recipe: ${recipeDetails.recipeName}");
    if (!mounted) return;
    setState(() { _recipeForAR = recipeDetails; });
    if (_pageController.hasClients) {
      _pageController.animateToPage(2, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }
  
  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() { _currentPageIndex = index; });
  }

  void _onBottomNavTapped(int index) {
    AppHaptics.lightClick();
    if (!mounted) return;

    // --- 修改：加入禁用 AR 頁面跳轉的邏輯 ---
    if (index == 2 && _recipeForAR == null) {
      // 如果目標是 AR 頁，但還沒有選定食譜
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先選擇一道食譜後，才能進入 AR 模式喔！'),
          duration: Duration(seconds: 2),
        ),
      );
      return; // 阻止跳轉
    }
    // -------------------------------------

    _pageController.jumpToPage(index);
    // onPageChanged 會處理 _currentPageIndex 的更新
  }

  void _navigateToSettings() {
    AppHaptics.lightClick();
    _onBottomNavTapped(3); // 跳轉到設定頁面 (索引為3)
  }

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? appBar;
    
    // --- 修改 AppBar，加入設定按鈕 ---
    List<Widget> actions = [];
    // 在 InputPage 和 RecommendationPage 顯示設定按鈕
    if (_currentPageIndex == 0 || _currentPageIndex == 1) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '設定',
          onPressed: _navigateToSettings,
        )
      );
    }
    
    if (_currentPageIndex == 2) { // ARPage
      appBar = null;
    } else {
      appBar = AppBar(
        title: Text(_pageTitles[_currentPageIndex]),
        leading: _currentPageIndex == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                },
              )
            : null,
        automaticallyImplyLeading: false,
        actions: actions.isNotEmpty ? actions : null,
      );
    }
    // --- 結束修改 ---

    final bool isPageViewScrollable = _currentPageIndex >= 2;

    return Scaffold(
      appBar: appBar,
      body: PageView(
        controller: _pageController,
        physics: isPageViewScrollable
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        children: <Widget>[
          InputPage(onComplete: _handleSearchSubmitted),
          RecommendationPage(
            query: _currentQuery,
            category: _currentCategory,
            mood: _currentMood,
            onRecipeSelectedForAR: _handleStartAR,
          ),
          ARPage(selectedRecipe: _recipeForAR),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPageIndex,
        onTap: _onBottomNavTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: '查詢'),
          const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '推薦'),
          // --- 修改：根據狀態改變 AR 頁面圖示的顏色 ---
          BottomNavigationBarItem(
            icon: Icon(
              Icons.view_in_ar,
              color: _recipeForAR == null ? Colors.grey : null, // 如果未選食譜，圖示變灰色
            ),
            label: 'AR'
          ),
          // -----------------------------------------
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}