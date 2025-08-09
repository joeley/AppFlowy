/// AI提示词选择器状态管理
/// 
/// 管理AI提示词的选择、过滤、分类和收藏功能
/// 支持内置提示词和自定义提示词数据库

import 'dart:async';

import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../plugins/trash/application/trash_service.dart';
import 'ai_entities.dart';
import 'appflowy_ai_service.dart';

part 'ai_prompt_selector_cubit.freezed.dart';

/// AI提示词选择器Cubit
/// 
/// 管理提示词的业务逻辑，包括：
/// - 加载内置和自定义提示词
/// - 按分类筛选提示词
/// - 搜索过滤提示词
/// - 管理收藏状态
class AiPromptSelectorCubit extends Cubit<AiPromptSelectorState> {
  AiPromptSelectorCubit({
    AppFlowyAIService? aiService,
  })  : _aiService = aiService ?? AppFlowyAIService(),
        super(AiPromptSelectorState.loading()) {
    // 监听过滤文本变化
    filterTextController.addListener(_filterTextChanged);
    _init();
  }

  // AI服务实例
  final AppFlowyAIService _aiService;
  // 搜索过滤文本控制器
  final filterTextController = TextEditingController();
  // 所有可用的提示词列表（包括内置和自定义）
  final List<AiPrompt> availablePrompts = [];

  /// 释放资源
  @override
  Future<void> close() async {
    filterTextController.dispose();
    await super.close();
  }

  /// 初始化提示词选择器
  /// 
  /// 1. 加载内置提示词
  /// 2. 默认显示精选提示词
  /// 3. 异步加载自定义提示词
  void _init() async {
    // 加载内置提示词
    availablePrompts.addAll(await _aiService.getBuiltInPrompts());

    // 筛选精选提示词
    final featuredPrompts =
        availablePrompts.where((prompt) => prompt.isFeatured);
    final visiblePrompts = _getFilteredPrompts(featuredPrompts);

    // 发射初始状态
    emit(
      AiPromptSelectorState.ready(
        visiblePrompts: visiblePrompts.toList(),
        isCustomPromptSectionSelected: false,   // 默认不选中自定义分类
        isFeaturedSectionSelected: true,        // 默认选中精选分类
        selectedPromptId: visiblePrompts.firstOrNull?.id,
        databaseConfig: null,
        isLoadingCustomPrompts: true,           // 正在加载自定义提示词
        selectedCategory: null,
        favoritePrompts: [],
      ),
    );

    // 异步加载自定义提示词
    loadCustomPrompts();
  }

  /// 加载自定义提示词
  /// 
  /// 从用户配置的数据库中加载自定义提示词
  void loadCustomPrompts() {
    state.maybeMap(
      ready: (readyState) async {
        emit(
          readyState.copyWith(isLoadingCustomPrompts: true),
        );

        // 获取或更新数据库配置
        CustomPromptDatabaseConfig? configuration = readyState.databaseConfig;
        if (configuration == null) {
          // 首次加载，从后端获取配置
          final configResult =
              await AIEventGetCustomPromptDatabaseConfiguration()
                  .send()
                  .toNullable();
          if (configResult != null) {
            final view = await getDatabaseView(configResult.viewId);
            if (view != null) {
              configuration = CustomPromptDatabaseConfig.fromAiPB(
                configResult,
                view,
              );
            }
          }
        } else {
          // 更新现有配置的视图信息
          final view = await getDatabaseView(configuration.view.id);
          if (view != null) {
            configuration = configuration.copyWith(view: view);
          }
        }

        if (configuration == null) {
          emit(
            readyState.copyWith(isLoadingCustomPrompts: false),
          );
          return;
        }

        // 清除旧的自定义提示词
        availablePrompts.removeWhere((prompt) => prompt.isCustom);

        // 从数据库加载新的自定义提示词
        final customPrompts =
            await _aiService.getDatabasePrompts(configuration.toDbPB());

        if (customPrompts == null) {
          final prompts = availablePrompts.where((prompt) => prompt.isFeatured);
          final visiblePrompts = _getFilteredPrompts(prompts);
          final selectedPromptId = _getVisibleSelectedPrompt(
            visiblePrompts,
            readyState.selectedPromptId,
          );

          emit(
            readyState.copyWith(
              visiblePrompts: visiblePrompts.toList(),
              selectedPromptId: selectedPromptId,
              databaseConfig: configuration,
              isLoadingCustomPrompts: false,
              isFeaturedSectionSelected: true,
              isCustomPromptSectionSelected: false,
              selectedCategory: null,
            ),
          );
        } else {
          availablePrompts.addAll(customPrompts);

          final prompts = _getPromptsByCategory(readyState);
          final visiblePrompts = _getFilteredPrompts(prompts);
          final selectedPromptId = _getVisibleSelectedPrompt(
            visiblePrompts,
            readyState.selectedPromptId,
          );

          emit(
            readyState.copyWith(
              visiblePrompts: visiblePrompts.toList(),
              databaseConfig: configuration,
              isLoadingCustomPrompts: false,
              selectedPromptId: selectedPromptId,
            ),
          );
        }
      },
      orElse: () {},
    );
  }

