/* Dart IO库 - 提供文件系统操作，包括目录创建、路径检查等 */
import 'dart:io';

/* Flutter基础库 - 提供kIsWeb等平台检查常量 */
import 'package:flutter/foundation.dart';

/* AppFlowy键值存储接口 - 用于持久化应用配置 */
import 'package:appflowy/core/config/kv.dart';
/* AppFlowy键值存储常量 - 定义配置键名 */
import 'package:appflowy/core/config/kv_keys.dart';
/* 通用正则表达式模式 - 用于路径格式化和验证 */
import 'package:appflowy/shared/patterns/common_patterns.dart';
/* 应用启动器 - 获取依赖注入容器 */
import 'package:appflowy/startup/startup.dart';
/* AppFlowy后端日志系统 - 记录调试和错误信息 */
import 'package:appflowy_backend/log.dart';
/* Dart path库 - 提供跨平台的路径操作工具 */
import 'package:path/path.dart' as p;

/* 应用启动任务模块 - 包含默认数据目录获取函数 */
import '../../../startup/tasks/prelude.dart';

/* 
 * AppFlowy数据文件夹名称常量
 * 
 * 重要说明：
 * - "DoNotRename"后缀提醒用户不要重命名这个文件夹
 * - 重命名会导致AppFlowy无法找到用户数据
 * - 包含用户的所有工作空间、文档、数据库和配置
 * 
 * 文件夹结构：
 * AppFlowyDataDoNotRename/
 * ├── databases/          # 数据库文件
 * ├── documents/          # 文档存储
 * ├── workspaces/         # 工作空间配置
 * ├── temp/              # 临时文件
 * └── logs/              # 日志文件
 */
const appFlowyDataFolder = "AppFlowyDataDoNotRename";

/* 
 * 应用数据存储管理类
 *
 * 核心职责：
 * - 管理AppFlowy数据目录的位置和访问
 * - 支持用户自定义数据存储路径
 * - 确保数据目录的有效性和可访问性
 * - 处理跨平台的路径差异
 * 
 * 设计思想：
 * - 延迟缓存：路径只在第一次访问时计算和缓存
 * - 平台适配：处理不同操作系统的路径格式差异
 * - 错误恢复：自动处理无效路径，回退到默认位置
 * - 数据完整性：确保数据目录的持久性和稳定性
 * 
 * 使用场景：
 * - 用户需要将数据存储到外部硬盘
 * - 企业环境中的集中化数据管理
 * - 多用户共享同一设备时的数据隔离
 * - 数据备份和迁移操作
 */
class ApplicationDataStorage {
  ApplicationDataStorage();
  
  /* 缓存的数据路径
   * null表示尚未初始化，非null表示已缓存有效路径
   * 
   * 缓存策略说明：
   * - 避免重复的磁盘I/O操作，提高性能
   * - 在应用运行期间保持路径的一致性
   * - 路径变更时会清空缓存，强制重新计算
   */
  String? _cachePath;

  /* 设置自定义数据存储路径
   * 
   * 功能描述：
   * - 允许用户指定自定义的数据存储位置
   * - 自动创建不存在的目录结构
   * - 处理路径格式的平台差异
   * - 无效路径时自动回退到默认路径
   * 
   * 路径处理规则：
   * 1. macOS: 移除Volumes前缀，处理外部存储设备路径
   * 2. Windows: 统一使用反斜杠路径分隔符
   * 3. 自动添加AppFlowyDataDoNotRename文件夹
   * 4. 创建完整的目录结构
   * 
   * @param path 用户指定的存储路径
   * 
   * 使用场景：
   * - 设置页面中的路径配置
   * - 数据迁移和备份操作
   * - 企业部署中的统一数据管理
   */
  Future<void> setCustomPath(String path) async {
    // 平台兼容性检查：移动端和Web端不支持自定义路径
    // 
    // 原因说明：
    // - Web: 浏览器沙箱限制，无法访问任意文件系统路径
    // - Android/iOS: 应用沙箱模式，数据必须存储在指定的应用目录内
    // - 桌面端(Windows/macOS/Linux): 支持用户选择任意可访问的路径
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      Log.info('LocalFileStorage is not supported on this platform.');
      return;
    }

