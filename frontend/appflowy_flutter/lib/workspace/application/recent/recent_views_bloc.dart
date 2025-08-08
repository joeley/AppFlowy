import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/recent/cached_recent_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recent_views_bloc.freezed.dart';

/// 最近访问视图管理BLoC - 负责管理用户最近访问的视图列表
/// 
/// 主要功能：
/// 1. 跟踪用户最近打开的视图
/// 2. 添加/移除最近访问记录
/// 3. 重置最近访问列表
/// 4. 悬停视图状态管理
/// 
/// 设计思想：
/// - 使用缓存服务提高性能
/// - 通过监听器模式实时更新
/// - 支持批量操作提高效率
class RecentViewsBloc extends Bloc<RecentViewsEvent, RecentViewsState> {
  RecentViewsBloc() : super(RecentViewsState.initial()) {
    // 从IOC容器获取缓存服务
    _service = getIt<CachedRecentService>();
    _dispatch();
  }

  late final CachedRecentService _service; // 最近访问缓存服务

  @override
  Future<void> close() async {
    // 移除监听器，防止内存泄漏
    _service.notifier.removeListener(_onRecentViewsUpdated);
    return super.close();
  }

  /// 事件分发器 - 处理所有最近访问相关事件
  void _dispatch() {
    on<RecentViewsEvent>(
      (event, emit) async {
        await event.map(
          // 初始化事件：添加监听器并获取初始数据
          initial: (e) async {
            // 监听最近访问列表变化
            _service.notifier.addListener(_onRecentViewsUpdated);
            // 获取初始最近访问列表
            add(const RecentViewsEvent.fetchRecentViews());
          },
          // 添加最近访问记录
          addRecentViews: (e) async {
            // true表示添加操作
            await _service.updateRecentViews(e.viewIds, true);
          },
          // 移除最近访问记录
          removeRecentViews: (e) async {
            // false表示移除操作
            await _service.updateRecentViews(e.viewIds, false);
          },
          // 获取最近访问列表
          fetchRecentViews: (e) async {
            emit(
              state.copyWith(
                isLoading: false,
                views: await _service.recentViews(), // 从缓存服务获取数据
              ),
            );
          },
          // 重置最近访问列表
          resetRecentViews: (e) async {
            await _service.reset(); // 清空所有记录
            // 重新获取列表（应该为空）
            add(const RecentViewsEvent.fetchRecentViews());
          },
          // 悬停视图事件 - 用于UI交互反馈
          hoverView: (e) async {
            emit(
              state.copyWith(hoveredView: e.view),
            );
          },
        );
      },
    );
  }

  /// 最近访问列表更新回调
  /// 当缓存服务中的数据变化时，触发重新获取
  void _onRecentViewsUpdated() =>
      add(const RecentViewsEvent.fetchRecentViews());
}

/// 最近访问事件定义
@freezed
class RecentViewsEvent with _$RecentViewsEvent {
  const factory RecentViewsEvent.initial() = Initial; // 初始化
  const factory RecentViewsEvent.addRecentViews(List<String> viewIds) =
      AddRecentViews; // 添加最近访问
  const factory RecentViewsEvent.removeRecentViews(List<String> viewIds) =
      RemoveRecentViews; // 移除最近访问
  const factory RecentViewsEvent.fetchRecentViews() = FetchRecentViews; // 获取列表
  const factory RecentViewsEvent.resetRecentViews() = ResetRecentViews; // 重置列表
  const factory RecentViewsEvent.hoverView(ViewPB view) = HoverView; // 悬停视图
}

/// 最近访问状态定义
@freezed
class RecentViewsState with _$RecentViewsState {
  const factory RecentViewsState({
    required List<SectionViewPB> views, // 最近访问视图列表
    @Default(true) bool isLoading, // 加载状态
    @Default(null) ViewPB? hoveredView, // 当前悬停的视图（用于UI高亮）
  }) = _RecentViewsState;

  /// 创建初始状态
  factory RecentViewsState.initial() => const RecentViewsState(views: []);
}
