import 'dart:async';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_setting.pb.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

/// 网络监听器 - 监听设备网络状态变化
/// 
/// 主要功能：
/// 1. 监听网络连接状态变化
/// 2. 识别网络类型（WiFi、蛇窝网络、蜂窝网络等）
/// 3. 同步网络状态到后端
/// 
/// 设计思想：
/// - 使用connectivity_plus插件监听网络变化
/// - 将网络状态转换为Protobuf格式同步给Rust后端
/// - 后端可以根据网络状态调整同步策略
class NetworkListener {
  NetworkListener() {
    // 监听网络状态变化
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  /// 网络连接管理器
  final Connectivity _connectivity = Connectivity();
  
  /// 网络状态订阅
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  /// 启动网络监听
  /// 
  /// 获取当前网络状态并启动监听
  Future<void> start() async {
    late ConnectivityResult result;
    // 平台消息可能失败，使用try/catch捕获异常
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      Log.error("Couldn't check connectivity status. $e");
      return;
    }
    return _updateConnectionStatus(result);
  }

  /// 停止网络监听
  Future<void> stop() async {
    await _connectivitySubscription.cancel();
  }

  /// 更新网络连接状态
  /// 
  /// 将Flutter的网络状态转换为Protobuf格式并同步到后端
  /// 
  /// 支持的网络类型：
  /// - WiFi：无线网络
  /// - Ethernet：以太网
  /// - Mobile：移动网络
  /// - Bluetooth：蓝牙
  /// - VPN：虚拟专用网络
  /// - None/Other：未知或无网络
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    // 将连接结果映射到网络类型
    final networkType = () {
      switch (result) {
        case ConnectivityResult.wifi:
          return NetworkTypePB.Wifi;
        case ConnectivityResult.ethernet:
          return NetworkTypePB.Ethernet;
        case ConnectivityResult.mobile:
          return NetworkTypePB.Cell;
        case ConnectivityResult.bluetooth:
          return NetworkTypePB.Bluetooth;
        case ConnectivityResult.vpn:
          return NetworkTypePB.VPN;
        case ConnectivityResult.none:
        case ConnectivityResult.other:
          return NetworkTypePB.NetworkUnknown;
      }
    }();
    
    // 创建网络状态对象并发送给后端
    final state = NetworkStatePB.create()..ty = networkType;
    return UserEventUpdateNetworkState(state).send().then((result) {
      result.fold((l) {}, (e) => Log.error(e));
    });
  }
}
