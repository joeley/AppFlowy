// 导入页面访问级别状态管理
import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
// 导入生成的SVG图标资源
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端底部弹窗组件
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
// 导入移动端页面卡片类型定义
import 'package:appflowy/mobile/presentation/home/shared/mobile_page_card.dart';
// 导入移动端滑动操作按钮组件
import 'package:appflowy/mobile/presentation/page_item/mobile_slide_action_button.dart';
// 导入收藏状态管理
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
// 导入最近访问状态管理
import 'package:appflowy/workspace/application/recent/recent_views_bloc.dart';
// 导入文件夹状态管理
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
// 导入视图状态管理
import 'package:appflowy/workspace/application/view/view_bloc.dart';
// 导入视图类型扩展工具
import 'package:appflowy/workspace/application/view/view_ext.dart';
// 导入工作区通用对话框组件
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
// 导入后端protobuf定义的视图类型
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';
// 导入Bloc状态管理库
import 'package:flutter_bloc/flutter_bloc.dart';
// 导入可滑动组件库
import 'package:flutter_slidable/flutter_slidable.dart';

/**
 * 移动端面板操作类型枚举
 * 
 * 定义了移动端列表项可滑动操作的所有类型
 * 这些操作通过滑动手势或长按触发，是AppFlowy移动端的核心交互方式
 * 
 * 架构说明：
 * - 每个操作类型都可以转换为对应的滑动按钮组件
 * - 支持上下文相关的动态配置（如最近访问、收藏列表等）
 * - 集成权限管理和状态相关的UI变化
 */
enum MobilePaneActionType {
  delete,               // 删除操作 - 红色背景，删除当前项目
  addToFavorites,       // 添加到收藏 - 蓝色背景，将项目加入收藏夹
  removeFromFavorites,  // 从收藏移除 - 粉色背景，从收藏夹移除
  more,                 // 更多操作 - 灰色背景，打开底部操作菜单
  add;                  // 添加子项 - 蓝色背景，在当前项目下创建新内容

