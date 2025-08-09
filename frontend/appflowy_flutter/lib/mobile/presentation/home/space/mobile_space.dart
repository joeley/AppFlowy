// 移动端空间组件
// 
// 这是AppFlowy移动端的空间（工作区）管理组件，负责显示和管理用户的所有工作空间
// 提供空间切换、页面创建、层级展示等核心功能
// 
// 主要特性：
// - 空间头部显示和管理
// - 空间切换菜单
// - 页面创建功能
// - 层级式页面结构显示
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/home/space/mobile_space_header.dart';
import 'package:appflowy/mobile/presentation/home/space/mobile_space_menu.dart';
import 'package:appflowy/mobile/presentation/page_item/mobile_view_item.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/shared/list_extension.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端空间组件
/// 
/// 这是移动端主页面中的空间区域，负责显示当前选中的工作空间
/// 和其下属的所有页面。使用SpaceBloc管理空间状态和操作。
class MobileSpace extends StatelessWidget {
  /// 构造函数
  const MobileSpace({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpaceBloc, SpaceState>(
      builder: (context, state) {
        // 如果没有空间，则不显示任何内容
        if (state.spaces.isEmpty) {
          return const SizedBox.shrink();
        }

        // 获取当前选中的空间，如果没有则使用第一个空间
        final currentSpace = state.currentSpace ?? state.spaces.first;

        return Column(
          children: [
            // 空间头部：显示空间名称、展开/折叠按钮、添加按钮
            MobileSpaceHeader(
              isExpanded: state.isExpanded,
              space: currentSpace,
              onAdded: () => _showCreatePageMenu(context, currentSpace),
              onPressed: () => _showSpaceMenu(context),
            ),
            // 空间内的页面列表，添加左侧内边距
            Padding(
              padding: const EdgeInsets.only(
                left: HomeSpaceViewSizes.mHorizontalPadding,
              ),
              child: _Pages(
                key: ValueKey(currentSpace.id), // 使用空间ID作为key保证组件正确重建
                space: currentSpace,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 显示空间切换菜单
  /// 
  /// 在底部弹窗中显示所有可用的空间，允许用户切换工作空间
  void _showSpaceMenu(BuildContext context) {
    showMobileBottomSheet(
      context,
      showDivider: false,           // 不显示分割线
      showHeader: true,             // 显示头部
      showDragHandle: true,         // 显示拖拽手柄
      showCloseButton: true,        // 显示关闭按钮
      showDoneButton: true,         // 显示完成按钮
      useRootNavigator: true,       // 使用根导航器
      title: LocaleKeys.space_title.tr(), // 空间标题
      backgroundColor: Theme.of(context).colorScheme.surface,
      enableScrollable: true,       // 允许滚动
      bottomSheetPadding: context.bottomSheetPadding(),
      builder: (_) {
        // 传递当前SpaceBloc给子组件
        return BlocProvider.value(
          value: context.read<SpaceBloc>(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: MobileSpaceMenu(), // 空间菜单组件
          ),
        );
      },
    );
  }

  /// 显示创建新页面的菜单
  /// 
  /// 在底部弹窗中显示可创建的页面类型（文档、表格、看板等）
  void _showCreatePageMenu(BuildContext context, ViewPB space) {
    final title = space.name; // 使用空间名称作为弹窗标题
    showMobileBottomSheet(
      context,
      showHeader: true,
      title: title,
      showDragHandle: true,
      showCloseButton: true,
      useRootNavigator: true,
      showDivider: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return AddNewPageWidgetBottomSheet(
          view: space, // 传入空间对象
          // 当用户选择页面类型时的回调函数
          onAction: (layout) {
            // 关闭弹窗
            Navigator.of(sheetContext).pop();
            // 发送创建页面事件
            context.read<SpaceBloc>().add(
                  SpaceEvent.createPage(
                    name: '',               // 初始名称为空，用户后续可重命名
                    layout: layout,         // 页面布局类型
                    index: 0,               // 插入的位置索引
                    openAfterCreate: true,  // 创建后自动打开
                  ),
                );
            // 自动展开空间，显示新创建的页面
            context.read<SpaceBloc>().add(
                  SpaceEvent.expand(space, true),
                );
          },
        );
      },
    );
  }
}

/// 空间内部页面列表组件
/// 
/// 负责渲染空间下的所有页面，使用ViewBloc管理单个空间的视图状态
/// 处理页面的层级显示和操作面板
class _Pages extends StatelessWidget {
  /// 构造函数
  const _Pages({
    super.key,
    required this.space,
  });

  /// 当前空间对象
  final ViewPB space;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 为每个空间创建独立的ViewBloc实例
      create: (context) =>
          ViewBloc(view: space)..add(const ViewEvent.initial()),
      child: BlocBuilder<ViewBloc, ViewState>(
        builder: (context, state) {
          // 根据空间权限判断是公共还是私人空间
          final spaceType = space.spacePermission == SpacePermission.publicToAll
              ? FolderSpaceType.public
              : FolderSpaceType.private;
          
          // 去除重复的子视图（防止数据异常）
          final childViews = state.view.childViews.unique((view) => view.id);
          if (childViews.length != state.view.childViews.length) {
            // 如果发现重复视图，记录错误日志
            final duplicatedViews = state.view.childViews
                .where((view) => childViews.contains(view))
                .toList();
            Log.error('some view id are duplicated: $duplicatedViews');
          }
          
          // 构建视图项列表
          return Column(
            children: childViews
                .map(
                  (view) => MobileViewItem(
                    key: ValueKey(
                      '${space.id} ${view.id}', // 结合空间ID和视图ID作为唯一标识
                    ),
                    spaceType: spaceType,
                    // 判断是否为第一个子视图（用于样式处理）
                    isFirstChild: view.id == state.view.childViews.first.id,
                    view: view,
                    level: 0,                    // 根级视图的层级为0
                    leftPadding: HomeSpaceViewSizes.leftPadding,
                    isFeedback: false,           // 不是拖拽反馈组件
                    // 视图被选中时的处理
                    onSelected: (v) => context.pushView(
                      v,
                      // 传递图标选择器的标签页类型
                      tabs: [
                        PickerTabType.emoji,
                        PickerTabType.icon,
                        PickerTabType.custom,
                      ].map((e) => e.name).toList(),
                    ),
                    // 右侧滑动操作面板
                    endActionPane: (context) {
                      final view = context.read<ViewBloc>().state.view;
                      // 根据视图类型定义可用操作
                      final actions = [
                        MobilePaneActionType.more, // 更多操作
                        if (view.layout == ViewLayoutPB.Document)
                          MobilePaneActionType.add, // 文档类型可以添加子页面
                      ];
                      return buildEndActionPane(
                        context,
                        actions,
                        spaceType: spaceType,
                        // 根据操作数量调整空间比例
                        spaceRatio: actions.length == 1 ? 3 : 4,
                      );
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
