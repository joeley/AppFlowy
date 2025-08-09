import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/animated_gesture.dart';
import 'package:appflowy/mobile/presentation/home/tab/mobile_space_tab.dart';
import 'package:appflowy/util/theme_extension.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// AI聊天浮动入口按钮（第一版）
/// 
/// 功能说明：
/// 1. 显示横条形的AI入口按钮
/// 2. 支持Hero动画过渡
/// 3. 带有阴影效果
/// 4. 点击触发创建新AI聊天
/// 
/// 设计特点：
/// - 横条形设计，显示提示文本
/// - 圆角边框样式
/// - 带阴影的浮动效果
class FloatingAIEntry extends StatelessWidget {
  const FloatingAIEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedGestureDetector(
      scaleFactor: 0.99,  // 点击时缩放效果
      // 点击后更新通知器，触发创建新的AI聊天
      onTapUp: () => mobileCreateNewAIChatNotifier.value =
          mobileCreateNewAIChatNotifier.value + 1,
      child: Hero(
        tag: "ai_chat_prompt",  // Hero动画标签
        child: DecoratedBox(
          decoration: _buildShadowDecoration(context),  // 阴影装饰
          child: Container(
            decoration: _buildWrapperDecoration(context),  // 边框装饰
            height: 48,
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _buildHintText(context),  // 提示文本和图标
            ),
          ),
        ),
      ),
    );
  }

  /// 构建阴影装饰
  /// 创建柔和的投影效果，增强浮动感
  BoxDecoration _buildShadowDecoration(BuildContext context) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          blurRadius: 20,  // 模糊半径
          spreadRadius: 1,  // 扩散半径
          offset: const Offset(0, 4),  // 向下偏移
          color: Colors.black.withValues(alpha: 0.05),  // 半透明黑色
        ),
      ],
    );
  }

  /// 构建容器装饰
  /// 根据主题模式调整边框透明度
  BoxDecoration _buildWrapperDecoration(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outline;
    // 根据亮暗模式调整边框透明度
    final borderColor = Theme.of(context).isLightMode
        ? outlineColor.withValues(alpha: 0.7)  // 亮色模式：较高透明度
        : outlineColor.withValues(alpha: 0.3);  // 暗色模式：较低透明度
    return BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      color: Theme.of(context).colorScheme.surface,
      border: Border.fromBorderSide(
        BorderSide(
          color: borderColor,
        ),
      ),
    );
  }

  /// 构建提示文本
  /// 包含AI图标和输入提示文字
  Widget _buildHintText(BuildContext context) {
    return Row(
      children: [
        // AI图标
        FlowySvg(
          FlowySvgs.toolbar_item_ai_s,
          size: const Size.square(16.0),
          color: Theme.of(context).hintColor,
          opacity: 0.7,
        ),
        const HSpace(8),
        // 提示文本
        FlowyText(
          LocaleKeys.chat_inputMessageHint.tr(),
          color: Theme.of(context).hintColor,
        ),
      ],
    );
  }
}

/// AI聊天浮动入口按钮（第二版）
/// 
/// 功能说明：
/// 1. 圆形浮动按钮设计
/// 2. 固定位置显示
/// 3. 点击创建新AI聊天
/// 
/// 设计特点：
/// - 圆形按钮，更简洁
/// - 只显示图标，无文字
/// - 带边框和阴影效果
class FloatingAIEntryV2 extends StatelessWidget {
  const FloatingAIEntryV2({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    return GestureDetector(
      onTap: () {
        // 更新通知器触发创建新AI聊天
        mobileCreateNewAIChatNotifier.value =
            mobileCreateNewAIChatNotifier.value + 1;
      },
      child: Container(
        width: 56,  // 圆形按钮尺寸
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,  // 圆形
          color: theme.surfaceColorScheme.primary,  // 主题色背景
          boxShadow: theme.shadow.small,  // 小阴影效果
          border: Border.all(color: theme.borderColorScheme.primary),  // 边框
        ),
        child: Center(
          child: FlowySvg(
            FlowySvgs.m_home_ai_chat_icon_m,  // AI聊天图标
            blendMode: null,
            size: Size(24, 24),  // 图标尺寸
          ),
        ),
      ),
    );
  }
}
