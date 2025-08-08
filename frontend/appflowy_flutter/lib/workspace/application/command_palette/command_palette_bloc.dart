import 'dart:async';

import 'package:appflowy/plugins/trash/application/trash_listener.dart';
import 'package:appflowy/plugins/trash/application/trash_service.dart';
import 'package:appflowy/workspace/application/command_palette/search_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-search/result.pb.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'command_palette_bloc.freezed.dart';

/*
 * 防抖器工具类
 * 
 * 用于搜索输入的防抖处理
 * 避免频繁触发搜索请求
 * 
 * 设计原理：
 * - 用户停止输入一段时间后才执行搜索
 * - 减少服务器压力和网络请求
 * - 提升用户体验，避免搜索结果频繁闪动
 */
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/*
 * 命令面板业务逻辑控制器
 * 
 * 核心功能：
 * 1. 全局搜索功能（本地搜索 + 服务器搜索）
 * 2. AI辅助搜索和问答
 * 3. 垃圾桶项目的搜索
 * 4. 实时搜索结果流处理
 * 
 * 设计特点：
 * - 防抖搜索：避免频繁触发搜索
 * - 多源搜索：结合本地和服务器结果
 * - 缓存视图：提高搜索性能
 * - 流式响应：支持实时更新搜索结果
 * 
 * 架构模式：
 * - BLoC模式管理搜索状态
 * - 观察者模式监听垃圾桶变化
 * - 流处理模式处理搜索响应
 */
