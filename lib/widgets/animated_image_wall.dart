// lib/widgets/animated_image_wall.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('AnimatedImageWall');

class AnimatedImageWall extends StatefulWidget {
  final List<String> imagePaths;
  final Duration imageFadeInDuration;
  final Duration wallFadeToPartialOpacityDuration;
  final Duration wallSettleDuration;
  final double finalWallOpacity;
  final VoidCallback onInitialAnimationComplete;
  // int numberOfRows; // 改為內部根據可用高度計算或由外部傳入固定值
  final double rowHeight;
  final Duration marqueeScrollDuration;
  final double? targetHeight; // 新增：允許外部傳入目標高度

  const AnimatedImageWall({
    super.key,
    required this.imagePaths,
    this.imageFadeInDuration = const Duration(milliseconds: 700),
    this.wallFadeToPartialOpacityDuration = const Duration(seconds: 1, milliseconds: 500),
    this.wallSettleDuration = const Duration(seconds: 2),
    this.finalWallOpacity = 0.1,
    required this.onInitialAnimationComplete,
    // this.numberOfRows = 5, // 移除預設值
    this.rowHeight = 120.0, // 調整預設行高，使其更大一些以減少行數
    this.marqueeScrollDuration = const Duration(seconds: 80),
    this.targetHeight, // 新增
  });

  @override
  State<AnimatedImageWall> createState() => _AnimatedImageWallState();
}

class _AnimatedImageWallState extends State<AnimatedImageWall> with TickerProviderStateMixin {
  double _wallOpacity = 0.0;
  List<AnimationController> _scrollAnimationControllers = [];
  List<List<String>> _rowImageLists = [];
  final Random _random = Random();
  bool _initialImagesFadedIn = false;
  List<List<bool>> _imageTileVisible = [];
  List<Timer> _imageFadeInTimers = [];
  int _actualNumberOfRows = 5; // 預設一個初始值

