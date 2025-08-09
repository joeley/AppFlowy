import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class MobileSettingItem extends StatelessWidget {
  const MobileSettingItem({
    super.key,
    this.name,
    this.padding = const EdgeInsets.only(bottom: 4),
    this.trailing,
    this.leadingIcon,
    this.title,
    this.subtitle,
    this.onTap,
  });

  final String? name;
  final EdgeInsets padding;
  final Widget? trailing;
  final Widget? leadingIcon;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ListTile(
        title: title ?? _buildDefaultTitle(context, name),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// 构建默认标题组件
  /// 
  /// 当没有提供自定义title时，使用此方法构建默认的标题UI：
  /// 1. 可选的前导图标 + 8像素间距
  /// 2. 可扩展的文本区域，支持溢出省略
  /// 3. 使用AppFlowy主题的heading4样式和主文本颜色
  /// 
  /// [context] 构建上下文，用于获取主题
  /// [name] 设置项名称文本
  /// 
  /// Returns: 包含图标和文本的Row布局Widget
  Widget _buildDefaultTitle(BuildContext context, String? name) {
    final theme = AppFlowyTheme.of(context); // 获取当前主题配置
    return Row(
      children: [
        // 条件渲染前导图标，使用展开语法避免null检查
        if (leadingIcon != null) ...[
          leadingIcon!, // 显示前导图标
          const HSpace(8), // 图标与文本之间的8像素水平间距
        ],
        Expanded( // 文本区域可扩展，占用剩余空间
          child: Text(
            name ?? '', // 显示名称，null时显示空字符串
            style: theme.textStyle.heading4.standard( // 使用标准的heading4样式
              color: theme.textColorScheme.primary, // 主文本颜色
            ),
            overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
          ),
        ),
      ],
    );
  }
}
