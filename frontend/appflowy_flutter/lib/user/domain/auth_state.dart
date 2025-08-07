// Protocol Buffers生成的用户信息类
// PB后缀表示Protocol Buffer
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
// Protocol Buffers生成的错误类
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
// freezed注解库
import 'package:freezed_annotation/freezed_annotation.dart';
// freezed生成的代码
part 'auth_state.freezed.dart';

/**
 * 认证状态 - 使用Union Type模式
 * 
 * Union Type（联合类型）的优势：
 * 1. **类型安全**：编译时保证所有状态都被处理
 * 2. **清晰的状态机**：明确定义所有可能的状态
 * 3. **携带相关数据**：每个状态可以携带不同的数据
 * 
 * 这种模式类似于：
 * - Kotlin的sealed class
 * - Rust的enum
 * - TypeScript的discriminated union
 * 
 * @freezed会为每个工厂构造函数生成一个子类
 */
@freezed
class AuthState with _$AuthState {
  /**
   * 已认证状态
   * 
   * @param userProfile 用户信息对象
   *                    包含用户ID、名称、邮箱等信息
   *                    使用Protocol Buffer序列化，可与Rust后端通信
   * 
   * 当用户成功登录后，应用处于这个状态
   */
  const factory AuthState.authenticated(UserProfilePB userProfile) =
      Authenticated;
  
  /**
   * 未认证状态
   * 
   * @param error 错误信息
   *              包含错误码和错误描述
   *              用于显示给用户或记录日志
   * 
   * 当用户未登录或登录失败时，应用处于这个状态
   */
  const factory AuthState.unauthenticated(FlowyError error) = Unauthenticated;
  
  /**
   * 初始状态
   * 
   * 没有任何参数，表示还未进行认证检查
   * 这是应用刚启动时的状态
   * 
   * _Initial是私有类名，由freezed自动生成
   */
  const factory AuthState.initial() = _Initial;
}
