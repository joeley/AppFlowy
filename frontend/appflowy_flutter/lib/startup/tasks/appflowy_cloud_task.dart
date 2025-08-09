import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/app_widget.dart';
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/startup/tasks/deeplink/expire_login_deeplink_handler.dart';
import 'package:appflowy/startup/tasks/deeplink/invitation_deeplink_handler.dart';
import 'package:appflowy/startup/tasks/deeplink/login_deeplink_handler.dart';
import 'package:appflowy/startup/tasks/deeplink/open_app_deeplink_handler.dart';
import 'package:appflowy/startup/tasks/deeplink/payment_deeplink_handler.dart';
import 'package:appflowy/user/application/auth/auth_error.dart';
import 'package:appflowy/user/application/user_auth_listener.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter/material.dart';
import 'package:url_protocol/url_protocol.dart';

/// AppFlowy深链接协议名称
/// 用于处理 appflowy-flutter:// 形式的URL
const appflowyDeepLinkSchema = 'appflowy-flutter';

/// AppFlowy云服务深链接处理器
/// 
/// 功能说明：
/// 1. 处理各种深链接场景（登录、支付、邀请等）
/// 2. 注册和管理深链接处理器
/// 3. 监听系统深链接事件
/// 4. Windows平台注册协议处理
/// 
/// 支持的深链接类型：
/// - 登录回调（OAuth认证）
/// - 支付完成回调
/// - 工作区邀请链接
/// - 登录过期处理
/// - 应用启动链接
class AppFlowyCloudDeepLink {
  /// 构造函数
  /// 
  /// 初始化流程：
  /// 1. 注册所有深链接处理器
  /// 2. 开始监听深链接事件
  /// 3. Windows平台注册URL协议
  AppFlowyCloudDeepLink() {
    // 注册所有深链接处理器到注册表
    _deepLinkHandlerRegistry = DeepLinkHandlerRegistry.instance
      ..register(LoginDeepLinkHandler())      // 登录深链接
      ..register(PaymentDeepLinkHandler())    // 支付深链接
      ..register(InvitationDeepLinkHandler()) // 邀请深链接
      ..register(ExpireLoginDeepLinkHandler())// 登录过期深链接
      ..register(OpenAppDeepLinkHandler());   // 打开应用深链接

    // 监听深链接事件流
    _deepLinkSubscription = _AppLinkWrapper.instance.listen(
      (Uri? uri) async {
        Log.info('onDeepLink: ${uri.toString()}');
        await _handleUri(uri);
      },
      onError: (Object err, StackTrace stackTrace) {
        Log.error('on DeepLink stream error: ${err.toString()}', stackTrace);
        _deepLinkSubscription.cancel();
      },
    );
    
    // Windows平台需要注册URL协议处理器
    // 让系统知道appflowy-flutter://协议由本应用处理
    if (Platform.isWindows) {
      registerProtocolHandler(appflowyDeepLinkSchema);
    }
  }

  /// 深链接状态通知器
  /// 用于通知UI层深链接处理状态的变化
  ValueNotifier<DeepLinkResult?>? _stateNotifier = ValueNotifier(null);

  /// 异步操作完成器
  /// 用于等待深链接处理完成（如登录流程）
  Completer<FlowyResult<UserProfilePB, FlowyError>>? _completer;

  /// 设置完成器
  /// 当需要等待深链接结果时设置
  set completer(Completer<FlowyResult<UserProfilePB, FlowyError>>? value) {
    Log.debug('AppFlowyCloudDeepLink: $hashCode completer');
    _completer = value;
  }

  /// 深链接事件订阅
  late final StreamSubscription<Uri?> _deepLinkSubscription;
  
  /// 深链接处理器注册表
  late final DeepLinkHandlerRegistry _deepLinkHandlerRegistry;

  /// 释放资源
  /// 
  /// 清理流程：
  /// 1. 取消深链接监听
  /// 2. 释放状态通知器
  /// 3. 清空完成器引用
  Future<void> dispose() async {
    Log.debug('AppFlowyCloudDeepLink: $hashCode dispose');
    await _deepLinkSubscription.cancel();

    _stateNotifier?.dispose();
    _stateNotifier = null;
    completer = null;
  }

  /// 注册完成器
  /// 
  /// 用于异步等待深链接处理结果
  /// 主要用于OAuth登录流程
  void registerCompleter(
    Completer<FlowyResult<UserProfilePB, FlowyError>> completer,
  ) {
    this.completer = completer;
  }

