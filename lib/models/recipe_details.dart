// lib/models/recipe_details.dart (用於 AR 頁的完整食譜數據)
import 'recipe_step.dart';

class RecipeDetails {
  final String recipeName;
  final String? difficultyStars;
  final String? difficultyText;
  final String? requiredItemsText;
  final String? calculationsText;
  final String? notesText;
  final List<RecipeStep> steps; // 加入步驟列表

  RecipeDetails({
    required this.recipeName,
    this.difficultyStars,
    this.difficultyText,
    this.requiredItemsText,
    this.calculationsText,
    this.notesText,
    required this.steps,
  });

  // 這個 fromJson 可能會比較複雜，因為它需要合併兩個 API 呼叫的結果
  // 或者後端直接提供一個包含所有資訊的 API 端點
  factory RecipeDetails.fromCombinedJson(Map<String, dynamic> detailsJson, List<dynamic> stepsJson) {
    List<RecipeStep> parsedSteps = stepsJson.map((stepData) => RecipeStep.fromJson(stepData)).toList();
    
    return RecipeDetails(
      recipeName: detailsJson['recipeName'] ?? '未知菜名',
      difficultyStars: detailsJson['difficultyStars'],
      difficultyText: detailsJson['difficultyText'],
      requiredItemsText: detailsJson['requiredItemsText'],
      calculationsText: detailsJson['calculationsText'],
      notesText: detailsJson['notesText'],
      steps: parsedSteps,
    );
  }
}