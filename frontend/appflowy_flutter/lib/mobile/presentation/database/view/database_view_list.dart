// 导入AppFlowy生成的SVG图标资源文件
import 'package:appflowy/generated/flowy_svgs.g.dart';
// 导入AppFlowy生成的本地化键值文件，用于多语言支持
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端应用栏动作组件，提供标准化的导航和操作按钮
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar_actions.dart';
// 导入移动端底部弹出页面组件，用于显示操作选项
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
// 导入移动端通用UI组件库
import 'package:appflowy/mobile/presentation/widgets/widgets.dart';
// 导入数据库控制器，管理数据库操作的核心逻辑
import 'package:appflowy/plugins/database/application/database_controller.dart';
// 导入数据库标签栏BLoC，管理多个数据库视图的标签页状态
import 'package:appflowy/plugins/database/application/tab_bar_bloc.dart';
// 导入文档编辑器插件的表情图标组件
import 'package:appflowy/plugins/document/presentation/editor_plugins/header/emoji_icon_widget.dart';
// 导入共享的图标表情选择器组件
import 'package:appflowy/shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';
// 导入工作区视图BLoC，管理视图相关的业务逻辑
import 'package:appflowy/workspace/application/view/view_bloc.dart';
// 导入视图扩展功能，为视图数据结构添加额外方法
import 'package:appflowy/workspace/application/view/view_ext.dart';
// 导入数据库相关的协议缓冲区定义
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
// 导入文件夹相关的协议缓冲区定义
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
// 导入Dart集合操作扩展库
import 'package:collection/collection.dart';
// 导入本地化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入AppFlowy基础架构主题扩展
import 'package:flowy_infra/theme_extension.dart';
// 导入AppFlowy基础架构UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter核心UI框架
import 'package:flutter/material.dart';
// 导入Flutter BLoC状态管理库
import 'package:flutter_bloc/flutter_bloc.dart';
// 导入Go Router路由管理库
import 'package:go_router/go_router.dart';

import 'database_view_layout.dart';
import 'database_view_quick_actions.dart';

/// 移动端数据库视图列表组件
/// 
/// 这是一个核心的数据库管理界面，主要功能包括：
/// 1. 显示数据库中所有视图的列表（包括主视图和子视图）
/// 2. 提供创建新数据库视图的入口按钮
/// 3. 管理视图之间的切换和选择状态
/// 4. 提供视图的快速操作菜单
/// 
/// 设计思路：
/// - 使用StatelessWidget保持组件的轻量化
/// - 通过BLoC模式管理视图状态和数据库标签栏状态
/// - 采用列表形式展示，支持动态添加和管理多个视图
/// - 集成底部弹出页面，提供良好的移动端用户体验
class MobileDatabaseViewList extends StatelessWidget {
  /// 构造函数 - 创建移动端数据库视图列表
  const MobileDatabaseViewList({super.key});

