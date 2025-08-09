import 'package:flutter/material.dart';

/// 圆角下划线Tab指示器
/// 
/// 功能说明：
/// 1. 自定义Tab标签的下划线指示器
/// 2. 支持圆角边框样式
/// 3. 支持固定宽度设置
/// 4. 支持自定义颜色和边框样式
/// 
/// 使用场景：
/// - TabBar的自定义indicator
/// - 需要固定宽度的指示器
/// - 需要圆角效果的Tab指示器
class RoundUnderlineTabIndicator extends Decoration {
  const RoundUnderlineTabIndicator({
    this.borderRadius,
    this.borderSide = const BorderSide(width: 2.0, color: Colors.white),
    this.insets = EdgeInsets.zero,
    required this.width,
  });

  /// 圆角半径
  final BorderRadius? borderRadius;
  
  /// 边框样式（颜色、宽度等）
  final BorderSide borderSide;
  
  /// 内边距
  final EdgeInsetsGeometry insets;
  
  /// 指示器的固定宽度
  final double width;

  /// 从另一个装饰器插值到当前装饰器
  /// 用于动画过渡效果
  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a is UnderlineTabIndicator) {
      return UnderlineTabIndicator(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        insets: EdgeInsetsGeometry.lerp(a.insets, insets, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  /// 从当前装饰器插值到另一个装饰器
  /// 用于动画过渡效果
  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b is UnderlineTabIndicator) {
      return UnderlineTabIndicator(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        insets: EdgeInsetsGeometry.lerp(insets, b.insets, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  /// 创建绘制器对象
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _UnderlinePainter(this, borderRadius, onChanged);
  }

  /// 计算指示器的矩形区域
  /// 
  /// 功能说明：
  /// 1. 根据Tab的矩形区域计算指示器位置
  /// 2. 指示器居中显示在Tab下方
  /// 3. 使用固定宽度而非Tab的全宽
  Rect _indicatorRectFor(Rect rect, TextDirection textDirection) {
    final Rect indicator = insets.resolve(textDirection).deflateRect(rect);
    // 计算中心点，确保指示器居中对齐
    final center = indicator.center.dx;
    return Rect.fromLTWH(
      center - width / 2.0,  // 左侧位置：中心点减去半个宽度
      indicator.bottom - borderSide.width,  // 底部位置
      width,  // 固定宽度
      borderSide.width,  // 高度为边框宽度
    );
  }

  /// 获取裁剪路径
  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    if (borderRadius != null) {
      // 如果有圆角，创建圆角矩形路径
      return Path()
        ..addRRect(
          borderRadius!.toRRect(_indicatorRectFor(rect, textDirection)),
        );
    }
    // 否则创建普通矩形路径
    return Path()..addRect(_indicatorRectFor(rect, textDirection));
  }
}

/// 下划线绘制器
/// 
/// 负责实际绘制Tab指示器的下划线
class _UnderlinePainter extends BoxPainter {
  _UnderlinePainter(
    this.decoration,
    this.borderRadius,
    super.onChanged,
  );

  /// 装饰器配置
  final RoundUnderlineTabIndicator decoration;
  
  /// 圆角半径
  final BorderRadius? borderRadius;

  /// 绘制指示器
  /// 
  /// 功能说明：
  /// 1. 根据是否有圆角选择不同的绘制方式
  /// 2. 支持圆角矩形和直线两种样式
  /// 3. 自动计算指示器位置和大小
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final Rect rect = offset & configuration.size!;
    final TextDirection textDirection = configuration.textDirection!;
    final Paint paint;
    
    if (borderRadius != null) {
      // 圆角模式：绘制圆角矩形
      paint = Paint()..color = decoration.borderSide.color;
      final Rect indicator = decoration._indicatorRectFor(rect, textDirection);
      // 创建圆角矩形
      final RRect rrect = RRect.fromRectAndCorners(
        indicator,
        topLeft: borderRadius!.topLeft,
        topRight: borderRadius!.topRight,
        bottomRight: borderRadius!.bottomRight,
        bottomLeft: borderRadius!.bottomLeft,
      );
      canvas.drawRRect(rrect, paint);
    } else {
      // 直线模式：绘制圆角端点的直线
      paint = decoration.borderSide.toPaint()..strokeCap = StrokeCap.round;
      final Rect indicator = decoration
          ._indicatorRectFor(rect, textDirection)
          .deflate(decoration.borderSide.width / 2.0);  // 收缩一半边框宽度，确保线条不会被裁剪
      canvas.drawLine(indicator.bottomLeft, indicator.bottomRight, paint);
    }
  }
}
