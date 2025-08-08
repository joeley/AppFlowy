import 'dart:typed_data';

import 'package:appflowy_backend/protobuf/flowy-notification/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';

/*
 * 通知解析器 - AppFlowy通知系统的核心组件
 * 
 * 这是一个泛型类，用于解析来自Rust后端的通知消息，并将其转换为Flutter可用的类型
 * 
 * 类型参数:
 * - T: 通知类型枚举 (如DocumentNotification, FolderNotification等)
 * - E: 错误类型 (通常是FlowyError)
 * 
 * 工作原理:
 * 1. 接收来自Rust后端的SubscribeObject原始通知
 * 2. 根据source和ty字段解析通知类型
 * 3. 解析payload或error数据
 * 4. 通过回调函数传递给业务层处理
 */
class NotificationParser<T, E extends Object> {
  NotificationParser({
    this.id,
    required this.callback,
    required this.errorParser,
    required this.tyParser,
  });

  /* 可选的对象ID过滤器 - 只处理特定对象的通知 */
  String? id;
  
  /* 通知处理回调函数 - 将解析后的通知和结果传递给业务层 */
  void Function(T, FlowyResult<Uint8List, E>) callback;
  
  /* 错误解析函数 - 将字节数据转换为具体的错误类型 */
  E Function(Uint8List) errorParser;
  
  /* 类型解析函数 - 根据数值类型和来源判断具体的通知类型 */
  T? Function(int, String) tyParser;

  /*
   * 解析通知对象的核心方法
   * 
   * 处理流程:
   * 1. 检查ID过滤器 - 如果设置了ID且不匹配则忽略
   * 2. 解析通知类型 - 使用tyParser根据ty和source确定通知类型
   * 3. 处理通知数据 - 区分成功载荷和错误信息
   * 4. 执行回调 - 将结果传递给注册的处理函数
   */
  void parse(SubscribeObject subject) {
    // ID过滤 - 只处理指定对象的通知
    if (id != null) {
      if (subject.id != id) {
        return;
      }
    }

    // 解析通知类型 - 根据数值和来源确定具体类型
    final ty = tyParser(subject.ty, subject.source);
    if (ty == null) {
      return;
    }

    // 处理通知数据 - 区分错误和成功情况
    if (subject.hasError()) {
      // 错误情况 - 解析错误数据并创建失败结果
      final bytes = Uint8List.fromList(subject.error);
      final error = errorParser(bytes);
      callback(ty, FlowyResult.failure(error));
    } else {
      // 成功情况 - 提取载荷数据并创建成功结果
      final bytes = Uint8List.fromList(subject.payload);
      callback(ty, FlowyResult.success(bytes));
    }
  }
}
