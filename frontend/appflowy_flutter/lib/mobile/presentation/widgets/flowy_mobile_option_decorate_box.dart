// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * AppFlowy移动端选项装饰盒组件
 * 
 * 设计思想：
 * 1. **视觉统一性** - 为选项列表提供统一的边框和背景样式
 * 2. **灵活控制** - 支持单独控制顶部和底部边框的显示隐藏
 * 3. **主题适配** - 自动使用主题颜色，支持深浅主题切换
 * 4. **无侵入性** - 作为装饰器存在，不影响子组件的功能
 * 
 * 使用场景：
 * - 设置页面中的选项列表
 * - 底部弹窗中的操作菜单
 * - 任何需要视觉分组的内容区域
 * - 数据列表项的背景装饰
 * 
 * 技术特点：
 * - 使用DecoratedBox而非Container，性能更优
 * - 边框样式可单独控制，支持复杂布局需求
 * - 颜色自动适配主题，无需手动管理
 * 
 * 架构说明：
 * - 传入的child组件会被包装在装饰盒内
 * - 装饰盒不修改child的布局和尺寸
 * - 只负责提供视觉效果，不处理交互逻辑
 */
class FlowyOptionDecorateBox extends StatelessWidget {
  const FlowyOptionDecorateBox({
    super.key,
    this.showTopBorder = true,     // 是否显示顶部边框，默认显示
    this.showBottomBorder = true,  // 是否显示底部边框，默认显示
    this.color,                    // 自定义背景颜色，为空则使用主题颜色
    required this.child,           // 被装饰的子组件
  });

  /// 是否显示顶部边框
  /// 在列表的第一个项目中通常设为false，避免与容器边框重复
  final bool showTopBorder;
  
  /// 是否显示底部边框
  /// 在列表的最后一个项目中通常设为false
  final bool showBottomBorder;
  
  /// 被装饰的子组件
  /// 该组件将被包装在装饰盒内，继承装饰样式
  final Widget child;
  
  /// 自定义背景颜色
  /// 如果为空，则使用当前主题的surface颜色
  /// 可用于特殊状态的视觉反馈（如选中、高亮等）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // 背景颜色：优先使用自定义颜色，否则使用主题的表面颜色
        color: color ?? Theme.of(context).colorScheme.surface,
        // 边框设置：只在顶部和底部添加边框
        border: Border(
          // 顶部边框：根据参数决定是否显示
          top: showTopBorder
              ? BorderSide(
                  // 使用主题的分割线颜色，保持视觉一致性
                  color: Theme.of(context).dividerColor,
                  width: 0.5,  // 极细的边框，不会抑夺主内容
                )
              : BorderSide.none,  // 不显示边框
          // 底部边框：同上
          bottom: showBottomBorder
              ? BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                )
              : BorderSide.none,
        ),
      ),
      // 子组件保持原有的布局和功能，装饰盒不做任何修改
      child: child,
    );
  }
}
