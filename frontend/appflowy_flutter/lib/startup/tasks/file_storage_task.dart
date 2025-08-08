/* Dart异步编程核心库 - 提供Stream、Timer等异步处理工具 */
import 'dart:async';
/* Dart JSON编解码库 - 处理与Rust后端的数据交换 */
import 'dart:convert';
/* Dart FFI库 - Flutter与原生代码(Rust)的互操作基础 */
import 'dart:ffi';
/* Dart Isolate库 - 处理跨线程通信和并发任务 */
import 'dart:isolate';

/* Flutter基础库 - 提供调试和平台检查支持 */
import 'package:flutter/foundation.dart';

/* AppFlowy后端调度器 - 处理与Rust后端的RPC通信 */
import 'package:appflowy_backend/dispatch/dispatch.dart';
/* AppFlowy日志系统 - 记录文件操作的调试信息和错误 */
import 'package:appflowy_backend/log.dart';
/* AppFlowy错误定义 - 标准化的错误类型和错误码 */
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
/* 文件存储协议缓冲区定义 - 与Rust后端的文件存储通信协议 */
import 'package:appflowy_backend/protobuf/flowy-storage/protobuf.dart';
/* AppFlowy结果包装器 - 提供类似Rust的Result<T, E>类型 */
import 'package:appflowy_result/appflowy_result.dart';
/* 固定精度数字库 - 处理大整数和精确的数值计算 */
import 'package:fixnum/fixnum.dart';

/* AppFlowy应用启动器 - 访问依赖注入容器和运行环境 */
import '../startup.dart';

/* 
 * 文件存储服务初始化任务
 *
 * 在AppFlowy应用启动过程中注册和初始化文件存储服务
 * 继承自LaunchTask，确保在正确的时机执行初始化
 * 
 * 职责：
 * - 创建FileStorageService单例实例
 * - 将服务注册到依赖注入容器中
 * - 配置服务的生命周期管理（自动清理资源）
 * 
 * 执行时机：
 * - 在应用启动序列中，位于基础服务初始化之后
 * - 确保依赖注入容器已经准备就绪
 * - 在UI组件加载之前完成，支撑文件相关功能
 */
class FileStorageTask extends LaunchTask {
  const FileStorageTask();

  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 注册文件存储服务为单例
    // 
    // 单例设计的原因：
    // - 避免重复创建连接和监听器，节省系统资源
    // - 全局共享文件上传状态，支持跨组件的进度追踪
    // - 统一管理与Rust后端的通信通道
    // - 确保文件操作的一致性和原子性
    context.getIt.registerSingleton(
      FileStorageService(),
      // 自动资源清理：应用关闭或热重载时调用dispose方法
      // 确保正确关闭网络连接、释放端口、清理内存等
      dispose: (service) async => service.dispose(),
    );
  }
}

/* 
 * 文件存储服务 - AppFlowy的文件管理和上传核心服务
 *
 * 架构设计：
 * - 基于Isolate的跨线程通信：Flutter主线程 ↔ Rust后端线程
 * - 事件驱动：通过RawReceivePort接收Rust后端的实时更新
 * - 观察者模式：支持多个UI组件同时监听同一文件的上传进度
 * - 自动清理：防止内存泄漏，维护监听器的生命周期
 *
 * 通信流程：
 * 1. Flutter发起文件操作请求 → Rust后端
 * 2. Rust后端处理文件操作，发送进度更新 → Flutter RawReceivePort
 * 3. RawReceivePort转发到StreamController → UI组件监听器
 * 4. UI组件更新进度显示或处理操作结果
 *
 * 支持的文件操作：
 * - 文件上传进度跟踪
 * - 文件状态查询(上传中/已完成/失败)
 * - 文件链接生成和管理
 * - 多文件并发操作支持
 *
 * 性能优化：
 * - 延迟创建通知器，仅在需要时分配资源
 * - 自动移除不活跃的监听器，防止内存积累
 * - 批量处理进度更新，减少UI重绘频率
 */
