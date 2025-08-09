// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';

/**
 * 移动端快速操作按钮组件
 * 
 * 设计思想：
 * 1. **快速操作** - 提供统一样式的快速操作按钮，提升用户效率
 * 2. **视觉一致** - 所有快速操作按钮使用相同的布局和样式
 * 3. **状态管理** - 支持启用/禁用状态，自动调整视觉效果
 * 4. **可扩展性** - 支持自定义右侧附加组件（如箭头、数字等）
 * 
 * 使用场景：
 * - 设置页面中的功能入口
 * - 快速操作菜单项
 * - 工具栏按钮
 * - 任何需要左侧图标+文字+右侧附加组件的场景
 * 
 * 交互特性：
 * - 支持点击反馈（InkWell水波效果）
 * - 禁用状态下自动降低透明度和取消交互
 * - 适配触摸屏幕的指头大小和点击区域
 * 
 * 架构说明：
 * - 使用Row布局，支持左侧图标、中间文本、右侧组件
 * - 适配器模式：HSpace组件动态调整间距
 * - 通过Opacity组件控制整体状态
 */
class MobileQuickActionButton extends StatelessWidget {
  const MobileQuickActionButton({
    super.key,
    required this.onTap,        // 点击事件回调
    required this.icon,         // 左侧图标数据
    required this.text,         // 按钮文本
    this.textColor,             // 自定义文本颜色
    this.iconColor,             // 自定义图标颜色
    this.iconSize,              // 自定义图标尺寸
    this.enable = true,         // 是否启用，默认启用
    this.rightIconBuilder,      // 右侧附加组件构建器
  });

  /// 点击事件回调函数
  /// 在按钮处于启用状态时点击会触发此回调
  final VoidCallback onTap;
  
  /// 左侧显示的SVG图标
  /// 使用AppFlowy的统一图标系统，保证视觉一致性
  final FlowySvgData icon;
  
  /// 按钮显示文本
  /// 支持本地化，使用FlowyText.regular组件渲染
  final String text;
  
  /// 自定义文本颜色
  /// 为空时使用默认主题颜色
  final Color? textColor;
  
  /// 自定义图标颜色
  /// 为空时使用默认主题颜色
  final Color? iconColor;
  
  /// 自定义图标尺寸
  /// 为空时使用默认18x18的正方形尺寸
  final Size? iconSize;
  
  /// 按钮启用状态
  /// false时按钮变灰并禁用点击交互
  final bool enable;
  
  /// 右侧附加组件构建器
  /// 可用于显示箭头、数字徽章、开关等组件
  final WidgetBuilder? rightIconBuilder;

  @override
  Widget build(BuildContext context) {
    // 获取图标尺寸：优先使用自定义尺寸，否则使用默认18x18
    final iconSize = this.iconSize ?? const Size.square(18);
    
    return Opacity(
      // 根据启用状态调整整体透明度
      opacity: enable ? 1.0 : 0.5,  // 禁用时50%透明度
      child: InkWell(
        // 点击事件：仅在启用状态下响应
        onTap: enable ? onTap : null,
        // 水波效果设置：禁用状态下取消点击反馈
        overlayColor:
            enable ? null : const WidgetStatePropertyAll(Colors.transparent),
        // 取消默认的水波颜色，使用透明效果
        splashColor: Colors.transparent,
        child: Container(
          // 固定高度保证列表中按钮的一致性
          height: 52,
          // 水平内边距提供合适的点击区域
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // ===== 左侧图标区域 =====
              FlowySvg(
                icon,
                size: iconSize,
                color: iconColor,  // 自定义颜色或默认主题颜色
              ),
              // 图标与文本之间的动态间距
              // 根据图标实际宽度调整，保证总间距为30px
              HSpace(30 - iconSize.width),
              
              // ===== 中间文本区域 =====
              Expanded(
                child: FlowyText.regular(
                  text,
                  fontSize: 16,      // 正文字体大小
                  color: textColor,  // 自定义颜色或默认主题颜色
                ),
              ),
              
              // ===== 右侧附加组件区域 =====
              // 根据需要条件性显示右侧组件
              if (rightIconBuilder != null) rightIconBuilder!(context),
            ],
          ),
        ),
      ),
    );
  }
}

/**
 * 移动端快速操作分隔线组件
 * 
 * 设计思想：
 * 1. **视觉分组** - 在快速操作按钮列表中提供视觉分隔
 * 2. **极简设计** - 使用极细的分割线，不干扰主要内容
 * 3. **统一样式** - 所有快速操作列表使用相同的分隔符
 * 4. **空间效率** - 占用最小的垂直空间
 * 
 * 使用场景：
 * - 快速操作按钮列表中的分组分隔
 * - 设置页面中功能区域的分隔
 * - 任何需要细分隔线的地方
 * 
 * 技术特点：
 * - 使用系统Divider组件，自动适配主题色彩
 * - 0.5px的高度和厚度，提供细腻的视觉效果
 * - 无额外的内边距或外边距，完全适配父容器
 */
class MobileQuickActionDivider extends StatelessWidget {
  const MobileQuickActionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    // 极细的分割线，高度和厚度都是0.5像素
    // 自动使用主题的分割线颜色，适配深浅主题
    return const Divider(height: 0.5, thickness: 0.5);
  }
}
