import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/default_mobile_action_pane.dart';
import 'package:appflowy/mobile/presentation/home/favorite_folder/mobile_home_favorite_folder_header.dart';
import 'package:appflowy/mobile/presentation/page_item/mobile_view_item.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端首页收藏夹组件
/// 
/// 负责在AppFlowy移动端首页显示用户收藏的文档、数据库等视图。
/// 设计思想：
/// - 采用折叠式设计，支持展开/折叠显示，节约屏幕空间
/// - 使用FolderBloc管理收藏夹的展开状态，保持状态一致性
/// - 为每个收藏项提供快速操作面板（取消收藏、更多操作）
/// - 支持灵活的展示模式：可强制展开或隐藏标题
class MobileFavoriteFolder extends StatelessWidget {
  const MobileFavoriteFolder({
    super.key,
    required this.views,
    this.showHeader = true,
    this.forceExpanded = false,
  });

  // 是否显示收藏夹标题头部（包括折叠按钮和分割线）
  final bool showHeader;
  // 是否强制展开收藏夹，无视FolderBloc的状态
  final bool forceExpanded;
  // 收藏的视图列表，包含文档、数据库等各种类型的视图
  final List<ViewPB> views;

  @override
  Widget build(BuildContext context) {
    // 如果没有收藏项，不显示任何内容
    if (views.isEmpty) {
      return const SizedBox.shrink();
    }

    // 为收藏夹创建专门的FolderBloc实例
    return BlocProvider<FolderBloc>(
      create: (context) => FolderBloc(type: FolderSpaceType.favorite)
        ..add(
          const FolderEvent.initial(), // 初始化收藏夹状态
        ),
      child: BlocBuilder<FolderBloc, FolderState>(
        builder: (context, state) {
          return Column(
            children: [
              // 条件性显示收藏夹标题和控制按钮
              if (showHeader) ...[
                // 收藏夹标题头部，包含折叠按钮和数量显示
                MobileFavoriteFolderHeader(
                  isExpanded: context.read<FolderBloc>().state.isExpanded,
                  // 点击折叠/展开按钮的处理
                  onPressed: () => context
                      .read<FolderBloc>()
                      .add(const FolderEvent.expandOrUnExpand()),
                  // 添加新收藏时的处理，自动展开收藏夹
                  onAdded: () => context.read<FolderBloc>().add(
                        const FolderEvent.expandOrUnExpand(isExpanded: true),
                      ),
                ),
                const VSpace(8.0), // 标题与分割线间的间距
                // 水平分割线，区分收藏夹和其他内容
                const Divider(
                  height: 1,
                ),
              ],
              // 条件性显示收藏项列表：强制展开或正常展开状态
              if (forceExpanded || state.isExpanded)
                // 使用map生成所有收藏项的widget列表
                ...views.map(
                  (view) => MobileViewItem(
                    // 使用空间类型和视图ID组成唯一key，保证widget稳定性
                    key: ValueKey(
                      '${FolderSpaceType.favorite.name} ${view.id}',
                    ),
                    spaceType: FolderSpaceType.favorite, // 标识为收藏空间类型
                    isDraggable: false, // 收藏项不支持拖拽重排
                    isFirstChild: view.id == views.first.id, // 标识是否为首个项
                    isFeedback: false, // 不是拖拽反馈widget
                    view: view, // 视图数据
                    level: 0, // 层级为0（所有收藏项在同一层级）
                    onSelected: context.pushView, // 点击时的导航处理
                    // 滑动操作面板：取消收藏和更多操作
                    endActionPane: (context) => buildEndActionPane(
                      context,
                      [
                        // 根据当前收藏状态显示对应操作
                        view.isFavorite
                            ? MobilePaneActionType.removeFromFavorites
                            : MobilePaneActionType.addToFavorites,
                        MobilePaneActionType.more, // 更多操作选项
                      ],
                      spaceType: FolderSpaceType.favorite,
                      spaceRatio: 5, // 操作面板宽度比例
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
