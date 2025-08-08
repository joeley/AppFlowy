import 'package:appflowy/features/workspace/logic/workspace_bloc.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/application/sidebar/space/space_bloc.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/recent_views_list.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_field.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_results_list.dart';
import 'package:appflowy/workspace/presentation/home/menu/menu_shared_state.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pbenum.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbenum.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'widgets/search_ask_ai_entrance.dart';

/*
 * 命令面板主组件
 * 
 * 核心功能：
 * 1. 全局搜索入口（Cmd/Ctrl + P 快捷键）
 * 2. 快速导航到任何文档或页面
 * 3. AI 辅助搜索
 * 4. 最近查看历史
 * 
 * 设计模式：
 * - InheritedWidget：跨组件树共享状态
 * - ValueNotifier：状态变化通知
 * - Controller模式：统一管理显示逻辑
 * 
 * 架构特点：
 * - 可在任何页面通过快捷键唤起
 * - 悬浮层显示，不影响底层内容
 * - 支持模糊搜索和智能排序
 */
class CommandPalette extends InheritedWidget {
  CommandPalette({
    super.key,
    required Widget? child,
    required this.notifier,
  }) : super(
          child: _CommandPaletteController(notifier: notifier, child: child),
        );

  /* 状态通知器：控制面板开关和数据传递 */
  final ValueNotifier<CommandPaletteNotifierValue> notifier;

  /* 获取最近的CommandPalette实例（必须存在） */
  static CommandPalette of(BuildContext context) {
    final CommandPalette? result =
        context.dependOnInheritedWidgetOfExactType<CommandPalette>();

    assert(result != null, "CommandPalette could not be found");

    return result!;
  }

  /* 安全获取CommandPalette实例（可能为null） */
  static CommandPalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommandPalette>();

  /* 切换命令面板显示状态 */
  void toggle({
    UserWorkspaceBloc? workspaceBloc,
    SpaceBloc? spaceBloc,
  }) {
    final value = notifier.value;
    notifier.value = notifier.value.copyWith(
      isOpen: !value.isOpen,
      userWorkspaceBloc: workspaceBloc,
      spaceBloc: spaceBloc,
    );
  }

