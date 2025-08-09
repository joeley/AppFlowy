/// 权限检查器
/// 
/// 管理移动端设备权限的检查和请求。
/// 支持相机、相册等权限的统一处理。
/// 
/// 主要功能：
/// 1. **权限检查**：检查设备权限状态
/// 2. **权限请求**：向用户请求必要权限
/// 3. **引导设置**：永久拒绝时引导用户到设置页面
/// 4. **平台适配**：处理不同平台的权限差异
import 'dart:async';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/widgets/show_flowy_mobile_confirm_dialog.dart';
import 'package:appflowy/startup/tasks/device_info_task.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_platform/universal_platform.dart';

/// 权限检查工具类
/// 
/// 提供静态方法检查和请求各种设备权限
class PermissionChecker {
  /// 检查相册权限
  /// 
  /// 处理流程：
  /// 1. 检查当前权限状态
  /// 2. 如果永久拒绝，显示对话框引导到设置
  /// 3. 如果暂时拒绝，请求权限
  /// 4. 返回最终权限状态
  /// 
  /// 特殊处理：
  /// - Android SDK 32及以下使用storage权限
  /// - Android SDK 33及以上使用photos权限
  static Future<bool> checkPhotoPermission(BuildContext context) async {
    // 检查当前权限状态
    final status = await Permission.photos.status;
    
    // 权限被永久拒绝，需要引导用户到设置页面
    if (status.isPermanentlyDenied && context.mounted) {
      unawaited(
        showFlowyMobileConfirmDialog(
          context,
          title: FlowyText.semibold(
            LocaleKeys.pageStyle_photoPermissionTitle.tr(),
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
          content: FlowyText(
            LocaleKeys.pageStyle_photoPermissionDescription.tr(),
            maxLines: 5,
            textAlign: TextAlign.center,
            fontSize: 12.0,
          ),
          actionAlignment: ConfirmDialogActionAlignment.vertical,
          actionButtonTitle: LocaleKeys.pageStyle_openSettings.tr(),
          actionButtonColor: Colors.blue,
          cancelButtonTitle: LocaleKeys.pageStyle_doNotAllow.tr(),
          cancelButtonColor: Colors.blue,
          onActionButtonPressed: () {
            // 打开应用设置页面
            openAppSettings();
          },
        ),
      );

      return false;
    } else if (status.isDenied) {
      // 权限被拒绝但可以再次请求
      // Android平台版本兼容处理
      // 参考：https://github.com/Baseflow/flutter-permission-handler/issues/1262#issuecomment-2006340937
      Permission permission = Permission.photos;
      if (UniversalPlatform.isAndroid &&
          ApplicationInfo.androidSDKVersion <= 32) {
        // Android 12及以下版本使用storage权限
        permission = Permission.storage;
      }
      
      // 请求权限
      final newStatus = await permission.request();
      if (newStatus.isDenied) {
        return false;
      }
    }

    return true;
  }

  /// 检查相机权限
  /// 
  /// 处理流程与相册权限类似：
  /// 1. 检查当前权限状态
  /// 2. 处理永久拒绝情况
  /// 3. 请求权限（如需要）
  /// 4. 返回权限状态
  static Future<bool> checkCameraPermission(BuildContext context) async {
    // 检查当前权限状态
    final status = await Permission.camera.status;
    
    // 权限被永久拒绝，显示引导对话框
    if (status.isPermanentlyDenied && context.mounted) {
      unawaited(
        showFlowyMobileConfirmDialog(
          context,
          title: FlowyText.semibold(
            LocaleKeys.pageStyle_cameraPermissionTitle.tr(),
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
          content: FlowyText(
            LocaleKeys.pageStyle_cameraPermissionDescription.tr(),
            maxLines: 5,
            textAlign: TextAlign.center,
            fontSize: 12.0,
          ),
          actionAlignment: ConfirmDialogActionAlignment.vertical,
          actionButtonTitle: LocaleKeys.pageStyle_openSettings.tr(),
          actionButtonColor: Colors.blue,
          cancelButtonTitle: LocaleKeys.pageStyle_doNotAllow.tr(),
          cancelButtonColor: Colors.blue,
          onActionButtonPressed: openAppSettings,
        ),
      );

      return false;
    } else if (status.isDenied) {
      // 请求相机权限
      final newStatus = await Permission.camera.request();
      if (newStatus.isDenied) {
        return false;
      }
    }

    return true;
  }
}
