import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

import '../../service/ai_entities.dart';
import 'layout_define.dart';

/// 桌面端格式切换按钮
/// 
/// 功能说明：
/// 1. 切换预定义格式栏的显示/隐藏
/// 2. 显示不同图标表示当前状态
/// 3. 悬停提示说明功能
/// 
/// 设计特点：
/// - 两种状态图标：文本格式图标/文本图像混合图标
/// - 清晰的视觉反馈
class PromptInputDesktopToggleFormatButton extends StatelessWidget {
  const PromptInputDesktopToggleFormatButton({
    super.key,
    required this.showFormatBar,
    required this.onTap,
  });

  final bool showFormatBar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      // 根据状态显示不同提示文本
      tooltipText: showFormatBar
          ? LocaleKeys.chat_changeFormat_defaultDescription.tr()  // 已显示格式栏
          : LocaleKeys.chat_changeFormat_blankDescription.tr(),    // 未显示格式栏
      width: 28.0,
      onPressed: onTap,
      // 根据状态显示不同图标
      icon: showFormatBar
          ? const FlowySvg(
              FlowySvgs.m_aa_text_s,  // 纯文本图标
              size: Size.square(16.0),
              color: Color(0xFF666D76),
            )
          : const FlowySvg(
              FlowySvgs.ai_text_image_s,  // 文本+图像图标
              size: Size(21.0, 16.0),
              color: Color(0xFF666D76),
            ),
    );
  }
}

/// 格式选择栏组件
/// 
/// 功能说明：
/// 1. 提供图像格式选择：纯文本、文本+图像、纯图像
/// 2. 提供文本格式选择：段落、项目符号、编号列表、表格
/// 3. 根据模型能力动态显示选项
/// 
/// 设计特点：
/// - 分组显示：图像格式和文本格式用分隔线区分
/// - 选中状态高亮
/// - 悬停提示说明每种格式
/// - 响应式设计，支持桌面和移动端
class ChangeFormatBar extends StatelessWidget {
  const ChangeFormatBar({
    super.key,
    required this.predefinedFormat,
    required this.spacing,
    required this.onSelectPredefinedFormat,
    this.showImageFormats = true,
  });

  final PredefinedFormat? predefinedFormat;
  final double spacing;
  final void Function(PredefinedFormat) onSelectPredefinedFormat;
  final bool showImageFormats;

  @override
  Widget build(BuildContext context) {
    // 判断是否显示文本格式选项（纯图像模式不显示）
    final showTextFormats = predefinedFormat?.imageFormat.hasText ?? true;
    return SizedBox(
      height: DesktopAIPromptSizes.predefinedFormatButtonHeight,
      child: SeparatedRow(
        mainAxisSize: MainAxisSize.min,
        separatorBuilder: () => HSpace(spacing),
        children: [
          // 图像格式选项（仅云端AI模型支持）
          if (showImageFormats) ...[
            _buildFormatButton(context, ImageFormat.text),           // 纯文本
            _buildFormatButton(context, ImageFormat.textAndImage),   // 文本+图像
            _buildFormatButton(context, ImageFormat.image),          // 纯图像
          ],
          // 分隔线
          if (showImageFormats && showTextFormats) _buildDivider(),
          // 文本格式选项
          if (showTextFormats) ...[
            _buildTextFormatButton(context, TextFormat.paragraph),     // 段落
            _buildTextFormatButton(context, TextFormat.bulletList),    // 项目符号
            _buildTextFormatButton(context, TextFormat.numberedList),  // 编号列表
            _buildTextFormatButton(context, TextFormat.table),         // 表格
          ],
        ],
      ),
    );
  }

