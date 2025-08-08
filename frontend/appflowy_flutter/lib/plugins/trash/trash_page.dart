import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/trash/src/sizes.dart';
import 'package:appflowy/plugins/trash/src/trash_header.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_list.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_scroll_bar.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_scrollview.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:styled_widget/styled_widget.dart';

import 'application/trash_bloc.dart';
import 'src/trash_cell.dart';

/*
 * 垃圾桶页面组件
 * 
 * 核心功能：
 * 1. 显示所有已删除的文档和页面
 * 2. 提供批量恢复/删除操作
 * 3. 单项恢复/永久删除
 * 4. 响应式列表布局
 * 
 * 用户体验：
 * - 清晰的列表展示
 * - 二次确认防误删
 * - 固定表头方便浏览
 * - 水平滚动支持
 */
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 80.0;  /* 左右边距，保证内容居中 */
    return BlocProvider(
      /* 创建TrashBloc并立即加载垃圾桶数据 */
      create: (context) => getIt<TrashBloc>()..add(const TrashEvent.initial()),
      child: BlocBuilder<TrashBloc, TrashState>(
        builder: (context, state) {
          return SizedBox.expand(
            child: Column(
              children: [
                _renderTopBar(context, state),    /* 顶部操作栏 */
                const VSpace(32),
                _renderTrashList(context, state), /* 垃圾桶列表 */
              ],
            ).padding(horizontal: horizontalPadding, vertical: 48),
          );
        },
      ),
    );
  }

  /*
   * 渲染垃圾桶列表
   * 
   * 布局结构：
   * - 外层：垂直滚动条
   * - 内层：水平滚动支持
   * - 使用CustomScrollView实现固定表头
   * 
   * Sliver组成：
   * - SliverPersistentHeader：固定表头
   * - SliverList：数据列表
   */
  Widget _renderTrashList(BuildContext context, TrashState state) {
    const barSize = 6.0;  /* 滚动条宽度 */
    return Expanded(
      child: ScrollbarListStack(
        axis: Axis.vertical,
        controller: _scrollController,
        scrollbarPadding: EdgeInsets.only(top: TrashSizes.headerHeight),
        barSize: barSize,
        child: StyledSingleChildScrollView(
          barSize: barSize,
          axis: Axis.horizontal,  /* 支持水平滚动 */
          child: SizedBox(
            width: TrashSizes.totalWidth,
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: CustomScrollView(
                shrinkWrap: true,
                physics: StyledScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  _renderListHeader(context, state),  /* 固定表头 */
                  _renderListBody(context, state),    /* 数据列表 */
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*
   * 渲染顶部操作栏
   * 
   * 包含元素：
   * 1. 标题："垃圾桶"
   * 2. 全部恢复按钮
   * 3. 全部删除按钮
   * 
   * 安全机制：
   * - 两个批量操作都需要二次确认
   * - 防止误操作导致数据丢失
   * 
   * UI细节：
   * - IntrinsicWidth保证按钮宽度自适应
   * - 图标+文本的组合提高识别度
   */
  Widget _renderTopBar(BuildContext context, TrashState state) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /* 页面标题 */
          FlowyText.semibold(
            LocaleKeys.trash_text.tr(),
            fontSize: FontSizes.s16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const Spacer(),
          /* 全部恢复按钮 */
          IntrinsicWidth(
            child: FlowyButton(
              text: FlowyText.medium(
                LocaleKeys.trash_restoreAll.tr(),
                lineHeight: 1.0,
              ),
              leftIcon: const FlowySvg(FlowySvgs.restore_s),
              onTap: () => showCancelAndConfirmDialog(
                context: context,
                confirmLabel: LocaleKeys.trash_restore.tr(),
                title: LocaleKeys.trash_confirmRestoreAll_title.tr(),
                description: LocaleKeys.trash_confirmRestoreAll_caption.tr(),
                onConfirm: (_) => context
                    .read<TrashBloc>()
                    .add(const TrashEvent.restoreAll()),
              ),
            ),
          ),
          const HSpace(6),
          /* 全部删除按钮 */
          IntrinsicWidth(
            child: FlowyButton(
              text: FlowyText.medium(
                LocaleKeys.trash_deleteAll.tr(),
                lineHeight: 1.0,
              ),
              leftIcon: const FlowySvg(FlowySvgs.delete_s),
              onTap: () => showConfirmDeletionDialog(
                context: context,
                name: LocaleKeys.trash_confirmDeleteAll_title.tr(),
                description: LocaleKeys.trash_confirmDeleteAll_caption.tr(),
                onConfirm: () =>
                    context.read<TrashBloc>().add(const TrashEvent.deleteAll()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
   * 渲染列表表头
   * 
   * 特性：
   * - floating: true - 滚动时可以浮动显示
   * - pinned: true - 始终固定在顶部
   * 
   * 使用SliverPersistentHeader实现固定表头
   * 用户滚动时表头始终可见
   */
  Widget _renderListHeader(BuildContext context, TrashState state) {
    return SliverPersistentHeader(
      delegate: TrashHeaderDelegate(),
      floating: true,  /* 浮动表头 */
      pinned: true,    /* 固定表头 */
    );
  }

  /*
   * 渲染列表主体
   * 
   * 使用SliverList动态构建列表项
   * 
   * 每个列表项功能：
   * 1. 显示删除项信息
   * 2. 恢复按钮 - 恢复到原位置
   * 3. 删除按钮 - 永久删除
   * 
   * 安全特性：
   * - 恢复和删除都需要二次确认
   * - 空名称时显示默认名称
   * 
   * 性能优化：
   * - addAutomaticKeepAlives: false
   * - 避免不必要的Widget缓存
   */
  Widget _renderListBody(BuildContext context, TrashState state) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final object = state.objects[index];
          return SizedBox(
            height: 42,  /* 固定行高 */
            child: TrashCell(
              object: object,
              /* 恢复操作：将项目恢复到原位置 */
              onRestore: () => showCancelAndConfirmDialog(
                context: context,
                title:
                    LocaleKeys.trash_restorePage_title.tr(args: [object.name]),
                description: LocaleKeys.trash_restorePage_caption.tr(),
                confirmLabel: LocaleKeys.trash_restore.tr(),
                onConfirm: (_) => context
                    .read<TrashBloc>()
                    .add(TrashEvent.putback(object.id)),
              ),
              /* 永久删除操作：不可恢复 */
              onDelete: () => showConfirmDeletionDialog(
                context: context,
                name: object.name.trim().isEmpty
                    ? LocaleKeys.menuAppHeader_defaultNewPageName.tr()
                    : object.name,
                description:
                    LocaleKeys.deletePagePrompt_deletePermanentDescription.tr(),
                onConfirm: () =>
                    context.read<TrashBloc>().add(TrashEvent.delete(object)),
              ),
            ),
          );
        },
        childCount: state.objects.length,
        addAutomaticKeepAlives: false,  /* 性能优化 */
      ),
    );
  }
}
