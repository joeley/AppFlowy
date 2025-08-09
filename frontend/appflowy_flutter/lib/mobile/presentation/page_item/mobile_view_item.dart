// 移动端视图项组件
// 
// 这是AppFlowy移动端侧边栏中的视图项组件，负责显示和管理工作区中的页面项
// 支持层级结构、拖拽排序、滑动操作、展开/折叠等功能
// 
// 主要特性：
// - 层级式显示，支持多级嵌套
// - 拖拽排序功能
// - 左右滑动操作面板
// - 展开/折叠子视图
import 'dart:io';

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/mobile/application/mobile_router.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/workspace/application/sidebar/folder/folder_bloc.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/home_sizes.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/draggable_view_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 视图项被选中的回调函数类型
/// [ViewPB] 被选中的视图对象
typedef ViewItemOnSelected = void Function(ViewPB);

/// 操作面板构建器类型
/// 用于构建滑动操作面板，返回ActionPane对象
typedef ActionPaneBuilder = ActionPane Function(BuildContext context);

/// 移动端视图项组件
/// 
/// 这是侧边栏中显示的单个视图项，支持层级结构、拖拽和滑动操作
/// 使用ViewBloc管理视图状态，监听视图变化并自动跳转到新创建的视图
class MobileViewItem extends StatelessWidget {
  /// 构造函数
  const MobileViewItem({
    super.key,
    required this.view,
    this.parentView,
    required this.spaceType,
    required this.level,
    this.leftPadding = 10,
    required this.onSelected,
    this.isFirstChild = false,
    this.isDraggable = true,
    required this.isFeedback,
    this.startActionPane,
    this.endActionPane,
  });

  /// 当前视图对象
  final ViewPB view;
  /// 父级视图对象，用于层级关系判断
  final ViewPB? parentView;

  /// 文件夹空间类型（私人/公共）
  final FolderSpaceType spaceType;

  /// 视图项的层级深度
  /// 用于计算左侧缩进距离，实现层级视觉效果
  final int level;

  /// 每个层级的左侧内边距
  /// 最终的左侧内边距 = level * leftPadding
  final double leftPadding;

  /// 视图被选中时的回调函数
  final ViewItemOnSelected onSelected;

  /// 是否为父视图的第一个子视图
  /// 用于显示顶部边框样式
  final bool isFirstChild;

  /// 是否支持拖拽功能
  /// 在作为拖拽反馈组件时应设为false
  final bool isDraggable;

  /// 是否为拖拽反馈组件
  /// 用于区分是否为拖拽过程中的视觉反馈
  final bool isFeedback;

  /// 左侧滑动操作面板构建器
  final ActionPaneBuilder? startActionPane;
  /// 右侧滑动操作面板构建器
  final ActionPaneBuilder? endActionPane;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 为每个视图项创建独立的ViewBloc实例
      create: (_) => ViewBloc(view: view)..add(const ViewEvent.initial()),
      child: BlocConsumer<ViewBloc, ViewState>(
        // 监听新视图创建事件，避免重复处理
        listenWhen: (p, c) =>
            c.lastCreatedView != null &&
            p.lastCreatedView?.id != c.lastCreatedView!.id,
        // 当创建新视图时自动跳转到该视图
        listener: (context, state) => context.pushView(state.lastCreatedView!),
        builder: (context, state) {
          // 使用内部组件渲染实际内容
          return InnerMobileViewItem(
            view: state.view,
            parentView: parentView,
            childViews: state.view.childViews,
            spaceType: spaceType,
            level: level,
            leftPadding: leftPadding,
            showActions: true,
            isExpanded: state.isExpanded,
            onSelected: onSelected,
            isFirstChild: isFirstChild,
            isDraggable: isDraggable,
            isFeedback: isFeedback,
            startActionPane: startActionPane,
            endActionPane: endActionPane,
          );
        },
      ),
    );
  }
}

/// 移动端视图项内部组件
/// 
/// 负责渲染视图项的实际内容，包括单个视图和其子视图的层级结构
/// 处理展开/折叠状态和拖拽功能的包装
class InnerMobileViewItem extends StatelessWidget {
  /// 构造函数
  const InnerMobileViewItem({
    super.key,
    required this.view,
    required this.parentView,
    required this.childViews,
    required this.spaceType,
    this.isDraggable = true,
    this.isExpanded = true,
    required this.level,
    required this.leftPadding,
    required this.showActions,
    required this.onSelected,
    this.isFirstChild = false,
    required this.isFeedback,
    this.startActionPane,
    this.endActionPane,
  });

