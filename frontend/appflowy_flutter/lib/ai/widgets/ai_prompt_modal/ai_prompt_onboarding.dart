import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai_prompt_database_modal.dart';

/// AI提示词引导组件
/// 
/// 功能说明：
/// 1. 首次使用自定义提示词时的引导界面
/// 2. 引导用户选择存储自定义提示词的数据库
/// 3. 提供清晰的说明和操作按钮
/// 
/// 使用场景：
/// - 用户首次访问自定义提示词区域
/// - 尚未配置自定义提示词数据库时显示
/// 
/// 设计理念：
/// - 简洁明了的引导文案
/// - 突出的操作按钮，降低使用门槛
/// - 与整体UI风格保持一致
class AiPromptOnboarding extends StatelessWidget {
  const AiPromptOnboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      // 使用min尺寸，内容自适应高度
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题：自定义提示词
        Text(
          LocaleKeys.ai_customPrompt_customPrompt.tr(),
          style: theme.textStyle.heading3.standard(
            color: theme.textColorScheme.primary,
          ),
        ),
        VSpace(
          theme.spacing.s,
        ),
        // 说明文字：介绍数据库提示词功能
        Text(
          LocaleKeys.ai_customPrompt_databasePrompts.tr(),
          style: theme.textStyle.body.standard(
            color: theme.textColorScheme.secondary,  // 使用次要颜色，降低视觉权重
          ),
        ),
        VSpace(
          theme.spacing.xxl,  // 较大间距，突出按钮
        ),
        // 主操作按钮：选择数据库
        AFFilledButton.primary(
          onTap: () async {
            // 打开数据库选择弹窗
            final config = await changeCustomPromptDatabaseConfig(context);

            // 如果用户选择了数据库，更新配置
            if (config != null && context.mounted) {
              context
                  .read<AiPromptSelectorCubit>()
                  .updateCustomPromptDatabaseConfiguration(config);
            }
          },
          builder: (context, isHovering, disabled) {
            return Text(
              LocaleKeys.ai_customPrompt_selectDatabase.tr(),
              style: theme.textStyle.body.enhanced(
                color: theme.textColorScheme.onFill,  // 按钮文字使用对比色
              ),
            );
          },
        ),
      ],
    );
  }
}
