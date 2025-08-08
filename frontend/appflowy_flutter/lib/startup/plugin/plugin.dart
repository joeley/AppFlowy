library;

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/startup/plugin/plugin.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/presentation/home/home_stack.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:flutter/widgets.dart';

export "./src/sandbox.dart";

/*
 * 插件类型枚举
 * 
 * 定义AppFlowy支持的所有插件类型
 * 每种类型对应一种特定的视图或功能模块
 */
enum PluginType {
  document,         /* 文档编辑器插件 */
  blank,           /* 空白页面插件 */
  trash,           /* 垃圾桶插件 */
  grid,            /* 表格数据库插件 */
  board,           /* 看板视图插件 */
  calendar,        /* 日历视图插件 */
  databaseDocument, /* 数据库文档插件 */
  chat,            /* 聊天功能插件 */
}

/* 插件唯一标识符类型别名 */
typedef PluginId = String;

/*
 * 插件抽象基类
 * 
 * AppFlowy插件系统的核心接口定义
 * 所有插件必须实现此接口以接入框架
 * 
 * 生命周期管理：
 * 1. init() - 插件初始化
 * 2. 运行期间通过notifier进行状态通知
 * 3. dispose() - 插件销毁，释放资源
 * 
 * 设计模式：
 * - 策略模式：不同插件实现不同的功能策略
 * - 观察者模式：通过notifier通知状态变化
 */
abstract class Plugin {
  /* 插件唯一标识符 */
  PluginId get id;

  /* 插件的UI构建器，负责生成插件界面 */
  PluginWidgetBuilder get widgetBuilder;

  /* 插件状态通知器，用于发布插件状态变化事件 */
  PluginNotifier? get notifier => null;

  /* 插件类型，用于区分不同功能的插件 */
  PluginType get pluginType;

  /* 插件初始化方法，在插件创建后调用 */
  void init() {}

  /* 插件销毁方法，释放资源和清理监听器 */
  void dispose() {
    notifier?.dispose();
  }
}

/*
 * 插件通知器抽象基类
 * 
 * 负责管理插件的状态通知机制
 * 使用泛型<T>支持不同类型的状态数据
 * 
 * 应用场景：
 * - 通知插件被删除
 * - 通知插件内容变化
 * - 同步插件状态到UI
 */
abstract class PluginNotifier<T> {
  /* 通知插件是否被删除的状态监听器 */
  ValueNotifier<T> get isDeleted;

  /* 清理通知器资源 */
  void dispose() {}
}

/*
 * 插件构建器抽象基类
 * 
 * 负责创建和配置插件实例
 * 实现工厂模式，根据数据动态创建插件
 * 
 * 职责：
 * 1. 根据传入数据构建插件实例
 * 2. 提供插件的元数据（名称、图标、类型）
 * 3. 定义插件的布局类型供后端识别
 * 
 * 设计思想：
 * - 将插件的创建逻辑与使用逻辑分离
 * - 支持插件的动态注册和加载
 */
abstract class PluginBuilder {
  /* 根据数据构建插件实例 */
  Plugin build(dynamic data);

  /* 插件在菜单中显示的名称 */
  String get menuName;

  /* 插件的图标数据 */
  FlowySvgData get icon;

  /* 插件类型，每个插件应该有唯一的类型标识 */
  PluginType get pluginType;

  /* 布局类型，用于后端确定视图的布局方式
   * AppFlowy支持4种布局：文档、表格、看板、日历
   */
  ViewLayoutPB? get layoutType;
}

/*
 * 插件配置抽象基类
 * 
 * 定义插件的配置选项和行为约束
 * 
 * 配置项说明：
 * - creatable: 控制用户是否可以主动创建此类插件
 *   例如：垃圾桶插件不应该由用户创建，而是系统内置
 */
abstract class PluginConfig {
  /* 返回false将禁止用户创建此类插件
   * 某些系统级插件（如垃圾桶）不应该由用户创建
   */
  bool get creatable => true;
}

