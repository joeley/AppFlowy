import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ai_prompt_modal/ai_prompt_modal.dart';

/// 浏览提示词按钮组件
/// 
/// 功能说明：
/// 1. 显示"浏览提示词"文本按钮
/// 2. 点击后打开提示词选择模态框
/// 3. 选中提示词后通过回调返回结果
/// 
/// 使用场景：
/// - 在AI输入框中快速选择预定义的提示词
/// - 提供可视化的提示词浏览和选择界面
/// 
/// 设计特点：
/// - 悬停效果提升交互体验
/// - 提示信息帮助用户理解功能
/// - 独立的状态管理器避免状态污染
class BrowsePromptsButton extends StatelessWidget {
  const BrowsePromptsButton({
    super.key,
    required this.onSelectPrompt,
  });

  /// 选择提示词后的回调函数
  /// 接收用户选中的提示词对象
  final void Function(AiPrompt) onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.ai_customPrompt_browsePrompts.tr(),  // 悬停提示文本
      child: BlocProvider(
        // 创建独立的AiPromptSelectorCubit实例
        // 确保每个按钮都有自己的状态管理器，避免状态冲突
        create: (context) => AiPromptSelectorCubit(),
        child: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () async {
                // 显示提示词选择模态框
                final prompt = await showAiPromptModal(
                  context,
                  aiPromptSelectorCubit: context.read<AiPromptSelectorCubit>(),
                );
                // 重置状态管理器，清理选择状态
                if (context.mounted) {
                  context.read<AiPromptSelectorCubit>().reset();
                }
                // 如果用户选择了提示词，执行回调
                if (prompt != null && context.mounted) {
                  onSelectPrompt(prompt);
                }
              },
              // 使整个区域都可点击，提升用户体验
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: DesktopAIPromptSizes.actionBarButtonSize,  // 统一的按钮高度
                child: FlowyHover(
                  style: const HoverStyle(
                    borderRadius: BorderRadius.all(Radius.circular(8)),  // 圆角设计
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(4.0),
                    child: Center(
                      child: FlowyText(
                        LocaleKeys.ai_customPrompt_browsePrompts.tr(),  // "浏览提示词"文本
                        fontSize: 12,
                        figmaLineHeight: 16,  // 设计稿指定的行高
                        color: Theme.of(context).hintColor,  // 使用提示颜色
                        overflow: TextOverflow.ellipsis,  // 文本过长时省略
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
