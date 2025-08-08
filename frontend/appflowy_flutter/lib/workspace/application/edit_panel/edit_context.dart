import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 编辑面板上下文抽象类
/// 
/// 用于封装不同类型的编辑内容，如：
/// - 属性编辑器
/// - 设置面板
/// - 详情视图
/// - 自定义表单
/// 
/// 设计思想：
/// - 通过identifier唯一标识编辑上下文
/// - title用于显示在面板标题栏
/// - child为实际编辑内容Widget
/// - 使用Equatable便于状态比较
abstract class EditPanelContext extends Equatable {
  const EditPanelContext({
    required this.identifier, // 唯一标识符
    required this.title,      // 面板标题
    required this.child,       // 编辑内容Widget
  });

  final String identifier; // 唯一标识符，用于区分不同的编辑上下文
  final String title;      // 面板标题，显示在编辑面板顶部
  final Widget child;      // 实际的编辑内容组件

  @override
  List<Object> get props => [identifier]; // 仅通过identifier判断相等性
}
