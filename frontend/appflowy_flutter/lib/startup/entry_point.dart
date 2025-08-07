// 启动配置类，包含版本号、环境变量等启动参数
import 'package:appflowy/startup/launch_configuration.dart';
// 导入EntryPoint抽象接口
import 'package:appflowy/startup/startup.dart';
// 闪屏页面，应用启动时显示的第一个界面
import 'package:appflowy/user/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';

/// AppFlowy应用的具体入口点实现
/// 
/// 这个类是整个应用的Widget树起点
/// 设计模式：策略模式（Strategy Pattern）
/// - EntryPoint是策略接口
/// - AppFlowyApplication是具体策略实现
/// - 允许在不同环境下使用不同的入口实现（如测试环境可以有TestApplication）
/// 
/// 职责：
/// 1. 创建应用的根Widget
/// 2. 传递启动配置到UI层
/// 3. 决定启动后显示的第一个界面
/// 
/// 这种设计让应用的启动流程与UI实现解耦
/// 类似于Android的Application类或iOS的AppDelegate
class AppFlowyApplication implements EntryPoint {
  @override
  Widget create(LaunchConfiguration config) {
    // 返回闪屏页面作为应用的第一个界面
    // SplashScreen负责：
    // 1. 显示启动画面（logo、加载动画等）
    // 2. 执行额外的异步初始化任务
    // 3. 根据用户登录状态决定跳转到登录页或主页
    // 
    // isAnon参数决定是否以匿名模式启动
    // - true: 跳过登录，直接进入本地模式
    // - false: 正常登录流程
    return SplashScreen(isAnon: config.isAnon);
  }
}
