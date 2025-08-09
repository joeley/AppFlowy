// 导入页面访问权限相关的Bloc管理器
import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/base/mobile_view_page_bloc.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar_actions.dart';
import 'package:appflowy/mobile/presentation/base/view_page/more_bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/plugins/document/presentation/editor_notification.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/page_style/page_style_bottom_sheet.dart';
import 'package:appflowy/plugins/shared/share/share_bloc.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/**
 * 移动端沉浸式AppBar组件
 * 
 * 设计思想：
 * - 支持沉浸式模式，在有封面时可以透明覆盖
 * - 根据透明度动态调整按钮外观
 * - 实现PreferredSizeWidget，可以用作Scaffold的appBar
 * 
 * 使用场景：
 * - 文档、数据库等页面的顶部导航栏
 * - 需要支持沉浸式体验的移动端页面
 */
class MobileViewPageImmersiveAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /**
   * 沉浸式AppBar构造函数
   * 
   * @param preferredSize AppBar的首选尺寸
   * @param appBarOpacity AppBar透明度的可监听对象
   * @param title 标题组件
   * @param actions 右侧动作按钮列表
   * @param view 当前视图对象
   */
  const MobileViewPageImmersiveAppBar({
    super.key,
    required this.preferredSize,
    required this.appBarOpacity,
    required this.title,
    required this.actions,
    required this.view,
  });

  final ValueListenable appBarOpacity; // AppBar透明度监听器
  final Widget title; // 标题组件
  final List<Widget> actions; // 右侧动作按钮列表
  final ViewPB? view; // 当前视图数据
  @override
  final Size preferredSize; // AppBar首选尺寸

  /**
   * 构建AppBar组件
   * 使用ValueListenableBuilder监听透明度变化，动态调整外观
   */
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appBarOpacity,
      builder: (_, opacity, __) => FlowyAppBar(
        // 根据透明度设置背景颜色，支持沉浸式效果
        backgroundColor:
            AppBarTheme.of(context).backgroundColor?.withValues(alpha: opacity),
        showDivider: false, // 不显示分割线
        title: _buildTitle(context, opacity: opacity),
        leadingWidth: 44, // 左侧按钮区域宽度
        leading: Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0, left: 12.0),
          child: _buildAppBarBackButton(context),
        ),
        actions: actions, // 右侧动作按钮
      ),
    );
  }

  /**
   * 构建标题组件
   * 
   * @param context 构建上下文
   * @param opacity 当前透明度值
   * @return 标题Widget
   */
  Widget _buildTitle(
    BuildContext context, {
    required double opacity,
  }) {
    return title;
  }

  /**
   * 构建AppBar的返回按钮
   * 支持沉浸式模式的视觉效果
   * 
   * @param context 构建上下文
   * @return 返回按钮Widget
   */
  Widget _buildAppBarBackButton(BuildContext context) {
    return AppBarButton(
      padding: EdgeInsets.zero,
      onTap: (context) => context.pop(), // 点击时返回上一页
      child: _ImmersiveAppBarButton(
        icon: FlowySvgs.m_app_bar_back_s, // 返回图标
        dimension: 30.0, // 按钮尺寸
        iconPadding: 3.0, // 图标内边距
        // 获取当前是否为沉浸式模式
        isImmersiveMode:
            context.read<MobileViewPageBloc>().state.isImmersiveMode,
        appBarOpacity: appBarOpacity, // 传递透明度监听器
      ),
    );
  }
}

/**
 * 移动端视图页面更多功能按钮
 * 
 * 设计思想：
 * - 提供视图页面的扩展功能入口
 * - 支持沉浸式模式下的视觉适配
 * - 通过底部弹窗展示更多操作选项
 * 
 * 使用场景：
 * - 文档、数据库等页面的更多操作入口
 * - 需要访问重命名、删除、分享等功能时
 */
