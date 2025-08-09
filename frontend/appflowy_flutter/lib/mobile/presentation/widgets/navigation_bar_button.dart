// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * 导航栏按钮组件
 * 
 * 设计思想：
 * 1. **专用性** - 专门用于导航栏的功能按钮，与UI一致
 * 2. **视觉统一** - 所有导航栏按钮使用相同的边框和尺寸
 * 3. **状态明确** - 支持启用/禁用状态，禁用时降低透明度
 * 4. **交互友好** - 使用FlowyButton提供一致的点击反馈
 * 
 * 使用场景：
 * - 页面顶部导航栏的功能按钮
 * - 工具栏中的操作按钮
 * - 任何需要与导航相关的按钮
 * 
 * 视觉特性：
 * - 带有灰色边框的圆角矩形
 * - 图标在左，文字在右的横向布局
 * - 禁用时降低透明度为30%
 * 
 * 架构说明：
 * - 使用Opacity控制整体组件的可见状态
 * - 内部使用FlowyButton统一按钮交互
 * - 通过ShapeDecoration定义外观样式
 */
class NavigationBarButton extends StatelessWidget {
  const NavigationBarButton({
    super.key,
    required this.text,     // 按钮显示文本
    required this.icon,     // 左侧显示的SVG图标
    required this.onTap,    // 点击事件回调
    this.enable = true,     // 是否启用，默认启用
  });

  /// 按钮显示文本
  /// 通常是功能名称，如"保存"、"返回"、"编辑"等
  final String text;
  
  /// 左侧显示的SVG图标
  /// 使用AppFlowy统一的图标资源，保持视觉一致性
  final FlowySvgData icon;
  
  /// 点击事件回调函数
  /// 在按钮启用时点击会触发此回调
  final VoidCallback onTap;
  
  /// 按钮启用状态
  /// false时按钮变灰并禁用点击交互
  final bool enable;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // 根据启用状态调整透明度
      opacity: enable ? 1.0 : 0.3,  // 禁用时30%透明度，提供清晰的视觉反馈
      child: Container(
        // 固定高度，与导航栏的标准高度一致
        height: 40,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            // 灰色半透明边框，不太突出但又有明确边界
            side: const BorderSide(color: Color(0x3F1F2329)),
            // 10px圆角，现代化的圆润外观
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: FlowyButton(
          // 使用内容自适应宽度，不占据不必要的空间
          useIntrinsicWidth: true,
          // 文本不自动扩展，保持紧凑布局
          expandText: false,
          // 图标与文字之间的8px间距
          iconPadding: 8,
          // 左侧SVG图标
          leftIcon: FlowySvg(icon),
          // 点击事件：仅在启用状态下响应
          onTap: enable ? onTap : null,
          // 按钮文本样式
          text: FlowyText(
            text,
            fontSize: 15.0,            // 中等字体大小
            figmaLineHeight: 18.0,     // 按照Figma设计稿的行高
            fontWeight: FontWeight.w400, // 正常字重
          ),
        ),
      ),
    );
  }
}