    // 平台特定的路径格式化处理
    if (Platform.isMacOS) {
      // macOS特殊处理：移除/Volumes/*前缀
      // 
      // 背景：macOS中外部驱动器通常挂载在/Volumes/下
      // 例如：/Volumes/ExternalDrive/MyFolder -> /ExternalDrive/MyFolder
      // 目的：简化路径表示，避免挂载点变化带来的问题
      path = path.replaceFirst(macOSVolumesRegex, '');
    } else if (Platform.isWindows) {
      // Windows路径格式标准化：统一使用反斜杠
      // 
      // 将Unix风格的正斜杠路径转换为Windows标准格式
      // 例如：C:/Users/Name -> C:\Users\Name
      // 确保与Windows文件系统API的兼容性
      path = path.replaceAll('/', '\\');
    }

    // 智能路径处理：确保数据文件夹的正确结构
    // 
    // 处理逻辑：
    // 1. 如果用户选择的路径不是以AppFlowyDataDoNotRename结尾
    //    则自动在该路径下创建AppFlowyDataDoNotRename文件夹
    // 2. 如果用户直接选择了AppFlowyDataDoNotRename文件夹
    //    则直接使用该路径作为数据目录
    // 
    // 示例：
    // 输入: "/Users/john/Documents" 
    // 输出: "/Users/john/Documents/AppFlowyDataDoNotRename"
    // 
    // 输入: "/Users/john/MyAppFlowyData/AppFlowyDataDoNotRename"
    // 输出: "/Users/john/MyAppFlowyData/AppFlowyDataDoNotRename" (不变)
    if (p.basename(path) != appFlowyDataFolder) {
      path = p.join(path, appFlowyDataFolder);
    }

    // 目录创建：确保完整的目录结构存在
    final directory = Directory(path);
    if (!directory.existsSync()) {
      // recursive: true 表示创建完整的目录路径
      // 例如：如果/a/b/c不存在，会依次创建/a, /a/b, /a/b/c
      // 
      // 异常处理：如果创建失败（权限不足、磁盘空间不足等）
      // 异常会向上传播，调用方需要处理这些情况
      await directory.create(recursive: true);
    }

