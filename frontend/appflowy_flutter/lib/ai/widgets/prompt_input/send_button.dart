/// AI提示词发送按钮组件
/// 
/// 提供一个多状态的发送按钮，支持发送、停止和禁用状态
/// 根据平台自动调整尺寸

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

import 'layout_define.dart';

/// 发送按钮状态枚举
enum SendButtonState {
  enabled,    // 可用状态，可以发送消息
  streaming,  // 正在流式输出，显示停止按钮
  disabled    // 禁用状态，不可点击
}

/// 提示词输入发送按钮
/// 
/// 根据不同状态显示不同的图标和行为：
/// - 可用状态：显示发送图标，点击发送消息
/// - 流式输出状态：显示停止图标，点击停止输出
/// - 禁用状态：灰色图标，不可点击
class PromptInputSendButton extends StatelessWidget {
  const PromptInputSendButton({
    super.key,
    required this.state,
    required this.onSendPressed,
    required this.onStopStreaming,
  });

  // 当前按钮状态
  final SendButtonState state;
  // 发送按钮点击回调
  final VoidCallback onSendPressed;
  // 停止流式输出回调
  final VoidCallback onStopStreaming;

  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      width: _buttonSize,
      // 根据状态设置工具提示
      richTooltipText: switch (state) {
        // 流式输出状态显示停止提示和ESC快捷键
        SendButtonState.streaming => TextSpan(
            children: [
              TextSpan(
                text: '${LocaleKeys.chat_stopTooltip.tr()}  ',
                style: context.tooltipTextStyle(),
              ),
              TextSpan(
                text: 'ESC',  // 快捷键提示
                style: context
                    .tooltipTextStyle()
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
            ],
          ),
        _ => null,  // 其他状态不显示提示
      },
      // 根据状态显示不同图标
      icon: switch (state) {
        // 可用状态：蓝色发送图标
        SendButtonState.enabled => FlowySvg(
            FlowySvgs.ai_send_filled_s,
            size: Size.square(_iconSize),
            color: Theme.of(context).colorScheme.primary,
          ),
        // 禁用状态：灰色发送图标
        SendButtonState.disabled => FlowySvg(
            FlowySvgs.ai_send_filled_s,
            size: Size.square(_iconSize),
            color: Theme.of(context).disabledColor,
          ),
        // 流式输出状态：蓝色停止图标
        SendButtonState.streaming => FlowySvg(
            FlowySvgs.ai_stop_filled_s,
            size: Size.square(_iconSize),
            color: Theme.of(context).colorScheme.primary,
          ),
      },
      // 根据状态处理点击事件
      onPressed: () {
        switch (state) {
          case SendButtonState.enabled:
            onSendPressed();    // 发送消息
            break;
          case SendButtonState.streaming:
            onStopStreaming();  // 停止输出
            break;
          case SendButtonState.disabled:
            break;              // 禁用状态不响应
        }
      },
      hoverColor: Colors.transparent,
    );
  }

  /// 获取按钮尺寸
  /// 
  /// 根据平台返回不同的按钮大小
  double get _buttonSize {
    return UniversalPlatform.isMobile
        ? MobileAIPromptSizes.sendButtonSize                // 移动端尺寸
        : DesktopAIPromptSizes.actionBarSendButtonSize;     // 桌面端尺寸
  }

  /// 获取图标尺寸
  /// 
  /// 根据平台返回不同的图标大小
  double get _iconSize {
    return UniversalPlatform.isMobile
        ? MobileAIPromptSizes.sendButtonSize                // 移动端图标尺寸
        : DesktopAIPromptSizes.actionBarSendButtonIconSize; // 桌面端图标尺寸
  }
}
