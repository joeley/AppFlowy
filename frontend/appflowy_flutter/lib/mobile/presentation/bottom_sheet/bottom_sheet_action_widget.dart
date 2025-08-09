// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入主题扩展
import 'package:flowy_infra/theme_extension.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * 底部弹窗操作组件
 * 
 * 设计思想：
 * 1. **可组合性** - 可以是纯文本按钮，也可以是带图标的按钮
 * 2. **主题一致性** - 自动适配应用主题颜色
 * 3. **灵活性** - 支持自定义图标颜色和文本内容
 * 4. **可访问性** - 使用语义化的组件结构
 * 
 * 使用场景：
 * - 底部弹窗中的操作选项（如分享、删除、重命名等）
 * - 需要图标+文字组合的操作按钮
 * - 统一样式的操作列表项
 * 
 * 架构说明：
 * - 根据是否传入SVG图标自动选择渲染模式
 * - 无图标时使用OutlinedButton，有图标时使用OutlinedButton.icon
 * - 按钮样式继承主题设置，确保视觉一致性
 */
class BottomSheetActionWidget extends StatelessWidget {
  const BottomSheetActionWidget({
    super.key,
    this.svg,           // 可选的SVG图标数据
    required this.text, // 必需的按钮文本
    required this.onTap,// 必需的点击回调
    this.iconColor,     // 可选的图标颜色，不指定则使用主题色
  });

  final FlowySvgData? svg;  // SVG图标数据，为空时显示纯文本按钮
  final String text;        // 按钮显示文本
  final VoidCallback onTap; // 按钮点击事件回调
  final Color? iconColor;   // 图标颜色覆盖，用于特殊状态（如错误、警告）

  @override
  Widget build(BuildContext context) {
    // 获取图标颜色：优先使用传入的颜色，否则使用主题前景色
    final iconColor =
        this.iconColor ?? AFThemeExtension.of(context).onBackground;

    // 如果没有提供SVG图标，渲染纯文本按钮
    if (svg == null) {
      return OutlinedButton(
        // 使用主题的轮廓按钮样式，内容居中对齐
        style: Theme.of(context)
            .outlinedButtonTheme
            .style
            ?.copyWith(alignment: Alignment.center),
        onPressed: onTap,
        child: FlowyText(
          text,
          textAlign: TextAlign.center,
        ),
      );
    }

    // 渲染带图标的按钮
    return OutlinedButton.icon(
      icon: FlowySvg(
        svg!,                        // 使用断言操作符，此时svg不为空
        size: const Size.square(22.0), // 统一的图标大小
        color: iconColor,             // 应用计算后的图标颜色
      ),
      label: FlowyText(
        text,
        overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
      ),
      // 使用主题样式，图标和文本左对齐（图标在左）
      style: Theme.of(context)
          .outlinedButtonTheme
          .style
          ?.copyWith(alignment: Alignment.centerLeft),
      onPressed: onTap,
    );
  }
}
