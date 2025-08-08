import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/user/application/user_service.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mobile_view_page_bloc.freezed.dart';

/// 移动端视图页面状态管理器
/// 
/// 主要功能：
/// 1. 管理移动端视图页面的基础状态
/// 2. 处理沉浸模式（全屏显示）
/// 3. 监听视图更新
/// 4. 管理用户信息
/// 
/// 设计思想：
/// - 为移动端页面提供统一的状态管理
/// - 支持沉浸模式，提供更好的阅读体验
/// - 只有文档页面支持沉浸模式（v0.5.6+）
class MobileViewPageBloc
    extends Bloc<MobileViewPageEvent, MobileViewPageState> {
  MobileViewPageBloc({
    required this.viewId,
  })  : _viewListener = ViewListener(viewId: viewId),
        super(MobileViewPageState.initial()) {
    on<MobileViewPageEvent>(
      (event, emit) async {
        await event.when(
          /// 初始化事件处理
          initial: () async {
            // 注册监听器
            _registerListeners();

            // 获取当前用户信息
            final userProfilePB =
                await UserBackendService.getCurrentUserProfile()
                    .fold((s) => s, (f) => null);
            // 获取视图信息
            final result = await ViewBackendService.getView(viewId);
            // 判断是否支持沉浸模式
            final isImmersiveMode =
                _isImmersiveMode(result.fold((s) => s, (f) => null));
            emit(
              state.copyWith(
                isLoading: false,
                result: result,
                isImmersiveMode: isImmersiveMode,
                userProfilePB: userProfilePB,
              ),
            );
          },
          /// 更新沉浸模式状态
          updateImmersionMode: (isImmersiveMode) {
            emit(
              state.copyWith(
                isImmersiveMode: isImmersiveMode,
              ),
            );
          },
        );
      },
    );
  }

  /// 视图ID
  final String viewId;
  
  /// 视图监听器
  final ViewListener _viewListener;

  @override
  Future<void> close() {
    _viewListener.stop();
    return super.close();
  }

  /// 注册监听器
  /// 
  /// 监听视图更新，当封面变化时更新沉浸模式状态
  void _registerListeners() {
    _viewListener.start(
      onViewUpdated: (view) {
        final isImmersiveMode = _isImmersiveMode(view);
        add(MobileViewPageEvent.updateImmersionMode(isImmersiveMode));
      },
    );
  }

  /// 判断是否支持沉浸模式
  /// 
  /// 沉浸模式条件：
  /// 1. 必须是文档页面
  /// 2. 必须设置了封面
  /// 3. 封面不能是预设样式
  /// 
  /// 注：仅文档页面支持沉浸模式（v0.5.6+）
  bool _isImmersiveMode(ViewPB? view) {
    if (view == null) {
      return false;
    }

    final cover = view.cover;
    if (cover == null || cover.type == PageStyleCoverImageType.none) {
      return false;
    } else if (view.layout == ViewLayoutPB.Document && !cover.isPresets) {
      // 只有文档布局支持沉浸模式
      return true;
    }

    return false;
  }
}

/// 移动端视图页面事件
@freezed
class MobileViewPageEvent with _$MobileViewPageEvent {
  /// 初始化事件
  const factory MobileViewPageEvent.initial() = Initial;
  
  /// 更新沉浸模式
  const factory MobileViewPageEvent.updateImmersionMode(bool isImmersiveMode) =
      UpdateImmersionMode;
}

/// 移动端视图页面状态
@freezed
class MobileViewPageState with _$MobileViewPageState {
  const factory MobileViewPageState({
    /// 是否正在加载
    @Default(true) bool isLoading,
    /// 视图获取结果
    @Default(null) FlowyResult<ViewPB, FlowyError>? result,
    /// 是否处于沉浸模式
    @Default(false) bool isImmersiveMode,
    /// 用户信息
    @Default(null) UserProfilePB? userProfilePB,
  }) = _MobileViewPageState;

  /// 创建初始状态
  factory MobileViewPageState.initial() => const MobileViewPageState();
}
