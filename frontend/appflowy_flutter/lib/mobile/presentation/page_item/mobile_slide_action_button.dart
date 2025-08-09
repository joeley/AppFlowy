/// 移动端滑动操作按钮组件
/// 
/// 这个文件定义了移动端列表项滑动操作中使用的动作按钮组件。
/// 主要用于左右滑动显示的快捷操作按钮，如删除、编辑、收藏等。
/// 
/// 设计思想：
/// - 基于FlutterSlidable库的CustomSlidableAction进行封装
/// - 提供统一的视觉样式和交互反馈
/// - 支持自定义图标、背景色、大小等属性
/// - 集成触觉反馈，提供更好的用户体验
/// - 使用FlowySvg保持与应用整体图标风格的一致性

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 移动端滑动操作按钮组件
/// 
/// 用于在列表项滑动操作中显示快捷动作按钮的无状态UI组件。
/// 
/// 功能说明：
/// 1. 封装CustomSlidableAction，提供统一的样式和交互
/// 2. 支持自定义SVG图标、大小、背景色等属性
/// 3. 集成触觉反馈（中等强度震动）
/// 4. 使用白色图标，适配各种深色背景
/// 
/// 使用场景：
/// - 列表项的删除操作按钮
/// - 列表项的编辑操作按钮
/// - 列表项的收藏/取消收藏按钮
/// - 其他需要滑动显示的快捷操作
class MobileSlideActionButton extends StatelessWidget {
  /// 构造函数
  /// 
  /// 创建移动端滑动操作按钮组件
  /// 
  /// 参数:
  /// - [svg] 要显示的SVG图标数据
  /// - [size] 图标大小，默认32.0px
  /// - [backgroundColor] 按钮背景色，默认透明
  /// - [borderRadius] 按钮圆角半径，默认无圆角
  /// - [onPressed] 按钮点击回调函数，接收BuildContext参数
  const MobileSlideActionButton({
    super.key,
    required this.svg,
    this.size = 32.0,
    this.backgroundColor = Colors.transparent,
    this.borderRadius = BorderRadius.zero,
    required this.onPressed,
  });

  /// 要显示的SVG图标数据
  final FlowySvgData svg;
  /// 图标的大小，同时作为正方形容器的宽高
  final double size;
  /// 按钮的背景色，可以设置为不同的主题色
  final Color backgroundColor;
  /// 按钮点击的回调函数，符合Slidable组件的类型定义
  final SlidableActionCallback onPressed;
  /// 按钮的边框圆角半径，用于控制视觉外观
  final BorderRadius borderRadius;

  /// 构建滑动操作按钮UI
  /// 
  /// 创建一个包含SVG图标的可滑动操作按钮。
  /// 按钮点击时会触发触觉反馈，然后执行用户定义的回调函数。
  /// 
  /// 特性说明：
  /// - 使用CustomSlidableAction作为基础组件，与Slidable配合使用
  /// - 集成中等强度的触觉反馈，增强用户交互体验
  /// - 图标使用白色，适配各种深色背景主题
  /// - 无内边距设计，最大化可点击区域
  /// 
  /// 返回值: 完整的滑动操作按钮UI组件
  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      borderRadius: borderRadius,    // 应用自定义的边框圆角
      backgroundColor: backgroundColor,  // 应用自定义的背景色
      onPressed: (context) {
        // 先触发中等强度的触觉反馈，提供触觉确认
        HapticFeedback.mediumImpact();
        // 再执行用户定义的回调函数
        onPressed(context);
      },
      padding: EdgeInsets.zero,  // 无内边距，最大化点击区域
      child: FlowySvg(
        svg,                           // 显示自定义的SVG图标
        size: Size.square(size),       // 设置为正方形尺寸
        color: Colors.white,           // 使用白色图标，与深色背景形成对比
      ),
    );
  }
}