  /// 订阅深链接加载状态
  /// 
  /// 参数：
  /// - listener: 状态变化回调函数
  /// 
  /// 返回：
  /// - 取消订阅的函数引用
  VoidCallback subscribeDeepLinkLoadingState(
    ValueChanged<DeepLinkResult> listener,
  ) {
    void listenerFn() {
      if (_stateNotifier?.value != null) {
        listener(_stateNotifier!.value!);
      }
    }

    _stateNotifier?.addListener(listenerFn);
    return listenerFn;
  }

  /// 取消订阅深链接加载状态
  void unsubscribeDeepLinkLoadingState(VoidCallback listener) =>
      _stateNotifier?.removeListener(listener);

  /// 传递Gotrue令牌响应
  /// 
  /// 用于处理OAuth认证后的令牌响应
  /// 将令牌构建为深链接URI并处理
  Future<void> passGotrueTokenResponse(
    GotrueTokenResponsePB gotrueTokenResponse,
  ) async {
    final uri = _buildDeepLinkUri(gotrueTokenResponse);
    await _handleUri(uri);
  }

  /// 处理深链接URI
  /// 
  /// 核心处理逻辑：
  /// 1. 重置状态
  /// 2. 验证URI有效性
  /// 3. 分发给对应的处理器
  /// 4. 处理结果回调
  Future<void> _handleUri(
    Uri? uri,
  ) async {
    // 重置状态为初始状态
    _stateNotifier?.value = DeepLinkResult(state: DeepLinkState.none);

    // 验证URI非空
    if (uri == null) {
      Log.error('onDeepLinkError: Unexpected empty deep link callback');
      _completer?.complete(FlowyResult.failure(AuthError.emptyDeepLink));
      completer = null;
      return;
    }

    // 使用注册表处理深链接
    await _deepLinkHandlerRegistry.processDeepLink(
      uri: uri,
      onStateChange: (handler, state) {
        // 仅处理登录深链接的状态变化
        // 其他类型的深链接不需要状态通知
        if (handler is LoginDeepLinkHandler) {
          _stateNotifier?.value = DeepLinkResult(state: state);
        }
      },
      onResult: (handler, result) async {
        // 处理登录深链接结果
        if (handler is LoginDeepLinkHandler &&
            result is FlowyResult<UserProfilePB, FlowyError>) {
          // 如果没有完成器，说明是直接从深链接启动
          // 需要调用runAppFlowy()来启动应用
          if (_completer == null) {
            await result.fold(
              (_) async {
                await runAppFlowy();
              },
              (err) {
                Log.error(err);
                final context = AppGlobals.rootNavKey.currentState?.context;
                if (context != null) {
                  showToastNotification(
                    message: err.msg,
                  );
                }
              },
            );
          } else {
            // 有完成器说明是应用内发起的OAuth流程
            // 完成异步等待
            _completer?.complete(result);
            completer = null;
          }
        } 
        // 处理登录过期深链接
        else if (handler is ExpireLoginDeepLinkHandler) {
          result.onFailure(
            (error) {
              final context = AppGlobals.rootNavKey.currentState?.context;
              if (context != null) {
                showToastNotification(
                  message: error.msg,
                  type: ToastificationType.error,
                );
              }
            },
          );
        }
      },
      onError: (error) {
        Log.error('onDeepLinkError: Unexpected deep link: $error');
        // 根据是否有完成器决定错误处理方式
        if (_completer == null) {
          // 直接显示错误提示
          final context = AppGlobals.rootNavKey.currentState?.context;
          if (context != null) {
            showToastNotification(
              message: error.msg,
              type: ToastificationType.error,
            );
          }
        } else {
          // 通过完成器返回错误
          _completer?.complete(FlowyResult.failure(error));
          completer = null;
        }
      },
    );
  }

