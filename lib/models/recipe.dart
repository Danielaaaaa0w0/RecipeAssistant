// lib/models/recipe.dart
class Recipe {
  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl; // 暫時用 URL，之後可以是本地路徑或真實 URL

  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.imageUrl =
        'https://via.placeholder.com/150/FFA726/FFFFFF?text=Recipe', // 預設佔位圖片
  });
}

// 模擬的食譜數據 (之後應從後端獲取)
const List<Recipe> dummyRecipes = [
  Recipe(id: '1', name: '香煎太陽蛋', category: '家鄉菜', description: '簡單美味的經典早餐'),
  Recipe(id: '2', name: '法式焦糖布丁', category: '甜點', description: '香濃滑順的法式甜點'),
  Recipe(id: '3', name: '泰式綠咖哩雞', category: '異國風情', description: '辛辣夠味的泰國料理'),
  Recipe(id: '4', name: '紅燒肉', category: '家鄉菜', description: '入口即化的家常美味'),
  Recipe(id: '5', name: '巧克力熔岩蛋糕', category: '甜點', description: '暖心爆漿的巧克力甜點'),
  Recipe(
    id: '6',
    name: '墨西哥塔可餅',
    category: '異國風情',
    description: '豐富多變的墨西哥街頭小吃',
  ),
  Recipe(id: '7', name: '蔥油餅', category: '家鄉菜', description: '外酥內軟的傳統麵點'),
];
