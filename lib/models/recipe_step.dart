
class RecipeStep {
  final int stepOrder;
  final String stepInstruction;
  final String? animationCue; // 對應 Unity 的動畫提示
  final String? audioPathMandarin; // 例如 "assets/audio/recipe_steps/奶油蘑菇濃湯/step_1_mandarin.mp3"
  final String? audioPathTaiwanese;

  RecipeStep({
    required this.stepOrder,
    required this.stepInstruction,
    this.animationCue,
    this.audioPathMandarin,
    this.audioPathTaiwanese,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepOrder: json['stepOrder'] ?? 0,
      stepInstruction: json['stepInstruction'] ?? '',
      animationCue: json['animationCue'],
      audioPathMandarin: json['audioPathMandarin'], // 從 JSON 讀取
      audioPathTaiwanese: json['audioPathTaiwanese'], // 從 JSON 讀取
    );
  }
}
