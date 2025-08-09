import 'package:flutter/material.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/style_widget/icon_button.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';

import 'layout_define.dart';

/// 附件上传按钮组件
/// 
/// 功能说明：
/// 1. 显示附件图标按钮
/// 2. 点击触发文件上传功能
/// 3. 悬停时显示提示文字
/// 
/// 设计特点：
/// - 固定尺寸，与其他操作按钮保持一致
/// - 悬停效果，提升交互体验
/// - 工具提示，帮助用户理解功能
class PromptInputAttachmentButton extends StatelessWidget {
  const PromptInputAttachmentButton({required this.onTap, super.key});

  // 点击回调函数
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.chat_uploadFile.tr(),  // "上传文件"提示
      child: SizedBox.square(
        dimension: DesktopAIPromptSizes.actionBarButtonSize,  // 统一按钮尺寸
        child: FlowyIconButton(
          hoverColor: AFThemeExtension.of(context).lightGreyHover,
          radius: BorderRadius.circular(8),
          icon: FlowySvg(
            FlowySvgs.ai_attachment_s,  // 附件图标
            size: const Size.square(16),
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// @提及按钮组件
/// 
/// 功能说明：
/// 1. 显示@符号按钮，用于提及页面或文档
/// 2. 点击后打开页面选择器
/// 3. 支持自定义按钮和图标尺寸
/// 
/// 使用场景：
/// - 在AI对话中引用特定页面或文档
/// - 让AI基于特定内容生成回复
/// 
/// 参数：
/// - [buttonSize]: 按钮尺寸
/// - [iconSize]: 图标尺寸
/// - [onTap]: 点击回调
class PromptInputMentionButton extends StatelessWidget {
  const PromptInputMentionButton({
    super.key,
    required this.buttonSize,
    required this.iconSize,
    required this.onTap,
  });

  final double buttonSize;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.chat_clickToMention.tr(),  // "点击提及"提示
      preferBelow: false,  // 提示显示在上方
      child: FlowyIconButton(
        width: buttonSize,
        hoverColor: AFThemeExtension.of(context).lightGreyHover,
        radius: BorderRadius.circular(8),
        icon: FlowySvg(
          FlowySvgs.chat_at_s,  // @符号图标
          size: Size.square(iconSize),
          color: Theme.of(context).iconTheme.color,
        ),
        onPressed: onTap,
      ),
    );
  }
}
