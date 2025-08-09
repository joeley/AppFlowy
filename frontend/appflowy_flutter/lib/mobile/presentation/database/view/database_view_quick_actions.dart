// 导入SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入本地化键值对
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_transition_bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_quick_action_button.dart';
import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// 导入数据库视图编辑屏幕
import 'edit_database_view_screen.dart';

/// 移动端数据库视图快速操作组件
/// 
/// 这是一个核心的移动端UI组件，为用户提供对数据库视图的快速操作入口。
/// 设计思想：
/// 1. 集成常用的视图管理操作，提高用户操作效率
/// 2. 根据视图类型动态展示可用操作，避免不必要的功能干扰
/// 3. 使用底部弹窗形式，符合移动端交互习惯
/// 4. 集成图标选择器，支持个性化视图外观
/// 
/// 主要功能：
/// - 编辑视图设置
/// - 更改视图图标
/// - 复制视图
/// - 删除视图
/// 
/// 使用限制：
/// - 内联视图（子视图）不支持某些操作
class MobileDatabaseViewQuickActions extends StatelessWidget {
  const MobileDatabaseViewQuickActions({
    super.key,
    required this.view,
    required this.databaseController,
  });

  /// 当前视图对象，包含视图的所有元数据
  final ViewPB view;
  /// 数据库控制器，用于执行数据库相关操作
  final DatabaseController databaseController;

  @override
  Widget build(BuildContext context) {
    final isInline = view.childViews.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(context, _Action.edit, () async {
          final bloc = context.read<ViewBloc>();
          await showTransitionMobileBottomSheet(
            context,
            showHeader: true,
            showDoneButton: true,
            title: LocaleKeys.grid_settings_editView.tr(),
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: MobileEditDatabaseViewScreen(
                databaseController: databaseController,
              ),
            ),
          );
          if (context.mounted) {
            context.pop();
          }
        }),
        const MobileQuickActionDivider(),
        _actionButton(
          context,
          _Action.changeIcon,
          () {
            showMobileBottomSheet(
              context,
              showDragHandle: true,
              showDivider: false,
              showHeader: true,
              title: LocaleKeys.titleBar_pageIcon.tr(),
              backgroundColor: AFThemeExtension.of(context).background,
              enableDraggableScrollable: true,
              minChildSize: 0.6,
              initialChildSize: 0.61,
              scrollableWidgetBuilder: (_, controller) {
                return Expanded(
                  child: FlowyIconEmojiPicker(
                    tabs: const [PickerTabType.icon],
                    enableBackgroundColorSelection: false,
                    onSelectedEmoji: (r) {
                      ViewBackendService.updateViewIcon(
                        view: view,
                        viewIcon: r.data,
                      );
                      Navigator.pop(context);
                    },
                  ),
                );
              },
              builder: (_) => const SizedBox.shrink(),
            ).then((_) {
              if (context.mounted) {
                Navigator.pop(context);
              }
            });
          },
          !isInline,
        ),
        const MobileQuickActionDivider(),
        _actionButton(
          context,
          _Action.duplicate,
          () {
            context.read<ViewBloc>().add(const ViewEvent.duplicate());
            context.pop();
          },
          !isInline,
        ),
        const MobileQuickActionDivider(),
        _actionButton(
          context,
          _Action.delete,
          () {
            context.read<ViewBloc>().add(const ViewEvent.delete());
            context.pop();
          },
          !isInline,
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    _Action action,
    VoidCallback onTap, [
    bool enable = true,
  ]) {
    return MobileQuickActionButton(
      icon: action.icon,
      text: action.label,
      textColor: action.color(context),
      iconColor: action.color(context),
      onTap: onTap,
      enable: enable,
    );
  }
}

/// 快速操作类型枚举
/// 定义所有可用的视图操作类型
enum _Action {
  /// 编辑视图
  edit,
  /// 更改图标
  changeIcon,
  /// 删除视图
  delete,
  /// 复制视图
  duplicate;

  /// 获取操作的显示标签
  String get label {
    return switch (this) {
      edit => LocaleKeys.grid_settings_editView.tr(),
      duplicate => LocaleKeys.button_duplicate.tr(),
      delete => LocaleKeys.button_delete.tr(),
      changeIcon => LocaleKeys.disclosureAction_changeIcon.tr(),
    };
  }

  /// 获取操作对应的图标
  FlowySvgData get icon {
    return switch (this) {
      edit => FlowySvgs.view_item_rename_s,
      duplicate => FlowySvgs.duplicate_s,
      delete => FlowySvgs.trash_s,
      changeIcon => FlowySvgs.change_icon_s,
    };
  }

  /// 获取操作按钮的颜色（仅删除操作特殊处理）
  Color? color(BuildContext context) {
    return switch (this) {
      delete => Theme.of(context).colorScheme.error,
      _ => null,
    };
  }
}
