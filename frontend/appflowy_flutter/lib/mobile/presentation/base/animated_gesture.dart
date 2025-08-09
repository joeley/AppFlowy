import 'package:appflowy/shared/feedback_gesture_detector.dart';
import 'package:flutter/material.dart';

/// 动画手势检测器 - 提供触摸反馈的交互式组件
/// 
/// 这是一个高级的手势检测组件，专门设计用于提升移动端用户交互体验。
/// 它结合了视觉动画反馈和触觉反馈，为用户提供流畅且直观的交互感受。
/// 
/// 设计思想：
/// 1. 微交互原则：通过细微的缩放动画提供即时的视觉反馈
/// 2. 多感官体验：结合视觉动画和触觉震动，增强用户感知
/// 3. 可配置性：提供丰富的参数来适应不同的UI场景需求
/// 4. 性能优化：使用AnimatedScale避免重复构建，提高渲染效率
/// 
/// 使用场景：
/// - 按钮点击效果：为自定义按钮添加专业的触摸反馈
/// - 卡片交互：在列表项或卡片上提供点击响应动画
/// - 菜单项激活：增强菜单项的可点击感知度
/// - 任何需要交互反馈的自定义组件
class AnimatedGestureDetector extends StatefulWidget {
  /// 创建一个动画手势检测器
  /// 
  /// [child] 必传参数，被包装的子组件
  /// [scaleFactor] 按下时的缩放比例，默认0.98（轻微缩小2%）
  /// [feedback] 是否启用触觉反馈，默认true
  /// [duration] 动画持续时间，默认100毫秒
  /// [alignment] 缩放中心点，默认居中
  /// [behavior] 手势检测行为，默认不透明（完全拦截点击）
  /// [onTapUp] 点击释放时的回调函数
  const AnimatedGestureDetector({
    super.key,
    this.scaleFactor = 0.98,
    this.feedback = true,
    this.duration = const Duration(milliseconds: 100),
    this.alignment = Alignment.center,
    this.behavior = HitTestBehavior.opaque,
    this.onTapUp,
    required this.child,
  });

  final Widget child;
  final double scaleFactor;
  final Duration duration;
  final Alignment alignment;
  final bool feedback;
  final HitTestBehavior behavior;
  final VoidCallback? onTapUp;

  @override
  State<AnimatedGestureDetector> createState() =>
      _AnimatedGestureDetectorState();
}

class _AnimatedGestureDetectorState extends State<AnimatedGestureDetector> {
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      // 处理点击释放事件
      onTapUp: (details) {
        // 恢复到原始大小，触发缩放动画
        setState(() => scale = 1.0);

        // 提供轻微的触觉反馈，增强用户体验
        // 使用light类型避免过强的震动干扰
        HapticFeedbackType.light.call();

        // 执行用户定义的回调函数
        // 放在最后确保动画和反馈优先执行
        widget.onTapUp?.call();
      },
      // 处理点击按下事件
      onTapDown: (details) {
        // 立即缩放到指定比例，提供即时的视觉反馈
        setState(() => scale = widget.scaleFactor);
      },
      // 使用AnimatedScale实现平滑的缩放动画
      // 相比Transform.scale，AnimatedScale提供了内置的动画插值
      child: AnimatedScale(
        scale: scale, // 当前缩放比例
        alignment: widget.alignment, // 缩放中心点
        duration: widget.duration, // 动画时长
        child: widget.child, // 被包装的实际内容
      ),
    );
  }
}
