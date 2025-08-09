import 'package:appflowy/features/page_access_level/logic/page_access_level_bloc.dart';
import 'package:appflowy/features/share_tab/data/models/share_access_level.dart';
import 'package:appflowy/features/workspace/data/repositories/rust_workspace_repository_impl.dart';
import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/application/base/mobile_view_page_bloc.dart';
import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/mobile/presentation/base/view_page/app_bar_buttons.dart';
import 'package:appflowy/mobile/presentation/presentation.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_state_container.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/plugins/document/presentation/document_collaborators.dart';
import 'package:appflowy/plugins/document/presentation/editor_notification.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
import 'package:appflowy/shared/icon_emoji_picker/tab.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/application/favorite/favorite_bloc.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy/workspace/presentation/widgets/view_title_bar.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/*
 * 移动端视图页面基类
 * 
 * 所有移动端视图（文档、表格、看板等）的统一底层容器
 * 提供通用功能：
 * 1. 状态管理（BLoC注入）
 * 2. 导航栏控制
 * 3. 主题适配
 * 4. 滚动监听
 * 5. 权限控制
 */

class MobileViewPage extends StatefulWidget {
  const MobileViewPage({
    super.key,
    required this.id,
    required this.viewLayout,
    this.title,
    this.arguments,
    this.fixedTitle,
    this.showMoreButton = true,
    this.blockId,
    this.bodyPaddingTop = 0.0,
    this.tabs = const [PickerTabType.emoji, PickerTabType.icon],
  });

  /* 视图ID，唯一标识 */
  final String id;
  /* 视图布局类型（文档、表格、看板等） */
  final ViewLayoutPB viewLayout;
  /* 可选标题 */
  final String? title;
  /* 额外参数，用于传递特定配置 */
  final Map<String, dynamic>? arguments;
  /* 是否显示更多按钮 */
  final bool showMoreButton;
  /* 文档块ID，用于定位 */
  final String? blockId;
  /* 主体顶部内边距 */
  final double bodyPaddingTop;
  /* 图标选择器标签页 */
  final List<PickerTabType> tabs;

  /* 固定标题（仅用于行页面） */
  final String? fixedTitle;

  @override
  State<MobileViewPage> createState() => _MobileViewPageState();
}

class _MobileViewPageState extends State<MobileViewPage> {
  /* 滚动通知观察者
   * 用于判断用户滚动方向，在沉浸模式下控制应用栏显示 */
  ScrollNotificationObserverState? _scrollNotificationObserver;

  /* 应用栏透明度控制器
   * 沉浸模式下根据滚动位置调整透明度 */
  final ValueNotifier<double> _appBarOpacity = ValueNotifier(1.0);

  @override
  void initState() {
    super.initState();

    /* 启动提醒服务 */
    getIt<ReminderBloc>().add(const ReminderEvent.started());
  }