  /// 当前视图对象
  final ViewPB view;
  /// 父级视图对象
  final ViewPB? parentView;
  /// 子视图列表
  final List<ViewPB> childViews;
  /// 文件夹空间类型
  final FolderSpaceType spaceType;

  /// 是否支持拖拽
  final bool isDraggable;
  /// 是否展开子视图
  final bool isExpanded;
  /// 是否为第一个子视图
  final bool isFirstChild;

  /// 是否为拖拽反馈组件
  final bool isFeedback;

  /// 层级深度
  final int level;
  /// 左侧内边距
  final double leftPadding;

  /// 是否显示操作按钮
  final bool showActions;
  /// 选中回调函数
  final ViewItemOnSelected onSelected;

  /// 左侧滑动操作面板构建器
  final ActionPaneBuilder? startActionPane;
  /// 右侧滑动操作面板构建器
  final ActionPaneBuilder? endActionPane;

  @override
  Widget build(BuildContext context) {
    // 构建单个视图项组件
    Widget child = SingleMobileInnerViewItem(
      view: view,
      parentView: parentView,
      level: level,
      showActions: showActions,
      spaceType: spaceType,
      onSelected: onSelected,
      isExpanded: isExpanded,
      isDraggable: isDraggable,
      leftPadding: leftPadding,
      isFeedback: isFeedback,
      startActionPane: startActionPane,
      endActionPane: endActionPane,
    );

    // 如果视图处于展开状态且有子视图，则渲染子视图列表
    if (isExpanded) {
      if (childViews.isNotEmpty) {
        // 递归构建子视图项，层级深度+1
        final children = childViews.map((childView) {
          return MobileViewItem(
            key: ValueKey('${spaceType.name} ${childView.id}'),
            parentView: view, // 当前视图作为子视图的父视图
            spaceType: spaceType,
            isFirstChild: childView.id == childViews.first.id, // 判断是否为第一个子视图
            view: childView,
            level: level + 1, // 子视图的层级深度加1
            onSelected: onSelected,
            isDraggable: isDraggable,
            leftPadding: leftPadding,
            isFeedback: isFeedback,
            startActionPane: startActionPane,
            endActionPane: endActionPane,
          );
        }).toList();

        // 使用Column将当前视图和子视图垂直排列
        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child, // 当前视图项
            ...children, // 所有子视图项
          ],
        );
      }
    }

    // 如果支持拖拽且不是引用数据库视图，则包装为可拖拽组件
    if (isDraggable && !isReferencedDatabaseView(view, parentView)) {
      child = DraggableViewItem(
        isFirstChild: isFirstChild,
        view: view,
        // 拖拽时的高亮颜色配置
        centerHighlightColor: Colors.blue.shade200, // 中间位置高亮
        topHighlightColor: Colors.blue.shade200,    // 顶部位置高亮
        bottomHighlightColor: Colors.blue.shade200, // 底部位置高亮
        // 拖拽反馈组件：拖拽时显示的视觉反馈
        feedback: (context) {
          return MobileViewItem(
            view: view,
            parentView: parentView,
            spaceType: spaceType,
            level: level,
            onSelected: onSelected,
            isDraggable: false, // 反馈组件不支持拖拽
            leftPadding: leftPadding,
            isFeedback: true,   // 标记为反馈组件
            startActionPane: startActionPane,
            endActionPane: endActionPane,
          );
        },
        child: child,
      );
    }

    return child;
  }
}

/// 单个移动端视图项内部组件
/// 
/// 渲染单个视图项的具体内容，包括展开/折叠按钮、图标、标题等
/// 支持滑动操作面板和点击交互
class SingleMobileInnerViewItem extends StatefulWidget {
  /// 构造函数
  const SingleMobileInnerViewItem({
    super.key,
    required this.view,
    required this.parentView,
    required this.isExpanded,
    required this.level,
    required this.leftPadding,
    this.isDraggable = true,
    required this.spaceType,
    required this.showActions,
    required this.onSelected,
    required this.isFeedback,
    this.startActionPane,
    this.endActionPane,
  });

  /// 当前视图对象
  final ViewPB view;
  /// 父级视图对象
  final ViewPB? parentView;
  /// 是否展开子视图
  final bool isExpanded;

  /// 是否为拖拽反馈组件
  final bool isFeedback;

  /// 层级深度
  final int level;
  /// 左侧内边距
  final double leftPadding;

  /// 是否支持拖拽
  final bool isDraggable;
  /// 是否显示操作按钮
  final bool showActions;
  /// 选中回调函数
  final ViewItemOnSelected onSelected;
  /// 文件夹空间类型
  final FolderSpaceType spaceType;
  /// 左侧滑动操作面板构建器
  final ActionPaneBuilder? startActionPane;
  /// 右侧滑动操作面板构建器
  final ActionPaneBuilder? endActionPane;