  /// 选择自定义提示词分类
  /// 
  /// 显示所有用户自定义的提示词
  void selectCustomSection() {
    state.maybeMap(
      ready: (readyState) {
        // 筛选自定义提示词
        final prompts = availablePrompts.where((prompt) => prompt.isCustom);
        final visiblePrompts = _getFilteredPrompts(prompts);

        emit(
          readyState.copyWith(
            visiblePrompts: visiblePrompts.toList(),
            selectedPromptId: visiblePrompts.firstOrNull?.id,
            isCustomPromptSectionSelected: true,    // 选中自定义分类
            isFeaturedSectionSelected: false,       // 取消精选分类
            selectedCategory: null,                 // 清空分类选择
          ),
        );
      },
      orElse: () {},
    );
  }

  /// 选择精选提示词分类
  /// 
  /// 显示所有精选的内置提示词
  void selectFeaturedSection() {
    state.maybeMap(
      ready: (readyState) {
        // 筛选精选提示词
        final prompts = availablePrompts.where((prompt) => prompt.isFeatured);
        final visiblePrompts = _getFilteredPrompts(prompts);

        emit(
          readyState.copyWith(
            visiblePrompts: visiblePrompts.toList(),
            selectedPromptId: visiblePrompts.firstOrNull?.id,
            isFeaturedSectionSelected: true,        // 选中精选分类
            isCustomPromptSectionSelected: false,   // 取消自定义分类
            selectedCategory: null,                 // 清空分类选择
          ),
        );
      },
      orElse: () {},
    );
  }

  /// 选择特定分类
  /// 
  /// 按分类筛选提示词（如开发、写作、营销等）
  void selectCategory(AiPromptCategory? category) {
    state.maybeMap(
      ready: (readyState) {
        // 根据分类筛选提示词
        final prompts = category == null
            ? availablePrompts  // 无分类，显示所有
            : availablePrompts
                .where((prompt) => prompt.category.contains(category));
        final visiblePrompts = _getFilteredPrompts(prompts);

        final selectedPromptId = _getVisibleSelectedPrompt(
          visiblePrompts,
          readyState.selectedPromptId,
        );

        emit(
          readyState.copyWith(
            visiblePrompts: visiblePrompts.toList(),
            selectedCategory: category,
            selectedPromptId: selectedPromptId,
            isFeaturedSectionSelected: false,
            isCustomPromptSectionSelected: false,
          ),
        );
      },
      orElse: () {},
    );
  }

  /// 选择具体的提示词
  void selectPrompt(String promptId) {
    state.maybeMap(
      ready: (readyState) {
        // 确认提示词存在于可见列表中
        final selectedPrompt = readyState.visiblePrompts
            .firstWhereOrNull((prompt) => prompt.id == promptId);
        if (selectedPrompt != null) {
          emit(
            readyState.copyWith(selectedPromptId: selectedPrompt.id),
          );
        }
      },
      orElse: () {},
    );
  }

