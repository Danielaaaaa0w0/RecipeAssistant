// lib/models/recipe_list_item.dart
class RecipeListItem {
  final String recipeName;
  final String? recommendationDescription;
  final String? difficultyStars;
  final String? imageUrl;
  final List<String> moods;
  final List<String> categories; // <--- 新增欄位

  RecipeListItem({
    required this.recipeName,
    this.recommendationDescription,
    this.difficultyStars,
    this.imageUrl,
    this.moods = const [],
    this.categories = const [], // <--- 初始化為空列表
  });

  factory RecipeListItem.fromJson(Map<String, dynamic> json) {
    var moodsFromJson = json['moods'];
    List<String> moodsList = [];
    if (moodsFromJson is List) {
      moodsList = List<String>.from(moodsFromJson.map((item) => item.toString()));
    } else if (moodsFromJson is String) {
      moodsList = [moodsFromJson];
    }

    // 解析 categories 列表
    var categoriesFromJson = json['categories'];
    List<String> categoriesList = [];
    if (categoriesFromJson is List) {
      categoriesList = List<String>.from(categoriesFromJson.map((item) => item.toString()));
    } else if (categoriesFromJson is String) { // 如果後端可能只回傳單個分類字串
      categoriesList = [categoriesFromJson];
    }

    return RecipeListItem(
      recipeName: json['recipeName'] as String? ?? '未知菜名',
      recommendationDescription: json['recommendationDescription'] as String?,
      difficultyStars: json['difficultyStars'] as String?,
      imageUrl: json['imageUrl'] as String?,
      moods: moodsList,
      categories: categoriesList, // <--- 賦值
    );
  }
}