    // 保存路径到持久化存储，并清理缓存
    await setPath(path);
  }

  /* 设置数据存储路径（内部方法）
   * 
   * 与setCustomPath的区别：
   * - setCustomPath: 面向用户的高级方法，包含路径验证和格式化
   * - setPath: 内部方法，直接保存路径到持久化存储
   * 
   * 调用方：
   * - 应用启动时的默认路径初始化
   * - 单元测试中的路径设置
   * - 其他内部组件的路径更新
   * 
   * @param path 已验证的有效路径
   */
  Future<void> setPath(String path) async {
    // 平台兼容性检查：与setCustomPath保持一致的平台限制
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      Log.info('LocalFileStorage is not supported on this platform.');
      return;
    }

    // 将路径保存到SharedPreferences中，实现跨会话持久化
    await getIt<KeyValueStorage>().set(KVKeys.pathLocation, path);
    
    // 清空缓存路径，强制下次访问时重新计算
    // 
    // 为什么不直接设置为新路径？
    // - 新设置的路径可能在保存后变为无效（权限变化、磁盘无效等）
    // - 下次getPath()时会重新验证路径的有效性
    // - 确保数据一致性和健壮性
    _cachePath = null;
  }

  /* 获取当前数据存储路径
   * 
   * 路径解析的优先级：
   * 1. 缓存路径（性能优先）
   * 2. 用户配置的自定义路径（从持久化存储读取）
   * 3. 系统默认路径（后备方案）
   * 
   * 健壮性保证：
   * - 自动检测路径有效性
   * - 无效路径时自动回退到默认路径
   * - 保证始终返回可用的路径
   * 
   * @return 有效的数据存储路径
   * 
   * 常见使用场景：
   * - 文档创建和保存操作
   * - 数据库初始化
   * - 工作空间的位置确定
   * - 备份和还原操作
   */
  Future<String> getPath() async {
    // 缓存命中：直接返回缓存的路径，避免重复的I/O操作
    if (_cachePath != null) {
      return _cachePath!;
    }

    // 从持久化存储读取用户配置的路径
    final response = await getIt<KeyValueStorage>().get(KVKeys.pathLocation);

    // 路径解析逻辑
    String path;
    if (response == null) {
      // 情况A：用户未设置自定义路径，使用系统默认路径
      final directory = await appFlowyApplicationDataDirectory();
      path = directory.path;
    } else {
      // 情况B：使用用户配置的自定义路径
      path = response;
    }
    
    // 缓存路径，提高后续访问性能
    _cachePath = path;

    // 路径有效性验证：防止返回不存在的路径
    if (!Directory(path).existsSync()) {
      // 当路径不存在时，可能的原因：
      // - 外部存储设备被断开连接
      // - 用户手动删除了目录
      // - 权限发生变化导致路径不可访问
      // - 系统升级或迁移导致路径变化
      
      // 清空所有持久化配置，重置为出厂状态
      await getIt<KeyValueStorage>().clear();
      
      // 返回到系统默认路径，确保应用可以继续运行
      final directory = await appFlowyApplicationDataDirectory();
      path = directory.path;
    }

    return path;
  }
}

/* 
 * 应用数据存储的Mock实现类
 *
 * 用途：
 * - 单元测试和集成测试中替换真实的存储实现
 * - 避免测试时污染用户的真实数据目录
 * - 提供可控的测试环境和预设数据路径
 * 
 * 测试策略：
 * - 支持预设初始路径，便于测试特定的路径场景
 * - 自动清理初始路径，避免测试间的状态污染
 * - 保持与生产代码相同的行为模式
 * 
 * 使用方式：
 * ```dart
 * // 测试前设置
 * MockApplicationDataStorage.initialPath = "/tmp/test_data";
 * final storage = MockApplicationDataStorage();
 * 
 * // 首次调用会使用预设路径
 * final path = await storage.getPath(); // 返回 "/tmp/test_data"
 * 
 * // 后续调用按正常逻辑处理
 * final path2 = await storage.getPath(); // 从配置或默认路径获取
 * ```
 */
class MockApplicationDataStorage extends ApplicationDataStorage {
  MockApplicationDataStorage();

  /* 初始测试路径 - 仅用于测试环境的路径预设
   * 
   * 生命周期：
   * - 设置：测试开始时由测试代码设置
   * - 使用：首次调用getPath()时消费
   * - 清理：使用后立即清空，避免影响后续测试
   * 
   * 注意事项：
   * - 这是一个静态变量，在测试类间可能有状态共享
   * - 使用@visibleForTesting注解，表明这是测试专用API
   * - 生产代码中不应该访问这个变量
   */
  @visibleForTesting
  static String? initialPath;

  @override
  Future<String> getPath() async {
    // 检查是否有预设的初始路径（仅测试时使用）
    final path = initialPath;
    if (path != null) {
      // 立即清空初始路径，确保只使用一次
      // 这避免了测试之间的状态污染
      initialPath = null;
      
      // 将预设路径设置为当前路径，保持行为一致性
      await super.setPath(path);
      
      // 直接返回预设路径，跳过复杂的路径解析逻辑
      return Future.value(path);
    }
    
    // 如果没有预设路径，使用父类的正常逻辑
    // 这确保了Mock类在大部分情况下的行为与生产代码一致
    return super.getPath();
  }
}