class MobileViewPageMoreButton extends StatelessWidget {
  /**
   * 更多功能按钮构造函数
   * 
   * @param view 当前视图对象
   * @param isImmersiveMode 是否为沉浸式模式
   * @param appBarOpacity AppBar透明度监听器
   */
  const MobileViewPageMoreButton({
    super.key,
    required this.view,
    required this.isImmersiveMode,
    required this.appBarOpacity,
  });

  final ViewPB view; // 当前视图数据
  final bool isImmersiveMode; // 是否为沉浸式模式
  final ValueListenable appBarOpacity; // AppBar透明度监听器

  /**
   * 构建更多功能按钮
   * 点击时显示底部弹窗，提供各种页面操作选项
   */
  @override
  Widget build(BuildContext context) {
    return AppBarButton(
      padding: const EdgeInsets.only(left: 8, right: 16),
      onTap: (context) {
        // 退出编辑模式，确保状态一致性
        EditorNotification.exitEditing().post();

        // 显示更多功能的底部弹窗
        showMobileBottomSheet(
          context,
          showDragHandle: true, // 显示拖拽手柄
          showDivider: false, // 不显示分割线
          backgroundColor: AFThemeExtension.of(context).background,
          builder: (_) => MultiBlocProvider(
            // 为底部弹窗提供必要的Bloc实例
            providers: [
              BlocProvider.value(value: context.read<ViewBloc>()), // 视图管理
              BlocProvider.value(value: context.read<FavoriteBloc>()), // 收藏管理
              BlocProvider.value(value: context.read<MobileViewPageBloc>()), // 移动端页面管理
              BlocProvider.value(value: context.read<ShareBloc>()), // 分享功能
              BlocProvider.value(value: context.read<PageAccessLevelBloc>()), // 页面权限管理
            ],
            child: MobileViewPageMoreBottomSheet(view: view),
          ),
        );
      },
      child: _ImmersiveAppBarButton(
        icon: FlowySvgs.m_app_bar_more_s, // 更多图标
        dimension: 30.0,
        iconPadding: 3.0,
        isImmersiveMode: isImmersiveMode,
        appBarOpacity: appBarOpacity,
      ),
    );
  }
}

/**
 * 移动端视图页面布局按钮
 * 
 * 设计思想：
 * - 专门用于文档类型页面的样式设置
 * - 只在文档视图中显示，其他类型页面自动隐藏
 * - 提供页面样式的快速访问入口
 * 
 * 使用场景：
 * - 文档页面的样式设置（字体、颜色、背景等）
 * - 需要自定义页面外观时
 */
class MobileViewPageLayoutButton extends StatelessWidget {
  /**
   * 布局按钮构造函数
   * 
   * @param view 当前视图对象
   * @param isImmersiveMode 是否为沉浸式模式
   * @param appBarOpacity AppBar透明度监听器
   * @param tabs 页面样式选择器的标签页类型
   */
  const MobileViewPageLayoutButton({
    super.key,
    required this.view,
    required this.isImmersiveMode,
    required this.appBarOpacity,
    required this.tabs,
  });

  final ViewPB view; // 当前视图数据
  final List<PickerTabType> tabs; // 样式选择器支持的标签页类型
  final bool isImmersiveMode; // 是否为沉浸式模式
  final ValueListenable appBarOpacity; // AppBar透明度监听器

