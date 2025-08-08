import 'package:appflowy/mobile/application/page_style/document_page_style_bloc.dart';
import 'package:appflowy/plugins/document/application/document_listener.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/plugins.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../shared/icon_emoji_picker/flowy_icon_emoji_picker.dart';

part 'recent_view_bloc.freezed.dart';

/// 最近访问视图状态管理器
/// 
/// 主要功能：
/// 1. 管理最近访问视图的显示状态
/// 2. 监听视图更新（名称、图标、封面）
/// 3. 处理文档封面的兼容性（V1和V2版本）
/// 4. 同步更新视图元数据
/// 
/// 设计思想：
/// - 监听文档和视图两个层面的变化
/// - 支持不同版本的封面格式（兼容性考虑）
/// - 只有文档类型支持封面功能
/// - 实时同步视图的名称和图标变化
class RecentViewBloc extends Bloc<RecentViewEvent, RecentViewState> {
  RecentViewBloc({
    required this.view,
  })  : _documentListener = DocumentListener(id: view.id),
        _viewListener = ViewListener(viewId: view.id),
        super(RecentViewState.initial()) {
    on<RecentViewEvent>(
      (event, emit) async {
        await event.when(
          /// 初始化事件处理
          initial: () async {
            // 监听文档更新，主要处理V1版本的封面
            _documentListener.start(
              onDocEventUpdate: (docEvent) async {
                // 如果已有V2版本封面，不处理V1
                if (state.coverTypeV2 != null) {
                  return;
                }
                // 获取V1版本封面信息
                final (coverType, coverValue) = await getCoverV1();
                add(
                  RecentViewEvent.updateCover(
                    coverType,
                    null,
                    coverValue,
                  ),
                );
              },
            );
            // 监听视图更新
            _viewListener.start(
              onViewUpdated: (view) {
                // 更新名称和图标
                add(
                  RecentViewEvent.updateNameOrIcon(
                    view.name,
                    view.icon.toEmojiIconData(),
                  ),
                );

                // 如果有额外数据，更新V2版本封面
                if (view.extra.isNotEmpty) {
                  final cover = view.cover;
                  add(
                    RecentViewEvent.updateCover(
                      CoverType.none,
                      cover?.type,
                      cover?.value,
                    ),
                  );
                }
              },
            );

            // 只有文档类型支持封面
            if (view.layout != ViewLayoutPB.Document) {
              emit(
                state.copyWith(
                  name: view.name,
                  icon: view.icon.toEmojiIconData(),
                ),
              );
            }

            // 获取V2版本封面
            final cover = getCoverV2();

            if (cover != null) {
              // 使用V2版本封面
              emit(
                state.copyWith(
                  name: view.name,
                  icon: view.icon.toEmojiIconData(),
                  coverTypeV2: cover.type,
                  coverValue: cover.value,
                ),
              );
            } else {
              // 回退到V1版本封面
              final (coverTypeV1, coverValue) = await getCoverV1();
              emit(
                state.copyWith(
                  name: view.name,
                  icon: view.icon.toEmojiIconData(),
                  coverTypeV1: coverTypeV1,
                  coverValue: coverValue,
                ),
              );
            }
          },
          /// 更新名称或图标
          updateNameOrIcon: (name, icon) {
            emit(
              state.copyWith(
                name: name,
                icon: icon,
              ),
            );
          },
          /// 更新封面信息
          updateCover: (coverTypeV1, coverTypeV2, coverValue) {
            emit(
              state.copyWith(
                coverTypeV1: coverTypeV1,
                coverTypeV2: coverTypeV2,
                coverValue: coverValue,
              ),
            );
          },
        );
      },
    );
  }

  /// 视图对象
  final ViewPB view;
  
  /// 文档监听器
  final DocumentListener _documentListener;
  
  /// 视图监听器
  final ViewListener _viewListener;

  /// 获取V2版本封面（0.5.5版本以上）
  PageStyleCover? getCoverV2() {
    return view.cover;
  }

  /// 获取V1版本封面（0.5.5版本及以下）
  /// 
  /// 为了兼容旧版本，保留此方法
  Future<(CoverType, String?)> getCoverV1() async {
    return (CoverType.none, null);
  }

  @override
  Future<void> close() async {
    await _documentListener.stop();
    await _viewListener.stop();
    return super.close();
  }
}

/// 最近访问视图事件
@freezed
class RecentViewEvent with _$RecentViewEvent {
  /// 初始化事件
  const factory RecentViewEvent.initial() = Initial;

  /// 更新封面事件
  const factory RecentViewEvent.updateCover(
    CoverType coverTypeV1, // 0.5.5版本及以下使用
    PageStyleCoverImageType? coverTypeV2, // 0.5.5版本以上使用
    String? coverValue,
  ) = UpdateCover;

  /// 更新名称或图标事件
  const factory RecentViewEvent.updateNameOrIcon(
    String name,
    EmojiIconData icon,
  ) = UpdateNameOrIcon;
}

/// 最近访问视图状态
@freezed
class RecentViewState with _$RecentViewState {
  const factory RecentViewState({
    /// 视图名称
    required String name,
    /// 视图图标
    required EmojiIconData icon,
    /// V1版本封面类型（兼容旧版本）
    @Default(CoverType.none) CoverType coverTypeV1,
    /// V2版本封面类型（新版本）
    PageStyleCoverImageType? coverTypeV2,
    /// 封面值（URL或路径）
    @Default(null) String? coverValue,
  }) = _RecentViewState;

  /// 创建初始状态
  factory RecentViewState.initial() =>
      RecentViewState(name: '', icon: EmojiIconData.none());
}
