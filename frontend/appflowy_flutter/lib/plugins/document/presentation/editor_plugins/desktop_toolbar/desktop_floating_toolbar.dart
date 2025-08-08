import 'package:appflowy/plugins/document/presentation/editor_plugins/base/toolbar_extension.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import 'toolbar_animation.dart';

/// 桌面端浮动工具栏组件
/// 
/// 在文档编辑器中显示浮动工具栏，提供格式化等操作。
/// 根据选区位置自动计算工具栏显示位置。
/// 
/// ## 核心功能
/// 1. **位置计算**：根据选区自动定位工具栏
/// 2. **动画支持**：可选的出现/消失动画
/// 3. **协调管理**：通过FloatingToolbarController协调多个工具栏
/// 4. **自适应布局**：根据窗口大小调整工具栏宽度
/// 
/// ## 显示逻辑
/// - 选区上方空间不足时，显示在下方
/// - 右侧空间不足时，左对齐显示
/// - 保持在编辑器可见区域内
class DesktopFloatingToolbar extends StatefulWidget {
  const DesktopFloatingToolbar({
    super.key,
    required this.editorState,
    required this.child,
    required this.onDismiss,
    this.enableAnimation = true,
  });

  /// 编辑器状态，用于获取选区和渲染信息
  final EditorState editorState;
  /// 子组件，实际的工具栏内容
  final Widget child;
  /// 关闭回调，当工具栏需要隐藏时调用
  final VoidCallback onDismiss;
  /// 是否启用动画
  final bool enableAnimation;

  @override
  State<DesktopFloatingToolbar> createState() => _DesktopFloatingToolbarState();
}

/// DesktopFloatingToolbar的状态类
/// 
/// 管理工具栏的位置计算和生命周期。
/// 注册到全局控制器，确保同时只有一个工具栏显示。
class _DesktopFloatingToolbarState extends State<DesktopFloatingToolbar> {
  EditorState get editorState => widget.editorState;

  /// 工具栏位置信息
  _Position? position;
  /// 全局工具栏控制器
  final toolbarController = getIt<FloatingToolbarController>();

  @override
  void initState() {
    super.initState();
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) {
      return;
    }
    final selectionRect = editorState.selectionRects();
    if (selectionRect.isEmpty) return;
    position = calculateSelectionMenuOffset(selectionRect.first);
    toolbarController._addCallback(dismiss);
  }

  @override
  void dispose() {
    toolbarController._removeCallback(dismiss);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (position == null) return Container();
    return Positioned(
      left: position!.left,
      top: position!.top,
      right: position!.right,
      child: widget.enableAnimation
          ? ToolbarAnimationWidget(child: widget.child)
          : widget.child,
    );
  }

  void dismiss() {
    widget.onDismiss.call();
  }

  _Position calculateSelectionMenuOffset(
    Rect rect,
  ) {
    const toolbarHeight = 40, topLimit = toolbarHeight + 8;
    final bool isLongMenu = onlyShowInSingleSelectionAndTextType(editorState);
    final editorOffset =
        editorState.renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final editorSize = editorState.renderBox?.size ?? Size.zero;
    final menuWidth =
        isLongMenu ? (isNarrowWindow(editorState) ? 490.0 : 660.0) : 420.0;
    final editorRect = editorOffset & editorSize;
    final left = rect.left, leftStart = 50;
    final top =
        rect.top < topLimit ? rect.bottom + topLimit : rect.top - topLimit;
    if (left + menuWidth > editorRect.right) {
      return _Position(
        editorRect.right - menuWidth,
        top,
        null,
      );
    } else if (rect.left - leftStart > 0) {
      return _Position(rect.left - leftStart, top, null);
    } else {
      return _Position(rect.left, top, null);
    }
  }
}

/// 位置信息类
/// 
/// 封装工具栏的位置坐标。
/// 使用Positioned组件的left、top、right属性进行定位。
/// 
/// ## 设计说明
/// - left和right通常只设置一个，用于水平定位
/// - top用于垂直定位
/// - null值表示不设置该方向的约束
class _Position {
  _Position(this.left, this.top, this.right);

  /// 左侧距离
  final double? left;
  /// 顶部距离
  final double? top;
  /// 右侧距离
  final double? right;
}

/// 浮动工具栏控制器
/// 
/// 全局管理文档编辑器中所有浮动工具栏的显示和隐藏。
/// 确保同一时刻只有一个工具栏显示，避免UI重叠。
/// 
/// ## 核心职责
/// 1. **状态管理**：跟踪当前是否有工具栏正在显示
/// 2. **回调协调**：管理所有工具栏的dismiss回调
/// 3. **事件通知**：通知监听器工具栏显示状态变化
/// 
/// ## 设计模式
/// - **单例模式**：通过依赖注入确保全局唯一实例
/// - **观察者模式**：支持多个组件监听工具栏状态
/// 
/// ## 工作流程
/// ```
/// 工具栏A显示 → 注册dismiss回调 → 通知所有监听器
///     ↓
/// 工具栏B要显示 → 调用hideToolbar → 执行所有dismiss回调
///     ↓
/// 工具栏A隐藏 → 移除回调 → 工具栏B显示
/// ```
class FloatingToolbarController {
  /// dismiss回调集合
  /// 
  /// 每个显示的工具栏都会注册一个dismiss回调，
  /// 当需要隐藏时，调用这些回调来关闭工具栏
  final Set<VoidCallback> _dismissCallbacks = {};
  
  /// 显示事件监听器集合
  /// 
  /// 当有新工具栏显示时，通知所有监听器，
  /// 让其他组件可以响应工具栏显示事件
  final Set<VoidCallback> _displayListeners = {};

  /// 添加dismiss回调（内部方法）
  /// 
  /// 当工具栏显示时调用此方法注册回调。
  /// 同时通知所有显示监听器有新工具栏显示。
  /// 
  /// [callback] 工具栏的dismiss回调函数
  void _addCallback(VoidCallback callback) {
    _dismissCallbacks.add(callback);
    // 通知所有监听器：有新工具栏显示了
    for (final listener in Set.of(_displayListeners)) {
      listener.call();
    }
  }

  /// 移除dismiss回调（内部方法）
  /// 
  /// 当工具栏销毁时调用此方法移除回调
  void _removeCallback(VoidCallback callback) =>
      _dismissCallbacks.remove(callback);

  /// 检查是否有工具栏正在显示
  /// 
  /// 通过判断是否有注册的dismiss回调来确定
  bool get isToolbarShowing => _dismissCallbacks.isNotEmpty;

  /// 添加显示事件监听器
  /// 
  /// 其他组件可以监听工具栏显示事件，
  /// 例如链接悬停菜单监听到有工具栏显示时自动隐藏
  /// 
  /// [listener] 显示事件回调函数
  void addDisplayListener(VoidCallback listener) =>
      _displayListeners.add(listener);

  /// 移除显示事件监听器
  void removeDisplayListener(VoidCallback listener) =>
      _displayListeners.remove(listener);

  /// 隐藏所有工具栏
  /// 
  /// 调用所有注册的dismiss回调，关闭当前显示的所有工具栏。
  /// 这确保了新工具栏显示前，旧工具栏已经关闭。
  /// 
  /// 使用场景：
  /// - 新工具栏要显示时
  /// - 用户点击编辑器其他区域时
  /// - 选区发生变化时
  void hideToolbar() {
    if (_dismissCallbacks.isEmpty) return;
    // 执行所有dismiss回调，关闭所有工具栏
    for (final callback in _dismissCallbacks) {
      callback.call();
    }
  }
}