  /// 构建数据库视图列表界面
  /// 
  /// 这个方法创建完整的视图列表界面，包括头部、视图列表和新建按钮
  /// 
  /// 界面结构：
  /// - 头部：显示视图数量和操作按钮
  /// - 主体：可滚动的视图列表
  /// - 底部：新建视图按钮和适配移动端的间距
  @override
  Widget build(BuildContext context) {
    // 监听ViewBloc状态变化，响应视图数据更新
    return BlocBuilder<ViewBloc, ViewState>(
      builder: (context, state) {
        // 构建完整的视图列表：主视图 + 所有子视图
        // 这样的设计保证了视图层级结构的完整展示
        final views = [state.view, ...state.view.childViews];

        return Column(
          children: [
            // 自定义头部组件，显示标题和操作按钮
            _Header(
              // 使用本地化字符串，根据视图数量动态显示标题
              // 通过DatabaseTabBarBloc获取当前标签页数量
              title: LocaleKeys.grid_settings_viewList.plural(
                context.watch<DatabaseTabBarBloc>().state.tabBars.length,
                namedArgs: {
                  'count':
                      '${context.watch<DatabaseTabBarBloc>().state.tabBars.length}',
                },
              ),
              showBackButton: false,        // 不显示返回按钮
              useFilledDoneButton: false,   // 使用普通完成按钮样式
              onDone: (context) => Navigator.pop(context), // 完成时关闭页面
            ),
            // 可扩展的主内容区域
            Expanded(
              child: ListView(
                shrinkWrap: true,     // 收缩包装，节省空间
                padding: EdgeInsets.zero, // 无内边距，由子组件自行控制
                children: [
                  // 遍历所有视图，为每个视图创建列表项
                  // 使用mapIndexed获取索引，用于控制边框显示
                  ...views.mapIndexed(
                    (index, view) => MobileDatabaseViewListButton(
                      view: view,
                      showTopBorder: index == 0, // 第一个项目显示顶部边框
                    ),
                  ),
                  const VSpace(20), // 垂直间距
                  // 新建数据库视图按钮
                  const MobileNewDatabaseViewButton(),
                  // 底部安全区域适配，考虑移动端底部导航栏等UI元素
                  VSpace(
                    context.bottomSheetPadding(ignoreViewPadding: false),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 私有头部组件
/// 
/// 这是一个专门为数据库视图列表设计的头部组件，功能包括：
/// 1. 显示页面标题（通常是视图数量统计）
/// 2. 提供可选的返回按钮
/// 3. 提供完成按钮（可选择填充样式）
/// 4. 支持自定义完成操作的回调
/// 
/// 设计特点：
/// - 与showMobileBottomSheet中的头部相似，但支持带返回值的页面关闭
/// - 使用Stack布局实现左中右三部分的对齐
/// - 高度固定为44.0，符合移动端应用栏标准
class _Header extends StatelessWidget {
  /// 构造函数 - 创建自定义头部组件
  /// 
  /// 参数说明：
  /// - [title]: 必需，头部显示的标题文本
  /// - [showBackButton]: 是否显示返回按钮
  /// - [useFilledDoneButton]: 是否使用填充样式的完成按钮
  /// - [onDone]: 完成按钮的点击回调函数
  const _Header({
    required this.title,
    required this.showBackButton,
    required this.useFilledDoneButton,
    required this.onDone,
  });

  /// 头部标题文本
  /// 通常显示视图数量或页面描述信息
  final String title;
  
  /// 是否显示返回按钮
  /// 控制左侧返回按钮的显示状态
  final bool showBackButton;
  
  /// 是否使用填充样式的完成按钮
  /// true: 使用AppBarFilledDoneButton（填充背景）
  /// false: 使用AppBarDoneButton（普通样式）
  final bool useFilledDoneButton;
  
  /// 完成按钮的点击回调函数
  /// 接收BuildContext参数，支持在回调中进行页面操作
  final void Function(BuildContext context) onDone;

  /// 构建头部UI界面
  /// 
  /// 采用Stack布局实现左中右三部分的精确对齐：
  /// - 左侧：可选的返回按钮
  /// - 中间：标题文本
  /// - 右侧：完成按钮（两种样式可选）
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0), // 底部留出小间距
      child: SizedBox(
        height: 44.0, // 固定高度，符合移动端应用栏标准
        child: Stack(
          children: [
            // 左侧返回按钮（条件显示）
            if (showBackButton)
              const Align(
                alignment: Alignment.centerLeft,
                child: AppBarBackButton(), // 标准的应用栏返回按钮
              ),
            // 中间标题文本
            Align(
              child: FlowyText.medium(
                title,
                fontSize: 16.0, // 标准的标题字体大小
              ),
            ),
            // 右侧完成按钮（两种样式）
            useFilledDoneButton
                ? Align(
                    alignment: Alignment.centerRight,
                    // 填充样式的完成按钮，通常用于重要操作
                    child: AppBarFilledDoneButton(
                      onTap: () => onDone(context),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    // 普通样式的完成按钮，用于常规操作
                    child: AppBarDoneButton(
                      onTap: () => onDone(context),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// 移动端数据库视图列表按钮组件
/// 
/// 这是数据库视图列表中每个视图项目的具体实现，功能包括：
/// 1. 显示视图名称和图标（支持表情和自定义图标）
/// 2. 显示选中状态指示器（蓝色勾号）
/// 3. 提供更多操作按钮（三个点的菜单）
/// 4. 支持点击切换视图的交互
/// 5. 支持打开快速操作菜单
/// 
/// 设计特点：
/// - 使用@visibleForTesting注解，支持在测试环境中直接访问
/// - 集成DatabaseTabBarBloc管理视图切换状态
/// - 使用FlowyOptionTile保持与其他选项的一致性
@visibleForTesting
class MobileDatabaseViewListButton extends StatelessWidget {
  /// 构造函数 - 创建数据库视图列表按钮
  /// 
  /// 参数说明：
  /// - [view]: 必需，要显示的视图数据对象
  /// - [showTopBorder]: 是否显示顶部边框（通常第一个项目显示）
  const MobileDatabaseViewListButton({
    super.key,
    required this.view,
    required this.showTopBorder,
  });

  /// 视图数据对象
  /// 包含视图的所有信息：名称、ID、图标等
  final ViewPB view;
  
  /// 是否显示顶部边框
  /// 用于区分第一个列表项目，提供视觉分隔
  final bool showTopBorder;

  /// 构建数据库视图列表按钮界面
  /// 
  /// 这个方法创建一个可点击的视图项目，包括状态管理和交互操作
  /// 
  /// 功能特点：
  /// - 监听数据库标签栏状态变化，实时更新选中状态
  /// - 支持点击切换到对应的数据库视图
  /// - 动态显示选中指示器和操作菜单
  @override
  Widget build(BuildContext context) {
    // 监听DatabaseTabBarBloc状态，响应视图切换和选中状态变化
    return BlocBuilder<DatabaseTabBarBloc, DatabaseTabBarState>(
      builder: (context, state) {
        // 在所有标签栏中查找当前视图的索引位置
        final index =
            state.tabBars.indexWhere((tabBar) => tabBar.viewId == view.id);
        // 判断是否为当前选中的视图
        final isSelected = index == state.selectedIndex;
        
        // 使用FlowyOptionTile创建统一样式的选项按钮
        return FlowyOptionTile.text(
          text: view.name,                // 视图名称
          onTap: () {
            // 点击时发送视图切换事件
            context
                .read<DatabaseTabBarBloc>()
                .add(DatabaseTabBarEvent.selectView(view.id));
          },
          leftIcon: _buildViewIconButton(context, view), // 左侧视图图标
          trailing: _trailing(                          // 右侧操作区域
            context,
            state.tabBarControllerByViewId[view.id]!.controller, // 数据库控制器
            isSelected, // 选中状态
          ),
          showTopBorder: showTopBorder, // 控制顶部边框显示
        );
      },
    );
  }

  /// 构建视图图标按钮
  /// 
  /// 这个方法创建视图列表项目的左侧图标，支持多种图标类型：
  /// 1. 表情图标：用户自定义的emoji表情
  /// 2. 自定义图标：用户上传或选择的图标
  /// 3. 默认图标：系统根据视图类型提供的默认图标
  /// 
  /// 参数说明：
  /// - [context]: 构建上下文，用于主题和样式访问
  /// - [view]: 视图数据对象，包含图标信息
  Widget _buildViewIconButton(BuildContext context, ViewPB view) {
    // 将视图图标数据转换为表情图标数据结构
    final iconData = view.icon.toEmojiIconData();
    Widget icon;
    
    // 判断图标数据是否为空或不是标准图标类型
    if (iconData.isEmpty || iconData.type != FlowyIconType.icon) {
      // 使用视图的默认图标（根据视图类型自动选择）
      icon = view.defaultIcon();
    } else {
      // 使用用户自定义的表情或图标
      icon = RawEmojiIconWidget(
        emoji: iconData,       // 表情数据
        emojiSize: 14.0,      // 表情大小
        enableColor: false,   // 禁用颜色变化，保持原始颜色
      );
    }
    
    // 返回固定尺寸的正方形容器，统一图标大小
    return SizedBox.square(
      dimension: 20.0, // 20x20像素的正方形区域
      child: icon,
    );
  }

  /// 构建右侧操作区域（trailing）
  /// 
  /// 这个方法创建列表项目右侧的操作区域，包括：
  /// 1. 选中状态指示器：蓝色勾号图标（仅在选中时显示）
  /// 2. 更多操作按钮：三个点的菜单按钮，打开快速操作菜单
  /// 
  /// 参数说明：
  /// - [context]: 构建上下文，用于主题和导航
  /// - [databaseController]: 数据库控制器，用于操作数据库
  /// - [isSelected]: 是否为当前选中的视图
  Widget _trailing(
    BuildContext context,
    DatabaseController databaseController,
    bool isSelected,
  ) {
    // 创建更多操作按钮（三个点图标）
    final more = FlowyIconButton(
      icon: FlowySvg(
        FlowySvgs.three_dots_s,           // 三个点的图标
        size: const Size.square(20),      // 20x20像素大小
        color: Theme.of(context).hintColor, // 使用主题的提示色
      ),
      onPressed: () {
        // 点击时显示底部弹出页面，包含快速操作选项
        showMobileBottomSheet(
          context,
          showDragHandle: true,  // 显示拖拽手柄
          backgroundColor: AFThemeExtension.of(context).background, // 使用主题背景色
          builder: (_) {
            // 为快速操作组件提供ViewBloc依赖
            return BlocProvider<ViewBloc>(
              create: (_) =>
                  ViewBloc(view: view)..add(const ViewEvent.initial()),
              child: MobileDatabaseViewQuickActions(
                view: view,                        // 当前视图
                databaseController: databaseController, // 数据库控制器
              ),
            );
          },
        );
      },
    );
    
    // 根据选中状态返回不同的UI布局
    if (isSelected) {
      // 选中状态：显示选中指示器 + 更多按钮
      return Row(
        mainAxisSize: MainAxisSize.min, // 最小化占用空间
        children: [
          // 蓝色勾号选中指示器
          const FlowySvg(
            FlowySvgs.m_blue_check_s,        // 蓝色勾号图标
            size: Size.square(20),           // 20x20像素大小
            blendMode: BlendMode.dst,        // 混合模式设置
          ),
          const HSpace(8), // 8像素水平间距
          more,            // 更多操作按钮
        ],
      );
    } else {
      // 非选中状态：仅显示更多按钮
      return more;
    }
  }
}

/// 移动端新建数据库视图按钮组件
/// 
/// 这是一个用于创建新数据库视图的功能按钮，主要特点：
/// 1. 显示“创建视图”的文本和加号图标
/// 2. 点击后弹出创建视图的配置界面
/// 3. 支持选择不同的数据库布局类型（网格、看板、日历等）
/// 4. 支持自定义视图名称
/// 
/// 设计思路：
/// - 使用StatelessWidget保持组件的简单性
/// - 通过底部弹出页面提供创建配置界面
/// - 使用异步操作处理用户输入和页面跳转
class MobileNewDatabaseViewButton extends StatelessWidget {
  /// 构造函数 - 创建新建数据库视图按钮
  const MobileNewDatabaseViewButton({super.key});

  /// 构建新建数据库视图按钮界面
  /// 
  /// 这个方法创建一个可点击的选项按钮，处理新建视图的完整流程。
  /// 
  /// 交互流程：
  /// 1. 用户点击按钮
  /// 2. 弹出底部弹出页面，包含创建配置界面
  /// 3. 用户输入视图名称和选择布局类型
  /// 4. 系统创建新视图并更新数据库标签栏
  @override
  Widget build(BuildContext context) {
    return FlowyOptionTile.text(
      // 使用本地化的“创建视图”文本
      text: LocaleKeys.grid_settings_createView.tr(),
      // 使用提示颜色，表明这是一个次要操作
      textColor: Theme.of(context).hintColor,
      // 左侧加号图标，直观表示“添加”功能
      leftIcon: FlowySvg(
        FlowySvgs.add_s,                    // 加号图标
        size: const Size.square(20),       // 20x20像素大小
        color: Theme.of(context).hintColor, // 与文本颜色一致
      ),
      // 异步点击事件处理
      onTap: () async {
        // 显示底部弹出页面，等待用户输入
        // 返回值为元组：(布局类型, 视图名称)
        final result = await showMobileBottomSheet<(DatabaseLayoutPB, String)>(
          context,
          showDragHandle: true, // 显示拖拽手柄，提升用户体验
          builder: (_) {
            // 返回创建数据库视图的配置界面
            return const MobileCreateDatabaseView();
          },
        );
        
        // 检查组件是否仍然挂载且用户确实提供了输入
        if (context.mounted && result != null) {
          // 发送创建视图事件给DatabaseTabBarBloc
          context
              .read<DatabaseTabBarBloc>()
              .add(DatabaseTabBarEvent.createView(result.$1, result.$2));
        }
      },
    );
  }
}

/// 移动端创建数据库视图组件
/// 
/// 这是一个复杂的有状态组件，负责处理新建数据库视图的完整流程：
/// 1. 用户输入视图名称（默认为“无标题”）
/// 2. 用户选择数据库布局类型（网格、看板、日历等）
/// 3. 提供实时预览和确认功能
/// 4. 返回选择结果给父组件进行后续处理
/// 
/// 设计思路：
/// - 使用StatefulWidget管理内部状态（名称和布局类型）
/// - 通过TextEditingController管理文本输入
/// - 集成自定义头部组件和布局选择器
/// - 支持自动聚焦和键盘交互
class MobileCreateDatabaseView extends StatefulWidget {
  /// 构造函数 - 创建移动端创建数据库视图组件
  const MobileCreateDatabaseView({super.key});

  @override
  State<MobileCreateDatabaseView> createState() =>
      _MobileCreateDatabaseViewState();
}

/// 移动端创建数据库视图状态类
/// 
/// 这个状态类管理创建数据库视图的所有可变状态和生命周期：
/// 
/// 状态管理：
/// - 文本输入控制器：管理视图名称的输入和编辑
/// - 布局类型状态：跟踪用户选择的数据库布局
/// 
/// 生命周期管理：
/// - initState: 初始化文本控制器和默认值
/// - dispose: 清理资源，避免内存泄漏
class _MobileCreateDatabaseViewState extends State<MobileCreateDatabaseView> {
  /// 文本输入控制器，管理视图名称的输入
  /// 使用late修饰符，在initState中初始化
  late final TextEditingController controller;
  
  /// 数据库布局类型状态
  /// 默认为网格布局，用户可以通过UI选择器修改
  DatabaseLayoutPB layoutType = DatabaseLayoutPB.Grid;

  /// 组件初始化方法
  /// 
  /// 在组件创建时执行，负责初始化所有必要的状态和资源。
  /// 
  /// 初始化内容：
  /// - 创建文本输入控制器
  /// - 设置默认的视图名称（使用本地化占位符文本）
  @override
  void initState() {
    super.initState();
    // 初始化文本输入控制器，默认使用本地化的占位符文本
    // 这样用户可以直接点击“完成”而不用手动输入名称
    controller = TextEditingController(
      text: LocaleKeys.grid_title_placeholder.tr(), // “无标题”或类似的本地化文本
    );
  }

  /// 组件销毁方法
  /// 
  /// 在组件被销毁时执行，负责清理所有资源和监听器。
  /// 
  /// 清理内容：
  /// - 释放文本输入控制器资源，避免内存泄漏
  /// - 调用父类的dispose方法完成清理流程
  @override
  void dispose() {
    // 释放文本控制器资源
    controller.dispose();
    // 调用父类的dispose方法
    super.dispose();
  }

  /// 构建创建数据库视图界面
  /// 
  /// 这个方法创建一个完整的视图创建界面，包括所有必要的交互组件。
  /// 
  /// 界面结构（从上到下）：
  /// 1. 头部：显示标题、返回按钮和完成按钮
  /// 2. 文本输入框：用于输入视图名称，支持自动聚焦
  /// 3. 垂直间距：分隔UI元素
  /// 4. 布局选择器：用于选择数据库的显示布局
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 自定义头部组件，包含标题和操作按钮
        _Header(
          title: LocaleKeys.grid_settings_createView.tr(), // 本地化的“创建视图”标题
          showBackButton: true,        // 显示返回按钮，允许用户取消操作
          useFilledDoneButton: true,   // 使用填充样式的完成按钮，强调主要操作
          onDone: (context) =>
              // 完成时返回元组：(布局类型, 清理后的视图名称)
              context.pop((layoutType, controller.text.trim())),
        ),
        // 文本输入框，用于输入视图名称
        FlowyOptionTile.textField(
          autofocus: true,    // 自动聚焦，方便用户直接输入
          controller: controller, // 绑定文本控制器
        ),
        const VSpace(20), // 20像素的垂直间距，分隔不同UI区域
        // 数据库布局选择器，用于选择显示模式
        DatabaseViewLayoutPicker(
          selectedLayout: layoutType, // 当前选中的布局类型
          onSelect: (layout) {
            // 选择变化时更新状态
            setState(() => layoutType = layout);
          },
        ),
      ],
    );
  }
}