  /**
   * 构建布局按钮
   * 只有文档类型的视图才显示此按钮
   */
  @override
  Widget build(BuildContext context) {
    // 只有文档类型的视图才显示布局按钮
    // 其他类型（数据库、看板等）不需要此功能
    if (view.layout != ViewLayoutPB.Document) {
      return const SizedBox.shrink();
    }

    return AppBarButton(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      onTap: (context) {
        // 退出编辑模式，避免状态冲突
        EditorNotification.exitEditing().post();

        // 显示页面样式设置的底部弹窗
        showMobileBottomSheet(
          context,
          showDragHandle: true, // 显示拖拽手柄
          showDivider: false, // 不显示分割线
          showDoneButton: true, // 显示完成按钮
          showHeader: true, // 显示头部
          title: LocaleKeys.pageStyle_title.tr(), // 页面样式标题
          backgroundColor: AFThemeExtension.of(context).background,
          builder: (_) => MultiBlocProvider(
            providers: [
              // 文档页面样式管理Bloc
              BlocProvider.value(value: context.read<DocumentPageStyleBloc>()),
              // 移动端页面管理Bloc
              BlocProvider.value(value: context.read<MobileViewPageBloc>()),
            ],
            child: PageStyleBottomSheet(
              view: context.read<ViewBloc>().state.view,
              tabs: tabs, // 传入支持的标签页类型
            ),
          ),
        );
      },
      child: _ImmersiveAppBarButton(
        icon: FlowySvgs.m_layout_s, // 布局图标
        dimension: 30.0,
        iconPadding: 3.0,
        isImmersiveMode: isImmersiveMode,
        appBarOpacity: appBarOpacity,
      ),
    );
  }
}

/**
 * 沉浸式AppBar按钮组件（私有类）
 * 
 * 设计思想：
 * - 专门为沉浸式模式设计的按钮样式
 * - 根据AppBar透明度和沉浸式状态动态调整外观
 * - 在沉浸式模式下提供半透明黑色背景，确保可见性
 * 
 * 技术实现：
 * - 使用ValueListenableBuilder监听透明度变化
 * - 在沉浸式模式下，图标为白色，背景为半透明黑色
 * - 非沉浸式模式下使用默认主题色
 */
class _ImmersiveAppBarButton extends StatelessWidget {
  /**
   * 沉浸式按钮构造函数
   * 
   * @param icon 按钮图标
   * @param dimension 按钮尺寸
   * @param iconPadding 图标内边距
   * @param isImmersiveMode 是否为沉浸式模式
   * @param appBarOpacity AppBar透明度监听器
   */
  const _ImmersiveAppBarButton({
    required this.icon,
    required this.dimension,
    required this.iconPadding,
    required this.isImmersiveMode,
    required this.appBarOpacity,
  });

  final FlowySvgData icon; // 按钮图标数据
  final double dimension; // 按钮尺寸
  final double iconPadding; // 图标内边距
  final bool isImmersiveMode; // 是否为沉浸式模式
  final ValueListenable appBarOpacity; // AppBar透明度监听器

  /**
   * 构建沉浸式按钮组件
   * 根据沉浸式模式和透明度动态调整按钮外观
   */
  @override
  Widget build(BuildContext context) {
    // 确保按钮尺寸在合理范围内
    assert(
      dimension > 0.0 && dimension <= kToolbarHeight,
      'dimension must be greater than 0, and less than or equal to kToolbarHeight',
    );

    // 沉浸式模式下，图标为白色并添加黑色背景
    // 图标的透明度会根据AppBar的透明度变化
    return UnconstrainedBox(
      child: SizedBox.square(
        dimension: dimension,
        child: ValueListenableBuilder(
          valueListenable: appBarOpacity,
          builder: (context, appBarOpacity, child) {
            Color? color;

            // 如果没有封面或封面不是沉浸式的，
            // 确保AppBar始终可见，使用默认颜色
            if (!isImmersiveMode) {
              color = null; // 使用默认主题色
            } else if (appBarOpacity < 0.99) {
              // 沉浸式模式且AppBar透明时，使用白色图标
              color = Colors.white;
            }

            Widget child = Container(
              margin: EdgeInsets.all(iconPadding),
              child: FlowySvg(icon, color: color),
            );

            // 在沉浸式模式且AppBar透明时，添加半透明黑色背景
            // 提高按钮在浅色背景上的可见性
            if (isImmersiveMode && appBarOpacity <= 0.99) {
              child = DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(dimension / 2.0), // 圆形背景
                  color: Colors.black.withValues(alpha: 0.2), // 20%透明度的黑色背景
                ),
                child: child,
              );
            }

            return child;
          },
        ),
      ),
    );
  }
}
