/* Flutter SharedPreferences库 - 用于跨平台的持久化键值存储
 * 
 * SharedPreferences实现原理：
 * - Android: 基于SharedPreferences API，数据存储在XML文件中
 * - iOS: 基于NSUserDefaults，数据存储在plist文件中  
 * - Web: 基于localStorage，数据存储在浏览器缓存中
 * - Windows/Linux/macOS: 基于系统特定的配置存储机制
 */
import 'package:shared_preferences/shared_preferences.dart';

/* 
 * 键值存储抽象接口
 *
 * 作用：为AppFlowy提供统一的键值存储抽象层
 * 设计思想：
 * - 抽象化存储实现：屏蔽底层存储细节，便于测试和替换实现
 * - 异步操作：所有操作都是异步的，避免阻塞UI线程
 * - 类型安全：通过泛型支持不同数据类型的序列化/反序列化
 * 
 * 存储策略：
 * - 所有数据以字符串形式存储，复杂对象需要序列化（通常为JSON）
 * - 支持格式化读取，允许自定义反序列化逻辑
 */
abstract class KeyValueStorage {
  /* 存储键值对
   * @param key 存储键，通常使用KVKeys中定义的常量
   * @param value 存储值，必须是字符串格式
   */
  Future<void> set(String key, String value);
  
  /* 根据键获取值
   * @param key 存储键
   * @return 如果键存在返回对应的值，否则返回null
   */
  Future<String?> get(String key);
  
  /* 格式化读取 - 支持自定义反序列化
   * @param key 存储键
   * @param formatter 格式化函数，将字符串转换为目标类型T
   * @return 格式化后的数据，如果键不存在或格式化失败返回null
   * 
   * 使用场景：
   * - JSON对象的反序列化
   * - 数字类型的转换
   * - 枚举类型的转换
   */
  Future<T?> getWithFormat<T>(
    String key,
    T Function(String value) formatter,
  );
  
  /* 删除指定键的数据 */
  Future<void> remove(String key);
  
  /* 清空所有存储的数据 - 慎用！通常只在用户登出或重置应用时使用 */
  Future<void> clear();
}

/* 
 * 基于SharedPreferences的键值存储实现类
 *
 * 核心特性：
 * - 延迟初始化：SharedPreferences实例只在第一次使用时创建
 * - 单例模式：确保整个应用只有一个SharedPreferences实例
 * - 线程安全：SharedPreferences本身是线程安全的
 * - 持久化存储：数据在应用重启后依然存在
 *
 * 性能优化策略：
 * - 缓存实例：避免重复的getInstance()调用
 * - 异步操作：所有I/O操作都是异步的，不会阻塞UI
 * - 内存缓存：SharedPreferences内部维护内存缓存，提高读取性能
 */
class DartKeyValue implements KeyValueStorage {
  /* SharedPreferences实例 - 使用延迟初始化模式
   * null表示尚未初始化，非null表示已经初始化完成
   */
  SharedPreferences? _sharedPreferences;
  
  /* 获取SharedPreferences实例
   * 使用断言（!）假设已经初始化，如果未初始化会抛出异常
   * 这是一种防御性编程，确保在使用前已经正确初始化
   */
  SharedPreferences get sharedPreferences => _sharedPreferences!;

  @override
  Future<String?> get(String key) async {
    // 确保SharedPreferences已初始化
    await _initSharedPreferencesIfNeeded();

    // SharedPreferences.getString()方法：
    // - 如果key存在，返回对应的字符串值
    // - 如果key不存在，返回null
    // - 内部有缓存机制，读取性能很高
    final value = sharedPreferences.getString(key);
    if (value != null) {
      return value;
    }
    return null; // 显式返回null，增强代码可读性
  }

  @override
  Future<T?> getWithFormat<T>(
    String key,
    T Function(String value) formatter,
  ) async {
    // 先获取原始字符串值
    final value = await get(key);
    if (value == null) {
      return null; // 键不存在时直接返回null
    }
    
    // 应用格式化函数进行类型转换
    // 注意：这里没有try-catch，格式化异常会向上抛出
    // 这是设计决策：让调用方处理格式化错误
    return formatter(value);
  }

  @override
  Future<void> remove(String key) async {
    await _initSharedPreferencesIfNeeded();

    // SharedPreferences.remove()是异步操作
    // 会同时更新内存缓存和磁盘存储
    await sharedPreferences.remove(key);
  }

  @override
  Future<void> set(String key, String value) async {
    await _initSharedPreferencesIfNeeded();

    // SharedPreferences.setString()的执行过程：
    // 1. 立即更新内存缓存（同步）
    // 2. 异步写入磁盘存储（后台线程）
    // 3. 返回Future，表示写入操作的完成状态
    await sharedPreferences.setString(key, value);
  }

  @override
  Future<void> clear() async {
    await _initSharedPreferencesIfNeeded();

    // 清空所有数据 - 这是一个危险操作！
    // 会删除应用的所有SharedPreferences数据
    // 通常只在以下场景使用：
    // - 用户手动重置应用
    // - 用户登出（清除所有本地状态）
    // - 应用升级时需要清理旧数据
    await sharedPreferences.clear();
  }

  /* 延迟初始化SharedPreferences实例
   *
   * 使用空值合并赋值运算符（??=）确保只初始化一次：
   * - 如果_sharedPreferences为null，则调用getInstance()初始化
   * - 如果_sharedPreferences已有值，则不执行任何操作
   *
   * SharedPreferences.getInstance()的工作原理：
   * - 首次调用时从磁盘读取所有数据到内存
   * - 返回单例实例，后续调用直接返回已缓存的实例
   * - 这是一个相对昂贵的操作，所以我们缓存结果
   */
  Future<void> _initSharedPreferencesIfNeeded() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
  }
}
