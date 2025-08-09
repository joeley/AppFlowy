import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet_buttons.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 底部弹窗头部组件
/// 
/// 这是一个通用的底部弹窗头部组件，提供标准的布局和交互模式。
/// 设计思想：
/// 1. 三栏布局设计 - 左侧关闭按钮、中间标题、右侧确认按钮
/// 2. 灵活的组件化设计 - 每个部分都可以独立配置或隐藏
/// 3. 一致的视觉风格 - 统一的间距、字体和布局规范
/// 4. 可扩展性 - 支持自定义确认按钮，满足不同场景需求
/// 
/// 架构特点：
/// - 使用Stack布局实现精确的位置控制
/// - 通过条件渲染实现按需显示组件
/// - 集成预制按钮组件，保持设计一致性
/// - 支持回调函数，与父组件灵活交互
/// 
/// 使用场景：所有移动端底部弹窗的标准头部
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    super.key,
    this.title,
    this.onClose,
    this.onDone,
    this.confirmButton,
  });

  /// 头部标题文本，显示在中央位置
  /// 如果为null则不显示标题区域
  final String? title;
  /// 关闭按钮点击回调函数
  /// 如果为null则不显示左侧关闭按钮
  final VoidCallback? onClose;
  /// 完成按钮点击回调函数
  /// 当confirmButton为null时使用此回调创建默认完成按钮
  final VoidCallback? onDone;
  /// 自定义右侧确认按钮组件
  /// 如果提供则使用此组件，否则使用默认的完成按钮
  final Widget? confirmButton;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // 使用中心对齐作为Stack的默认对齐方式
      alignment: Alignment.center,
      children: [
        // 左侧关闭按钮区域（条件显示）
        if (onClose != null)
          Positioned(
            // 固定在左侧位置
            left: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: BottomSheetCloseButton(
                onTap: onClose,
              ),
            ),
          ),
        // 中央标题区域（条件显示）
        if (title != null)
          Align(
            child: FlowyText.medium(
              // 使用非空断言，因为已经检查过title不为null
              title!,
              fontSize: 16,
            ),
          ),
        // 右侧确认按钮区域（条件显示）
        if (onDone != null || confirmButton != null)
          Align(
            alignment: Alignment.centerRight,
            // 优先使用自定义确认按钮，否则使用默认完成按钮
            child: confirmButton ?? BottomSheetDoneButton(onDone: onDone),
          ),
      ],
    );
  }
}
