import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// AI模型选择菜单组件
/// 
/// 功能说明：
/// 1. 显示当前选中的AI模型
/// 2. 点击打开模型列表选择弹出层
/// 3. 支持本地模型和云端模型切换
/// 
/// 使用场景：
/// - 在AI对话中选择不同的模型获得不同的回复效果
/// - 支持多种模型（GPT、Claude、本地模型等）
class SelectModelMenu extends StatefulWidget {
  const SelectModelMenu({
    super.key,
    required this.aiModelStateNotifier,
  });

  /// AI模型状态通知器
  final AIModelStateNotifier aiModelStateNotifier;

  @override
  State<SelectModelMenu> createState() => _SelectModelMenuState();
}

class _SelectModelMenuState extends State<SelectModelMenu> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SelectModelBloc(
        aiModelStateNotifier: widget.aiModelStateNotifier,
      ),
      child: BlocBuilder<SelectModelBloc, SelectModelState>(
        builder: (context, state) {
          return AppFlowyPopover(
            offset: Offset(-12.0, 0.0),
            constraints: BoxConstraints(maxWidth: 250, maxHeight: 600),
            direction: PopoverDirection.topWithLeftAligned,
            margin: EdgeInsets.zero,
            controller: popoverController,
            popupBuilder: (popoverContext) {
              return SelectModelPopoverContent(
                models: state.models,
                selectedModel: state.selectedModel,
                onSelectModel: (model) {
                  if (model != state.selectedModel) {
                    context
                        .read<SelectModelBloc>()
                        .add(SelectModelEvent.selectModel(model));
                  }
                  popoverController.close();
                },
              );
            },
            child: _CurrentModelButton(
              model: state.selectedModel,
              onTap: () {
                if (state.selectedModel != null) {
                  popoverController.show();
                }
              },
            ),
          );
        },
      ),
    );
  }
}

/// 模型选择弹出层内容
/// 
/// 功能说明：
/// 1. 将模型分为本地模型和云端模型两组
/// 2. 每组显示标题和模型列表
/// 3. 支持滚动查看所有模型
/// 
/// 布局结构：
/// - 本地模型组（如果有）
/// - 云端模型组（如果有）
class SelectModelPopoverContent extends StatelessWidget {
  const SelectModelPopoverContent({
    super.key,
    required this.models,
    required this.selectedModel,
    this.onSelectModel,
  });

  /// 所有可用的AI模型列表
  final List<AIModelPB> models;
  /// 当前选中的模型
  final AIModelPB? selectedModel;
  /// 选择模型的回调
  final void Function(AIModelPB)? onSelectModel;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return const SizedBox.shrink();
    }

    // 将模型分为本地模型和云端模型
    final localModels = models.where((model) => model.isLocal).toList();
    final cloudModels = models.where((model) => !model.isLocal).toList();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localModels.isNotEmpty) ...[
              _ModelSectionHeader(
                title: LocaleKeys.chat_switchModel_localModel.tr(),
              ),
              const VSpace(4.0),
            ],
            ...localModels.map(
              (model) => _ModelItem(
                model: model,
                isSelected: model == selectedModel,
                onTap: () => onSelectModel?.call(model),
              ),
            ),
            if (cloudModels.isNotEmpty && localModels.isNotEmpty) ...[
              const VSpace(8.0),
              _ModelSectionHeader(
                title: LocaleKeys.chat_switchModel_cloudModel.tr(),
              ),
              const VSpace(4.0),
            ],
            ...cloudModels.map(
              (model) => _ModelItem(
                model: model,
                isSelected: model == selectedModel,
                onTap: () => onSelectModel?.call(model),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模型分组标题组件
/// 
/// 用于显示"本地模型"或"云端模型"等分组标题
class _ModelSectionHeader extends StatelessWidget {
  const _ModelSectionHeader({
    required this.title,
  });

  /// 分组标题文本
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: FlowyText(
        title,
        fontSize: 12,
        figmaLineHeight: 16,
        color: Theme.of(context).hintColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 模型列表项组件
/// 
/// 功能说明：
/// 1. 显示模型名称和描述
/// 2. 选中状态显示勾选图标
/// 3. 悬停效果提升交互体验
/// 
/// 设计特点：
/// - 最小高度32px，保证点击区域
/// - 文本超长时省略显示
class _ModelItem extends StatelessWidget {
  const _ModelItem({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  /// AI模型数据
  final AIModelPB model;
  /// 是否被选中
  final bool isSelected;
  /// 点击回调
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: FlowyButton(
        onTap: onTap,
        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        text: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模型名称
            FlowyText(
              model.i18n,
              figmaLineHeight: 20,
              overflow: TextOverflow.ellipsis,
            ),
            // 模型描述（如果有）
            if (model.desc.isNotEmpty)
              FlowyText(
                model.desc,
                fontSize: 12,
                figmaLineHeight: 16,
                color: Theme.of(context).hintColor,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        // 选中状态显示勾选图标
        rightIcon: isSelected
            ? FlowySvg(
                FlowySvgs.check_s,
                size: const Size.square(20),
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }
}

/// 当前模型显示按钮
/// 
/// 功能说明：
/// 1. 显示AI图标和当前模型名称
/// 2. 默认模型只显示图标
/// 3. 点击打开模型选择列表
/// 
/// 设计特点：
/// - 简洁的图标+文本布局
/// - 悬停提示功能说明
class _CurrentModelButton extends StatelessWidget {
  const _CurrentModelButton({
    required this.model,
    required this.onTap,
  });

  /// 当前选中的模型
  final AIModelPB? model;
  /// 点击回调
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlowyTooltip(
      message: LocaleKeys.chat_switchModel_label.tr(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: DesktopAIPromptSizes.actionBarButtonSize,
          child: FlowyHover(
            style: const HoverStyle(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    // TODO: remove this after change icon to 20px
                    padding: EdgeInsets.all(2),
                    child: FlowySvg(
                      FlowySvgs.ai_sparks_s,
                      color: Theme.of(context).hintColor,
                      size: Size.square(16),
                    ),
                  ),
                  // 非默认模型显示模型名称
                  if (model != null && !model!.isDefault)
                    Padding(
                      padding: EdgeInsetsDirectional.only(end: 2.0),
                      child: FlowyText(
                        model!.i18n,  // 国际化模型名称
                        fontSize: 12,
                        figmaLineHeight: 16,
                        color: Theme.of(context).hintColor,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  FlowySvg(
                    FlowySvgs.ai_source_drop_down_s,
                    color: Theme.of(context).hintColor,
                    size: const Size.square(8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
