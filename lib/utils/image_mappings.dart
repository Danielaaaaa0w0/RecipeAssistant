// lib/utils/image_mappings.dart

const Map<String, String> recipeImagePaths = {
  "奶油蘑菇濃湯": "assets/images/cream_mushroom_soup.jpeg",
  "美式炒蛋": "assets/images/american_scrambled_eggs.jpg",
  "咖啡椰奶凍": "assets/images/coffee_coconut_milk_jelly.jpg",
  "涼拌小黃瓜": "assets/images/cucumber_salad.jpg",
  "蛋炒飯": "assets/images/egg_fried_rice.jpg",
  "蒜香花椰菜": "assets/images/garlic_cauliflower.jpg", // 您的檔名可能是 garlic_cauliflower.jpg
  "日式肥牛丼飯": "assets/images/japanese_beef_donburi.jpg",
  "番茄炒蛋": "assets/images/scrambled_eggs_with_tomato.jpg",
  "草莓冰淇淋": "assets/images/strawberry_ice_cream.jpg",
  "番茄牛肉蛋花湯": "assets/images/tomato_beef_egg_drop_soup.jpg",
};

const String chefAvatarPath = "assets/images/chef_avatar.jpg";

// --- 新增：獲取所有食譜圖片路徑列表 (用於動態牆) ---
final List<String> allRecipeImagePathsForWall = recipeImagePaths.values.toList();
// ----------------------------------------------------

String getRecipeImagePath(String recipeName, {String defaultPath = "assets/images/default_recipe_image.png"}) {
  String cleanRecipeName = recipeName.endsWith("的做法")
      ? recipeName.substring(0, recipeName.length - 3)
      : recipeName;
  return recipeImagePaths[cleanRecipeName] ?? defaultPath;
}