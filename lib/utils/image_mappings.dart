// lib/utils/image_mappings.dart

// 食譜名稱 (鍵) 應該與您從後端獲取或 Neo4j 中儲存的 Recipe name 一致
// (假設都已經移除了 "的做法" 後綴)
const Map<String, String> recipeImagePaths = {
  "奶油蘑菇濃湯": "assets/images/cream_mushroom_soup.jpeg",
  "美式炒蛋": "assets/images/american_scrambled_eggs.jpg",
  "咖啡椰奶凍": "assets/images/coffee_coconut_milk_jelly.jpg",
  "涼拌小黃瓜": "assets/images/cucumber_salad.jpg",
  "蛋炒飯": "assets/images/egg_fried_rice.jpg",
  "蒜香花椰菜": "assets/images/garlic_cauliflower.jpg",
  "日式肥牛丼飯": "assets/images/japanese_beef_donburi.jpg",
  "番茄炒蛋": "assets/images/scrambled_eggs_with_tomato.jpg",
  "草莓冰淇淋": "assets/images/strawberry_ice_cream.jpg",
  "番茄牛肉蛋花湯": "assets/images/tomato_beef_egg_drop_soup.jpg", // 使用修正後的檔名
  // 如果有其他食譜，繼續添加...
};

// Avatar 的圖片可以直接指定
const String chefAvatarPath = "assets/images/chef_avatar.gif";

// 提供一個輔助函數來獲取圖片路徑，可以加入預設圖片邏輯
String getRecipeImagePath(String recipeName, {String defaultPath = "assets/images/default_recipe_image.png"}) {
  // 這裡可以加入邏輯，例如如果 recipeName 包含 "的做法"，先移除它
  String cleanRecipeName = recipeName.endsWith("的做法")
      ? recipeName.substring(0, recipeName.length - 3)
      : recipeName;
  return recipeImagePaths[cleanRecipeName] ?? defaultPath;
}