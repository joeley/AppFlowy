import 'dart:convert';

import 'package:appflowy/core/config/kv.dart';
import 'package:appflowy/core/config/kv_keys.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'space_order_bloc.freezed.dart';

/// 移动端空间Tab类型枚举
/// 
/// 注意：枚举顺序不能更改，因为索引值会被持久化存储
enum MobileSpaceTabType {
  // 请勿更改枚举顺序 - DO NOT CHANGE THE ORDER
  spaces,     // 空间
  recent,     // 最近
  favorites,  // 收藏
  shared;     // 共享

  /// 获取本地化文本
  String get tr {
    switch (this) {
      case MobileSpaceTabType.recent:
        return LocaleKeys.sideBar_RecentSpace.tr();
      case MobileSpaceTabType.spaces:
        return LocaleKeys.sideBar_Spaces.tr();
      case MobileSpaceTabType.favorites:
        return LocaleKeys.sideBar_favoriteSpace.tr();
      case MobileSpaceTabType.shared:
        return 'Shared';
    }
  }
}

/// 空间Tab顺序管理BLoC
/// 
/// 功能说明：
/// 1. 管理Tab的显示顺序
/// 2. 记录用户最后打开的Tab
/// 3. 支持Tab拖拽重新排序
/// 4. 持久化存储用户偏好
/// 
/// 核心功能：
/// - 加载和保存Tab顺序
/// - 记录默认Tab
/// - 处理Tab重新排序
class SpaceOrderBloc extends Bloc<SpaceOrderEvent, SpaceOrderState> {
  SpaceOrderBloc() : super(const SpaceOrderState()) {
    on<SpaceOrderEvent>(
      (event, emit) async {
        await event.when(
          // 初始化：加载Tab顺序和默认Tab
          initial: () async {
            final tabsOrder = await _getTabsOrder();
            final defaultTab = await _getDefaultTab();
            emit(
              state.copyWith(
                tabsOrder: tabsOrder,
                defaultTab: defaultTab,
                isLoading: false,
              ),
            );
          },
          // 打开Tab：记录最后打开的Tab
          open: (index) async {
            final tab = state.tabsOrder[index];
            await _setDefaultTab(tab);
          },
          // 重新排序：更新Tab顺序并保存
          reorder: (from, to) async {
            final tabsOrder = List.of(state.tabsOrder);
            tabsOrder.insert(to, tabsOrder.removeAt(from));
            await _setTabsOrder(tabsOrder);
            emit(state.copyWith(tabsOrder: tabsOrder));
          },
        );
      },
    );
  }

  /// 键值存储实例
  final _storage = getIt<KeyValueStorage>();

  /// 获取默认Tab
  /// 
  /// 从本地存储读取用户最后打开的Tab
  /// 如果读取失败，默认返回空间Tab
  Future<MobileSpaceTabType> _getDefaultTab() async {
    try {
      return await _storage.getWithFormat<MobileSpaceTabType>(
              KVKeys.lastOpenedSpace, (value) {
            return MobileSpaceTabType.values[int.parse(value)];
          }) ??
          MobileSpaceTabType.spaces;
    } catch (e) {
      return MobileSpaceTabType.spaces;
    }
  }

  /// 设置默认Tab
  /// 
  /// 保存用户最后打开的Tab索引
  Future<void> _setDefaultTab(MobileSpaceTabType tab) async {
    await _storage.set(
      KVKeys.lastOpenedSpace,
      tab.index.toString(),
    );
  }

  /// 获取Tab顺序
  /// 
  /// 功能说明：
  /// 1. 从本地存储读取Tab顺序
  /// 2. 自动添加新的Tab类型（如shared）
  /// 3. 处理数据格式错误，返回默认顺序
  Future<List<MobileSpaceTabType>> _getTabsOrder() async {
    try {
      return await _storage.getWithFormat<List<MobileSpaceTabType>>(
              KVKeys.spaceOrder, (value) {
            final order = jsonDecode(value).cast<int>();
            if (order.isEmpty) {
              return MobileSpaceTabType.values;
            }
            // 确保新添加的Tab类型（如shared）被包含
            if (!order.contains(MobileSpaceTabType.shared.index)) {
              order.add(MobileSpaceTabType.shared.index);
            }
            return order
                .map((e) => MobileSpaceTabType.values[e])
                .cast<MobileSpaceTabType>()
                .toList();
          }) ??
          MobileSpaceTabType.values;
    } catch (e) {
      return MobileSpaceTabType.values;
    }
  }

  /// 保存Tab顺序
  /// 
  /// 将Tab顺序序列化为JSON并保存到本地存储
  Future<void> _setTabsOrder(List<MobileSpaceTabType> tabsOrder) async {
    await _storage.set(
      KVKeys.spaceOrder,
      jsonEncode(tabsOrder.map((e) => e.index).toList()),
    );
  }
}

/// 空间Tab顺序事件
@freezed
class SpaceOrderEvent with _$SpaceOrderEvent {
  /// 初始化事件
  const factory SpaceOrderEvent.initial() = Initial;
  
  /// 打开Tab事件
  const factory SpaceOrderEvent.open(int index) = Open;
  
  /// 重新排序事件
  const factory SpaceOrderEvent.reorder(int from, int to) = Reorder;
}

/// 空间Tab顺序状态
@freezed
class SpaceOrderState with _$SpaceOrderState {
  const factory SpaceOrderState({
    /// 默认Tab（最后打开的）
    @Default(MobileSpaceTabType.spaces) MobileSpaceTabType defaultTab,
    
    /// Tab显示顺序
    @Default(MobileSpaceTabType.values) List<MobileSpaceTabType> tabsOrder,
    
    /// 是否正在加载
    @Default(true) bool isLoading,
  }) = _SpaceOrderState;

  factory SpaceOrderState.initial() => const SpaceOrderState();
}
