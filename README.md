# 心意廚房 - RecipeAR Assistant 🍳 AR 食譜助手

「心意廚房」是一款使用 Flutter 和 Unity (AR) 技術開發的移動應用程式，旨在幫助使用者解決「有想為家人做菜的心意，卻因時間與技能不足卻步」的問題。透過引導式搜尋、擴增實境 (AR) 步驟展示以及多語言語音輔助，讓烹飪變得更輕鬆、更有趣。

Slogan: **有心意，就能做出好料理 - 心意廚房。**

---

## ✨ 主要功能

* **引導式食譜搜尋：**
    * 透過虛擬人物影片引導，分階段詢問使用者的**心情**、想做的**料理名稱/關鍵字**以及偏好的**菜色類別**。
    * 支援語音輸入和手動文字輸入，並允許使用者跳過某些篩選條件。
    * （未來可擴展）整合自然語言處理 (NLU) 技術，更精準地理解使用者意圖。
* **食譜推薦列表：**
    * 根據使用者的搜尋條件，從後端獲取並展示符合條件的食譜列表。
    * 每個列表項包含食譜圖片（本地資源）、名稱、難度星級、心情標籤和分類標籤。
* **食譜詳情展示：**
    * 點選推薦列表中的食譜後，以**滑動式卡片對話框 (PageView in Dialog)** 展示食譜的詳細資訊，包括烹飪難度、必備原料與工具、精確用量以及附加內容/小提示，字體放大以提升閱讀體驗。
* **AR 步驟指導：**
    * 選定食譜後，進入 AR 頁面，由虛擬人物（未來可能為 GIF 動畫）展示做菜步驟。
    * 每個步驟配有**預合成的語音檔**（支援國語和台語），可透過設定頁面或 AR 頁面內的漢堡選單切換。
    * 提供「上一步」、「下一步」、「重播一次」等控制按鈕，與 Unity AR 場景互動，播放對應動畫。
* **使用者設定：**
    * 允許使用者切換步驟語音的語言偏好（國語/台語）。
* **動態歡迎頁面：**
    * App 啟動時展示動態料理圖片牆背景，淡化後播放 App Logo、名稱和 Slogan 動畫。
    * 包含背景音樂（播放一次）和觸覺回饋效果。

---

## 🛠️ 技術棧

* **前端 (Mobile App):**
    * Flutter (目前使用版本 3.22.3)
    * 主要套件：
        * `flutter_unity_widget`: 整合 Unity AR 內容。
        * `video_player`: 用於 InputPage 的 Avatar 影片播放。
        * `audioplayers`: 用於 ARPage 的步驟語音和 WelcomePage 的背景音樂播放。
        * `provider` & `shared_preferences`: 用於全局狀態管理（如語言偏好）。
        * `http`: 與後端 API 通信。
        * `record` & `permission_handler` & `path_provider`: 用於語音輸入。
        * `logging`: 日誌記錄。
        * `smooth_page_indicator`: 用於推薦食譜詳情彈窗的頁面指示器。
        * `vibration`: 用於按鈕觸覺回饋。
* **後端 (Server):**
    * Python
    * Flask: Web 框架。
    * Neo4j Python Driver: 與 Neo4j 資料庫互動。
    * Requests & Base64: 呼叫外部 Whisper API。
    * (之前) 本地 Whisper: `openai-whisper`, `torch`。
* **資料庫 (Database):**
    * Neo4j 圖形資料庫: 儲存食譜知識圖譜（菜名、分類、心情、步驟、食材等及其關係）。
* **AR 引擎 (AR Engine):**
    * Unity: 負責 AR 內容的渲染和互動邏輯。
* **語音辨識 (ASR):**
    * 外部實驗室提供的 Whisper API (URL: `http://140.116.245.149:5002/proxy`)。

---

## 🚀 專案結構 (簡要)

* **Flutter App (`recipe_assistant`):**
    * `lib/`
        * `main.dart`: App 入口，Provider 設定。
        * `app.dart`: `MyApp` Widget，MaterialApp 設定。
        * `screens/`: 包含各個頁面 (Welcome, Input, Recommendation, AR, Settings, MainController)。
        * `widgets/`: 可重用的 UI 元件 (例如 `AnimatedImageWall`)。
        * `models/`: 資料模型 (例如 `RecipeListItem`, `RecipeDetails`, `RecipeStep`)。
        * `services/`: 服務類 (例如 `LanguagePreferenceService`)。
        * `utils/`: 工具類 (例如 `image_mappings.dart`, `keyword_mappings.dart`, `haptic_feedback_utils.dart`)。
    * `assets/`:
        * `images/`: 本地圖片資源。
        * `videos/`: Avatar 影片資源。
        * `audio/`: 背景音樂和食譜步驟語音資源。
    * `pubspec.yaml`: 專案依賴和 assets 宣告。
* **Python 後端 (`my_whisper_backend/`):**
    * `main.py`: Flask App 和 API 路由。
    * `config.py`: 設定檔 (Neo4j 連線資訊)。
    * `services/`:
        * `neo4j_service.py`: Neo4j 查詢邏輯。
        * `whisper_service.py`: 呼叫實驗室 Whisper API 的邏輯。
    * `requirements.txt`: Python 依賴。
    * `md_to_json_converter.py`: 將 Markdown 食譜轉換為 JSON 的腳本。
    * `dishes/`: 存放原始 Markdown 食譜檔案。
    * `output_json.../`: 存放轉換後的 JSON 檔案。

---

## 📋 未來展望與待辦事項

* [ ] **Unity AR 細化：** 增強 AR 模型的互動性和視覺效果。
* [ ] **Unity -> Flutter 通信：** 實現例如「動畫播放完畢」等事件的回傳。
* [ ] **NLU 整合：** 在後端引入自然語言理解，處理更複雜的用戶查詢。
* [ ] **後端安全性與效能優化。**
* [ ] **Flutter UI/UX 持續打磨：** 例如更細緻的動畫、空狀態頁面、錯誤提示。
* [ ] **測試覆蓋：** 編寫單元測試、Widget 測試和整合測試。
* [ ] **多使用者支援 (如果需要)：** 例如用戶個人收藏、歷史記錄等。

---

## ⚙️ 如何運行 (簡要)

**1. 設定後端：**
   * 進入 `my_whisper_backend` 資料夾。
   * 建立並啟動 Python 虛擬環境。
   * 安裝依賴：`pip install -r requirements.txt`。
   * 確保 Neo4j 資料庫服務已啟動並包含匯入的食譜數據。
   * 確保 `config.py` 中的 Neo4j 連線資訊正確。
   * 運行 Flask 伺服器：`python main.py` (或 `flask run --host=0.0.0.0 --port=8000`)。

**2. 設定 Flutter 前端：**
   * 進入 `recipe_assistant` (Flutter 專案) 資料夾。
   * 確保 Flutter 環境已設定 (版本 3.22.3)。
   * 執行 `flutter pub get`。
   * **修改後端 IP 地址：**
     * `lib/screens/input_page.dart` 中的 `whisperBackendUrl`。
     * `lib/screens/recommendation_page.dart` 中的 `baseUrl`。
     將其指向您後端伺服器的實際 IP 地址。
   * **Unity 專案設定：** 確保與 `flutter_unity_widget` 相關的 Unity 匯出和原生平台設定已正確完成。
   * 連接設備或啟動模擬器。
   * 運行 Flutter App：`flutter run`。

---

感謝您的閱讀！如果您有任何建議或問題，歡迎提出。