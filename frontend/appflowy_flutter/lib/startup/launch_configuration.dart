/// 应用启动配置类
/// 
/// 封装应用启动时所需的所有配置参数
/// 这个类相当于应用的"启动参数包"，在整个启动流程中传递
/// 
/// 设计思想：
/// - 将所有启动相关的配置集中管理
/// - 使用不可变对象（const构造函数+final字段）保证配置的一致性
/// - 通过单一配置对象在各个启动任务间传递，避免参数分散
/// 
/// 类似于Java Spring Boot的application.properties
/// 或者Node.js的config对象
class LaunchConfiguration {
  const LaunchConfiguration({
    this.isAnon = false,
    required this.version,
    required this.rustEnvs,
  });

  /// 匿名模式标志
  /// 
  /// APP will automatically register after launching.
  /// 
  /// true: 匿名用户模式
  /// - 无需登录即可使用
  /// - 数据仅保存在本地，不同步到云端
  /// - 适用于快速体验或隐私模式
  /// 
  /// false: 正常模式
  /// - 需要用户登录或注册
  /// - 支持云端同步功能
  /// - 完整的协作功能
  final bool isAnon;
  
  /// 应用版本号
  /// 
  /// 格式通常为 "主版本.次版本.修订版本" (如 "1.0.0")
  /// 用途：
  /// - 显示在关于页面
  /// - 用于版本更新检查
  /// - 发送给后端用于兼容性判断
  /// - 错误报告中的版本信息
  final String version;
  
  /// Rust后端环境变量
  /// 
  /// 传递给Rust后端的配置参数
  /// 可能包含：
  /// - API服务器地址
  /// - 日志级别
  /// - 数据库路径
  /// - 调试开关
  /// - 特性开关
  /// 
  /// 这是Flutter前端与Rust后端通信的重要桥梁
  /// 通过环境变量的方式配置后端行为
  final Map<String, String> rustEnvs;
}
