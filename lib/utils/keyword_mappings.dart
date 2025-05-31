// lib/utils/keyword_mappings.dart

// 心情選項 (與 InputPage 中的 _moods 列表對應，作為標準值)
// 這個列表也可以從外部（例如 LanguagePreferenceService 或其他設定檔）獲取，如果選項會動態變化
final List<String> standardMoods = [
  "低落", "疲憊", "放鬆", "快樂", "焦慮", "懷舊", "忙碌"
];

// 心情關鍵字映射
// 鍵 (Key): 使用者可能說出的詞彙或字串片段 (建議都用小寫以便不區分大小寫匹配)
// 值 (Value): 對應到 standardMoods 中的標準心情選項
final Map<String, String> moodKeywords = {
  // 對應 "低落"
  "低落": "低落",
  "難過": "低落",
  "不開心": "低落",
  "沮喪": "低落",
  "傷心": "低落",
  "心情不好": "低落",
  "sad": "低落", // 英文也可以考慮
  "blue": "低落",

  // 對應 "疲憊"
  "疲憊": "疲憊",
  "累": "疲憊",
  "好累": "疲憊",
  "沒力": "疲憊",
  "tired": "疲憊",

  // 對應 "放鬆"
  "放鬆": "放鬆",
  "輕鬆": "放鬆",
  "悠閒": "放鬆",
  "chill": "放鬆",
  "relax": "放鬆",

  // 對應 "快樂"
  "快樂": "快樂",
  "開心": "快樂",
  "高興": "快樂",
  "愉快": "快樂",
  "happy": "快樂",

  // 對應 "焦慮"
  "焦慮": "焦慮",
  "緊張": "焦慮",
  "不安": "焦慮",
  "煩躁": "焦慮",
  "anxious": "焦慮",

  // 對應 "懷舊"
  "懷舊": "懷舊",
  "想家": "懷舊", // 可能的情境
  "古早味": "懷舊",

  // 對應 "忙碌"
  "忙碌": "忙碌",
  "很忙": "忙碌",
  "沒時間": "忙碌", // 可能的情境，希望快速料理
  "busy": "忙碌",

  // 您可以根據需要繼續擴充這個列表
  // 考慮加入一些常見的錯別字或口語化表達
};

// 分類選項 (與 InputPage 中的 _categories 列表對應)
final List<String> standardCategories = [
  "家常菜", "甜點", "異國風情", "湯品", "健康輕食"
];

// 分類關鍵字映射
final Map<String, String> categoryKeywords = {
  // 對應 "家常菜"
  "家常": "家常菜",
  "家常菜": "家常菜",
  "日常菜": "家常菜",

  // 對應 "甜點"
  "甜點": "甜點",
  "點心": "甜點",
  "下午茶": "甜點", // 相關情境
  "dessert": "甜點",

  // 對應 "異國風情"
  "異國": "異國風情",
  "異國菜": "異國風情",
  "外國菜": "異國風情",
  "西餐": "異國風情", // 廣義
  "日式": "異國風情", // 具體
  "韓式": "異國風情",

  // 對應 "湯品"
  "湯": "湯品",
  "湯品": "湯品",
  "喝湯": "湯品",
  "soup": "湯品",

  // 對應 "健康輕食"
  "健康": "健康輕食",
  "輕食": "健康輕食",
  "沙拉": "健康輕食", // 相關菜式
  "低卡": "健康輕食",
  "養生": "健康輕食", // 也可能對應到心情的「健康」
};

// 輔助函數：從輸入文本中提取第一個匹配的標準選項
String? extractKeyword(String inputText, Map<String, String> keywordsMap, List<String> standardOptions) {
  if (inputText.isEmpty) return null;
  String lowerInput = inputText.toLowerCase(); // 轉換為小寫進行不區分大小寫匹配

  // 優先完全匹配標準選項 (如果用戶直接說出或選擇了標準詞)
  for (String option in standardOptions) {
    if (lowerInput.contains(option.toLowerCase())) { // 也將標準選項轉為小寫比較
      return option;
    }
  }

  // 如果沒有完全匹配標準選項，再遍歷關鍵字
  for (String keyword in keywordsMap.keys) {
    if (lowerInput.contains(keyword.toLowerCase())) { // 關鍵字也轉小寫
      return keywordsMap[keyword]; // 返回對應的標準選項
    }
  }
  return null; // 沒有匹配到任何關鍵字
}