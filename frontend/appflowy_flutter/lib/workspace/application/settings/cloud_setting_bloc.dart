import 'package:appflowy/env/cloud_env.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_setting_bloc.freezed.dart';

/// 云同步设置管理BLoC - 管理应用的云服务配置
/// 
/// 主要功能：
/// 1. 管理云服务类型（AppFlowy Cloud、Supabase、本地存储等）
/// 2. 切换不同的认证和存储后端
/// 3. 为设置页面提供云服务状态
/// 
/// 设计思想：
/// - 支持多种云服务后端，灵活切换
/// - 通过AuthenticatorType统一不同后端的接口
/// - 状态管理简单，主要跟踪当前选中的云服务类型
class CloudSettingBloc extends Bloc<CloudSettingEvent, CloudSettingState> {
  CloudSettingBloc(AuthenticatorType cloudType)
      : super(CloudSettingState.initial(cloudType)) { // 初始化时设置当前云服务类型
    on<CloudSettingEvent>((event, emit) async {
      await event.when(
        initial: () async {}, // 初始化事件，目前不执行任何操作
        // 更新云服务类型事件
        // 用户在设置中切换云服务时触发
        updateCloudType: (AuthenticatorType newCloudType) async {
          emit(state.copyWith(cloudType: newCloudType));
        },
      );
    });
  }
}

/// 云设置事件定义
@freezed
class CloudSettingEvent with _$CloudSettingEvent {
  const factory CloudSettingEvent.initial() = _Initial; // 初始化事件
  const factory CloudSettingEvent.updateCloudType(
    AuthenticatorType newCloudType, // 新的云服务类型
  ) = _UpdateCloudType; // 更新云服务类型
}

/// 云设置状态定义
/// 保存当前选中的云服务类型
@freezed
class CloudSettingState with _$CloudSettingState {
  const factory CloudSettingState({
    required AuthenticatorType cloudType, // 当前云服务类型（AppFlowy Cloud/Supabase/Local等）
  }) = _CloudSettingState;

  /// 创建初始状态
  /// 使用传入的云服务类型作为初始值
  factory CloudSettingState.initial(AuthenticatorType cloudType) =>
      CloudSettingState(
        cloudType: cloudType,
      );
}
