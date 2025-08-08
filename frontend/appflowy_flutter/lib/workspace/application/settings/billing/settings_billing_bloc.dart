import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/application/subscription_success_listenable/subscription_success_listenable.dart';
import 'package:appflowy/workspace/application/workspace/workspace_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/workspace.pbserver.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:protobuf/protobuf.dart';

part 'settings_billing_bloc.freezed.dart';

/// 计费设置管理BLoC - 负责处理订阅计划和计费相关功能
/// 
/// 主要功能：
/// 1. 获取和显示订阅信息
/// 2. 管理订阅计划（创建、取消、更新）
/// 3. 处理支付流程和支付成功回调
/// 4. 管理计费门户（Billing Portal）
/// 5. 处理订阅周期切换（月付/年付）
/// 
/// 设计思想：
/// - 与后端紧密集成，确保订阅状态同步
/// - 支持多种订阅计划和附加功能
/// - 通过监听器模式处理支付成功回调
/// - 异步加载计费门户，优化用户体验
class SettingsBillingBloc
    extends Bloc<SettingsBillingEvent, SettingsBillingState> {
  SettingsBillingBloc({
    required this.workspaceId, // 工作区ID
    required Int64 userId, // 用户ID
  }) : super(const _Initial()) {
    // 初始化服务
    _userService = UserBackendService(userId: userId);
    _service = WorkspaceService(workspaceId: workspaceId, userId: userId);
    // 监听支付成功事件
    _successListenable = getIt<SubscriptionSuccessListenable>();
    _successListenable.addListener(_onPaymentSuccessful);

    on<SettingsBillingEvent>((event, emit) async {
      await event.when(
        // 初始化事件：加载订阅信息
        started: () async {
          emit(const SettingsBillingState.loading());

          FlowyError? error;

          // 获取工作区订阅信息
          final result = await UserBackendService.getWorkspaceSubscriptionInfo(
            workspaceId,
          );

          final subscriptionInfo = result.fold(
            (s) => s,
            (e) {
              error = e;
              return null;
            },
          );

          if (subscriptionInfo == null || error != null) {
            return emit(SettingsBillingState.error(error: error));
          }

          // 异步加载计费门户信息
          // 不阻塞主流程，加载完成后通过事件更新
          if (!_billingPortalCompleter.isCompleted) {
            unawaited(_fetchBillingPortal());
            unawaited(
              _billingPortalCompleter.future.then(
                (result) {
                  if (isClosed) return;

                  result.fold(
                    (portal) {
                      _billingPortal = portal;
                      // 触发计费门户加载完成事件
                      add(
                        SettingsBillingEvent.billingPortalFetched(
                          billingPortal: portal,
                        ),
                      );
                    },
                    (e) => Log.error('Error fetching billing portal: $e'),
                  );
                },
              ),
            );
          }

          emit(
            SettingsBillingState.ready(
              subscriptionInfo: subscriptionInfo,
              billingPortal: _billingPortal,
            ),
          );
        },
        // 计费门户加载完成事件
        // 更新状态中的计费门户信息
        billingPortalFetched: (billingPortal) async => state.maybeWhen(
          orElse: () {},
          ready: (subscriptionInfo, _, plan, isLoading) => emit(
            SettingsBillingState.ready(
              subscriptionInfo: subscriptionInfo,
              billingPortal: billingPortal,
              successfulPlanUpgrade: plan,
              isLoading: isLoading,
            ),
          ),
        ),
        // 打开客户计费门户
        // 在浏览器中打开第三方支付平台的管理页面
        openCustomerPortal: () async {
          // 如果门户已加载，直接打开
          if (_billingPortalCompleter.isCompleted && _billingPortal != null) {
            return afLaunchUrlString(_billingPortal!.url);
          }
          // 否则等待加载完成
          await _billingPortalCompleter.future;
          if (_billingPortal != null) {
            await afLaunchUrlString(_billingPortal!.url);
          }
        },
        // 添加订阅计划
        // 创建订阅并跳转到支付页面
        addSubscription: (plan) async {
          final result =
              await _userService.createSubscription(workspaceId, plan);

          result.fold(
            // 成功：打开支付链接
            (link) => afLaunchUrlString(link.paymentLink),
            // 失败：记录错误
            (f) => Log.error(f.msg, f),
          );
        },
        // 取消订阅计划
        // 取消后会降级到免费计划或移除附加功能
        cancelSubscription: (plan, reason) async {
          final s = state.mapOrNull(ready: (s) => s);
          if (s == null) {
            return;
          }

          emit(s.copyWith(isLoading: true));

          final result =
              await _userService.cancelSubscription(workspaceId, plan, reason);
          final successOrNull = result.fold(
            (_) => true,
            (f) {
              Log.error(
                'Failed to cancel subscription of ${plan.label}: ${f.msg}',
                f,
              );
              return null;
            },
          );

          if (successOrNull != true) {
            return;
          }

          final subscriptionInfo = state.mapOrNull(
            ready: (s) => s.subscriptionInfo,
          );

          // 防御性检查：确保订阅信息存在
          if (subscriptionInfo == null) {
            return;
          }

          // 更新本地订阅信息
          subscriptionInfo.freeze();
          final newInfo = subscriptionInfo.rebuild((value) {
            // 如果是附加功能，从列表中移除
            if (plan.isAddOn) {
              value.addOns.removeWhere(
                (addon) => addon.addOnSubscription.subscriptionPlan == plan,
              );
            }

            // 如果取消Pro计划，降级到免费计划
            if (plan == WorkspacePlanPB.ProPlan &&
                value.plan == WorkspacePlanPB.ProPlan) {
              value.plan = WorkspacePlanPB.FreePlan;
              value.planSubscription.freeze();
              value.planSubscription = value.planSubscription.rebuild((sub) {
                sub.status = WorkspaceSubscriptionStatusPB.Active;
                sub.subscriptionPlan = SubscriptionPlanPB.Free;
              });
            }
          });

          emit(
            SettingsBillingState.ready(
              subscriptionInfo: newInfo,
              billingPortal: _billingPortal,
            ),
          );
        },
        // 支付成功事件
        // 重新加载订阅信息以更新状态
        paymentSuccessful: (plan) async {
          final result = await UserBackendService.getWorkspaceSubscriptionInfo(
            workspaceId,
          );

          final subscriptionInfo = result.toNullable();
          if (subscriptionInfo != null) {
            emit(
              SettingsBillingState.ready(
                subscriptionInfo: subscriptionInfo,
                billingPortal: _billingPortal,
              ),
            );
          }
        },
        // 更新订阅周期
        // 切换月付/年付模式
        updatePeriod: (plan, interval) async {
          final s = state.mapOrNull(ready: (s) => s);
          if (s == null) {
            return;
          }

          emit(s.copyWith(isLoading: true));

          final result = await _userService.updateSubscriptionPeriod(
            workspaceId,
            plan,
            interval,
          );
          final successOrNull = result.fold((_) => true, (f) {
            Log.error(
              'Failed to update subscription period of ${plan.label}: ${f.msg}',
              f,
            );
            return null;
          });

          if (successOrNull != true) {
            return emit(s.copyWith(isLoading: false));
          }

          // Fetch new subscription info
          final newResult =
              await UserBackendService.getWorkspaceSubscriptionInfo(
            workspaceId,
          );

          final newSubscriptionInfo = newResult.toNullable();
          if (newSubscriptionInfo != null) {
            emit(
              SettingsBillingState.ready(
                subscriptionInfo: newSubscriptionInfo,
                billingPortal: _billingPortal,
              ),
            );
          }
        },
      );
    });
  }

  late final String workspaceId; // 工作区ID
  late final WorkspaceService _service; // 工作区服务
  late final UserBackendService _userService; // 用户服务
  // 计费门户加载完成信号
  final _billingPortalCompleter =
      Completer<FlowyResult<BillingPortalPB, FlowyError>>();

  BillingPortalPB? _billingPortal; // 计费门户信息
  late final SubscriptionSuccessListenable _successListenable; // 支付成功监听器

  @override
  Future<void> close() {
    // 清理监听器
    _successListenable.removeListener(_onPaymentSuccessful);
    return super.close();
  }

  /// 获取计费门户信息
  /// 计费门户是第三方支付平台提供的管理页面
  Future<void> _fetchBillingPortal() async {
    final billingPortalResult = await _service.getBillingPortal();
    _billingPortalCompleter.complete(billingPortalResult);
  }

  /// 支付成功回调
  /// 当支付完成后触发，更新订阅状态
  Future<void> _onPaymentSuccessful() async => add(
        SettingsBillingEvent.paymentSuccessful(
          plan: _successListenable.subscribedPlan,
        ),
      );
}

