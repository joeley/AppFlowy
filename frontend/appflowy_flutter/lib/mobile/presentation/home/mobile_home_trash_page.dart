import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/plugins/trash/application/prelude.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

/// 移动端垃圾桶页面
/// 
/// 功能说明：
/// 1. 显示已删除的文档和页面
/// 2. 支持恢复和永久删除操作
/// 3. 提供批量操作功能
/// 4. 显示删除时间和状态
/// 
/// 操作模式：
/// - 单项操作：滑动显示恢复/删除按钮
/// - 批量操作：通过更多菜单恢复/清空所有项目
class MobileHomeTrashPage extends StatelessWidget {
  const MobileHomeTrashPage({super.key});

  /// 路由名称常量
  static const routeName = '/trash';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 创建垃圾桶BLoC并初始化
      create: (context) => getIt<TrashBloc>()..add(const TrashEvent.initial()),
      child: BlocBuilder<TrashBloc, TrashState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(LocaleKeys.trash_text.tr()),
              actions: [
                // 仅在有垃圾项目时显示更多菜单
                state.objects.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        splashRadius: 20,
                        icon: const Icon(Icons.more_horiz),
                        onPressed: () {
                          final trashBloc = context.read<TrashBloc>();
                          // 显示批量操作底部弹出菜单
                          showMobileBottomSheet(
                            context,
                            showHeader: true,
                            showCloseButton: true,
                            showDragHandle: true,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            title: LocaleKeys.trash_mobile_actions.tr(),
                            builder: (_) => Row(
                              children: [
                                // 恢复所有按钮
                                Expanded(
                                  child: _TrashActionAllButton(
                                    trashBloc: trashBloc,
                                  ),
                                ),
                                const SizedBox(
                                  width: 16,
                                ),
                                Expanded(
                                  child: _TrashActionAllButton(
                                    trashBloc: trashBloc,
                                    type: _TrashActionType.restoreAll,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
            body: state.objects.isEmpty
                ? const _EmptyTrashBin()
                : _DeletedFilesListView(state),
          );
        },
      ),
    );
  }
}

/// 垃圾桶批量操作类型枚举
/// 
/// 用于区分恢复全部和删除全部操作
enum _TrashActionType {
  /// 恢复全部项目
  restoreAll,
  /// 删除全部项目
  deleteAll,
}

/// 空垃圾桶显示组件
/// 
/// 当垃圾桶为空时显示的占位内容
/// 包含空状态图标、标题和描述文本
class _EmptyTrashBin extends StatelessWidget {
  const _EmptyTrashBin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 空状态垃圾桶图标
          const FlowySvg(
            FlowySvgs.m_empty_trash_xl,
            size: Size.square(46),
          ),
          const VSpace(16.0),
          // 主标题文本
          FlowyText.medium(
            LocaleKeys.trash_mobile_empty.tr(),
            fontSize: 18.0,
            textAlign: TextAlign.center,
          ),
          const VSpace(8.0),
          // 描述文本，使用提示颜色
          FlowyText.regular(
            LocaleKeys.trash_mobile_emptyDescription.tr(),
            fontSize: 17.0,
            maxLines: 10,
            textAlign: TextAlign.center,
            lineHeight: 1.3,
            color: Theme.of(context).hintColor,
          ),
          // 为底部导航栏预留空间
          const VSpace(kBottomNavigationBarHeight + 36.0),
        ],
      ),
    );
  }
}

/// 垃圾桶批量操作按钮组件
/// 
/// 功能说明：
/// 1. 支持恢复全部和删除全部操作
/// 2. 显示确认对话框防止误操作
/// 3. 在无项目时显示提示消息
class _TrashActionAllButton extends StatelessWidget {
  /// 在删除全部和恢复全部之间切换
  const _TrashActionAllButton({
    this.type = _TrashActionType.deleteAll,
    required this.trashBloc,
  });
  
