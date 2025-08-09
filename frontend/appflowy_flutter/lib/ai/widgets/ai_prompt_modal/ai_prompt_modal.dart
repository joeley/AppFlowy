import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/user/prelude.dart';
import 'package:appflowy/workspace/presentation/widgets/dialog_v2.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai_prompt_category_list.dart';
import 'ai_prompt_onboarding.dart';
import 'ai_prompt_preview.dart';
import 'ai_prompt_visible_list.dart';

/// 显示AI提示词选择模态框
/// 
/// 功能说明：
/// 1. 加载并显示所有可用的AI提示词
/// 2. 支持分类浏览、搜索和预览
/// 3. 返回用户选择的提示词对象
/// 
/// 参数：
/// - [context]: 构建上下文
/// - [aiPromptSelectorCubit]: 提示词选择器状态管理器
/// 
/// 返回值：
/// - 用户选择的提示词对象，取消选择返回null
Future<AiPrompt?> showAiPromptModal(
  BuildContext context, {
  required AiPromptSelectorCubit aiPromptSelectorCubit,
}) async {
  // 预加载自定义提示词
  aiPromptSelectorCubit.loadCustomPrompts();

  return showDialog<AiPrompt?>(
    context: context,
    builder: (_) {
      // 使用MultiBlocProvider提供必要的状态管理器
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: aiPromptSelectorCubit,
          ),
          BlocProvider.value(
            value: context.read<UserWorkspaceBloc>(),
          ),
        ],
        child: const AiPromptModal(),
      );
    },
  );
}

/// AI提示词模态框主组件
/// 
/// 功能架构：
/// 1. 左侧：分类列表（精选、自定义、各种分类）
/// 2. 中间：提示词列表（支持搜索过滤）
/// 3. 右侧：提示词预览（显示详情和示例）
/// 
/// 布局策略：
/// - 使用Flex布局，1:2:3的比例分配空间
/// - 根据状态动态显示引导页或内容页
/// - 响应式设计，适配不同屏幕尺寸
class AiPromptModal extends StatelessWidget {
  const AiPromptModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      backgroundColor: theme.backgroundColorScheme.primary,
      // 设置模态框最大尺寸，确保良好的显示效果
      constraints: const BoxConstraints(
        maxWidth: 1200,
        maxHeight: 800,
      ),
      child: BlocListener<AiPromptSelectorCubit, AiPromptSelectorState>(
        // 监听状态变化，处理错误情况
        listener: (context, state) {
          state.maybeMap(
            // 数据库无效时显示错误对话框
            invalidDatabase: (_) {
              showLoadPromptFailedDialog(context);
            },
            orElse: () {},
          );
        },
        child: Column(
          children: [
            // 模态框头部：标题和关闭按钮
            AFModalHeader(
              leading: Text(
                LocaleKeys.ai_customPrompt_browsePrompts.tr(),  // "浏览提示词"
                style: theme.textStyle.heading4.prominent(
                  color: theme.textColorScheme.primary,
                ),
              ),
              trailing: [
                // 关闭按钮
                AFGhostButton.normal(
                  onTap: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.all(theme.spacing.xs),
                  builder: (context, isHovering, disabled) {
                    return Center(
                      child: FlowySvg(
                        FlowySvgs.toast_close_s,
                        size: Size.square(20),
                      ),
                    );
                  },
                ),
              ],
            ),
            // 模态框主体内容区
            Expanded(
              child: AFModalBody(
                child:
                    BlocBuilder<AiPromptSelectorCubit, AiPromptSelectorState>(
                  builder: (context, state) {
                    return state.maybeMap(
                      // 加载状态：显示进度指示器
                      loading: (_) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      // 就绪状态：显示三栏布局
                      ready: (readyState) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 左栏：分类列表（固定flex=1）
                            const Expanded(
                              child: AiPromptCategoryList(),
                            ),
                            // 条件渲染：未配置自定义数据库时显示引导页
                            if (readyState.isCustomPromptSectionSelected &&
                                readyState.databaseConfig == null)
                              const Expanded(
                                flex: 5,  // 引导页占据中右两栏空间
                                child: Center(
                                  child: AiPromptOnboarding(),
                                ),
                              )
                            else ...[
                              // 中栏：提示词列表（flex=2）
                              const Expanded(
                                flex: 2,
                                child: AiPromptVisibleList(),
                              ),
                              // 右栏：提示词预览（flex=3）
                              Expanded(
                                flex: 3,
                                child: BlocBuilder<AiPromptSelectorCubit,
                                    AiPromptSelectorState>(
                                  builder: (context, state) {
                                    // 查找当前选中的提示词
                                    final selectedPrompt = state.maybeMap(
                                      ready: (state) {
                                        return state.visiblePrompts
                                            .firstWhereOrNull(
                                          (prompt) =>
                                              prompt.id ==
                                              state.selectedPromptId,
                                        );
                                      },
                                      orElse: () => null,
                                    );
                                    // 无选中项时返回空组件
                                    if (selectedPrompt == null) {
                                      return const SizedBox.shrink();
                                    }
                                    // 显示选中提示词的预览
                                    return AiPromptPreview(
                                      prompt: selectedPrompt,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示加载提示词失败的对话框
/// 
/// 当自定义提示词数据库无效或无法访问时调用
/// 提供友好的错误提示和帮助信息
void showLoadPromptFailedDialog(
  BuildContext context,
) {
  showSimpleAFDialog(
    context: context,
    title: LocaleKeys.ai_customPrompt_invalidDatabase.tr(),      // 错误标题
    content: LocaleKeys.ai_customPrompt_invalidDatabaseHelp.tr(), // 帮助信息
    primaryAction: (
      LocaleKeys.button_ok.tr(),
      (context) {},  // 点击确定后关闭对话框
    ),
  );
}