/// 计费设置事件定义
/// 包含所有与订阅和计费相关的事件
@freezed
class SettingsBillingEvent with _$SettingsBillingEvent {
  const factory SettingsBillingEvent.started() = _Started; // 初始化事件

  // 计费门户加载完成事件
  const factory SettingsBillingEvent.billingPortalFetched({
    required BillingPortalPB billingPortal,
  }) = _BillingPortalFetched;

  const factory SettingsBillingEvent.openCustomerPortal() = _OpenCustomerPortal; // 打开客户门户

  // 添加订阅计划
  const factory SettingsBillingEvent.addSubscription(SubscriptionPlanPB plan) =
      _AddSubscription;

  // 取消订阅计划
  const factory SettingsBillingEvent.cancelSubscription(
    SubscriptionPlanPB plan, {
    @Default(null) String? reason, // 可选的取消原因
  }) = _CancelSubscription;

  // 支付成功事件
  const factory SettingsBillingEvent.paymentSuccessful({
    SubscriptionPlanPB? plan,
  }) = _PaymentSuccessful;

  // 更新订阅周期
  const factory SettingsBillingEvent.updatePeriod({
    required SubscriptionPlanPB plan, // 订阅计划
    required RecurringIntervalPB interval, // 付款周期（月/年）
  }) = _UpdatePeriod;
}

/// 计费设置状态定义
/// 使用sealed class模式确保状态完整性
/// 继承Equatable以优化状态比较性能
@freezed
class SettingsBillingState extends Equatable with _$SettingsBillingState {
  const SettingsBillingState._();

  const factory SettingsBillingState.initial() = _Initial; // 初始状态

  const factory SettingsBillingState.loading() = _Loading; // 加载中

  // 错误状态
  const factory SettingsBillingState.error({
    @Default(null) FlowyError? error,
  }) = _Error;

  // 就绪状态 - 包含完整的订阅信息
  const factory SettingsBillingState.ready({
    required WorkspaceSubscriptionInfoPB subscriptionInfo, // 订阅信息
    required BillingPortalPB? billingPortal, // 计费门户
    @Default(null) SubscriptionPlanPB? successfulPlanUpgrade, // 成功升级的计划
    @Default(false) bool isLoading, // 是否正在处理中
  }) = _Ready;

  /// 重写Equatable的props属性
  /// 用于状态比较，确保相同内容的状态被认为相等
  @override
  List<Object?> get props => maybeWhen(
        orElse: () => const [],
        error: (error) => [error],
        ready: (subscription, billingPortal, plan, isLoading) => [
          subscription,
          billingPortal,
          plan,
          isLoading,
          ...subscription.addOns, // 包含所有附加功能
        ],
      );
}