  /* 更新关联的BLoC实例 */
  void updateBlocs({
    UserWorkspaceBloc? workspaceBloc,
    SpaceBloc? spaceBloc,
  }) {
    notifier.value = notifier.value.copyWith(
      userWorkspaceBloc: workspaceBloc,
      spaceBloc: spaceBloc,
    );
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/*
 * 快捷键意图定义
 * 用于处理Cmd/Ctrl+P快捷键
 */
class _ToggleCommandPaletteIntent extends Intent {
  const _ToggleCommandPaletteIntent();
}

/*
 * 命令面板控制器组件
 * 
 * 职责：
 * 1. 监听快捷键触发
 * 2. 管理弹出层的显示/隐藏
 * 3. 处理状态变化通知
 * 4. 协调BLoC之间的通信
 */
class _CommandPaletteController extends StatefulWidget {
  const _CommandPaletteController({
    required this.child,
    required this.notifier,
  });

  final Widget? child;
  final ValueNotifier<CommandPaletteNotifierValue> notifier;

  @override
  State<_CommandPaletteController> createState() =>
      _CommandPaletteControllerState();
}

class _CommandPaletteControllerState extends State<_CommandPaletteController> {
  late ValueNotifier<CommandPaletteNotifierValue> _toggleNotifier =
      widget.notifier;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _toggleNotifier.addListener(_onToggle);
  }

  @override
  void dispose() {
    _toggleNotifier.removeListener(_onToggle);
    super.dispose();
  }

  @override
  void didUpdateWidget(_CommandPaletteController oldWidget) {
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_onToggle);
      _toggleNotifier = widget.notifier;
      _toggleNotifier.addListener(_onToggle);
    }
    super.didUpdateWidget(oldWidget);
  }

  /*
   * 处理命令面板开关切换
   * 
   * 打开流程：
   * 1. 刷新缓存的视图数据
   * 2. 准备必要的BLoC提供器
   * 3. 显示浮动层
   * 4. 传递快捷键构建器
   * 
   * 关闭流程：
   * 1. 弹出浮动层
   * 2. 重置状态标志
   * 
   * 注意事项：
   * - 使用FlowyOverlay而非Dialog，支持更灵活的定位
   * - 通过MultiBlocProvider传递必要的状态管理器
   * - 异步处理关闭回调，确保状态同步
   */
  void _onToggle() {
    if (_toggleNotifier.value.isOpen && !_isOpen) {
      /* 打开命令面板 */
      _isOpen = true;
      final workspaceBloc = _toggleNotifier.value.userWorkspaceBloc;
      final spaceBloc = _toggleNotifier.value.spaceBloc;
      final commandBloc = context.read<CommandPaletteBloc>();
      Log.info(
        'CommandPalette onToggle: workspaceType ${workspaceBloc?.state.userProfile.workspaceType}',
      );
      /* 刷新视图缓存，确保搜索结果准确 */
      commandBloc.add(CommandPaletteEvent.refreshCachedViews());
      FlowyOverlay.show(
        context: context,
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: commandBloc),
            if (workspaceBloc != null) BlocProvider.value(value: workspaceBloc),
            if (spaceBloc != null) BlocProvider.value(value: spaceBloc),
          ],
          child: CommandPaletteModal(shortcutBuilder: _buildShortcut),
        ),
      ).then((_) {
        /* 关闭后重置状态 */
        _isOpen = false;
        _toggleNotifier.value = _toggleNotifier.value.copyWith(isOpen: false);
      });
    } else if (!_toggleNotifier.value.isOpen && _isOpen) {
      /* 关闭命令面板 */
      FlowyOverlay.pop(context);
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _buildShortcut(widget.child ?? const SizedBox.shrink());

  /*
   * 构建快捷键监听器
   * 
   * 快捷键配置：
   * - macOS: Cmd + P
   * - Windows/Linux: Ctrl + P
   * 
   * 实现原理：
   * - FocusableActionDetector捕获键盘事件
   * - 将快捷键映射到Intent
   * - Intent触发对应的Action
   * - Action更新notifier状态
   */
  Widget _buildShortcut(Widget child) => FocusableActionDetector(
        actions: {
          _ToggleCommandPaletteIntent:
              CallbackAction<_ToggleCommandPaletteIntent>(
            onInvoke: (intent) => _toggleNotifier.value = _toggleNotifier.value
                .copyWith(isOpen: !_toggleNotifier.value.isOpen),
          ),
        },
        shortcuts: {
          LogicalKeySet(
            UniversalPlatform.isMacOS
                ? LogicalKeyboardKey.meta    /* macOS使用Cmd键 */
                : LogicalKeyboardKey.control, /* 其他平台使用Ctrl键 */
            LogicalKeyboardKey.keyP,
          ): const _ToggleCommandPaletteIntent(),
        },
        child: child,
      );
}

/*
 * 命令面板模态框组件
 * 
 * UI结构：
 * 1. 搜索输入框
 * 2. 最近访问列表（无搜索时）
 * 3. 搜索结果列表（有搜索时）
 * 4. AI问答入口（服务器版）
 * 5. 无结果提示
 * 
 * 交互特性：
 * - 实时搜索反馈
 * - 键盘导航支持
 * - 智能结果排序
 * - AI聊天集成
 */
class CommandPaletteModal extends StatelessWidget {
  const CommandPaletteModal({super.key, required this.shortcutBuilder});

  final Widget Function(Widget) shortcutBuilder;