  /// 构建深链接URI
  /// 
  /// 将Gotrue令牌响应转换为深链接URI格式
  /// 
  /// 参数包括：
  /// - access_token: 访问令牌
  /// - expires_at: 过期时间戳
  /// - expires_in: 有效期（秒）
  /// - provider_refresh_token: 提供商刷新令牌
  /// - provider_token: 提供商访问令牌
  /// - refresh_token: 刷新令牌
  /// - token_type: 令牌类型（通常是Bearer）
  /// 
  /// 返回：
  /// - 构建好的URI，格式：appflowy-flutter://login-callback#参数
  /// - 如果没有参数则返回null
  Uri? _buildDeepLinkUri(GotrueTokenResponsePB gotrueTokenResponse) {
    final params = <String, String>{};

    // 收集所有令牌相关参数
    if (gotrueTokenResponse.hasAccessToken() &&
        gotrueTokenResponse.accessToken.isNotEmpty) {
      params['access_token'] = gotrueTokenResponse.accessToken;
    }

    if (gotrueTokenResponse.hasExpiresAt()) {
      params['expires_at'] = gotrueTokenResponse.expiresAt.toString();
    }

    if (gotrueTokenResponse.hasExpiresIn()) {
      params['expires_in'] = gotrueTokenResponse.expiresIn.toString();
    }

    if (gotrueTokenResponse.hasProviderRefreshToken() &&
        gotrueTokenResponse.providerRefreshToken.isNotEmpty) {
      params['provider_refresh_token'] =
          gotrueTokenResponse.providerRefreshToken;
    }

    if (gotrueTokenResponse.hasProviderAccessToken() &&
        gotrueTokenResponse.providerAccessToken.isNotEmpty) {
      params['provider_token'] = gotrueTokenResponse.providerAccessToken;
    }

    if (gotrueTokenResponse.hasRefreshToken() &&
        gotrueTokenResponse.refreshToken.isNotEmpty) {
      params['refresh_token'] = gotrueTokenResponse.refreshToken;
    }

    if (gotrueTokenResponse.hasTokenType() &&
        gotrueTokenResponse.tokenType.isNotEmpty) {
      params['token_type'] = gotrueTokenResponse.tokenType;
    }

    // 没有参数则返回null
    if (params.isEmpty) {
      return null;
    }

    // 构建URI片段，使用URL编码确保安全
    final fragment = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    // 返回完整的深链接URI
    return Uri.parse('appflowy-flutter://login-callback#$fragment');
  }
}

/// AppFlowy云服务初始化任务
/// 
/// 功能说明：
/// 1. 初始化云服务认证监听器
/// 2. 监听用户登录/登出状态
/// 3. 处理认证失效情况
/// 
/// 认证管理：
/// - 自动检测认证状态变化
/// - 处理认证过期或无效
/// - 管理登出流程状态
class InitAppFlowyCloudTask extends LaunchTask {
  /// 用户认证状态监听器
  UserAuthStateListener? _authStateListener;
  
  /// 登出状态标志
  /// 防止在登出过程中重复调用runAppFlowy
  bool isLoggingOut = false;

  /// 初始化云服务任务
  /// 
  /// 执行流程：
  /// 1. 检查云服务是否启用
  /// 2. 创建认证状态监听器
  /// 3. 开始监听认证状态变化
  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);

    // 仅在云服务启用时初始化
    if (!isAppFlowyCloudEnabled) {
      return;
    }
    
    // 创建认证状态监听器
    _authStateListener = UserAuthStateListener();

    // 开始监听认证状态
    _authStateListener?.start(
      didSignIn: () {
        // 登录成功，重置登出状态
        isLoggingOut = false;
      },
      onInvalidAuth: (message) async {
        Log.error(message);
        // 认证无效且不在登出过程中时重启应用
        if (!isLoggingOut) {
          await runAppFlowy();
        }
      },
    );
  }

  /// 释放资源
  @override
  Future<void> dispose() async {
    await super.dispose();

    await _authStateListener?.stop();
    _authStateListener = null;
  }
}

/// AppLinks包装器
/// 
/// 功能说明：
/// 为AppLinks提供多监听器支持的包装器
/// AppLinks原生只支持单个监听器，这个包装器通过广播流支持多个监听器
/// 
/// 设计模式：
/// - 单例模式：全局唯一实例
/// - 适配器模式：将单监听器转换为多监听器
/// - 广播模式：支持多个订阅者
class _AppLinkWrapper {
  /// 私有构造函数（单例模式）
  /// 
  /// 初始化时立即开始监听原始URI流
  /// 并转发到广播流控制器
  _AppLinkWrapper._() {
    _appLinkSubscription = _appLinks.uriLinkStream.listen((event) {
      _streamSubscription.sink.add(event);
    });
  }

  /// 单例实例
  static final _AppLinkWrapper instance = _AppLinkWrapper._();

  /// AppLinks原始实例
  final AppLinks _appLinks = AppLinks();
  
  /// 广播流控制器，支持多个监听器
  final _streamSubscription = StreamController<Uri?>.broadcast();
  
  /// 原始流订阅
  late final StreamSubscription<Uri?> _appLinkSubscription;

  /// 添加监听器
  /// 
  /// 参数：
  /// - listener: URI事件处理函数
  /// - onError: 错误处理函数
  /// - cancelOnError: 是否在错误时取消订阅
  /// 
  /// 返回：流订阅对象，用于后续取消订阅
  StreamSubscription<Uri?> listen(
    void Function(Uri?) listener, {
    Function? onError,
    bool? cancelOnError,
  }) {
    return _streamSubscription.stream.listen(
      listener,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  /// 释放资源
  void dispose() {
    _streamSubscription.close();
    _appLinkSubscription.cancel();
  }
}
