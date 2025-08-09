import 'dart:io';

import 'package:appflowy_backend/log.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

import '../startup.dart';

/// 应用程序信息管理类
/// 
/// 功能说明：
/// 1. 收集设备信息（设备ID、架构、操作系统）
/// 2. 管理应用版本信息
/// 3. 检查更新状态
/// 4. 处理关键更新通知
/// 
/// 使用场景：
/// - 应用启动时收集设备信息
/// - 发送崩溃报告时附带设备信息
/// - 检查应用更新
/// - 统计分析用户设备分布
class ApplicationInfo {
  /// Android SDK版本号
  /// -1表示非Android平台或获取失败
  static int androidSDKVersion = -1;
  
  /// 应用程序版本号（如：1.0.0）
  static String applicationVersion = '';
  
  /// 构建号（如：100）
  /// 每次发布递增，用于区分同版本的不同构建
  static String buildNumber = '';
  
  /// 设备唯一标识符
  /// 不同平台有不同的ID生成方式
  static String deviceId = '';
  
  /// CPU架构（如：x86_64、arm64）
  static String architecture = '';
  
  /// 操作系统类型（android/ios/macos/windows/linux）
  static String os = '';

  /// macOS主版本号（如：14 for Sonoma）
  static int? macOSMajorVersion;
  /// macOS次版本号
  static int? macOSMinorVersion;

  /// 最新版本通知器
  /// 用于UI层监听版本更新
  static ValueNotifier<String> latestVersionNotifier = ValueNotifier('');
  /// 获取最新版本号（如：0.9.0）
  static String get latestVersion => latestVersionNotifier.value;

  /// 检查是否有可用更新
  /// 
  /// 比较最新版本和当前版本
  /// 返回true表示有新版本可用
  static bool get isUpdateAvailable {
    try {
      if (latestVersion.isEmpty) {
        return false;
      }
      // 使用Version类进行语义化版本比较
      return Version.parse(latestVersion) > Version.parse(applicationVersion);
    } catch (e) {
      return false;
    }
  }

  /// 最新的appcast项（包含更新详情）
  static AppcastItem? _latestAppcastItem;
  static AppcastItem? get latestAppcastItem => _latestAppcastItem;
  static set latestAppcastItem(AppcastItem? value) {
    _latestAppcastItem = value;
    // 更新关键更新标志
    isCriticalUpdateNotifier.value = value?.criticalUpdate == true;
  }

  /// 关键更新通知器
  /// true表示必须更新才能继续使用
  static ValueNotifier<bool> isCriticalUpdateNotifier = ValueNotifier(false);
  static bool get isCriticalUpdate => isCriticalUpdateNotifier.value;
}

/// 应用程序信息收集任务
/// 
/// 功能说明：
/// 在应用启动时收集设备和应用信息
/// 
/// 收集的信息包括：
/// - 应用版本和构建号
/// - 设备ID（每个平台不同）
/// - CPU架构
/// - 操作系统信息
/// - Android SDK版本（Android平台）
/// - macOS版本号（macOS平台）
class ApplicationInfoTask extends LaunchTask {
  const ApplicationInfoTask();

  /// 初始化设备信息收集
  /// 
  /// 执行流程：
  /// 1. 获取应用包信息（版本号、构建号）
  /// 2. 根据平台收集特定的设备信息
  /// 3. 保存到ApplicationInfo静态类中供全局使用
  @override
  Future<void> initialize(LaunchContext context) async {
    await super.initialize(context);
    
    // 初始化设备信息插件和包信息
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    // ========== macOS平台特殊处理 ==========
    // 获取macOS版本号，用于兼容性判断
    if (Platform.isMacOS) {
      final macInfo = await deviceInfoPlugin.macOsInfo;
      ApplicationInfo.macOSMajorVersion = macInfo.majorVersion;
      ApplicationInfo.macOSMinorVersion = macInfo.minorVersion;
    }

    // ========== Android平台特殊处理 ==========
    // 获取Android SDK版本，用于API兼容性判断
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      ApplicationInfo.androidSDKVersion = androidInfo.version.sdkInt;
    }

    // ========== 通用信息收集 ==========
    // 保存应用版本信息
    ApplicationInfo.applicationVersion = packageInfo.version;
    ApplicationInfo.buildNumber = packageInfo.buildNumber;

    // ========== 平台特定信息收集 ==========
    String? deviceId;
    String? architecture;
    String? os;
    
    try {
      if (Platform.isAndroid) {
        // Android平台
        final AndroidDeviceInfo androidInfo =
            await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.device;                    // 设备型号
        architecture = androidInfo.supportedAbis.firstOrNull;  // CPU架构（优先选择）
        os = 'android';
        
      } else if (Platform.isIOS) {
        // iOS平台
        final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor;          // 供应商ID（应用卸载后会变）
        architecture = iosInfo.utsname.machine;          // 设备型号（如：iPhone13,2）
        os = 'ios';
        
      } else if (Platform.isMacOS) {
        // macOS平台
        final MacOsDeviceInfo macInfo = await deviceInfoPlugin.macOsInfo;
        deviceId = macInfo.systemGUID;                   // 系统GUID
        architecture = macInfo.arch;                     // CPU架构（x86_64/arm64）
        os = 'macos';
        
      } else if (Platform.isWindows) {
        // Windows平台
        final WindowsDeviceInfo windowsInfo =
            await deviceInfoPlugin.windowsInfo;
        deviceId = windowsInfo.deviceId;                 // Windows设备ID
        architecture = 'x86_64';                         // 目前只支持x86_64
        os = 'windows';
        
      } else if (Platform.isLinux) {
        // Linux平台
        final LinuxDeviceInfo linuxInfo = await deviceInfoPlugin.linuxInfo;
        deviceId = linuxInfo.machineId;                  // 机器ID
        architecture = 'x86_64';                         // 目前只支持x86_64
        os = 'linux';
        
      } else {
        // 未知平台
        deviceId = null;
        architecture = null;
        os = null;
      }
    } catch (e) {
      // 获取设备信息失败，记录错误但不中断启动
      Log.error('Failed to get platform version, $e');
    }

    // 保存收集到的信息，空值使用空字符串
    ApplicationInfo.deviceId = deviceId ?? '';
    ApplicationInfo.architecture = architecture ?? '';
    ApplicationInfo.os = os ?? '';
  }
}
