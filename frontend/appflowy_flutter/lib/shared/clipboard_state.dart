import 'package:flutter/foundation.dart';

/// 剪贴板状态管理器
///
/// 管理应用内剪贴板操作的状态，主要用于文档编辑器。
/// 区分剪切和复制操作，处理粘贴操作的并发控制。
///
/// 核心功能：
/// 1. **操作类型追踪**：区分剪切(cut)和复制(copy)操作
/// 2. **粘贴状态管理**：追踪粘贴操作的进行状态
/// 3. **并发控制**：支持多个粘贴操作的并发管理
/// 
/// 使用场景：
/// - 文档内JSON格式的复制粘贴
/// - 需要区分剪切和复制的场景（剪切后原内容需要删除）
/// - 防止粘贴操作的重复执行
class ClipboardState {
  ClipboardState();

  /// 是否为剪切操作
  /// 剪切操作后，下次粘贴会被视为复制操作
  bool _isCut = false;

  /// 获取当前是否为剪切状态
  bool get isCut => _isCut;

  /// 粘贴处理状态通知器
  /// 用于通知UI层粘贴操作的进行状态
  final ValueNotifier<bool> isHandlingPasteNotifier = ValueNotifier(false);
  
  /// 获取当前是否正在处理粘贴
  bool get isHandlingPaste => isHandlingPasteNotifier.value;

  /// 正在处理的粘贴操作ID集合
  /// 支持多个粘贴操作并发进行
  final Set<String> _handlingPasteIds = {};

  /// 释放资源
  void dispose() {
    isHandlingPasteNotifier.dispose();
  }

  /// 标记执行了剪切操作
  /// 
  /// 调用后，剪贴板状态变为剪切模式
  /// 下次粘贴时原内容应该被移除
  void didCut() {
    _isCut = true;
  }

  /// 标记执行了粘贴操作
  /// 
  /// 粘贴完成后重置剪切状态
  /// 确保剪切只生效一次
  void didPaste() {
    _isCut = false;
  }

  /// 开始处理粘贴操作
  /// 
  /// 使用唯一ID标识粘贴操作，支持并发控制
  /// 通知UI层粘贴操作开始
  void startHandlingPaste(String id) {
    _handlingPasteIds.add(id);
    isHandlingPasteNotifier.value = true;
  }

  /// 结束处理粘贴操作
  /// 
  /// 移除指定ID的粘贴操作
  /// 当所有粘贴操作完成时，通知UI层
  void endHandlingPaste(String id) {
    _handlingPasteIds.remove(id);
    if (_handlingPasteIds.isEmpty) {
      isHandlingPasteNotifier.value = false;
    }
  }
}
