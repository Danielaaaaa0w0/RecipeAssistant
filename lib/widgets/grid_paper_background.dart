// lib/widgets/grid_paper_background.dart (新建檔案)
import 'package:flutter/material.dart';

/// 一個自訂的 Widget，用於繪製方格紙背景
class GridPaperBackground extends StatelessWidget {
  const GridPaperBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 使用一個溫暖、不刺眼的米黃色作為背景
      color: const Color(0xFFFDF9F3), // 稍微調整背景色，使其更柔和
      child: CustomPaint(
        painter: GridPaperPainter(
          // 將格線顏色改為灰階且更透明
          gridColor: Colors.black.withOpacity(0.08),
        ),
        child: Container(), // CustomPaint 需要一個 child
      ),
    );
  }
}

/// 用於繪製方格線的 CustomPainter
class GridPaperPainter extends CustomPainter {
  final Color gridColor;
  final double gridStep;

  GridPaperPainter({
    required this.gridColor,
    this.gridStep = 20.0, // 所有格線的間距
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- 修改：只用一種畫筆和一種間距，實現統一的細線 ---
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.4; // 設定更細的線條寬度

    // 繪製垂直線
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 繪製水平線
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // --- 結束修改 ---
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // 背景是靜態的，不需要重繪
  }
}