  /// 操作类型（删除或恢复）
  final _TrashActionType type;
  /// 垃圾桶BLoC实例
  final TrashBloc trashBloc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 判断是否为删除全部操作
    final isDeleteAll = type == _TrashActionType.deleteAll;
    return BlocProvider.value(
      value: trashBloc,
      child: BottomSheetActionWidget(
        svg: isDeleteAll ? FlowySvgs.m_delete_m : FlowySvgs.m_restore_m,
        // 根据操作类型显示不同文本
        text: isDeleteAll
            ? LocaleKeys.trash_deleteAll.tr()
            : LocaleKeys.trash_restoreAll.tr(),
        onTap: () {
          final trashList = trashBloc.state.objects;
          // 只有当垃圾桶不为空时才执行操作
          if (trashList.isNotEmpty) {
            context.pop(); // 关闭底部弹出菜单
            // 显示确认对话框
            showFlowyMobileConfirmDialog(
              context,
              title: FlowyText(
                isDeleteAll
                    ? LocaleKeys.trash_confirmDeleteAll_title.tr()
                    : LocaleKeys.trash_restoreAll.tr(),
              ),
              content: FlowyText(
                isDeleteAll
                    ? LocaleKeys.trash_confirmDeleteAll_caption.tr()
                    : LocaleKeys.trash_confirmRestoreAll_caption.tr(),
              ),
              actionButtonTitle: isDeleteAll
                  ? LocaleKeys.trash_deleteAll.tr()
                  : LocaleKeys.trash_restoreAll.tr(),
              // 根据操作类型设置按钮颜色（删除使用错误颜色）
              actionButtonColor: isDeleteAll
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              onActionButtonPressed: () {
                // 执行对应的垃圾桶操作
                if (isDeleteAll) {
                  trashBloc.add(
                    const TrashEvent.deleteAll(),
                  );
                } else {
                  trashBloc.add(
                    const TrashEvent.restoreAll(),
                  );
                }
              },
              cancelButtonTitle: LocaleKeys.button_cancel.tr(),
            );
          } else {
            // 当没有已删除文件时显示提示消息
            Fluttertoast.showToast(
              msg: LocaleKeys.trash_mobile_empty.tr(),
              gravity: ToastGravity.CENTER,  // 居中显示
            );
          }
        },
      ),
    );
  }
}

/// 已删除文件列表显示组件
/// 
/// 功能说明：
/// 1. 显示垃圾桶中的所有已删除项目
/// 2. 为每个项目提供恢复和永久删除按钮
/// 3. 显示项目名称和图标
class _DeletedFilesListView extends StatelessWidget {
  const _DeletedFilesListView(
    this.state,
  );

  /// 垃圾桶状态数据
  final TrashState state;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        itemBuilder: (context, index) {
          final deletedFile = state.objects[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              // TODO: 显示不同文件类型的图标，等TrashPB支持文件类型字段后实现
              leading: FlowySvg(
                FlowySvgs.document_s,  // 目前统一使用文档图标
                size: const Size.square(24),
                color: theme.colorScheme.onSurface,
              ),
              // 显示已删除文件的名称
              title: Text(
                deletedFile.name,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
              ),
              horizontalTitleGap: 0,  // 去除图标和标题间的默认间距
              // 设置列表项背景颜色（透明度为10%）
              tileColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              // 圆角边框
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              // 右侧操作按钮组
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 恢复按钮
                  IconButton(
                    splashRadius: 20,  // 限制水波纹效果范围
                    icon: FlowySvg(
                      FlowySvgs.m_restore_m,
                      size: const Size.square(24),
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      // 恢复已删除的文件
                      context
                          .read<TrashBloc>()
                          .add(TrashEvent.putback(deletedFile.id));
                      // 显示恢复成功提示
                      Fluttertoast.showToast(
                        msg:
                            '${deletedFile.name} ${LocaleKeys.trash_mobile_isRestored.tr()}',
                        gravity: ToastGravity.BOTTOM,
                      );
                    },
                  ),
                  // 永久删除按钮
                  IconButton(
                    splashRadius: 20,
                    icon: FlowySvg(
                      FlowySvgs.m_delete_m,
                      size: const Size.square(24),
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      // 永久删除文件
                      context
                          .read<TrashBloc>()
                          .add(TrashEvent.delete(deletedFile));
                      // 显示删除成功提示
                      Fluttertoast.showToast(
                        msg:
                            '${deletedFile.name} ${LocaleKeys.trash_mobile_isDeleted.tr()}',
                        gravity: ToastGravity.BOTTOM,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        itemCount: state.objects.length,
      ),
    );
  }
}