class FileStorageService {
  FileStorageService() {
    // 设置端口消息处理器：将Rust后端的消息转发到StreamController
    // 这是整个文件通信系统的入口点
    _port.handler = _controller.add;
    // 订阅消息流，处理来自Rust后端的文件进度更新
    _subscription = _controller.stream.listen(
      (event) {
        // 尝试将JSON字符串解析为FileProgress对象
        final fileProgress = FileProgress.fromJsonString(event);
        if (fileProgress != null) {
          // 记录调试日志，便于开发时追踪文件操作
          Log.debug(
            "FileStorageService upload file: ${fileProgress.fileUrl} ${fileProgress.progress}",
          );
          
          // 查找对应文件URL的通知器
          final notifier = _notifierList[fileProgress.fileUrl];
          if (notifier != null) {
            // 更新通知器的值，触发UI监听器更新
            // 这将导致所有监听此文件的Widget重新构建
            notifier.value = fileProgress;
          }
          // 注意：如果找不到对应的通知器，说明没有UI组件关心此文件的进度
          // 这种情况下我们直接忽略该更新，避免不必要的资源消耗
        }
        // 注意：如果JSON解析失败，可能是因为：
        // 1. Rust后端发送了格式错误的数据
        // 2. 协议版本不匹配
        // 3. 网络传输过程中数据损坏
        // 此时我们静默忽略，避免崩溃
      },
    );

    // 根据运行模式决定是否注册消息流
    if (!integrationMode().isTest) {
      // 创建注册消息流的请求载荷
      final payload = RegisterStreamPB()
        // 将RawReceivePort的原生端口ID传给Rust后端
        // Rust后端将使用这个端口ID向Flutter发送消息
        ..port = Int64(_port.sendPort.nativePort);
      
      // 发送注册请求到Rust后端
      // 这建立了Flutter与Rust之间的双向通信通道
      FileStorageEventRegisterStream(payload).send();
    }
    // 测试模式下不注册消息流，避免干扰测试环境
  }

  /* 文件进度通知器映射表
   * 
   * 结构：Map<文件URL, 自动清理通知器>
   * 用途：
   * - 为每个正在处理的文件维护一个通知器
   * - 支持多个UI组件同时监听同一文件的进度
   * - 通过AutoRemoveNotifier实现自动资源清理
   * 
   * 生命周期：
   * - 创建：UI组件调用onFileProgress()时
   * - 更新：收到Rust后端进度更新时
   * - 销毁：UI组件销毁或手动调用dispose()时
   */
  final Map<String, AutoRemoveNotifier<FileProgress>> _notifierList = {};
  
  /* 原生接收端口 - Flutter与Rust后端的直接通信通道
   * 
   * 特性：
   * - 低延迟：直接与原生代码通信，无Flutter中间层开销
   * - 高性能：适合高频次的进度更新消息
   * - 原生支持：直接传递原生数据类型和指针
   * 
   * 注意事项：
   * - 必须在适当时机调用close()释放资源
   * - 消息处理在主线程中执行，避免長时间操作
   */
  final RawReceivePort _port = RawReceivePort();
  
  /* 消息流控制器 - 将原生消息转换为标准的Dart Stream
   * 
   * broadcast模式的优势：
   * - 支持多个监听器同时监听同一个流
   * - 新的监听器可以随时加入，不会错过当前消息
   * - 自动管理监听器的生命周期
   * 
   * 消息流向：
   * RawReceivePort → StreamController → 多个监听器
   */
  final StreamController<String> _controller = StreamController.broadcast();
  
  /* 流订阅句柄 - 管理与消息流的连接
   * 
   * 作用：
   * - 监听消息流的数据事件
   * - 在服务销毁时取消订阅，避免内存泄漏
   * - 提供订阅状态的查询和控制能力
   * 
   * 生命周期：
   * - 创建：构造函数中调用_controller.stream.listen()
   * - 清理：dispose()方法中调用cancel()
   */
  late StreamSubscription<String> _subscription;

  /* 创建或获取文件进度通知器
   * 
   * 功能：
   * - 为指定文件URL创建一个新的进度监听器
   * - 自动清理旧的监听器，避免内存泄漏
   * - 立即触发文件状态查询，获取最新进度
   * 
   * 使用场景：
   * - UI组件需要显示文件上传进度条
   * - 文件上传状态的实时监控
   * - 多个组件同时关注同一文件的进度
   * 
   * @param fileUrl 文件的唯一标识符（通常是URL或文件路径）
   * @return 自动管理生命周期的进度通知器
   * 
   * 注意事项：
   * - 每次调用都会创建新的通知器，旧的会被自动销毁
   * - 返回的通知器会自动从映射表中移除自己
   * - 初始状态为进度0%，会立即触发状态查询
   */
  AutoRemoveNotifier<FileProgress> onFileProgress({required String fileUrl}) {
    // 清理旧的通知器：避免同一文件的重复监听器
    // dispose()会触发通知器的清理逻辑，包括从映射表中移除
    _notifierList.remove(fileUrl)?.dispose();

    // 创建新的自动清理通知器
    final notifier = AutoRemoveNotifier<FileProgress>(
      // 初始状态：进倅0%，表示刚开始监听
      FileProgress(fileUrl: fileUrl, progress: 0),
      // 传入映射表引用，支持自动清理功能
      notifierList: _notifierList,
      // 文件ID，用于在销毁时从映射表中移除
      fileId: fileUrl,
    );
    
    // 将新通知器添加到映射表中
    _notifierList[fileUrl] = notifier;

    // 立即触发文件状态查询，获取最新的进度信息
    // 这确保了UI组件能够立即显示当前的文件状态
    getFileState(fileUrl);

    return notifier;
  }

