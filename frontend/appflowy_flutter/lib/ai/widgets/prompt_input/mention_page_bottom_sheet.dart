import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/flowy_search_text_field.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/show_mobile_bottom_sheet.dart';
import 'package:appflowy/plugins/base/drag_handler.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import 'mention_page_menu.dart';

/// 显示移动端页面选择器底部弹窗
/// 
/// 功能说明：
/// 1. 显示所有可选页面列表
/// 2. 支持搜索过滤
/// 3. 支持自定义过滤条件
/// 4. 选中后返回页面对象
/// 
/// 参数：
/// - [filter]: 过滤函数，用于筛选可选页面
/// 
/// 返回：选中的页面对象，取消返回null
Future<ViewPB?> showPageSelectorSheet(
  BuildContext context, {
  required bool Function(ViewPB view) filter,
}) async {
  return showMobileBottomSheet<ViewPB>(
    context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    maxChildSize: 0.98,
    enableDraggableScrollable: true,
    scrollableWidgetBuilder: (context, scrollController) {
      return Expanded(
        child: _MobilePageSelectorBody(
          filter: filter,
          scrollController: scrollController,
        ),
      );
    },
    builder: (context) => const SizedBox.shrink(),
  );
}

/// 移动端页面选择器主体组件
/// 
/// 功能说明：
/// 1. 固定头部：标题和搜索框
/// 2. 列表显示所有页面
/// 3. 实时搜索过滤
/// 4. 点击选择页面
/// 
/// 设计特点：
/// - 使用CustomScrollView实现固定头部
/// - FutureBuilder异步加载页面列表
/// - 实时搜索不需要重新加载数据
class _MobilePageSelectorBody extends StatefulWidget {
  const _MobilePageSelectorBody({
    this.filter,
    this.scrollController,
  });

  /// 页面过滤函数
  final bool Function(ViewPB view)? filter;
  /// 滚动控制器
  final ScrollController? scrollController;

  @override
  State<_MobilePageSelectorBody> createState() =>
      _MobilePageSelectorBodyState();
}

class _MobilePageSelectorBodyState extends State<_MobilePageSelectorBody> {
  /// 搜索框控制器
  final textController = TextEditingController();
  /// 页面列表Future，只加载一次
  late final Future<List<ViewPB>> _viewsFuture = _fetchViews();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.scrollController,
      shrinkWrap: true,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _Header(
            child: ColoredBox(
              color: Theme.of(context).cardColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DragHandle(),
                  SizedBox(
                    height: 44.0,
                    child: Center(
                      child: FlowyText.medium(
                        LocaleKeys.document_mobilePageSelector_title.tr(),
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SizedBox(
                      height: 44.0,
                      child: FlowySearchTextField(
                        controller: textController,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const Divider(height: 0.5, thickness: 0.5),
                ],
              ),
            ),
          ),
        ),
        FutureBuilder(
          future: _viewsFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: CircularProgressIndicator.adaptive(),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return SliverToBoxAdapter(
                child: FlowyText(
                  LocaleKeys.document_mobilePageSelector_failedToLoad.tr(),
                ),
              );
            }

            // 应用过滤条件
            final views = snapshot.data!
                .where((v) => widget.filter?.call(v) ?? true)
                .toList();

            // 根据搜索框内容过滤
            final filtered = views.where(
              (v) =>
                  textController.text.isEmpty ||
                  v.name
                      .toLowerCase()
                      .contains(textController.text.toLowerCase()),
            );

            // 无搜索结果
            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: FlowyText(
                  LocaleKeys.document_mobilePageSelector_noPagesFound.tr(),
                ),
              );
            }

            // 显示搜索结果列表
            return SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final view = filtered.elementAt(index);
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(view),  // 选中返回
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Colors.transparent,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            MentionViewIcon(view: view),  // 页面图标
                            const HSpace(8),
                            Expanded(
                              child: MentionViewTitleAndAncestors(view: view),  // 标题和路径
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 获取所有页面列表
  /// 
  /// 通过后端服务获取所有可用页面
  Future<List<ViewPB>> _fetchViews() async =>
      (await ViewBackendService.getAllViews()).toNullable()?.items ?? [];
}

/// 固定头部委托类
/// 
/// 功能说明：
/// 创建一个固定高度的头部
/// 包含标题、搜索框和分隔线
/// 
/// 设计特点：
/// - 固定高度120.5px
/// - 滚动时保持固定
class _Header extends SliverPersistentHeaderDelegate {
  const _Header({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  /// 最大高度
  @override
  double get maxExtent => 120.5;

  /// 最小高度（与最大相同，保持固定）
  @override
  double get minExtent => 120.5;

  /// 不需要重建
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
