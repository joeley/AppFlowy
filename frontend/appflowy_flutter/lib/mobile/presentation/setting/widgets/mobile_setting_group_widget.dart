// 移动端设置组组件文件
// 用于将多个设置项组织成带标题的设置组，提供统一的UI样式
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 移动端设置组组件
/// 
/// 设计思想：
/// 1. 采用组合模式，将多个设置项组织成一个逻辑组
/// 2. 提供统一的标题样式和间距规范
/// 3. 支持可选的分割线显示，用于区分不同设置组
/// 4. 使用Column布局垂直排列标题和设置项
/// 
/// 主要特性：
/// - 支持自定义组标题
/// - 接受Widget列表作为设置项内容
/// - 可控制是否显示分割线
/// - 遵循AppFlowy主题规范
class MobileSettingGroup extends StatelessWidget {
  /// 构造函数
  /// 
  /// [groupTitle] 设置组的标题文本
  /// [settingItemList] 设置项Widget列表，通常包含MobileSettingItem组件
  /// [showDivider] 是否显示底部分割线，默认为true，用于视觉上分离不同设置组
  const MobileSettingGroup({
    required this.groupTitle,
    required this.settingItemList,
    this.showDivider = true,
    super.key,
  });

  final String groupTitle; // 设置组标题，显示在所有设置项上方
  final List<Widget> settingItemList; // 设置项Widget列表，支持任意Widget但通常为MobileSettingItem
  final bool showDivider; // 控制是否在组底部显示分割线，用于视觉分组

  /// 构建设置组UI
  /// 
  /// UI结构：
  /// 1. 顶部间距 - 与前一个组件保持距离
  /// 2. 标题文本 - 使用heading4样式，主色调
  /// 3. 标题后间距 - 标题与内容的分隔
  /// 4. 设置项列表 - 展开所有设置项Widget
  /// 5. 可选分割线 - 根据showDivider决定是否显示
  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context); // 获取当前主题配置
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 左对齐布局
      children: [
        VSpace(theme.spacing.s), // 顶部间距，使用主题定义的小间距
        Text(
          groupTitle,
          style: theme.textStyle.heading4.enhanced( // 使用heading4文本样式
            color: theme.textColorScheme.primary, // 主文本颜色
          ),
        ),
        VSpace(theme.spacing.s), // 标题下方间距
        ...settingItemList, // 展开设置项列表，每个设置项独立渲染
        showDivider
            ? AFDivider(spacing: theme.spacing.m) // 显示分割线，使用中等间距
            : const SizedBox.shrink(), // 不显示分割线时使用空组件
      ],
    );
  }
}