class CommandPaletteBloc
    extends Bloc<CommandPaletteEvent, CommandPaletteState> {
  CommandPaletteBloc() : super(CommandPaletteState.initial()) {
    /* 注册所有事件处理器 */
    on<_SearchChanged>(_onSearchChanged);         /* 搜索输入变化 */
    on<_PerformSearch>(_onPerformSearch);         /* 执行搜索操作 */
    on<_NewSearchStream>(_onNewSearchStream);     /* 新的搜索流 */
    on<_ResultsChanged>(_onResultsChanged);       /* 结果变化 */
    on<_TrashChanged>(_onTrashChanged);           /* 垃圾桶变化 */
    on<_WorkspaceChanged>(_onWorkspaceChanged);   /* 工作区切换 */
    on<_ClearSearch>(_onClearSearch);             /* 清空搜索 */
    on<_GoingToAskAI>(_onGoingToAskAI);          /* 准备询问AI */
    on<_AskedAI>(_onAskedAI);                     /* AI询问完成 */
    on<_RefreshCachedViews>(_onRefreshCachedViews); /* 刷新缓存视图 */
    on<_UpdateCachedViews>(_onUpdateCachedViews);   /* 更新缓存视图 */

    _initTrash();
    _refreshCachedViews();
  }

  /* 搜索防抖器：300ms延迟，避免频繁搜索 */
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  /* 垃圾桶服务：处理垃圾桶的CRUD操作 */
  final TrashService _trashService = TrashService();
  /* 垃圾桶监听器：实时监听垃圾桶变化 */
  final TrashListener _trashListener = TrashListener();
  /* 当前活跃的搜索查询，用于验证搜索结果的有效性 */
  String? _activeQuery;

  @override
  Future<void> close() {
    _trashListener.close();
    _searchDebouncer.dispose();
    state.searchResponseStream?.dispose();
    return super.close();
  }

  /*
   * 初始化垃圾桶数据
   * 
   * 功能：
   * 1. 启动垃圾桶变化监听器
   * 2. 加载当前垃圾桶内容
   * 3. 更新状态中的垃圾桶数据
   * 
   * 时机：BLoC初始化时自动执行
   */
  Future<void> _initTrash() async {
    /* 启动监听器，实时接收垃圾桶变化通知 */
    _trashListener.start(
      trashUpdated: (trashOrFailed) => add(
        CommandPaletteEvent.trashChanged(
          trash: trashOrFailed.toNullable(),
        ),
      ),
    );

    /* 主动读取一次垃圾桶数据 */
    final trashOrFailure = await _trashService.readTrash();
    trashOrFailure.fold(
      (trash) {
        if (!isClosed) {
          add(CommandPaletteEvent.trashChanged(trash: trash.items));
        }
      },
      (error) => debugPrint('Failed to load trash: $error'),
    );
  }

  /*
   * 刷新缓存的视图数据
   * 
   * 问题背景：
   * - 搜索结果中可能出现不存在的视图
   * - 图标数据可能丢失
   * 
   * 解决方案：
   * - 获取所有视图并缓存
   * - 用于修复搜索结果显示问题
   * 
   * 调用时机：
   * - BLoC初始化时
   * - 工作区切换时
   * - 手动刷新时
   */
  Future<void> _refreshCachedViews() async {
    final repeatedViewPB =
        (await ViewBackendService.getAllViews()).toNullable();
    if (repeatedViewPB == null || isClosed) return;
    add(CommandPaletteEvent.updateCachedViews(views: repeatedViewPB.items));
  }

  FutureOr<void> _onRefreshCachedViews(
    _RefreshCachedViews event,
    Emitter<CommandPaletteState> emit,
  ) {
    _refreshCachedViews();
  }

  FutureOr<void> _onUpdateCachedViews(
    _UpdateCachedViews event,
    Emitter<CommandPaletteState> emit,
  ) {
    final cachedViews = <String, ViewPB>{};
    for (final view in event.views) {
      cachedViews[view.id] = view;
    }
    emit(state.copyWith(cachedViews: cachedViews));
  }

  /*
   * 处理搜索输入变化事件
   * 
   * 核心机制：防抖处理
   * - 用户输入后等待300ms
   * - 如果期间有新输入，重置计时器
   * - 最终触发真正的搜索操作
   * 
   * 优势：
   * - 减少无效搜索请求
   * - 提升搜索响应性能
   * - 改善用户体验
   */
  FutureOr<void> _onSearchChanged(
    _SearchChanged event,
    Emitter<CommandPaletteState> emit,
  ) {
    _searchDebouncer.run(
      () {
        if (!isClosed) {
          add(CommandPaletteEvent.performSearch(search: event.search));
        }
      },
    );
  }

  /*
   * 执行搜索操作
   * 
   * 搜索流程：
   * 1. 空查询处理：清空所有搜索结果
   * 2. 非空查询处理：
   *    - 设置搜索状态为进行中
   *    - 记录当前查询（用于验证结果有效性）
   *    - 调用后端搜索服务
   *    - 创建搜索结果流
   * 
   * 异步处理：
   * - 使用unawaited避免阻塞
   * - 通过流处理实时返回结果
   * 
   * 错误处理：
   * - 搜索失败时重置搜索状态
   * - 记录错误日志
   */
  FutureOr<void> _onPerformSearch(
    _PerformSearch event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.search.isEmpty) {
      /* 清空搜索：重置所有搜索相关状态 */
      emit(
        state.copyWith(
          query: null,
          searching: false,
          serverResponseItems: [],
          localResponseItems: [],
          combinedResponseItems: {},
          resultSummaries: [],
          generatingAIOverview: false,
        ),
      );
    } else {
      /* 开始搜索：设置搜索状态，记录查询 */
      emit(state.copyWith(query: event.search, searching: true));
      _activeQuery = event.search;

      /* 异步执行搜索，不阻塞UI */
      unawaited(
        SearchBackendService.performSearch(
          event.search,
        ).then(
          (result) => result.fold(
            (stream) {
              /* 搜索成功：创建新的搜索流 */
              if (!isClosed && _activeQuery == event.search) {
                add(CommandPaletteEvent.newSearchStream(stream: stream));
              }
            },
            (error) {
              /* 搜索失败：重置状态 */
              debugPrint('Search error: $error');
              if (!isClosed) {
                add(
                  CommandPaletteEvent.resultsChanged(
                    searchId: '',
                    searching: false,
                    generatingAIOverview: false,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  /*
   * 处理新的搜索响应流
   * 
   * 流式搜索机制：
   * 1. 清理旧的搜索流
   * 2. 建立新的搜索流监听
   * 3. 分别处理不同类型的搜索结果：
   *    - 本地搜索结果（快速返回）
   *    - 服务器搜索结果（可能较慢）
   *    - AI摘要结果（最慢）
   * 
   * 设计优势：
   * - 渐进式展示结果
   * - 本地结果优先显示
   * - AI增强搜索体验
   * 
   * 注意：服务器结果到达时清空摘要
   */
  FutureOr<void> _onNewSearchStream(
    _NewSearchStream event,
    Emitter<CommandPaletteState> emit,
  ) {
    /* 清理之前的搜索流，避免内存泄漏 */
    state.searchResponseStream?.dispose();
    emit(
      state.copyWith(
        searchId: event.stream.searchId,
        searchResponseStream: event.stream,
      ),
    );

    /* 监听搜索流的各种事件 */
    event.stream.listen(
      /* 本地搜索结果：最快返回 */
      onLocalItems: (items, searchId) => _handleResultsUpdate(
        searchId: searchId,
        localItems: items,
      ),
      /* 服务器搜索结果：可能包含更多内容 */
      onServerItems: (items, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: [], /* 服务器结果到达时清空摘要 */
        serverItems: items,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      /* AI生成的摘要：提供智能化的搜索理解 */
      onSummaries: (summaries, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: summaries,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      /* 搜索完成：更新搜索状态 */
      onFinished: (searchId) => _handleResultsUpdate(
        searchId: searchId,
        searching: false,
      ),
    );
  }

  /*
   * 统一处理搜索结果更新
   * 
   * 验证机制：
   * - 检查searchId是否为当前活跃搜索
   * - 避免旧搜索结果覆盖新搜索
   * 
   * 更新类型：
   * - 服务器搜索结果
   * - 本地搜索结果
   * - AI摘要
   * - 搜索状态（进行中/完成）
   */
  void _handleResultsUpdate({
    required String searchId,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
    bool searching = true,
    bool generatingAIOverview = false,
  }) {
    /* 只处理当前活跃搜索的结果 */
    if (_isActiveSearch(searchId)) {
      add(
        CommandPaletteEvent.resultsChanged(
          searchId: searchId,
          serverItems: serverItems,
          localItems: localItems,
          summaries: summaries,
          searching: searching,
          generatingAIOverview: generatingAIOverview,
        ),
      );
    }
  }

  /*
   * 处理搜索结果变化
   * 
   * 合并策略：
   * 1. 服务器结果优先（包含内容预览）
   * 2. 本地结果补充（使用putIfAbsent避免覆盖）
   * 3. 去重处理（基于item.id）
   * 
   * 数据结构：
   * - serverResponseItems：服务器原始结果
   * - localResponseItems：本地原始结果
   * - combinedResponseItems：合并后的结果（Map去重）
   * 
   * 注意事项：
   * - 本地结果的content为空（不包含预览）
   * - 保留各自原始数据用于调试
   */
  FutureOr<void> _onResultsChanged(
    _ResultsChanged event,
    Emitter<CommandPaletteState> emit,
  ) async {
    /* 验证搜索ID，确保处理正确的搜索结果 */
    if (state.searchId != event.searchId) return;

    /* 合并搜索结果，服务器结果优先 */
    final combinedItems = <String, SearchResultItem>{};
    
    /* 添加服务器结果（包含内容预览） */
    for (final item in event.serverItems ?? state.serverResponseItems) {
      combinedItems[item.id] = SearchResultItem(
        id: item.id,
        icon: item.icon,
        displayName: item.displayName,
        content: item.content,
        workspaceId: item.workspaceId,
      );
    }

    /* 添加本地结果（不覆盖已存在的服务器结果） */
    for (final item in event.localItems ?? state.localResponseItems) {
      combinedItems.putIfAbsent(
        item.id,
        () => SearchResultItem(
          id: item.id,
          icon: item.icon,
          displayName: item.displayName,
          content: '', /* 本地结果不包含内容预览 */
          workspaceId: item.workspaceId,
        ),
      );
    }

    /* 更新状态 */
    emit(
      state.copyWith(
        serverResponseItems: event.serverItems ?? state.serverResponseItems,
        localResponseItems: event.localItems ?? state.localResponseItems,
        resultSummaries: event.summaries ?? state.resultSummaries,
        combinedResponseItems: combinedItems,
        searching: event.searching,
        generatingAIOverview: event.generatingAIOverview,
      ),
    );
  }

  FutureOr<void> _onTrashChanged(
    _TrashChanged event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.trash != null) {
      emit(state.copyWith(trash: event.trash!));
    } else {
      final trashOrFailure = await _trashService.readTrash();
      trashOrFailure.fold((trash) {
        emit(state.copyWith(trash: trash.items));
      }, (error) {
        // Optionally handle error; otherwise, we simply do nothing.
      });
    }
  }

  FutureOr<void> _onWorkspaceChanged(
    _WorkspaceChanged event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(
      state.copyWith(
        query: '',
        serverResponseItems: [],
        localResponseItems: [],
        combinedResponseItems: {},
        resultSummaries: [],
        searching: false,
        generatingAIOverview: false,
      ),
    );
    _refreshCachedViews();
  }

  FutureOr<void> _onClearSearch(
    _ClearSearch event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(CommandPaletteState.initial().copyWith(trash: state.trash));
  }

  FutureOr<void> _onGoingToAskAI(
    _GoingToAskAI event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: true, askAISources: event.sources));
  }

  FutureOr<void> _onAskedAI(
    _AskedAI event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: false, askAISources: null));
  }

  /*
   * 验证是否为当前活跃的搜索
   * 
   * 作用：防止旧搜索结果污染新搜索
   * 场景：用户快速连续搜索时，旧结果可能晚于新结果返回
   */
  bool _isActiveSearch(String searchId) =>
      !isClosed && state.searchId == searchId;
}

@freezed
class CommandPaletteEvent with _$CommandPaletteEvent {
  const factory CommandPaletteEvent.searchChanged({required String search}) =
      _SearchChanged;
  const factory CommandPaletteEvent.performSearch({required String search}) =
      _PerformSearch;
  const factory CommandPaletteEvent.newSearchStream({
    required SearchResponseStream stream,
  }) = _NewSearchStream;
  const factory CommandPaletteEvent.resultsChanged({
    required String searchId,
    required bool searching,
    required bool generatingAIOverview,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
  }) = _ResultsChanged;

  const factory CommandPaletteEvent.trashChanged({
    @Default(null) List<TrashPB>? trash,
  }) = _TrashChanged;
  const factory CommandPaletteEvent.workspaceChanged({
    @Default(null) String? workspaceId,
  }) = _WorkspaceChanged;
  const factory CommandPaletteEvent.clearSearch() = _ClearSearch;
  const factory CommandPaletteEvent.goingToAskAI({
    @Default(null) List<SearchSourcePB>? sources,
  }) = _GoingToAskAI;
  const factory CommandPaletteEvent.askedAI() = _AskedAI;
  const factory CommandPaletteEvent.refreshCachedViews() = _RefreshCachedViews;
  const factory CommandPaletteEvent.updateCachedViews({
    required List<ViewPB> views,
  }) = _UpdateCachedViews;
}

/*
 * 搜索结果项数据模型
 * 
 * 统一的搜索结果表示
 * 合并了本地和服务器搜索结果
 * 
 * 字段说明：
 * - id：唯一标识符
 * - content：内容预览（服务器结果有，本地结果无）
 * - icon：图标信息
 * - displayName：显示名称
 * - workspaceId：所属工作区ID
 */
class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.icon,
    required this.content,
    required this.displayName,
    this.workspaceId,
  });

  final String id;
  final String content;
  final ResultIconPB icon;
  final String displayName;
  final String? workspaceId;
}

@freezed
class CommandPaletteState with _$CommandPaletteState {
  const CommandPaletteState._();
  const factory CommandPaletteState({
    @Default(null) String? query,
    @Default([]) List<SearchResponseItemPB> serverResponseItems,
    @Default([]) List<LocalSearchResponseItemPB> localResponseItems,
    @Default({}) Map<String, SearchResultItem> combinedResponseItems,
    @Default({}) Map<String, ViewPB> cachedViews,
    @Default([]) List<SearchSummaryPB> resultSummaries,
    @Default(null) SearchResponseStream? searchResponseStream,
    required bool searching,
    required bool generatingAIOverview,
    @Default(false) bool askAI,
    @Default(null) List<SearchSourcePB>? askAISources,
    @Default([]) List<TrashPB> trash,
    @Default(null) String? searchId,
  }) = _CommandPaletteState;

  factory CommandPaletteState.initial() => const CommandPaletteState(
        searching: false,
        generatingAIOverview: false,
      );
}