  @override
  Widget build(BuildContext context) {
    final workspaceState = context.read<UserWorkspaceBloc?>()?.state;
    /* 判断是否显示AI功能（仅服务器版支持） */
    final showAskingAI =
        workspaceState?.userProfile.workspaceType == WorkspaceTypePB.ServerW;
    
    return BlocListener<CommandPaletteBloc, CommandPaletteState>(
      listener: (_, state) {
        /* 处理AI问答请求：创建新的聊天页面 */
        if (state.askAI && context.mounted) {
          if (Navigator.canPop(context)) FlowyOverlay.pop(context);
          final currentWorkspace = workspaceState?.workspaces;
          final spaceBloc = context.read<SpaceBloc?>();
          if (currentWorkspace != null && spaceBloc != null) {
            spaceBloc.add(
              SpaceEvent.createPage(
                name: '',
                layout: ViewLayoutPB.Chat,
                index: 0,
                openAfterCreate: true,
              ),
            );
          }
        }
      },
      child: BlocBuilder<CommandPaletteBloc, CommandPaletteState>(
        builder: (context, state) {
          final theme = AppFlowyTheme.of(context);
          final noQuery = state.query?.isEmpty ?? true, hasQuery = !noQuery;
          final hasResult = state.combinedResponseItems.isNotEmpty,
              searching = state.searching;
          final spaceXl = theme.spacing.xl;
          
          return FlowyDialog(
            backgroundColor: theme.surfaceColorScheme.layer01,
            alignment: Alignment.topCenter,  /* 顶部居中显示 */
            insetPadding: const EdgeInsets.only(top: 100),
            constraints: const BoxConstraints(
              maxHeight: 640,
              maxWidth: 960,
              minWidth: 572,
              minHeight: 640,
            ),
            expandHeight: false,
            child: shortcutBuilder(
              Padding(
                padding: EdgeInsets.fromLTRB(spaceXl, spaceXl, spaceXl, 0),
                child: Column(
                  children: [
                    /* 搜索输入框：始终显示在顶部 */
                    SearchField(query: state.query, isLoading: searching),
                    
                    /* 无查询时：显示最近访问列表 */
                    if (noQuery)
                      Flexible(
                        child: RecentViewsList(
                          onSelected: () => FlowyOverlay.pop(context),
                        ),
                      ),
                    
                    /* 有查询且有结果：显示搜索结果 */
                    if (hasResult && hasQuery)
                      Flexible(
                        child: SearchResultList(
                          cachedViews: state.cachedViews,
                          resultItems:
                              state.combinedResponseItems.values.toList(),
                          resultSummaries: state.resultSummaries,
                        ),
                      )
                    
                    /* 有查询但无结果：显示无结果提示 */
                    else if (hasQuery && !searching) ...[
                      if (showAskingAI) SearchAskAiEntrance(), /* AI入口 */
                      Expanded(
                        child: const NoSearchResultsHint(),
                      ),
                    ],
                    
                    /* 搜索中：显示加载指示器 */
                    if (hasQuery && searching && !hasResult)
                      Expanded(
                        child: Center(
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/*
 * 无搜索结果提示组件
 * 
 * 功能：
 * 1. 友好的无结果提示
 * 2. 提供垃圾桶链接（可能在垃圾桶中）
 * 3. 居中显示的优雅布局
 * 
 * 交互：
 * - 点击"垃圾桶"链接打开垃圾桶页面
 * - 关闭命令面板
 * - 清理最近打开记录
 */
class NoSearchResultsHint extends StatelessWidget {
  const NoSearchResultsHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context),
        textColor = theme.textColorScheme.secondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /* 搜索图标 */
          FlowySvg(
            FlowySvgs.m_home_search_icon_m,
            color: theme.iconColorScheme.secondary,
            size: Size.square(24),
          ),
          const VSpace(8),
          /* 主提示文本 */
          Text(
            LocaleKeys.search_noResultForSearching.tr(),
            style: theme.textStyle.body.enhanced(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const VSpace(4),
          /* 副提示文本，包含可点击的垃圾桶链接 */
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: LocaleKeys.search_noResultForSearchingHintWithoutTrash.tr(),
              style: theme.textStyle.caption.standard(color: textColor),
              children: [
                TextSpan(
                  text: LocaleKeys.trash_text.tr(),
                  style: theme.textStyle.caption.underline(color: textColor),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      /* 点击后：关闭面板，打开垃圾桶 */
                      FlowyOverlay.pop(context);
                      getIt<MenuSharedState>().latestOpenView = null;
                      getIt<TabsBloc>().add(
                        TabsEvent.openPlugin(
                          plugin: makePlugin(pluginType: PluginType.trash),
                        ),
                      );
                    },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*
 * 命令面板通知器值对象
 * 
 * 封装命令面板的状态和依赖
 * 
 * 字段说明：
 * - isOpen：面板是否打开
 * - userWorkspaceBloc：工作区状态管理
 * - spaceBloc：空间状态管理
 * 
 * 用途：
 * - 通过ValueNotifier传递状态变化
 * - 携带必要的BLoC实例
 * - 支持不可变更新（copyWith）
 */
class CommandPaletteNotifierValue {
  CommandPaletteNotifierValue({
    this.isOpen = false,
    this.userWorkspaceBloc,
    this.spaceBloc,
  });

  final bool isOpen;
  final UserWorkspaceBloc? userWorkspaceBloc;
  final SpaceBloc? spaceBloc;

  CommandPaletteNotifierValue copyWith({
    bool? isOpen,
    UserWorkspaceBloc? userWorkspaceBloc,
    SpaceBloc? spaceBloc,
  }) {
    return CommandPaletteNotifierValue(
      isOpen: isOpen ?? this.isOpen,
      userWorkspaceBloc: userWorkspaceBloc ?? this.userWorkspaceBloc,
      spaceBloc: spaceBloc ?? this.spaceBloc,
    );
  }
}