  /// 切换收藏状态
  /// 
  /// 添加或移除提示词的收藏状态
  void toggleFavorite(String promptId) {
    state.maybeMap(
      ready: (readyState) {
        final favoritePrompts = [...readyState.favoritePrompts];
        if (favoritePrompts.contains(promptId)) {
          // 取消收藏
          favoritePrompts.remove(promptId);
        } else {
          // 添加收藏
          favoritePrompts.add(promptId);
        }
        emit(
          readyState.copyWith(favoritePrompts: favoritePrompts),
        );
      },
      orElse: () {},
    );
  }

  /// 重置选择器状态
  /// 
  /// 清空搜索和筛选条件，恢复到初始状态
  void reset() {
    // 清空搜索文本
    filterTextController.clear();
    state.maybeMap(
      ready: (readyState) {
        emit(
          readyState.copyWith(
            visiblePrompts: availablePrompts,
            isCustomPromptSectionSelected: false,   // 恢复到精选分类
            isFeaturedSectionSelected: true,
            selectedPromptId: availablePrompts.firstOrNull?.id,
            selectedCategory: null,                 // 清空分类选择
          ),
        );
      },
      orElse: () {},
    );
  }

  /// 更新自定义提示词数据库配置
  /// 
  /// 当用户选择新的数据库作为提示词来源时调用
  void updateCustomPromptDatabaseConfiguration(
    CustomPromptDatabaseConfig configuration,
  ) async {
    state.maybeMap(
      ready: (readyState) async {
        emit(
          readyState.copyWith(isLoadingCustomPrompts: true),
        );

        // 从新数据库加载提示词
        final customPrompts =
            await _aiService.getDatabasePrompts(configuration.toDbPB());

        if (customPrompts == null) {
          // 数据库格式不正确
          emit(AiPromptSelectorState.invalidDatabase());
          emit(readyState);
          return;
        }

        // 更新可用提示词列表
        availablePrompts
          ..removeWhere((prompt) => prompt.isCustom)  // 移除旧的自定义提示词
          ..addAll(customPrompts);                   // 添加新的自定义提示词

        // 保存配置到后端
        await AIEventSetCustomPromptDatabaseConfiguration(
          configuration.toAiPB(),
        ).send().onFailure(Log.error);

        final prompts = _getPromptsByCategory(readyState);
        final visiblePrompts = _getFilteredPrompts(prompts);
        final selectedPromptId = _getVisibleSelectedPrompt(
          visiblePrompts,
          readyState.selectedPromptId,
        );
        emit(
          readyState.copyWith(
            visiblePrompts: visiblePrompts.toList(),
            selectedPromptId: selectedPromptId,
            databaseConfig: configuration,
            isLoadingCustomPrompts: false,
          ),
        );
      },
      orElse: () => {},
    );
  }

  /// 处理搜索文本变化
  /// 
  /// 根据输入的搜索关键词过滤提示词列表
  void _filterTextChanged() {
    state.maybeMap(
      ready: (readyState) {
        // 获取当前分类下的提示词
        final prompts = _getPromptsByCategory(readyState);
        // 应用搜索过滤
        final visiblePrompts = _getFilteredPrompts(prompts);

        final selectedPromptId = _getVisibleSelectedPrompt(
          visiblePrompts,
          readyState.selectedPromptId,
        );

        emit(
          readyState.copyWith(
            visiblePrompts: visiblePrompts.toList(),
            selectedPromptId: selectedPromptId,
          ),
        );
      },
      orElse: () {},
    );
  }

  /// 根据搜索文本过滤提示词
  /// 
  /// 在提示词名称中搜索关键词
  Iterable<AiPrompt> _getFilteredPrompts(Iterable<AiPrompt> prompts) {
    final filterText = filterTextController.value.text.trim().toLowerCase();

    return prompts.where((prompt) {
      // 注意：这里可能是代码错误，重复了prompt.name
      // 正确的可能应该是"${prompt.name} ${prompt.content}"
      final content = "${prompt.name} ${prompt.name}".toLowerCase();
      return content.contains(filterText);
    }).toList();
  }

