import 'dart:io';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/shared/patterns/common_patterns.dart';
import 'package:appflowy/workspace/presentation/home/toast.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:string_validator/string_validator.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// 失败回调类型
typedef OnFailureCallback = void Function(Uri uri);

/// 启动URI
/// 
/// 智能处理不同类型的URI：
/// - 本地文件路径：使用OpenFilex打开
/// - 网络链接：使用url_launcher打开
/// 
/// 参数：
/// - [uri]: 要打开的URI
/// - [context]: 上下文，用于显示Toast
/// - [onFailure]: 失败回调
/// - [mode]: 启动模式
/// - [webOnlyWindowName]: Web平台窗口名称
/// - [addingHttpSchemeWhenFailed]: 失败时是否添加http协议
/// 
/// 设计思想：
/// - 区分本地文件和网络链接
/// - 自动添加缺失的HTTP协议
/// - 处理各平台的差异
Future<bool> afLaunchUri(
  Uri uri, {
  BuildContext? context,
  OnFailureCallback? onFailure,
  launcher.LaunchMode mode = launcher.LaunchMode.platformDefault,
  String? webOnlyWindowName,
  bool addingHttpSchemeWhenFailed = false,
}) async {
  final url = uri.toString();
  final decodedUrl = Uri.decodeComponent(url);

  // 检查是否为本地文件路径
  if (localPathRegex.hasMatch(decodedUrl)) {
    return _afLaunchLocalUri(
      uri,
      context: context,
      onFailure: onFailure,
    );
  }

  // 在Linux、Android或Windows上，如果URL没有协议，添加https协议
  if ((UniversalPlatform.isLinux ||
          UniversalPlatform.isAndroid ||
          UniversalPlatform.isWindows) &&
      !isURL(url, {'require_protocol': true})) {
    uri = Uri.parse('https://$url');
  }

  /// 在macOS上打开错误链接会弹出系统错误对话框
  /// 只在macOS上使用[canLaunchUrl]检查
  /// Linux上存在已知问题，url_launcher可能启动失败
  /// 参考：https://github.com/flutter/flutter/issues/88463
  bool result = true;
  if (UniversalPlatform.isMacOS) {
    result = await launcher.canLaunchUrl(uri);
  }

  if (result) {
    try {
      // 尝试直接启动URI
      result = await launcher.launchUrl(
        uri,
        mode: mode,
        webOnlyWindowName: webOnlyWindowName,
      );
    } on PlatformException catch (e) {
      Log.error('Failed to open uri: $e');
      return false;
    }
  }

  // 如果URI不是有效的URL，尝试添加http协议后启动
  if (addingHttpSchemeWhenFailed &&
      !result &&
      !isURL(url, {'require_protocol': true})) {
    try {
      final uriWithScheme = Uri.parse('http://$url');
      result = await launcher.launchUrl(
        uriWithScheme,
        mode: mode,
        webOnlyWindowName: webOnlyWindowName,
      );
    } on PlatformException catch (e) {
      Log.error('Failed to open uri: $e');
      if (context != null && context.mounted) {
        _errorHandler(uri, context: context, onFailure: onFailure, e: e);
      }
    }
  }

  return result;
}

/// 启动URL字符串
/// 
/// 将字符串转换为URI后启动
/// 
/// 参见[afLaunchUri]获取更多细节
Future<bool> afLaunchUrlString(
  String url, {
  bool addingHttpSchemeWhenFailed = false,
  BuildContext? context,
  OnFailureCallback? onFailure,
}) async {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException catch (e) {
    Log.error('Failed to parse url: $e');
    return false;
  }

  // 调用afLaunchUri处理URI
  return afLaunchUri(
    uri,
    addingHttpSchemeWhenFailed: addingHttpSchemeWhenFailed,
    context: context,
    onFailure: onFailure,
  );
}

/// 启动本地URI
/// 
/// 使用OpenFilex打开本地文件或文件夹
/// 
/// 功能：
/// 1. 尝试打开文件
/// 2. 如果文件无法打开，回退到打开所在文件夹
/// 3. 显示操作结果Toast
/// 
/// 参见[afLaunchUri]获取更多细节
Future<bool> _afLaunchLocalUri(
  Uri uri, {
  BuildContext? context,
  OnFailureCallback? onFailure,
}) async {
  final decodedUrl = Uri.decodeComponent(uri.toString());
  // 使用OpenFileX打开文件
  var result = await OpenFilex.open(decodedUrl);
  if (result.type != ResultType.done) {
    // 文件无法打开，回退到打开父文件夹
    final parentFolder = Directory(decodedUrl).parent.path;
    result = await OpenFilex.open(parentFolder);
  }
  // 根据结果显示Toast消息
  final message = switch (result.type) {
    ResultType.done => LocaleKeys.openFileMessage_success.tr(),
    ResultType.fileNotFound => LocaleKeys.openFileMessage_fileNotFound.tr(),
    ResultType.noAppToOpen => LocaleKeys.openFileMessage_noAppToOpenFile.tr(),
    ResultType.permissionDenied =>
      LocaleKeys.openFileMessage_permissionDenied.tr(),
    ResultType.error => LocaleKeys.failedToOpenUrl.tr(),
  };
  if (context != null && context.mounted) {
    showToastNotification(
      message: message,
      type: result.type == ResultType.done
          ? ToastificationType.success
          : ToastificationType.error,
    );
  }
  final openFileSuccess = result.type == ResultType.done;
  if (!openFileSuccess && onFailure != null) {
    onFailure(uri);
    Log.error('Failed to open file: $result.message');
  }
  return openFileSuccess;
}

/// 错误处理器
/// 
/// 处理URI启动失败的情况
/// 
/// 参数：
/// - [uri]: 失败的URI
/// - [context]: 上下文
/// - [onFailure]: 失败回调
/// - [e]: 平台异常
void _errorHandler(
  Uri uri, {
  BuildContext? context,
  OnFailureCallback? onFailure,
  PlatformException? e,
}) {
  Log.error('Failed to open uri: $e');

  if (onFailure != null) {
    // 调用自定义失败处理
    onFailure(uri);
  } else {
    // 显示默认错误消息
    showMessageToast(
      LocaleKeys.failedToOpenUrl.tr(args: [e?.message ?? "PlatformException"]),
      context: context,
    );
  }
}
