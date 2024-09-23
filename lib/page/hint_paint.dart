import 'dart:math';

import 'package:flutter/material.dart';

import '../sudoku/native_sudoku_api.g.dart';

class HintPainter extends CustomPainter {
  IndirectHint? _indirectHint;
  DirectHint? _directHint;

  double radians(double degrees) {
    return degrees * (pi / 180);
  }

  (double, double, double, double) getRegionSize(Size size, int regionType, int regionIndex) {
    double x = 0, y = 0, width = 0, height = 0;
    int row = 0, col = 0;
    if (regionType == 0) {
      //九宫
      row = regionIndex ~/ 3;
      col = regionIndex % 3;
      x = size.width / 3 * col;
      y = size.height / 3 * row;
      width = size.width / 3;
      height = size.height / 3;
    } else if (regionType == 1) {
      //行
      x = 0;
      y = size.height / 9 * regionIndex;
      width = size.width;
      height = size.height / 9;
    } else if (regionType == 2) {
      //列
      x = size.width / 9 * regionIndex;
      y = 0;
      width = size.width / 9;
      height = size.height;
    }

    return (x, y, width, height);
  }

  Offset getMarkCenter(Size size, int cellIndex, int markIndex) {
    int row = cellIndex ~/ 9;
    int col = cellIndex % 9;
    double x = size.width / 9 * col;
    double y = size.height / 9 * row;
    int markRow = markIndex ~/ 3;
    int markCol = markIndex % 3;

    x = x + size.width / 27 * (markCol + 0.5);
    y = y + size.height / 27 * (markRow + 0.5);

    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_indirectHint?.links != null) {
      if (_indirectHint!.links!.isNotEmpty) {
        Path path = Path();
        var paint = Paint();
        paint.color = Colors.orange.withOpacity(0.5);
        paint.strokeWidth = 2;
        paint.style = PaintingStyle.stroke;

        for (var link in _indirectHint!.links!) {
          int cellIndex = link!.srcCellIndex;
          int markIndex = link.srcCellValue;
          Offset startPoint = getMarkCenter(size, cellIndex, markIndex - 1);
          cellIndex = link.dstCellIndex;
          markIndex = link.dstCellValue;
          Offset endPoint = getMarkCenter(size, cellIndex, markIndex - 1);

          final double arrowSize = 6; // 箭头大小
          final double arrowAngleDegrees = 90; // 箭头的角度

          // 计算箭杆的方向角（弧度）
          double dx = endPoint.dx - startPoint.dx;
          double dy = endPoint.dy - startPoint.dy;
          double angleRadians = atan2(dy, dx);
          double halfMarkSize = size.width / 100;
          if (angleRadians == 0) {
            //水平向右
            startPoint = Offset(startPoint.dx + halfMarkSize, startPoint.dy);
            endPoint = Offset(endPoint.dx - halfMarkSize, endPoint.dy);
          } else if (angleRadians == pi / 2) {
            //垂直向下
            startPoint = Offset(startPoint.dx, startPoint.dy + halfMarkSize);
            endPoint = Offset(endPoint.dx, endPoint.dy - halfMarkSize);
          } else if (angleRadians == pi || angleRadians == -pi) {
            //水平向左
            startPoint = Offset(startPoint.dx - halfMarkSize, startPoint.dy);
            endPoint = Offset(endPoint.dx + halfMarkSize, endPoint.dy);
          } else if (angleRadians == -pi / 2) {
            //垂直向上
            startPoint = Offset(startPoint.dx, startPoint.dy - halfMarkSize);
            endPoint = Offset(endPoint.dx, endPoint.dy + halfMarkSize);
          } else if (angleRadians > 0 && angleRadians < pi / 2) {
            //斜向右下
            startPoint = Offset(startPoint.dx + halfMarkSize, startPoint.dy + halfMarkSize);
            endPoint = Offset(endPoint.dx - halfMarkSize, endPoint.dy - halfMarkSize);
          } else if (angleRadians > pi / 2 && angleRadians < pi) {
            //斜向左下
            startPoint = Offset(startPoint.dx - halfMarkSize, startPoint.dy + halfMarkSize);
            endPoint = Offset(endPoint.dx + halfMarkSize, endPoint.dy - halfMarkSize);
          } else if (angleRadians < 0 && angleRadians > -pi / 2) {
            //斜向右上
            startPoint = Offset(startPoint.dx + halfMarkSize, startPoint.dy - halfMarkSize);
            endPoint = Offset(endPoint.dx - halfMarkSize, endPoint.dy + halfMarkSize);
          } else if (angleRadians > -pi  && angleRadians < -pi/2) {
            //斜向左上
            startPoint = Offset(startPoint.dx - halfMarkSize, startPoint.dy - halfMarkSize);
            endPoint = Offset(endPoint.dx + halfMarkSize, endPoint.dy + halfMarkSize);
          }

          // 根据箭杆的方向角计算箭头的角度
          double halfArrowAngleRadians = radians(arrowAngleDegrees) / 2;
          // 计算箭头尖端的位置
          Offset tipLeft = Offset(
            endPoint.dx - arrowSize * cos(angleRadians - halfArrowAngleRadians),
            endPoint.dy - arrowSize * sin(angleRadians - halfArrowAngleRadians),
          );

          Offset tipRight = Offset(
            endPoint.dx - arrowSize * cos(angleRadians + halfArrowAngleRadians),
            endPoint.dy - arrowSize * sin(angleRadians + halfArrowAngleRadians),
          );

          // 创建路径
          path
            ..moveTo(startPoint.dx, startPoint.dy)
            ..lineTo(endPoint.dx, endPoint.dy)
            ..lineTo(tipLeft.dx, tipLeft.dy)
            ..moveTo(endPoint.dx, endPoint.dy)
            ..lineTo(tipRight.dx, tipRight.dy)
            ..close();
        }
        canvas.drawPath(path, paint);
      }
    }

    if (_directHint?.regions != null) {
      Path path = Path();
      var paint = Paint(); //2080E5
      paint.color = Colors.blue;
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;

      for (var region in _directHint!.regions) {
        var (x, y, width, height) = getRegionSize(size, region!.regionType, region.regionIndex);
        path.moveTo(x, y);
        path.lineTo(x + width, y);
        path.lineTo(x + width, y + height);
        path.lineTo(x, y + height);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    if (_indirectHint?.regions != null) {
      Path path = Path();
      var paint = Paint(); //2080E5
      paint.color = Colors.blue;
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;

      for (var region in _indirectHint!.regions!) {
        var (x, y, width, height) = getRegionSize(size, region!.regionType, region.regionIndex);
        path.moveTo(x, y);
        path.lineTo(x + width, y);
        path.lineTo(x + width, y + height);
        path.lineTo(x, y + height);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  HintPainter(this._directHint, this._indirectHint);
}