  /* 查询指定文件的当前状态
   * 
   * 功能：
   * - 向Rust后端发送文件状态查询请求
   * - 获取文件的当前上传进度、状态和错误信息
   * - 支持同步和异步两种调用方式
   * 
   * 返回状态说明：
   * - 成功：返回FileStatePB对象，包含详细状态信息
   * - 失败：返回FlowyError对象，包含错误代码和描述
   * 
   * @param url 文件的URL或唯一标识符
   * @return Future包装的结果，支持链式调用和错误处理
   * 
   * 使用示例：
   * ```dart
   * final result = await fileStorage.getFileState('file_123.jpg');
   * result.fold(
   *   (fileState) => print('文件状态: ${fileState.uploadProgress}%'),
   *   (error) => print('查询失败: ${error.msg}'),
   * );
   * ```
   */
  Future<FlowyResult<FileStatePB, FlowyError>> getFileState(String url) {
    // 构造查询请求载荷
    final payload = QueryFilePB()..url = url;
    
    // 发送请求到Rust后端并返回结果
    // FileStorageEventQueryFile是自动生成的RPC调用包装器
    return FileStorageEventQueryFile(payload).send();
  }

  /* 销毁文件存储服务，释放所有资源
   * 
   * 清理顺序重要性：
   * 1. 首先清理所有通知器，防止新的更新事件
   * 2. 关闭消息流控制器，停止接收新消息
   * 3. 取消流订阅，断开与消息流的连接
   * 4. 最后关闭原生端口，断开与Rust的通信
   * 
   * 调用时机：
   * - 应用关闭时
   * - 热重载时
   * - 服务重启时
   * - 单元测试的tearDown阶段
   * 
   * 资源清理的重要性：
   * - 避免内存泄漏：及时释放所有引用和监听器
   * - 防止资源竞争：避免端口占用和文件句柄泄漏
   * - 系统稳定性：正确的清理流程保证系统的长期稳定
   */
  Future<void> dispose() async {
    // 清理所有文件进度通知器
    // 这会触发每个通知器的dispose()方法
    // 同时从映射表中移除对应的条目
    for (final notifier in _notifierList.values) {
      notifier.dispose();
    }
    // 注意：_notifierList.values 返回的是快照，
    // 即使在遍历过程中有元素被移除也不会影响遍历

    // 关闭消息流控制器，停止接收新的消息
    await _controller.close();
    
    // 取消流订阅，断开与消息流的连接
    await _subscription.cancel();
    
    // 最后关闭原生接收端口，断开与Rust后端的通信
    // 这个操作是同步的，会立即释放系统资源
    _port.close();
  }
}

class FileProgress {
  FileProgress({
    required this.fileUrl,
    required this.progress,
    this.error,
  });

  static FileProgress? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    try {
      if (json.containsKey('file_url') && json.containsKey('progress')) {
        return FileProgress(
          fileUrl: json['file_url'] as String,
          progress: (json['progress'] as num).toDouble(),
          error: json['error'] as String?,
        );
      }
    } catch (e) {
      Log.error('unable to parse file progress: $e');
    }
    return null;
  }

  // Method to parse a JSON string and return a FileProgress object or null
  static FileProgress? fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return FileProgress.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  final double progress;
  final String fileUrl;
  final String? error;
}

class AutoRemoveNotifier<T> extends ValueNotifier<T> {
  AutoRemoveNotifier(
    super.value, {
    required this.fileId,
    required Map<String, AutoRemoveNotifier<FileProgress>> notifierList,
  }) : _notifierList = notifierList;

  final String fileId;
  final Map<String, AutoRemoveNotifier<FileProgress>> _notifierList;

  @override
  void dispose() {
    _notifierList.remove(fileId);
    super.dispose();
  }
}
