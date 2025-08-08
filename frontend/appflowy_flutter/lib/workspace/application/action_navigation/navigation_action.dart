/// 导航动作类型枚举
enum ActionType {
  openView,    // 打开视图
  jumpToBlock, // 跳转到文档块
  openRow,     // 打开数据库行
}

/// 动作参数键名常量
class ActionArgumentKeys {
  static String view = "view";           // 视图对象
  static String nodePath = "node_path";   // 节点路径
  static String blockId = "block_id";     // 文档块ID
  static String rowId = "row_id";         // 数据库行ID
}

/// 导航动作 - 用于与ActionNavigationBloc通信
/// 
/// 主要功能：
/// 1. 处理通知点击事件
/// 2. 打开指定视图
/// 3. 跳转到指定文档块
/// 4. 打开数据库行
/// 
/// 设计思想：
/// - 通过type和objectId定位目标
/// - arguments携带额外参数
/// - 支持链式导航动作
class NavigationAction {
  const NavigationAction({
    this.type = ActionType.openView, // 默认打开视图
    this.arguments,                   // 可选参数
    required this.objectId,           // 目标对象ID
  });

  final ActionType type;                    // 动作类型

  final String objectId;                    // 目标对象ID（视图ID、块ID等）
  final Map<String, dynamic>? arguments;    // 额外参数

  /// 复制并修改导航动作
  NavigationAction copyWith({
    ActionType? type,
    String? objectId,
    Map<String, dynamic>? arguments,
  }) =>
      NavigationAction(
        type: type ?? this.type,
        objectId: objectId ?? this.objectId,
        arguments: arguments ?? this.arguments,
      );
}