  @override
  State<SingleMobileInnerViewItem> createState() =>
      _SingleMobileInnerViewItemState();
}

class _SingleMobileInnerViewItemState extends State<SingleMobileInnerViewItem> {
  @override
  Widget build(BuildContext context) {
    // 构建视图项的子组件列表
    final children = [
      // 展开/折叠按钮（左侧箭头或点）
      _buildLeftIcon(),
      // 视图图标（emoji或默认图标）
      _buildViewIcon(),
      // 图标与标题之间的间距
      const HSpace(8),
      // 视图标题，使用Expanded占据剩余空间
      Expanded(
        child: FlowyText.regular(
          widget.view.nameOrDefault, // 使用视图名称或默认名称
          fontSize: 16.0,
          figmaLineHeight: 20.0,
          overflow: TextOverflow.ellipsis, // 文字超出时显示省略号
        ),
      ),
    ];

    // 构建可点击的视图项容器
    Widget child = InkWell(
      borderRadius: BorderRadius.circular(4.0), // 圆角点击效果
      onTap: () => widget.onSelected(widget.view), // 点击时触发选中回调
      child: SizedBox(
        height: HomeSpaceViewSizes.mViewHeight, // 统一的视图项高度
        child: Padding(
          // 根据层级计算左侧内边距，实现层级缩进效果
          padding: EdgeInsets.only(left: widget.level * widget.leftPadding),
          child: Row(
            children: children, // 将所有子组件水平排列
          ),
        ),
      ),
    );

    // 如果定义了滑动操作面板，则包装为Slidable组件
    if (widget.startActionPane != null || widget.endActionPane != null) {
      child = Slidable(
        // 为滑动组件指定唯一key，用于滑动状态管理
        key: ValueKey(widget.view.hashCode),
        // 左侧滑动操作面板（从左向右滑动时显示）
        startActionPane: widget.startActionPane?.call(context),
        // 右侧滑动操作面板（从右向左滑动时显示）
        endActionPane: widget.endActionPane?.call(context),
        child: child,
      );
    }

    return child;
  }

  /// 构建视图图标
  /// 优先显示自定义emoji图标，否则显示默认图标
  Widget _buildViewIcon() {
    final iconData = widget.view.icon.toEmojiIconData();
    final icon = iconData.isNotEmpty
        ? EmojiIconWidget(
            emoji: widget.view.icon.toEmojiIconData(),
            // Android和iOS平台的emoji大小适配
            emojiSize: Platform.isAndroid ? 16.0 : 18.0,
          )
        : Opacity(
            opacity: 0.7, // 默认图标使用较低的透明度
            child: widget.view.defaultIcon(size: const Size.square(18)),
          );
    // 使用固定宽度容器保持布局一致性
    return SizedBox(
      width: 18.0,
      child: icon,
    );
  }

  /// 构建左侧展开/折叠按钮
  /// - 如果视图有子视图，显示展开/折叠箭头
  /// - 如果视图没有子视图，显示空间占位符
  Widget _buildLeftIcon() {
    const rightPadding = 6.0; // 右侧间距
    
    // 如果没有子视图，则显示空白占位符
    if (context.read<ViewBloc>().state.view.childViews.isEmpty) {
      return HSpace(widget.leftPadding + rightPadding);
    }

    // 有子视图的情况下，显示可点击的展开/折叠按钮
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 扩大点击区域
      child: Padding(
        padding:
            const EdgeInsets.only(right: rightPadding, top: 6.0, bottom: 6.0),
        child: FlowySvg(
          // 根据展开状态显示不同的箭头图标
          widget.isExpanded ? FlowySvgs.m_expand_s : FlowySvgs.m_collapse_s,
          blendMode: null,
        ),
      ),
      // 点击时切换展开/折叠状态
      onTap: () {
        context
            .read<ViewBloc>()
            .add(ViewEvent.setIsExpanded(!widget.isExpanded));
      },
    );
  }
}

/// 判断是否为引用数据库视图
/// 
/// 这是一个临时解决方案：理想情况下应该使用view.isEndPoint等字段来判断
/// 视图是否能包含子视图，但目前还没有该字段
/// 
/// 当前逻辑：如果视图和其父视图都是数据库类型，则认为是引用关系
bool isReferencedDatabaseView(ViewPB view, ViewPB? parentView) {
  if (parentView == null) {
    return false;
  }
  // 子视图和父视图都是数据库类型时，认为是引用关系（不支持拖拽）
  return view.layout.isDatabaseView && parentView.layout.isDatabaseView;
}