/*
 * 插件界面构建器抽象基类
 * 
 * 负责构建插件的UI界面
 * 混入NavigationItem支持导航功能
 * 
 * 核心功能：
 * 1. 提供导航项列表
 * 2. 定义内容区域内边距
 * 3. 根据上下文构建具体的Widget
 * 
 * 设计特点：
 * - 支持响应式布局（shrinkWrap）
 * - 支持传递额外数据进行动态渲染
 * - 统一的内边距管理
 */
abstract class PluginWidgetBuilder with NavigationItem {
  /* 插件相关的导航项列表 */
  List<NavigationItem> get navigationItems;

  /* 内容区域的内边距设置 */
  EdgeInsets get contentPadding =>
      const EdgeInsets.symmetric(horizontal: 40, vertical: 28);

  /* 构建插件的实际Widget界面
   * 
   * 参数：
   * - context: 插件运行上下文，包含用户信息和回调
   * - shrinkWrap: 是否根据内容自适应大小
   * - data: 额外的配置数据
   */
  Widget buildWidget({
    required PluginContext context,
    required bool shrinkWrap,
    Map<String, dynamic>? data,
  });
}

/*
 * 插件上下文
 * 
 * 为插件提供运行时的环境信息和回调
 * 
 * 包含内容：
 * 1. 用户信息 - 用于权限控制和个性化
 * 2. 删除回调 - 处理插件被删除时的清理工作
 * 
 * 使用场景：
 * - 插件需要根据用户权限显示不同内容
 * - 插件需要在被删除时执行清理操作
 * - 插件需要访问用户的个性化设置
 */
class PluginContext {
  PluginContext({
    this.userProfile,
    this.onDeleted,
  });

  /* 插件被删除时的回调函数
   * 参数：被删除的视图对象和索引位置
   */
  final Function(ViewPB, int?)? onDeleted;
  
  /* 当前用户的配置信息 */
  final UserProfilePB? userProfile;
}

/*
 * 注册插件到系统
 * 
 * 将插件构建器注册到插件沙箱中
 * 支持可选的配置参数
 * 
 * 参数：
 * - builder: 插件构建器实例
 * - config: 可选的插件配置
 * 
 * 注册流程：
 * 1. 获取全局的PluginSandbox实例
 * 2. 将builder按类型注册
 * 3. 关联配置信息（如果提供）
 */
void registerPlugin({required PluginBuilder builder, PluginConfig? config}) {
  getIt<PluginSandbox>()
      .registerPlugin(builder.pluginType, builder, config: config);
}

/*
 * 创建插件实例
 * 
 * 根据插件类型和数据创建对应的插件
 * 如果插件未注册，返回空白插件作为降级处理
 * 
 * 参数：
 * - pluginType: 要创建的插件类型
 * - data: 初始化插件所需的数据
 * 
 * 返回：
 * - 对应类型的插件实例
 * - 未注册时返回BlankPlugin
 * 
 * 容错机制：
 * - 优雅降级：未知插件类型不会导致崩溃
 * - 空白插件提供基础功能保证系统可用
 */
Plugin makePlugin({required PluginType pluginType, dynamic data}) {
  final plugin = getIt<PluginSandbox>().buildPlugin(pluginType, data);
  return plugin;
}

/*
 * 获取可创建的插件构建器列表
 * 
 * 返回所有用户可以创建的插件构建器
 * 根据配置过滤掉不可创建的插件
 * 
 * 过滤逻辑：
 * 1. 获取所有已注册的插件构建器
 * 2. 检查每个插件的creatable配置
 * 3. 只返回可创建的插件（默认为true）
 * 
 * 应用场景：
 * - 显示"新建"菜单中的可用选项
 * - 限制某些系统级插件的创建
 */
List<PluginBuilder> pluginBuilders() {
  final pluginBuilders = getIt<PluginSandbox>().builders;
  final pluginConfigs = getIt<PluginSandbox>().pluginConfigs;
  return pluginBuilders.where(
    (builder) {
      final config = pluginConfigs[builder.pluginType]?.creatable;
      return config ?? true;
    },
  ).toList();
}

/*
 * 插件异常枚举
 * 
 * 定义插件系统可能出现的异常类型
 */
enum FlowyPluginException {
  invalidData,  /* 无效的插件数据 */
}
