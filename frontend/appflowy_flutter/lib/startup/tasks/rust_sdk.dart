import 'dart:convert';
import 'dart:io';

// 后端环境配置
import 'package:appflowy/env/backend_env.dart';
// 云环境配置
import 'package:appflowy/env/cloud_env.dart';
// 设备ID管理
import 'package:appflowy/user/application/auth/device_id.dart';
// Rust后端SDK
import 'package:appflowy_backend/appflowy_backend.dart';
// 路径处理库
import 'package:path/path.dart' as path;
// 获取平台特定目录
import 'package:path_provider/path_provider.dart';

import '../startup.dart';

/// Rust SDK初始化任务
/// 
/// 这是AppFlowy的核心任务之一
/// 
/// AppFlowy采用Flutter+Rust的架构：
/// - Flutter：负责UI展示和交互
/// - Rust：负责核心业务逻辑、数据处理和存储
/// 
/// 主要职责：
/// 1. 准备数据存储目录
/// 2. 获取设备唯一标识
/// 3. 构建配置参数
/// 4. 启动Rust后端服务
/// 
/// 这个任务必须在所有业务功能之前执行
/// 因为所有的数据操作都依赖于Rust SDK
class InitRustSDKTask extends LaunchTask {
  const InitRustSDKTask({
    this.customApplicationPath,
  });

  // Customize the RustSDK initialization path
  /// 自定义数据存储路径
  /// 主要用于测试环境，可以指定不同的数据目录
  final Directory? customApplicationPath;

  @override
  LaunchTaskType get type => LaunchTaskType.dataProcessing;  // 数据处理类任务

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 获取平台特定的应用支持目录
    // iOS: ~/Library/Application Support/
    // Android: /data/data/<package>/files/
    // Windows: C:\Users\<user>\AppData\Roaming\
    final root = await getApplicationSupportDirectory();
    
    // 获取AppFlowy的数据目录
    // 根据不同的运行模式会有不同的目录
    final applicationPath = await appFlowyApplicationDataDirectory();
    
    // 优先使用自定义路径，否则使用默认路径
    final dir = customApplicationPath ?? applicationPath;
    
    // 获取设备唯一ID
    // 用于区分不同设备的数据同步
    final deviceId = await getDeviceId();

    // Pass the environment variables to the Rust SDK
    // 构建Rust SDK所需的配置
    final env = _makeAppFlowyConfiguration(
      root.path,
      context.config.version,
      dir.path,
      applicationPath.path,
      deviceId,
      rustEnvs: context.config.rustEnvs,
    );
    
    // 初始化Rust SDK
    // 这里通过FFI（Foreign Function Interface）调用Rust代码
    // JSON序列化配置后传递给Rust
    await context.getIt<FlowySDK>().init(jsonEncode(env.toJson()));
  }
}

/// 构建AppFlowy配置对象
/// 
/// 这个配置将传递给Rust后端，包含所有必要的运行参数
AppFlowyConfiguration _makeAppFlowyConfiguration(
  String root,           // 根目录
  String appVersion,     // 应用版本
  String customAppPath,  // 自定义数据路径
  String originAppPath,  // 原始数据路径
  String deviceId, {     // 设备ID
  required Map<String, String> rustEnvs,  // Rust环境变量
}) {
  // 获取云环境配置
  final env = getIt<AppFlowyCloudSharedEnv>();
  
  return AppFlowyConfiguration(
    root: root,
    app_version: appVersion,
    custom_app_path: customAppPath,
    origin_app_path: originAppPath,
    device_id: deviceId,
    // 当前操作系统类型
    platform: Platform.operatingSystem,
    // 认证类型：本地、云端等
    authenticator_type: env.authenticatorType.value,
    // AppFlowy云配置
    appflowy_cloud_config: env.appflowyCloudConfig,
    // 额外的环境变量
    envs: rustEnvs,
  );
}

/// 获取AppFlowy数据存储目录
/// 
/// The default directory to store the user data. The directory can be
/// customized by the user via the [ApplicationDataStorage]
/// 
/// 根据不同的运行模式返回不同的目录：
/// - 开发模式：使用data_dev目录，避免影响正式数据
/// - 发布模式：使用data目录
/// - 测试模式：使用.sandbox目录，便于清理
/// 
/// 这种设计避免了不同环境的数据混淆
Future<Directory> appFlowyApplicationDataDirectory() async {
  switch (integrationMode()) {
    case IntegrationMode.develop:
      // 开发模式：使用独立的data_dev目录
      final Directory documentsDir = await getApplicationSupportDirectory()
          .then((directory) => directory.create());
      return Directory(path.join(documentsDir.path, 'data_dev'));
    
    case IntegrationMode.release:
      // 发布模式：使用正式的data目录
      final Directory documentsDir = await getApplicationSupportDirectory();
      return Directory(path.join(documentsDir.path, 'data'));
    
    case IntegrationMode.unitTest:
    case IntegrationMode.integrationTest:
      // 测试模式：使用临时的.sandbox目录
      // 测试结束后可以轻松删除
      return Directory(path.join(Directory.current.path, '.sandbox'));
  }
}
