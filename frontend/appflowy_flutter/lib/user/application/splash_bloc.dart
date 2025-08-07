// 启动模块，用于获取依赖注入
import 'package:appflowy/startup/startup.dart';
// 认证服务接口
import 'package:appflowy/user/application/auth/auth_service.dart';
// 认证状态定义
import 'package:appflowy/user/domain/auth_state.dart';
// BLoC库，提供状态管理框架
import 'package:flutter_bloc/flutter_bloc.dart';
// freezed库，用于生成不可变对象和union types
import 'package:freezed_annotation/freezed_annotation.dart';

// freezed生成的代码文件
// 运行`flutter pub run build_runner build`生成
part 'splash_bloc.freezed.dart';

/**
 * 闪屏页BLoC - 管理闪屏页的业务逻辑和状态
 * 
 * BLoC（Business Logic Component）模式的核心思想：
 * 1. **分离关注点**：UI与业务逻辑完全分离
 * 2. **单向数据流**：Event -> BLoC -> State -> UI
 * 3. **响应式编程**：使用Stream处理异步事件
 * 4. **可测试性**：业务逻辑独立于UI，易于单元测试
 * 
 * 类似于：
 * - Redux中的Reducer + Actions
 * - MVI架构的Intent + Model
 * - MVVM中的ViewModel
 */
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  /**
   * 构造函数
   * 
   * 初始化BLoC并设置事件处理器
   * super()调用设置初始状态
   */
  SplashBloc() : super(SplashState.initial()) {
    // 注册事件处理器
    // on<T>方法定义如何处理特定类型的事件
    on<SplashEvent>((event, emit) async {
      // 使用freezed生成的map方法进行模式匹配
      // 类似于Kotlin的when或Rust的match
      await event.map(
        // 处理getUser事件
        getUser: (val) async {
          // 从依赖注入容器获取AuthService
          // 调用getUser方法获取当前用户信息
          final response = await getIt<AuthService>().getUser();
          
          // fold方法处理Result类型（Either模式）
          // 左值（成功）：返回用户信息
          // 右值（失败）：返回错误信息
          final authState = response.fold(
            (user) => AuthState.authenticated(user),    // 创建已认证状态
            (error) => AuthState.unauthenticated(error), // 创建未认证状态
          );
          
          // emit方法发射新状态
          // copyWith是freezed生成的方法，用于创建不可变对象的副本
          emit(state.copyWith(auth: authState));
        },
      );
    });
  }
}

/**
 * 闪屏页事件定义
 * 
 * @freezed注解会生成：
 * 1. 不可变类
 * 2. copyWith方法
 * 3. 序列化/反序列化方法
 * 4. equals和hashCode实现
 * 
 * 事件代表用户操作或系统触发的动作
 * 这里只有一个事件：获取用户信息
 */
@freezed
class SplashEvent with _$SplashEvent {
  /**
   * 获取用户事件
   * 
   * 在闪屏页加载时触发，用于检查用户登录状态
   * _GetUser是私有构造函数，由freezed生成
   */
  const factory SplashEvent.getUser() = _GetUser;
}

/**
 * 闪屏页状态定义
 * 
 * 状态代表UI应该显示的数据
 * 每当状态改变，UI会自动重建
 * 
 * @freezed使这个类成为不可变的（immutable）
 * 不可变性是BLoC模式的核心原则之一
 */
@freezed
class SplashState with _$SplashState {
  /**
   * 主构造函数
   * 
   * @param auth 认证状态 - 跟踪用户是否已登录
   *             这是一个union type，可以是：
   *             - Authenticated: 已登录，包含用户信息
   *             - Unauthenticated: 未登录，包含错误信息
   *             - Initial: 初始状态
   */
  const factory SplashState({
    required AuthState auth,
  }) = _SplashState;

  /**
   * 工厂方法 - 创建初始状态
   * 
   * 用于BLoC初始化时设置默认状态
   * 初始状态表示还没有进行任何认证检查
   */
  factory SplashState.initial() => const SplashState(
        auth: AuthState.initial(),
      );
}
