import 'package:flutter/cupertino.dart';

/// 视图展开器注册中心
/// 
/// 这是AppFlowy中管理视图（页面/文档）展开/折叠状态的核心组件。
/// 
/// ## 核心功能
/// 1. **集中管理展开状态**：为每个视图维护其展开器集合
/// 2. **支持批量操作**：支持"折叠所有子页面"等批量操作
/// 3. **多对一映射**：一个视图可以有多个展开器（虽然实际通常只有一个）
/// 
/// ## 设计思想
/// 采用注册表模式（Registry Pattern）来解耦视图组件和展开逻辑：
/// - ViewBloc在创建时注册自己的展开器
/// - 外部组件通过注册表查询和控制展开状态
/// - 销毁时自动注销，避免内存泄漏
/// 
/// ## 应用场景
/// 1. 侧边栏视图树的展开/折叠
/// 2. "折叠所有子页面"功能的实现
/// 3. 程序化控制视图展开状态（如搜索后自动展开路径）
/// 
/// ## 工作流程
/// ```
/// ViewBloc创建 → 注册ViewExpander → 外部查询/控制 → ViewBloc销毁时注销
/// ```
class ViewExpanderRegistry {
  /// 展开器映射表
  /// 
  /// key: 视图ID (view.id)
  /// value: 该视图的所有展开器集合（通常只有一个）
  /// 
  /// 使用Set是为了：
  /// 1. 避免重复注册
  /// 2. 支持未来可能的多展开器场景
  final Map<String, Set<ViewExpander>> _viewExpanders = {};

  /// 查询指定视图是否处于展开状态
  /// 
  /// 如果视图未注册或没有展开器，返回false
  bool isViewExpanded(String id) => getExpander(id)?.isViewExpanded ?? false;

  /// 注册视图展开器
  /// 
  /// [id] 视图ID，作为唯一标识
  /// [expander] 视图的展开器实例
  /// 
  /// 注册过程：
  /// 1. 获取或创建该视图的展开器集合
  /// 2. 添加新的展开器
  /// 3. 更新映射表
  void register(String id, ViewExpander expander) {
    final expanders = _viewExpanders[id] ?? {};
    expanders.add(expander);
    _viewExpanders[id] = expanders;
  }

  /// 注销视图展开器
  /// 
  /// [id] 视图ID
  /// [expander] 要注销的展开器实例
  /// 
  /// 注销策略：
  /// 1. 从集合中移除指定展开器
  /// 2. 如果集合为空，移除整个映射条目（清理内存）
  /// 3. 否则更新集合
  /// 
  /// 这确保了不会有僵尸引用占用内存
  void unregister(String id, ViewExpander expander) {
    final expanders = _viewExpanders[id] ?? {};
    expanders.remove(expander);
    if (expanders.isEmpty) {
      _viewExpanders.remove(id);
    } else {
      _viewExpanders[id] = expanders;
    }
  }

  /// 获取指定视图的第一个展开器
  /// 
  /// [id] 视图ID
  /// 
  /// 返回：
  /// - 第一个展开器（如果存在）
  /// - null（如果视图未注册或没有展开器）
  /// 
  /// 注意：虽然支持多个展开器，但实际使用中通常只有一个
  ViewExpander? getExpander(String id) {
    final expanders = _viewExpanders[id] ?? {};
    return expanders.isEmpty ? null : expanders.first;
  }
}

/// 视图展开器
/// 
/// 封装了视图的展开状态查询和展开操作。
/// 采用回调模式，让ViewBloc保持对展开逻辑的控制权。
/// 
/// ## 设计模式
/// 使用命令模式（Command Pattern）封装展开操作：
/// - 将操作封装为对象
/// - 支持操作的参数化
/// - 可以在不同时间调用操作
/// 
/// ## 使用示例
/// ```dart
/// // 在ViewBloc中创建
/// expander = ViewExpander(
///   () => state.isExpanded,        // 查询当前展开状态
///   () => add(ViewEvent.expand())  // 执行展开操作
/// );
/// 
/// // 在外部使用
/// if (!expander.isViewExpanded) {
///   expander.expand();
/// }
/// ```
class ViewExpander {
  ViewExpander(this._isExpandedCallback, this._expandCallback);

  /// 获取展开状态的回调
  /// 
  /// 返回true表示已展开，false表示已折叠
  /// 通常绑定到ViewState.isExpanded
  final ValueGetter<bool> _isExpandedCallback;

  /// 执行展开操作的回调
  /// 
  /// 触发视图展开，通常会：
  /// 1. 发送展开事件到ViewBloc
  /// 2. 更新UI状态
  /// 3. 持久化展开状态到本地存储
  final VoidCallback _expandCallback;

  /// 获取当前视图是否展开
  /// 
  /// 代理调用_isExpandedCallback获取实时状态
  bool get isViewExpanded => _isExpandedCallback.call();

  /// 展开视图
  /// 
  /// 代理调用_expandCallback执行展开操作
  /// 注意：这里只有expand没有collapse，因为"折叠所有"功能
  /// 是通过ViewBloc的collapseAllPages事件直接处理的
  void expand() => _expandCallback.call();
}