  /// 根据操作类型创建对应的滑动操作按钮
  /// 
  /// 这是一个工厂方法，将抽象的操作类型转换为具体的UI组件
  /// 每个操作都有独特的视觉样式和交互逻辑
  /// 
  /// @param context 构建上下文，用于访问Bloc状态和主题信息
  /// @param cardType 页面卡片类型，用于决定操作的上下文相关行为
  /// @param spaceType 空间类型，用于创建子项时确定所属空间
  /// @return 配置好的滑动操作按钮组件
  MobileSlideActionButton actionButton(
    BuildContext context, {
    MobilePageCardType? cardType,     // 页面卡片类型，影响操作行为
    FolderSpaceType? spaceType,       // 文件夹空间类型，用于子项创建
  }) {
    switch (this) {
      // ===== 删除操作 =====
      case MobilePaneActionType.delete:
        return MobileSlideActionButton(
          backgroundColor: Colors.red,        // 红色背景，警示危险操作
          svg: FlowySvgs.delete_s,            // 删除图标
          size: 30.0,                         // 较大的图标尺寸，方便点击
          onPressed: (context) =>
              // 触发视图删除事件，由ViewBloc处理删除逻辑
              context.read<ViewBloc>().add(const ViewEvent.delete()),
        );
      // ===== 从收藏移除操作 =====
      case MobilePaneActionType.removeFromFavorites:
        return MobileSlideActionButton(
          backgroundColor: const Color(0xFFFA217F), // 粉红色背景，区别于删除操作
          svg: FlowySvgs.favorite_section_remove_from_favorite_s, // 从收藏移除的专用图标
          size: 24.0,                              // 标准图标尺寸
          onPressed: (context) {
            // 显示取消收藏成功的提示消息
            showToastNotification(
              message: LocaleKeys.button_unfavoriteSuccessfully.tr(),
            );

            // 触发收藏状态切换，将当前视图从收藏夹移除
            context
                .read<FavoriteBloc>()
                .add(FavoriteEvent.toggle(context.read<ViewBloc>().view));
          },
        );
      // ===== 添加到收藏操作 =====
      case MobilePaneActionType.addToFavorites:
        return MobileSlideActionButton(
          backgroundColor: const Color(0xFF00C8FF), // 蓝色背景，积极正面的操作
          svg: FlowySvgs.favorite_s,               // 收藏图标（空心）
          size: 24.0,                              // 标准图标尺寸
          onPressed: (context) {
            // 显示添加收藏成功的提示消息
            showToastNotification(
              message: LocaleKeys.button_favoriteSuccessfully.tr(),
            );

            // 触发收藏状态切换，将当前视图添加到收藏夹
            context
                .read<FavoriteBloc>()
                .add(FavoriteEvent.toggle(context.read<ViewBloc>().view));
          },
        );
      case MobilePaneActionType.add:
        return MobileSlideActionButton(
          backgroundColor: const Color(0xFF00C8FF),
          svg: FlowySvgs.add_m,
          size: 28.0,
          onPressed: (context) {
            final viewBloc = context.read<ViewBloc>();
            final view = viewBloc.state.view;
            final title = view.name;
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
                  view: view,
                  onAction: (layout) {
                    Navigator.of(sheetContext).pop();
                    viewBloc.add(
                      ViewEvent.createView(
                        layout.defaultName,
                        layout,
                        section: spaceType!.toViewSectionPB,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      case MobilePaneActionType.more:
        return MobileSlideActionButton(
          backgroundColor: const Color(0xE5515563),
          svg: FlowySvgs.three_dots_s,
          size: 24.0,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          ),
          onPressed: (context) {
            final viewBloc = context.read<ViewBloc>();
            final favoriteBloc = context.read<FavoriteBloc>();
            final recentViewsBloc = context.read<RecentViewsBloc?>();
            showMobileBottomSheet(
              context,
              showDragHandle: true,
              showDivider: false,
              useRootNavigator: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              builder: (context) {
                return MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: viewBloc),
                    BlocProvider.value(value: favoriteBloc),
                    if (recentViewsBloc != null)
                      BlocProvider.value(value: recentViewsBloc),
                    BlocProvider(
                      create: (_) =>
                          PageAccessLevelBloc(view: viewBloc.state.view)
                            ..add(const PageAccessLevelEvent.initial()),
                    ),
                  ],
                  child: BlocBuilder<ViewBloc, ViewState>(
                    builder: (context, state) {
                      return MobileViewItemBottomSheet(
                        view: viewBloc.state.view,
                        actions: _buildActions(state.view, cardType: cardType),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
    }
  }

  List<MobileViewItemBottomSheetBodyAction> _buildActions(
    ViewPB view, {
    MobilePageCardType? cardType,
  }) {
    final isFavorite = view.isFavorite;

    if (cardType != null) {
      switch (cardType) {
        case MobilePageCardType.recent:
          return [
            isFavorite
                ? MobileViewItemBottomSheetBodyAction.removeFromFavorites
                : MobileViewItemBottomSheetBodyAction.addToFavorites,
            MobileViewItemBottomSheetBodyAction.divider,
            MobileViewItemBottomSheetBodyAction.divider,
            MobileViewItemBottomSheetBodyAction.removeFromRecent,
          ];
        case MobilePageCardType.favorite:
          return [
            isFavorite
                ? MobileViewItemBottomSheetBodyAction.removeFromFavorites
                : MobileViewItemBottomSheetBodyAction.addToFavorites,
            MobileViewItemBottomSheetBodyAction.divider,
          ];
      }
    }

    return [
      isFavorite
          ? MobileViewItemBottomSheetBodyAction.removeFromFavorites
          : MobileViewItemBottomSheetBodyAction.addToFavorites,
      MobileViewItemBottomSheetBodyAction.divider,
      MobileViewItemBottomSheetBodyAction.rename,
      if (view.layout != ViewLayoutPB.Chat)
        MobileViewItemBottomSheetBodyAction.duplicate,
      MobileViewItemBottomSheetBodyAction.divider,
      MobileViewItemBottomSheetBodyAction.delete,
    ];
  }
}

ActionPane buildEndActionPane(
  BuildContext context,
  List<MobilePaneActionType> actions, {
  bool needSpace = true,
  MobilePageCardType? cardType,
  FolderSpaceType? spaceType,
  required double spaceRatio,
}) {
  return ActionPane(
    motion: const ScrollMotion(),
    extentRatio: actions.length / spaceRatio,
    children: [
      if (needSpace) const HSpace(60),
      ...actions.map(
        (action) => action.actionButton(
          context,
          spaceType: spaceType,
          cardType: cardType,
        ),
      ),
    ],
  );
}