  /// 根据当前选择的分类获取提示词
  /// 
  /// 按优先级：具体分类 > 精选/自定义 > 全部
  Iterable<AiPrompt> _getPromptsByCategory(_AiPromptSelectorReadyState state) {
    return availablePrompts.where((prompt) {
      // 先检查是否选择了具体分类
      if (state.selectedCategory != null) {
        return prompt.category.contains(state.selectedCategory);
      }
      // 检查是否选择了精选分类
      if (state.isFeaturedSectionSelected) {
        return prompt.isFeatured;
      }
      // 检查是否选择了自定义分类
      if (state.isCustomPromptSectionSelected) {
        return prompt.isCustom;
      }
      // 默认显示全部
      return true;
    });
  }

  /// 获取可见列表中的选中提示词
  /// 
  /// 如果当前选中的提示词不在可见列表中，默认选择第一个
  String? _getVisibleSelectedPrompt(
    Iterable<AiPrompt> visiblePrompts,
    String? currentlySelectedPromptId,
  ) {
    // 保持当前选中（如果它仍然可见）
    if (visiblePrompts
        .any((prompt) => prompt.id == currentlySelectedPromptId)) {
      return currentlySelectedPromptId;
    }

    // 否则选择第一个可见的提示词
    return visiblePrompts.firstOrNull?.id;
  }

  /// 获取数据库视图
  /// 
  /// 先尝试从正常视图获取，如果失败则从回收站查找
  static Future<ViewPB?> getDatabaseView(String viewId) async {
    // 尝试从正常视图获取
    final view = await ViewBackendService.getView(viewId).toNullable();

    if (view != null) {
      return view;
    }

    // 如果不存在，尝试从回收站查找
    final trashViews = await TrashService().readTrash().toNullable();
    final trashedItem =
        trashViews?.items.firstWhereOrNull((element) => element.id == viewId);

    if (trashedItem == null) {
      return null;
    }

    // 创建一个基本的ViewPB对象
    return ViewPB()
      ..id = trashedItem.id
      ..name = trashedItem.name;
  }
}

/// AI提示词选择器状态
/// 
/// 使用freezed生成的不可变状态类
@freezed
class AiPromptSelectorState with _$AiPromptSelectorState {
  const AiPromptSelectorState._();

  // 加载中状态
  const factory AiPromptSelectorState.loading() = _AiPromptSelectorLoadingState;

  // 数据库无效错误状态
  const factory AiPromptSelectorState.invalidDatabase() =
      _AiPromptSelectorErrorState;

  // 就绪状态
  const factory AiPromptSelectorState.ready({
    // 当前可见的提示词列表（经过筛选和搜索）
    required List<AiPrompt> visiblePrompts,
    // 收藏的提示词ID列表
    required List<String> favoritePrompts,
    // 是否选中自定义分类
    required bool isCustomPromptSectionSelected,
    // 是否选中精选分类
    required bool isFeaturedSectionSelected,
    // 当前选中的分类（可选）
    required AiPromptCategory? selectedCategory,
    // 当前选中的提示词ID（可选）
    required String? selectedPromptId,
    // 是否正在加载自定义提示词
    required bool isLoadingCustomPrompts,
    // 自定义提示词数据库配置（可选）
    required CustomPromptDatabaseConfig? databaseConfig,
  }) = _AiPromptSelectorReadyState;

  // 判断是否在加载中
  bool get isLoading => this is _AiPromptSelectorLoadingState;
  // 判断是否就绪
  bool get isReady => this is _AiPromptSelectorReadyState;

  /// 获取当前选中的提示词对象
  AiPrompt? get selectedPrompt => maybeMap(
        ready: (state) => state.visiblePrompts
            .firstWhereOrNull((prompt) => prompt.id == state.selectedPromptId),
        orElse: () => null,
      );
}
