// scaled_app包：提供应用缩放功能，解决不同屏幕密度下的UI适配问题
// 这是Flutter应用处理多屏幕适配的一种策略
import 'package:scaled_app/scaled_app.dart';

// startup模块：封装了整个应用的启动逻辑
// 将复杂的初始化过程从main函数中分离，保持入口文件简洁
import 'startup/startup.dart';

/// AppFlowy应用程序的入口点
/// 
/// 这是整个Flutter应用的起点，类似于Java中的main方法。
/// Flutter应用的执行流程：
/// 1. Dart VM启动
/// 2. 执行main函数
/// 3. 初始化Flutter框架
/// 4. 运行应用Widget树
/// 
/// 设计思想：
/// - 保持入口文件极简，只负责最基础的框架初始化
/// - 将具体的业务初始化逻辑委托给专门的启动模块(startup)
/// - 这种分层设计让代码结构更清晰，职责更单一
Future<void> main() async {
  // ScaledWidgetsFlutterBinding是scaled_app包提供的增强版WidgetsFlutterBinding
  // WidgetsFlutterBinding是Flutter框架和Flutter引擎的桥梁，负责：
  // 1. 管理Flutter框架和底层引擎的通信
  // 2. 处理窗口大小变化、屏幕旋转等系统事件
  // 3. 调度Widget的构建和渲染
  // 
  // ensureInitialized()确保Flutter绑定层已经初始化
  // 必须在main函数中调用任何Flutter框架API之前调用此方法
  // 这类似于Java Spring Boot中的SpringApplication.run()
  ScaledWidgetsFlutterBinding.ensureInitialized(
    // scaleFactor：定义全局缩放因子的计算函数
    // 参数_表示忽略传入的MediaQueryData（包含屏幕信息）
    // 返回1.0表示不进行任何缩放，保持原始大小
    // 实际项目中可能会根据屏幕尺寸动态计算缩放比例
    scaleFactor: (_) => 1.0,
  );

  // 启动AppFlowy应用的核心逻辑
  // await关键字确保应用初始化完成后才继续执行
  // 这里采用了异步初始化模式，允许在启动时执行耗时操作：
  // - 数据库初始化
  // - 用户配置加载
  // - 网络服务连接
  // - 依赖注入容器初始化等
  // 
  // 将启动逻辑封装在单独的函数中是一种最佳实践
  // 类似于Java中将Spring配置与main方法分离
  await runAppFlowy();
}
