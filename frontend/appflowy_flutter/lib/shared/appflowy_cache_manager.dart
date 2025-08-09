import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy_backend/log.dart';
import 'package:path_provider/path_provider.dart';

/// 缓存管理器
/// 
/// 统一管理应用中的各种缓存，提供清理和大小统计功能。
/// 
/// 主要功能：
/// 1. **缓存注册**：支持注册多个缓存实现
/// 2. **统一清理**：一次性清理所有已注册的缓存
/// 3. **大小统计**：计算所有缓存的总大小
/// 4. **错误处理**：优雅处理清理过程中的异常
/// 
/// 设计模式：
/// - **策略模式**：通过ICache接口支持不同的缓存策略
/// - **注册模式**：动态注册和管理缓存实现
class FlowyCacheManager {
  /// 已注册的缓存列表
  final _caches = <ICache>[];

  /// 注册缓存
  /// 
  /// 添加新的缓存实现到管理器中
  /// 如果添加新的缓存类型，需要在这里注册
  void registerCache(ICache cache) {
    _caches.add(cache);
  }

  /// 注销所有缓存
  /// 
  /// 清空缓存注册列表
  void unregisterAllCache(ICache cache) {
    _caches.clear();
  }

  /// 清理所有缓存
  /// 
  /// 遍历所有已注册的缓存并执行清理操作
  /// 即使某个缓存清理失败也会继续清理其他缓存
  Future<void> clearAllCache() async {
    try {
      for (final cache in _caches) {
        await cache.clearAll();
      }

      Log.info('Cache cleared');
    } catch (e) {
      Log.error(e);
    }
  }

  /// 获取缓存总大小
  /// 
  /// 计算所有已注册缓存的总大小（字节）
  /// 如果获取失败返回0
  Future<int> getCacheSize() async {
    try {
      int tmpDirSize = 0;
      for (final cache in _caches) {
        tmpDirSize += await cache.cacheSize();
      }
      Log.info('Cache size: $tmpDirSize');
      return tmpDirSize;
    } catch (e) {
      Log.error(e);
      return 0;
    }
  }
}

/// 缓存接口
/// 
/// 定义缓存必须实现的基本操作
/// 所有缓存实现都应该遵循这个接口
abstract class ICache {
  /// 获取缓存大小（字节）
  Future<int> cacheSize();
  
  /// 清理所有缓存
  Future<void> clearAll();
}

/// 临时目录缓存
/// 
/// 管理系统临时目录中的缓存文件
/// 主要用于清理下载的文件、图片缓存等临时数据
class TemporaryDirectoryCache implements ICache {
  @override
  Future<int> cacheSize() async {
    final tmpDir = await getTemporaryDirectory();
    final tmpDirStat = await tmpDir.stat();
    return tmpDirStat.size;
  }

  @override
  Future<void> clearAll() async {
    final tmpDir = await getTemporaryDirectory();
    // 递归删除临时目录下的所有内容
    await tmpDir.delete(recursive: true);
  }
}

/// 功能开关缓存
/// 
/// 管理功能开关的缓存状态
/// 清理时会重置所有功能开关到默认状态
class FeatureFlagCache implements ICache {
  @override
  Future<int> cacheSize() async {
    // 功能开关数据很小，返回0
    return 0;
  }

  @override
  Future<void> clearAll() async {
    // 清除所有功能开关设置
    await FeatureFlag.clear();
  }
}