  /// 构建图像格式按钮
  /// 
  /// 功能：
  /// 1. 显示格式图标
  /// 2. 处理点击切换
  /// 3. 高亮当前选中状态
  Widget _buildFormatButton(BuildContext context, ImageFormat format) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 如果已选中，不做处理
        if (predefinedFormat != null &&
            format == predefinedFormat!.imageFormat) {
          return;
        }
        // 如果格式包含文本，保留文本格式设置
        if (format.hasText) {
          final textFormat =
              predefinedFormat?.textFormat ?? TextFormat.paragraph;  // 默认段落格式
          onSelectPredefinedFormat(
            PredefinedFormat(imageFormat: format, textFormat: textFormat),
          );
        } else {
          // 纯图像模式，清空文本格式
          onSelectPredefinedFormat(
            PredefinedFormat(imageFormat: format, textFormat: null),
          );
        }
      },
      child: FlowyTooltip(
        message: format.i18n,
        preferBelow: false,
        child: SizedBox.square(
          dimension: _buttonSize,
          child: FlowyHover(
            isSelected: () => format == predefinedFormat?.imageFormat,
            child: Center(
              child: FlowySvg(
                format.icon,
                size: format == ImageFormat.textAndImage
                    ? Size(21.0 / 16.0 * _iconSize, _iconSize)
                    : Size.square(_iconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建分隔线
  /// 
  /// 用于分隔图像格式和文本格式选项
  Widget _buildDivider() {
    return VerticalDivider(
      indent: 6.0,
      endIndent: 6.0,
      width: 1.0 + spacing * 2,
    );
  }

  /// 构建文本格式按钮
  /// 
  /// 功能：
  /// 1. 显示格式图标（段落、列表、表格）
  /// 2. 处理点击切换
  /// 3. 保持图像格式不变
  Widget _buildTextFormatButton(
    BuildContext context,
    TextFormat format,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 如果已选中，不做处理
        if (predefinedFormat != null &&
            format == predefinedFormat!.textFormat) {
          return;
        }
        // 切换文本格式，保持图像格式不变
        onSelectPredefinedFormat(
          PredefinedFormat(
            imageFormat: predefinedFormat?.imageFormat ?? ImageFormat.text,  // 默认纯文本
            textFormat: format,
          ),
        );
      },
      child: FlowyTooltip(
        message: format.i18n,
        preferBelow: false,
        child: SizedBox.square(
          dimension: _buttonSize,
          child: FlowyHover(
            isSelected: () => format == predefinedFormat?.textFormat,
            child: Center(
              child: FlowySvg(
                format.icon,
                size: Size.square(_iconSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取按钮尺寸
  /// 
  /// 根据平台返回不同尺寸
  double get _buttonSize {
    return UniversalPlatform.isMobile
        ? MobileAIPromptSizes.predefinedFormatButtonHeight
        : DesktopAIPromptSizes.predefinedFormatButtonHeight;
  }

  /// 获取图标尺寸
  /// 
  /// 根据平台返回不同尺寸
  double get _iconSize {
    return UniversalPlatform.isMobile
        ? MobileAIPromptSizes.predefinedFormatIconHeight
        : DesktopAIPromptSizes.predefinedFormatIconHeight;
  }
}

/// 移动端格式切换按钮
/// 
/// 功能说明：
/// 与桌面端类似，但UI适配移动端
/// 使用FlowyButton而不是FlowyIconButton
class PromptInputMobileToggleFormatButton extends StatelessWidget {
  const PromptInputMobileToggleFormatButton({
    super.key,
    required this.showFormatBar,
    required this.onTap,
  });

  final bool showFormatBar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32.0,
      child: FlowyButton(
        radius: const BorderRadius.all(Radius.circular(8.0)),
        margin: EdgeInsets.zero,
        expandText: false,
        text: showFormatBar
            ? const FlowySvg(
                FlowySvgs.m_aa_text_s,
                size: Size.square(20.0),
              )
            : const FlowySvg(
                FlowySvgs.ai_text_image_s,
                size: Size(26.25, 20.0),
              ),
        onTap: onTap,
      ),
    );
  }
}
