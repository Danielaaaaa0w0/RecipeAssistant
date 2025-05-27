// lib/models/recipe_list_item.dart (用於推薦列表)
class RecipeListItem {
  final String recipeName;
  final String? recommendationDescription;
  final String? difficultyStars;
  final String? imageUrl;

  RecipeListItem({
    required this.recipeName,
    this.recommendationDescription,
    this.difficultyStars,
    this.imageUrl,
  });

  factory RecipeListItem.fromJson(Map<String, dynamic> json) {
    return RecipeListItem(
      recipeName: json['recipeName'] ?? '未知菜名',
      recommendationDescription: json['recommendationDescription'],
      difficultyStars: json['difficultyStars'],
      imageUrl: json['imageUrl'],
    );
  }
}