/// AI提示词数据库选择器状态管理
/// 
/// 管理自定义提示词数据库的选择和配置
/// 允许用户选择数据库视图并映射字段到提示词属性

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/plugins/database/domain/field_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_prompt_database_selector_cubit.freezed.dart';

/// AI提示词数据库选择器Cubit
/// 
/// 处理提示词数据库配置的业务逻辑，包括：
/// - 选择数据库视图
/// - 配置字段映射（标题、内容、示例、分类）
/// - 验证数据库格式
class AiPromptDatabaseSelectorCubit
    extends Cubit<AiPromptDatabaseSelectorState> {
  AiPromptDatabaseSelectorCubit({
    required CustomPromptDatabaseConfig? configuration,
  }) : super(AiPromptDatabaseSelectorState.loading()) {
    _init(configuration);
  }

  /// 初始化数据库选择器
  /// 
  /// 加载现有配置和字段信息
  void _init(CustomPromptDatabaseConfig? config) async {
    // 无配置时显示空状态
    if (config == null) {
      emit(AiPromptDatabaseSelectorState.empty());
      return;
    }

    // 获取数据库字段
    final fields = await _getFields(config.view.id);

    if (fields == null) {
      emit(AiPromptDatabaseSelectorState.empty());
      return;
    }

    // 发射已选择状态
    emit(
      AiPromptDatabaseSelectorState.selected(
        config: config,
        fields: fields,
      ),
    );
  }

  /// 选择数据库视图
  /// 
  /// 验证并选择一个数据库视图作为提示词源
  void selectDatabaseView(String viewId) async {
    // 测试数据库是否符合提示词格式
    final configuration = await _testDatabase(viewId);

    if (configuration == null) {
      // 数据库格式不正确，显示错误后恢复原状态
      final stateCopy = state;
      emit(AiPromptDatabaseSelectorState.invalidDatabase());
      emit(stateCopy);
      return;
    }

    // 获取视图和字段信息
    final databaseView = await AiPromptSelectorCubit.getDatabaseView(viewId);
    final fields = await _getFields(viewId);

    if (databaseView == null || fields == null) {
      // 无法获取视图或字段，显示错误
      final stateCopy = state;
      emit(AiPromptDatabaseSelectorState.invalidDatabase());
      emit(stateCopy);
      return;
    }

    // 创建配置对象
    final config = CustomPromptDatabaseConfig.fromDbPB(
      configuration,
      databaseView,
    );

    // 发射成功状态
    emit(
      AiPromptDatabaseSelectorState.selected(
        config: config,
        fields: fields,
      ),
    );
  }

  /// 选择内容字段
  /// 
  /// 映射数据库字段到提示词的内容属性
  void selectContentField(String fieldId) {
    final state = this.state;
    // 仅在已选择状态下处理
    if (state is! _Selected) {
      return;
    }

    // 更新内容字段ID
    final config = state.config.copyWith(
      contentFieldId: fieldId,
    );

    emit(
      AiPromptDatabaseSelectorState.selected(
        config: config,
        fields: state.fields,
      ),
    );
  }

  /// 选择示例字段
  /// 
  /// 映射数据库字段到提示词的示例属性（可选）
  void selectExampleField(String? fieldId) {
    final state = this.state;
    // 仅在已选择状态下处理
    if (state is! _Selected) {
      return;
    }

    // 创建新配置，更新示例字段ID
    final config = CustomPromptDatabaseConfig(
      exampleFieldId: fieldId,
      view: state.config.view,
      titleFieldId: state.config.titleFieldId,
      contentFieldId: state.config.contentFieldId,
      categoryFieldId: state.config.categoryFieldId,
    );

    emit(
      AiPromptDatabaseSelectorState.selected(
        config: config,
        fields: state.fields,
      ),
    );
  }

  /// 选择分类字段
  /// 
  /// 映射数据库字段到提示词的分类属性（可选）
  void selectCategoryField(String? fieldId) {
    final state = this.state;
    // 仅在已选择状态下处理
    if (state is! _Selected) {
      return;
    }

    // 创建新配置，更新分类字段ID
    final config = CustomPromptDatabaseConfig(
      categoryFieldId: fieldId,
      view: state.config.view,
      titleFieldId: state.config.titleFieldId,
      contentFieldId: state.config.contentFieldId,
      exampleFieldId: state.config.exampleFieldId,
    );

    emit(
      AiPromptDatabaseSelectorState.selected(
        config: config,
        fields: state.fields,
      ),
    );
  }

  /// 获取数据库字段列表
  /// 
  /// 从后端获取指定视图的所有字段
  Future<List<FieldPB>?> _getFields(String viewId) {
    return FieldBackendService.getFields(viewId: viewId).toNullable();
  }

  /// 测试数据库是否符合提示词格式
  /// 
  /// 验证数据库视图是否包含必需的字段
  /// 返回自动检测的字段映射配置
  Future<CustomPromptDatabaseConfigPB?> _testDatabase(
    String viewId,
  ) {
    return DatabaseEventTestCustomPromptDatabaseConfiguration(
      DatabaseViewIdPB(value: viewId),
    ).send().toNullable();
  }
}

/// AI提示词数据库选择器状态
/// 
/// 使用freezed生成的不可变状态类
@freezed
class AiPromptDatabaseSelectorState with _$AiPromptDatabaseSelectorState {
  // 加载中状态
  const factory AiPromptDatabaseSelectorState.loading() = _Loading;

  // 空状态（未选择数据库）
  const factory AiPromptDatabaseSelectorState.empty() = _Empty;

  // 已选择状态
  const factory AiPromptDatabaseSelectorState.selected({
    // 数据库配置
    required CustomPromptDatabaseConfig config,
    // 可用字段列表
    required List<FieldPB> fields,
  }) = _Selected;

  // 无效数据库错误状态
  const factory AiPromptDatabaseSelectorState.invalidDatabase() =
      _InvalidDatabase;
}