  @override
  void dispose() {
    _appBarOpacity.dispose();

    /* 不需要手动移除监听器
     * 观察者在组件卸载时会自动处理 */
    _scrollNotificationObserver = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      /* 创建页面级别BLoC，管理视图状态 */
      create: (_) => MobileViewPageBloc(viewId: widget.id)
        ..add(const MobileViewPageEvent.initial()),
      child: BlocBuilder<MobileViewPageBloc, MobileViewPageState>(
        builder: (context, state) {
          /* 解析视图数据 */
          final view = state.result?.fold((s) => s, (f) => null);
          final body = _buildBody(context, state);

          /* 视图未加载时不显示内容 */
          if (view == null) {
            return SizedBox.shrink();
          }

          return MultiBlocProvider(
            providers: [
              /* 收藏BLoC */
              BlocProvider(
                create: (_) =>
                    FavoriteBloc()..add(const FavoriteEvent.initial()),
              ),
              /* 视图BLoC - 管理视图元数据 */
              BlocProvider(
                create: (_) =>
                    ViewBloc(view: view)..add(const ViewEvent.initial()),
              ),
              /* 提醒BLoC - 使用全局单例 */
              BlocProvider.value(
                value: getIt<ReminderBloc>(),
              ),
              /* 分享BLoC - 管理分享状态 */
              BlocProvider(
                create: (_) =>
                    ShareBloc(view: view)..add(const ShareEvent.initial()),
              ),
              /* 工作区BLoC - 只在有用户信息时创建 */
              if (state.userProfilePB != null)
                BlocProvider(
                  create: (_) => UserWorkspaceBloc(
                    userProfile: state.userProfilePB!,
                    repository: RustWorkspaceRepositoryImpl(
                      userId: state.userProfilePB!.id,
                    ),
                  )..add(UserWorkspaceEvent.initialize()),
                ),
              /* 文档页面样式BLoC - 仅用于文档视图 */
              if (view.layout.isDocumentView)
                BlocProvider(
                  create: (_) => DocumentPageStyleBloc(view: view)
                    ..add(const DocumentPageStyleEvent.initial()),
                ),
              /* 页面访问级别BLoC - 用于文档和数据库视图 */
              if (view.layout.isDocumentView || view.layout.isDatabaseView)
                BlocProvider(
                  create: (_) => PageAccessLevelBloc(view: view)
                    ..add(const PageAccessLevelEvent.initial()),
                ),
            ],
            child: Builder(
              builder: (context) {
                /* 监听视图变化并重建 */
                final view = context.watch<ViewBloc>().state.view;
                return _buildApp(context, view, body);
              },
            ),
          );
        },
      ),
    );
  }

  /// 构建应用程序主体结构
  /// 
  /// 根据视图类型（文档/其他）选择不同的应用栏和布局方式
  /// 文档视图使用沉浸式应用栏，其他视图使用标准应用栏
  Widget _buildApp(
    BuildContext context,
    ViewPB? view,
    Widget child,
  ) {
    // 判断是否为文档视图，文档视图需要特殊的沉浸式处理
    final isDocument = view?.layout.isDocumentView ?? false;
    // 构建应用栏标题
    final title = _buildTitle(context, view);
    // 构建应用栏操作按钮
    final actions = _buildAppBarActions(context, view);
    
    // 根据视图类型选择不同的应用栏实现
    final appBar = isDocument
        ? MobileViewPageImmersiveAppBar(
            preferredSize: Size(
              double.infinity,
              AppBarTheme.of(context).toolbarHeight ?? kToolbarHeight,
            ),
            title: title,
            appBarOpacity: _appBarOpacity, // 沉浸模式下的透明度控制
            actions: actions,
            view: view,
          )
        : FlowyAppBar(title: title, actions: actions); // 标准应用栏
    
    // 根据视图类型处理主体内容
    final body = isDocument
        ? Builder(
            builder: (context) {
              // 重建滚动通知观察者，用于沉浸模式下的应用栏透明度控制
              _rebuildScrollNotificationObserver(context);
              return child;
            },
          )
        : SafeArea(child: child); // 非文档视图使用SafeArea包装
    
    return Scaffold(
      // 文档视图延伸到应用栏后面，实现沉浸效果
      extendBodyBehindAppBar: isDocument,
      appBar: appBar,
      body: Padding(
        // 应用顶部内边距
        padding: EdgeInsets.only(top: widget.bodyPaddingTop),
        child: body,
      ),
    );
  }

  /// 构建页面主体内容
  /// 
  /// 处理加载状态、错误状态和成功状态的不同显示
  /// 使用插件系统动态构建不同类型的视图内容
  Widget _buildBody(BuildContext context, MobileViewPageState state) {
    // 加载状态：显示进度指示器
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 检查是否有结果数据
    final result = state.result;
    if (result == null) {
      // 无结果时显示错误状态容器
      return FlowyMobileStateContainer.error(
        emoji: '😔',
        title: LocaleKeys.error_weAreSorry.tr(),
        description: LocaleKeys.error_loadingViewError.tr(),
        errorMsg: '',
      );
    }

    // 处理Either<ViewPB, FlowyError>类型的结果
    return result.fold(
      // 成功情况：构建视图内容
      (view) {
        // 获取视图对应的插件并初始化
        final plugin = view.plugin(arguments: widget.arguments ?? const {})
          ..init();
        // 使用插件的widgetBuilder构建具体的视图内容
        return plugin.widgetBuilder.buildWidget(
          shrinkWrap: false,
          context: PluginContext(userProfile: state.userProfilePB),
          // 传递给插件的数据上下文
          data: {
            MobileDocumentScreen.viewFixedTitle: widget.fixedTitle,
            MobileDocumentScreen.viewBlockId: widget.blockId,
            MobileDocumentScreen.viewSelectTabs: widget.tabs,
          },
        );
      },
      // 错误情况：显示错误信息
      (error) {
        return FlowyMobileStateContainer.error(
          emoji: '😔',
          title: LocaleKeys.error_weAreSorry.tr(),
          description: LocaleKeys.error_loadingViewError.tr(),
          errorMsg: error.toString(),
        );
      },
    );
  }

  /// 构建应用栏右侧操作按钮
  /// 
  /// 根据视图类型和权限状态动态生成操作按钮列表
  /// 文档视图：协作者、同步指示器、布局按钮、更多按钮
  /// 数据库视图：同步指示器、更多按钮
  List<Widget> _buildAppBarActions(BuildContext context, ViewPB? view) {
    if (view == null) {
      return [];
    }

    // 获取当前页面状态
    final isImmersiveMode =
        context.read<MobileViewPageBloc>().state.isImmersiveMode;
    final isLocked =
        context.read<PageAccessLevelBloc?>()?.state.isLocked ?? false;
    final accessLevel = context.read<PageAccessLevelBloc>().state.accessLevel;
    final actions = <Widget>[];

    // 同步功能开启且为文档视图时显示协作者信息
    if (FeatureFlag.syncDocument.isOn) {
      if (view.layout.isDocumentView) {
        actions.addAll([
          DocumentCollaborators(
            width: 60,
            height: 44,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(vertical: 8),
            view: view,
          ),
          const HSpace(12.0), // 协作者组件后的间距
        ]);
      }
    }

    // 文档视图且未锁定时显示布局按钮
    if (view.layout.isDocumentView && !isLocked) {
      actions.addAll([
        MobileViewPageLayoutButton(
          view: view,
          isImmersiveMode: isImmersiveMode,
          appBarOpacity: _appBarOpacity, // 沉浸模式下的透明度控制
          tabs: widget.tabs,
        ),
      ]);
    }

    // 根据权限和配置决定是否显示更多按钮
    if (widget.showMoreButton && accessLevel != ShareAccessLevel.readOnly) {
      actions.addAll([
        MobileViewPageMoreButton(
          view: view,
          isImmersiveMode: isImmersiveMode,
          appBarOpacity: _appBarOpacity,
        ),
      ]);
    } else {
      // 不显示更多按钮时添加占位间距
      actions.addAll([
        const HSpace(18.0),
      ]);
    }

    return actions;
  }

  /// 构建应用栏标题
  /// 
  /// 在沉浸模式下，根据滚动位置动态调整标题显示
  /// 透明度低时显示锁定状态，透明度高时显示完整标题
  Widget _buildTitle(BuildContext context, ViewPB? view) {
    final icon = view?.icon;
    return ValueListenableBuilder(
      valueListenable: _appBarOpacity, // 监听应用栏透明度变化
      builder: (_, value, child) {
        // 当透明度很低时（滚动到顶部附近），只显示锁定状态
        if (value < 0.99) {
          return Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: _buildLockStatus(context, view),
          );
        }

        // 确定显示的标题文本（优先级：固定标题 > 视图名称 > 传入标题）
        final name =
            widget.fixedTitle ?? view?.nameOrDefault ?? widget.title ?? '';

        // 透明度较高时显示完整标题
        return Opacity(
          opacity: value, // 根据滚动位置调整整体透明度
          child: Row(
            children: [
              // 显示视图图标（如果存在）
              if (icon != null && icon.value.isNotEmpty) ...[
                RawEmojiIconWidget(
                  emoji: icon.toEmojiIconData(),
                  emojiSize: 15,
                ),
                const HSpace(4), // 图标与标题间的间距
              ],
              // 标题文本，使用Flexible允许文本自适应宽度
              Flexible(
                child: FlowyText.medium(
                  name,
                  fontSize: 15.0,
                  overflow: TextOverflow.ellipsis, // 文本溢出时显示省略号
                  figmaLineHeight: 18.0,
                ),
              ),
              const HSpace(4.0),
              // 锁定状态图标
              _buildLockStatusIcon(context, view),
            ],
          ),
        );
      },
    );
  }

  /// 构建页面锁定状态显示组件
  /// 
  /// 在沉浸模式下透明度较低时显示，用于提示用户当前页面的锁定状态
  Widget _buildLockStatus(BuildContext context, ViewPB? view) {
    // 聊天视图不支持锁定功能
    if (view == null || view.layout == ViewLayoutPB.Chat) {
      return const SizedBox.shrink();
    }

    return BlocConsumer<PageAccessLevelBloc, PageAccessLevelState>(
      // 只在锁定状态加载完成时触发监听
      listenWhen: (previous, current) =>
          previous.isLoadingLockStatus == current.isLoadingLockStatus &&
          current.isLoadingLockStatus == false,
      // 当页面被锁定时的处理
      listener: (context, state) {
        if (state.isLocked) {
          // 显示锁定提示
          showToastNotification(
            message: LocaleKeys.lockPage_pageLockedToast.tr(),
          );
          // 退出编辑模式
          EditorNotification.exitEditing().post();
        }
      },
      // 根据锁定状态构建不同的UI组件
      builder: (context, state) {
        if (state.isLocked) {
          // 显示已锁定状态
          return LockedPageStatus();
        } else if (!state.isLocked && state.lockCounter > 0) {
          // 显示重新锁定状态（之前被锁定过）
          return ReLockedPageStatus();
        }
        // 未锁定状态不显示任何内容
        return const SizedBox.shrink();
      },
    );
  }

  /// 构建锁定状态图标
  /// 
  /// 在标题栏中显示的小图标，支持点击切换锁定状态
  Widget _buildLockStatusIcon(BuildContext context, ViewPB? view) {
    // 聊天视图不支持锁定功能
    if (view == null || view.layout == ViewLayoutPB.Chat) {
      return const SizedBox.shrink();
    }

    return BlocConsumer<PageAccessLevelBloc, PageAccessLevelState>(
      // 只在锁定状态加载完成时触发监听
      listenWhen: (previous, current) =>
          previous.isLoadingLockStatus == current.isLoadingLockStatus &&
          current.isLoadingLockStatus == false,
      // 监听锁定状态变化
      listener: (context, state) {
        if (state.isLocked) {
          showToastNotification(
            message: LocaleKeys.lockPage_pageLockedToast.tr(),
          );
        }
      },
      // 根据状态构建不同的锁定图标
      builder: (context, state) {
        if (state.isLocked) {
          // 已锁定：显示锁定图标，点击可解锁
          return GestureDetector(
            behavior: HitTestBehavior.opaque, // 扩大点击区域
            onTap: () {
              // 发送解锁事件
              context.read<PageAccessLevelBloc>().add(
                    const PageAccessLevelEvent.unlock(),
                  );
            },
            child: Padding(
              padding: const EdgeInsets.only(
                top: 4.0,
                right: 8,
                bottom: 4.0,
              ),
              child: FlowySvg(
                FlowySvgs.lock_page_fill_s, // 锁定状态图标
                blendMode: null,
              ),
            ),
          );
        } else if (!state.isLocked && state.lockCounter > 0) {
          // 未锁定但之前被锁定过：显示解锁图标，点击可重新锁定
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // 发送锁定事件
              context.read<PageAccessLevelBloc>().add(
                    const PageAccessLevelEvent.lock(),
                  );
            },
            child: Padding(
              padding: const EdgeInsets.only(
                top: 4.0,
                right: 8,
                bottom: 4.0,
              ),
              child: FlowySvg(
                FlowySvgs.unlock_page_s, // 解锁状态图标
                color: Color(0xFF8F959E), // 灰色显示
                blendMode: null,
              ),
            ),
          );
        }
        // 从未被锁定过的页面不显示任何图标
        return const SizedBox.shrink();
      },
    );
  }

  /// 重建滚动通知观察者
  /// 
  /// 用于沉浸模式下监听滚动事件，动态调整应用栏透明度
  void _rebuildScrollNotificationObserver(BuildContext context) {
    // 移除之前的监听器，避免内存泄漏
    _scrollNotificationObserver?.removeListener(_onScrollNotification);
    // 从当前context获取滚动通知观察者
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    // 添加新的滚动通知监听器
    _scrollNotificationObserver?.addListener(_onScrollNotification);
  }

  /// 沉浸模式相关功能
  /// 根据滚动位置自动显示或隐藏应用栏
  /// 
  /// 监听滚动事件，动态调整应用栏透明度以实现沉浸式体验
  void _onScrollNotification(ScrollNotification notification) {
    // 如果观察者为空则直接返回
    if (_scrollNotificationObserver == null) {
      return;
    }

    // 只处理滚动更新通知，且符合默认谓词条件
    if (notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      final ScrollMetrics metrics = notification.metrics;
      
      // 计算透明度变化的基准高度
      double height =
          MediaQuery.of(context).padding.top + widget.bodyPaddingTop;
      // Android平台需要额外考虑工具栏高度
      if (defaultTargetPlatform == TargetPlatform.android) {
        height += AppBarTheme.of(context).toolbarHeight ?? kToolbarHeight;
      }
      
      // 计算滚动进度（0.0到1.0之间）
      final progress = (metrics.pixels / height).clamp(0.0, 1.0);
      
      // 降低应用栏透明度变化的敏感度，避免频繁更新
      // 只有在变化足够大或到达边界值时才更新
      if ((progress - _appBarOpacity.value).abs() >= 0.1 ||
          progress == 0 ||
          progress == 1.0) {
        _appBarOpacity.value = progress;
      }
    }
  }
}
