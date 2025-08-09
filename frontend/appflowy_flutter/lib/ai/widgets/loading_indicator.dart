/// AI加载指示器组件
/// 
/// 提供一个动态的加载指示器，用于显示AI正在处理的状态
/// 使用三个彩色圆点的波浪动画效果

import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// AI响应生成动画指示器
/// 
/// 显示一个动态的加载指示器，表示AI正在生成响应
/// 包含可选的文本和三个彩色圆点的波浪动画
class AILoadingIndicator extends StatelessWidget {
  const AILoadingIndicator({
    super.key,
    this.text = "",  // 显示在动画前的提示文本
    this.duration = const Duration(seconds: 1),  // 一个完整动画周期的时长
  });

  // 加载指示器前的提示文本
  final String text;
  // 动画周期时长
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // 将动画周期分为5个时间片段，用于控制每个圆点的动画节奏
    final slice = Duration(milliseconds: duration.inMilliseconds ~/ 5);
    return SelectionContainer.disabled(  // 禁用文本选择
      child: SizedBox(
        height: 20,
        child: SeparatedRow(
          separatorBuilder: () => const HSpace(4),  // 圆点间距
          children: [
            // 显示提示文本
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4.0),
              child: FlowyText(
                text,
                color: Theme.of(context).hintColor,  // 使用主题的提示颜色
              ),
            ),
            // 第一个圆点：紫色，立即开始动画
            buildDot(const Color(0xFF9327FF))
                .animate(onPlay: (controller) => controller.repeat())  // 循环播放
                .slideY(duration: slice, begin: 0, end: -1)           // 向上移动
                .then()
                .slideY(begin: -1, end: 1)                            // 向下移动
                .then()
                .slideY(begin: 1, end: 0)                             // 回到中间
                .then()
                .slideY(duration: slice * 2, begin: 0, end: 0),       // 保持位置
            // 第二个圆点：粉红色，延迟一个时间片段后开始动画
            buildDot(const Color(0xFFFB006D))
                .animate(onPlay: (controller) => controller.repeat())  // 循环播放
                .slideY(duration: slice, begin: 0, end: 0)            // 初始等待
                .then()
                .slideY(begin: 0, end: -1)                            // 向上移动
                .then()
                .slideY(begin: -1, end: 1)                            // 向下移动
                .then()
                .slideY(begin: 1, end: 0)                             // 回到中间
                .then()
                .slideY(begin: 0, end: 0),                            // 保持位置
            // 第三个圆点：黄色，延迟两个时间片段后开始动画
            buildDot(const Color(0xFFFFCE00))
                .animate(onPlay: (controller) => controller.repeat())  // 循环播放
                .slideY(duration: slice * 2, begin: 0, end: 0)        // 初始等待更长时间
                .then()
                .slideY(duration: slice, begin: 0, end: -1)           // 向上移动
                .then()
                .slideY(begin: -1, end: 1)                            // 向下移动
                .then()
                .slideY(begin: 1, end: 0),                            // 回到中间
          ],
        ),
      ),
    );
  }

  /// 构建单个圆点
  /// 
  /// 创建一个指定颜色的小圆点，用于动画显示
  Widget buildDot(Color color) {
    return SizedBox.square(
      dimension: 4,  // 4x4像素的正方形
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),  // 圆角半径为2，形成圆形
        ),
      ),
    );
  }
}
