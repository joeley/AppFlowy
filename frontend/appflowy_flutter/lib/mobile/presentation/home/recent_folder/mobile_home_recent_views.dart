import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/home/recent_folder/mobile_recent_view.dart';
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
import 'package:appflowy/workspace/application/recent/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// 移动端首页最近访问文件夹组件
/// 
/// 负责在AppFlowy移动端首页显示用户最近访问的文档、数据库等视图。
/// 设计思想：
/// - 采用水平滚动列表，方便用户快速浏览多个最近访问项
/// - 使用RecentViewsBloc管理最近访问历史，支持清空操作
/// - 智能去重逻辑，避免重复显示同一文档
/// - 限制显示数量为20个，保证加载性能和用户体验
/// - 监听工作区切换，自动重置最近访问列表
class MobileRecentFolder extends StatefulWidget {
  const MobileRecentFolder({super.key});

  @override
  State<MobileRecentFolder> createState() => _MobileRecentFolderState();
}

class _MobileRecentFolderState extends State<MobileRecentFolder> {
  @override
  Widget build(BuildContext context) {
    // 为最近访问功能创建独立的BLoC实例
    return BlocProvider(
      create: (context) =>
          RecentViewsBloc()..add(const RecentViewsEvent.initial()),
      // 监听工作区切换事件，当工作区变化时重置最近访问列表
      child: BlocListener<UserWorkspaceBloc, UserWorkspaceState>(
        // 仅在工作区ID发生实际变化时触发重置
        listenWhen: (previous, current) =>
            current.currentWorkspace != null &&
            previous.currentWorkspace?.workspaceId !=
                current.currentWorkspace!.workspaceId,
        // 工作区切换时清空最近访问列表
        listener: (context, state) => context
            .read<RecentViewsBloc>()
            .add(const RecentViewsEvent.resetRecentViews()),
        child: BlocBuilder<RecentViewsBloc, RecentViewsState>(
          builder: (context, state) {
            // 使用Set进行去重，避免显示重复的视图
            final ids = <String>{};

            // 提取视图实体列表
            List<ViewPB> recentViews = state.views.map((e) => e.item).toList();
            // 使用Set的add方法特性进行去重：如果元素已存在，add返回false
            recentViews.retainWhere((element) => ids.add(element.id));

            // 限制显示数量为前20个，保证性能和用户体验
            recentViews = recentViews.take(20).toList();

            // 如果没有最近访问项，不显示任何内容
            if (recentViews.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                // 最近访问视图列表组件
                _RecentViews(
                  key: ValueKey(recentViews), // 使用列表作为key，当列表变化时重建
                  // 注意：最近访问列表是倒序排列的（最近的在前）
                  recentViews: recentViews,
                ),
                const VSpace(12.0), // 底部间距
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 最近访问视图列表组件
/// 
/// 实现水平滚动的最近访问项显示，包括标题和清空功能。
/// 每个项目采用固定尺寸的正方形布局，保证视觉一致性。
class _RecentViews extends StatelessWidget {
  const _RecentViews({
    super.key,
    required this.recentViews,
  });

  // 要显示的最近访问视图列表
  final List<ViewPB> recentViews;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题区域：可点击显示清空选项
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            child: FlowyText.semibold(
              LocaleKeys.sideBar_recent.tr(), // "最近"标题
              fontSize: 20.0,
            ),
            // 点击标题显示操作菜单
            onTap: () {
              showMobileBottomSheet(
                context,
                showDivider: false,
                showDragHandle: true,
                backgroundColor: AFThemeExtension.of(context).background,
                builder: (_) {
                  return Column(
                    children: [
                      // 清空所有最近访问记录的选项
                      FlowyOptionTile.text(
                        text: LocaleKeys.button_clear.tr(),
                        // 使用删除图标，采用错误色彩突出危险性
                        leftIcon: FlowySvg(
                          FlowySvgs.m_delete_s,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textColor: Theme.of(context).colorScheme.error,
                        onTap: () {
                          // 执行清空操作：移除当前所有显示的最近访问项
                          context.read<RecentViewsBloc>().add(
                                RecentViewsEvent.removeRecentViews(
                                  recentViews.map((e) => e.id).toList(),
                                ),
                              );
                          context.pop(); // 关闭底部弹窗
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        // 水平滚动的最近访问项列表
        SizedBox(
          height: 148, // 固定高度148像素，与单项尺寸一致
          child: ListView.separated(
            // 使用PageStorageKey保持滚动位置
            key: const PageStorageKey('recent_views_page_storage_key'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            scrollDirection: Axis.horizontal, // 水平滚动
            itemBuilder: (context, index) {
              final view = recentViews[index];
              return SizedBox.square(
                dimension: 148, // 每个项目都是148x148的正方形
                child: MobileRecentView(view: view), // 单个最近访问项的组件
              );
            },
            // 项目间的分隔符：8像素的水平间距
            separatorBuilder: (context, index) => const HSpace(8),
            itemCount: recentViews.length,
          ),
        ),
      ],
    );
  }
}