  @override
  void initState() {
    super.initState();
    if (widget.imagePaths.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialAnimationComplete();
      });
      return;
    }
    // 使用 LayoutBuilder 後，這個計算可以移到 build 方法中或第一次佈局後
    // _calculateNumberOfRows();
    // _prepareRowDataAndAnimations();
    // _startInitialWallAndImagesFadeIn();

    // 延遲初始化，等待第一次 build 獲取到 targetHeight (如果沒傳的話)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateNumberOfRows(context); // 傳入 context 以獲取 MediaQuery
        _prepareRowDataAndAnimations();
        _startInitialWallAndImagesFadeIn();
      }
    });
  }

  void _calculateNumberOfRows(BuildContext context) {
    // 如果外部傳入了 targetHeight，則使用它；否則嘗試獲取螢幕高度
    final double availableHeight = widget.targetHeight ?? MediaQuery.of(context).size.height;
    if (widget.rowHeight > 0) {
      _actualNumberOfRows = (availableHeight / widget.rowHeight).ceil();
      // 可以設定一個最小和最大行數，避免極端情況
      _actualNumberOfRows = _actualNumberOfRows.clamp(3, 10).toInt(); // 例如最少3行，最多10行
    } else {
      _actualNumberOfRows = 5; // 預設
    }
    _log.info("Calculated number of rows: $_actualNumberOfRows for height: $availableHeight and rowHeight: ${widget.rowHeight}");
  }


  void _prepareRowDataAndAnimations() {
    _scrollAnimationControllers = List.generate(_actualNumberOfRows, (index) {
      return AnimationController(
        duration: widget.marqueeScrollDuration,
        vsync: this,
      );
    });

    _rowImageLists = List.generate(_actualNumberOfRows, (rowIndex) {
      List<String> singleRowImages = [];
      List<String> shuffledPaths = List.from(widget.imagePaths)..shuffle(_random);
      // 確保每行至少有足夠圖片填滿約2-3個螢幕寬度
      // 這裡需要 BuildContext 來獲取螢幕寬度，但 initState 時 context 可能還不可用
      // 我們可以在 _calculateNumberOfRows 或 build 方法中獲取螢幕寬度並傳遞
      // 暫時使用一個估算值，或者在 _startInitialWallAndImagesFadeIn 中再調整
      double screenWidth = MediaQuery.of(context).size.width; // 假設在 build 後調用
      int numRepeats = max((screenWidth * 2.5 / (widget.rowHeight * shuffledPaths.length)).ceil(), 3);
      for (int i = 0; i < numRepeats; i++) {
        singleRowImages.addAll(shuffledPaths);
      }
      return singleRowImages;
    });

    _imageTileVisible = List.generate(
        _actualNumberOfRows,
        (rowIndex) => List.generate(_rowImageLists[rowIndex].length, (_) => false)
    );
  }

  void _startInitialWallAndImagesFadeIn() {
    if (!mounted || widget.imagePaths.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _wallOpacity = 1.0);
    });

    _imageFadeInTimers.clear();
    for (int i = 0; i < _actualNumberOfRows; i++) {
      if (i >= _rowImageLists.length) break; // 防禦性檢查
      for (int j = 0; j < _rowImageLists[i].length; j++) {
        Duration delay = Duration(milliseconds: 200 + _random.nextInt(1800));
        var timer = Timer(delay, () {
          if (mounted && i < _imageTileVisible.length && j < _imageTileVisible[i].length) {
            setState(() => _imageTileVisible[i][j] = true);
          }
        });
        _imageFadeInTimers.add(timer);
      }
    }

    Future.delayed(widget.wallSettleDuration, () {
      if (mounted) {
        _initialImagesFadedIn = true;
        setState(() => _wallOpacity = widget.finalWallOpacity);
        Future.delayed(widget.wallFadeToPartialOpacityDuration, () {
          if (mounted) {
            widget.onInitialAnimationComplete();
            for (var controller in _scrollAnimationControllers) {
              if (!controller.isAnimating) controller.repeat();
            }
            _log.info("跑馬燈動畫已啟動");
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _scrollAnimationControllers) {
      controller.dispose();
    }
    for (var timer in _imageFadeInTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  Widget _buildMarqueeRow(int rowIndex) {
    List<String> images = _rowImageLists[rowIndex];
    // 估算總寬度時，使用行高作為圖片平均寬度，乘以圖片數量
    // 乘以2是為了讓 Transform.translate 產生循環效果時有足夠的內容可以移動
    double estimatedTotalContentWidth = images.length * widget.rowHeight;

    return AnimatedBuilder(
      animation: _scrollAnimationControllers[rowIndex],
      builder: (context, child) {
        double scrollValue = _scrollAnimationControllers[rowIndex].value;
        double scrollOffset = scrollValue * estimatedTotalContentWidth;

        // 讓奇偶行滾動方向相反
        if (rowIndex.isOdd) {
          // (正向滾動，從右到左的感覺，所以 offset 為負)
          // 當 scrollOffset 增加時，實際的 translate offset 應該是負的
        } else {
          // (反向滾動，從左到右的感覺，所以 offset 為正)
          scrollOffset = -scrollOffset;
        }
        // 為了實現循環，當一個完整的圖片列表滾動完畢後，將其重置
        // scrollOffset = scrollOffset % estimatedTotalContentWidth;
        // 由於我們在 Row 中已經複製了圖片列表，所以Transform.translate 可以直接用 offset
        // 但要注意，當 offset 超過一個列表長度時，要能平滑接續

        return Transform.translate(
          // 這裡的 offset 計算需要確保圖片能循環出現
          // 一個簡單的方法是讓 Row 的寬度是預期顯示寬度的很多倍，或者動態調整
          // 由於 AnimationController.repeat() 是從 0 到 1，我們需要自己處理循環邏輯
          // 或者讓 Row 的內容非常長，然後讓 scrollOffset 在一個大範圍內變化
          // 這裡的取模是為了讓 Transform.translate 的 offset 不會無限增大
          offset: Offset(scrollOffset, 0),
          child: child,
        );
      },
      child: Row(
        // 為了製造無限滾動的錯覺，我們渲染多組圖片
        // 這裡的 images.length 已經是原始圖片的數倍了
        children: List.generate(images.length, (index) { // 直接使用 _rowImageLists 的長度
          return SizedBox(
            width: widget.rowHeight, // 假設圖片是正方形的
            height: widget.rowHeight,
            child: AnimatedOpacity(
              // 初始淡入後，圖片保持可見，除非整體牆體透明度改變
              opacity: _initialImagesFadedIn ? 1.0 : (_imageTileVisible[rowIndex][index] ? 1.0 : 0.0),
              duration: widget.imageFadeInDuration,
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.all(1.0), // 圖片間的微小間距
                child: Image.asset(
                  images[index], // 直接使用 images[index]
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(color: Colors.grey[300]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty || _rowImageLists.isEmpty) { // 如果還沒準備好數據或沒有圖片
      return const SizedBox.shrink();
    }
    // 如果 _actualNumberOfRows 尚未根據 context 計算，則在 build 時計算一次
    // 但更好的做法是在 initState 的 addPostFrameCallback 中完成
    // if (_scrollAnimationControllers.isEmpty && _actualNumberOfRows > 0) {
    //   _prepareRowDataAndAnimations(); // 確保動畫控制器已初始化
    // }


    return AnimatedOpacity(
      opacity: _wallOpacity,
      duration: _initialImagesFadedIn ? widget.wallFadeToPartialOpacityDuration : const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 嘗試讓 Column 在垂直方向上居中
        children: List.generate(_actualNumberOfRows, (rowIndex) { // 使用 _actualNumberOfRows
          if (rowIndex >= _scrollAnimationControllers.length || rowIndex >= _rowImageLists.length) {
            return const SizedBox.shrink(); // 防禦性編程
          }
          return SizedBox(
            height: widget.rowHeight,
            child: ClipRect(
              child: OverflowBox(
                alignment: rowIndex.isOdd ? Alignment.centerRight : Alignment.centerLeft,
                maxWidth: double.infinity,
                child: _buildMarqueeRow(rowIndex),
              ),
            ),
          );
        }),
      ),
    );
  }
}