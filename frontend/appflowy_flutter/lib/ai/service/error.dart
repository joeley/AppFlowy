/// AI错误处理
/// 
/// 定义AI功能中的错误类型和错误码
/// 用于统一处理AI服务返回的各种错误情况

import 'package:freezed_annotation/freezed_annotation.dart';

// 代码生成文件
part 'error.freezed.dart';
part 'error.g.dart';

/// AI错误实体类
/// 
/// 封装AI服务的错误信息
/// 使用freezed生成不可变对象，支持JSON序列化
@freezed
class AIError with _$AIError {
  const factory AIError({
    // 错误消息描述
    required String message,
    // 错误码，用于区分不同类型的错误
    required AIErrorCode code,
  }) = _AIError;

  /// 从JSON创建错误对象
  /// 
  /// 用于反序列化服务器返回的错误信息
  factory AIError.fromJson(Map<String, Object?> json) =>
      _$AIErrorFromJson(json);
}

/// AI错误码枚举
/// 
/// 定义所有可能的AI错误类型
/// 使用JsonValue注解指定与后端对应的字符串值
enum AIErrorCode {
  // AI响应限额超出：用户达到了AI使用次数限制
  @JsonValue('AIResponseLimitExceeded')
  aiResponseLimitExceeded,
  
  // AI图片响应限额超出：用户达到了AI图片生成次数限制
  @JsonValue('AIImageResponseLimitExceeded')
  aiImageResponseLimitExceeded,
  
  // 其他错误：未分类的通用错误
  @JsonValue('Other')
  other,
}

/// AI错误扩展
/// 
/// 为AIError类添加便捷方法
extension AIErrorExtension on AIError {
  /// 判断是否为限额超出错误
  /// 
  /// 用于快速判断是否需要提示用户升级或等待限额重置
  bool get isLimitExceeded => code == AIErrorCode.aiResponseLimitExceeded;
}
