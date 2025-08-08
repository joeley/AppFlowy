import 'dart:convert';

import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:collection/collection.dart';

/// 收藏服务 - 负责处理收藏相关的后端交互
/// 
/// 主要功能：
/// 1. 读取收藏列表
/// 2. 切换收藏状态
/// 3. 固定/取消固定收藏项
/// 
/// 设计思想：
/// - 通过extra字段存储固定状态
/// - 过滤掉Space类型的视图（工作区空间）
/// - 使用JSON序列化存储额外信息
class FavoriteService {
  /// 读取收藏列表
  /// 
  /// 返回：收藏视图列表，已过滤掉Space类型
  Future<FlowyResult<RepeatedFavoriteViewPB, FlowyError>> readFavorites() {
    final result = FolderEventReadFavorites().send();
    return result.then((result) {
      return result.fold(
        (favoriteViews) {
          // 过滤掉Space类型的视图
          // Space是工作区空间，不应该出现在收藏列表中
          return FlowyResult.success(
            RepeatedFavoriteViewPB(
              items: favoriteViews.items.where((e) => !e.item.isSpace),
            ),
          );
        },
        (error) => FlowyResult.failure(error),
      );
    });
  }

  /// 切换收藏状态
  /// 
  /// 参数：
  /// - [viewId]: 视图ID
  /// 
  /// 返回：操作结果
  Future<FlowyResult<void, FlowyError>> toggleFavorite(String viewId) async {
    final id = RepeatedViewIdPB.create()..items.add(viewId);
    return FolderEventToggleFavorite(id).send();
  }

  /// 固定收藏项
  /// 固定的收藏项会显示在收藏列表顶部
  Future<FlowyResult<void, FlowyError>> pinFavorite(ViewPB view) async {
    return pinOrUnpinFavorite(view, true);
  }

  /// 取消固定收藏项
  Future<FlowyResult<void, FlowyError>> unpinFavorite(ViewPB view) async {
    return pinOrUnpinFavorite(view, false);
  }

  /// 固定或取消固定收藏项
  /// 
  /// 参数：
  /// - [view]: 视图对象
  /// - [isPinned]: true表示固定，false表示取消固定
  /// 
  /// 实现方式：
  /// 通过更新视图的extra字段来存储固定状态
  Future<FlowyResult<void, FlowyError>> pinOrUnpinFavorite(
    ViewPB view,
    bool isPinned,
  ) async {
    try {
      // 解析当前的extra数据
      final current =
          view.extra.isNotEmpty ? jsonDecode(view.extra) : <String, dynamic>{};
      // 合并新的固定状态
      final merged = mergeMaps(
        current,
        <String, dynamic>{ViewExtKeys.isPinnedKey: isPinned},
      );
      // 更新视图的extra字段
      await ViewBackendService.updateView(
        viewId: view.id,
        extra: jsonEncode(merged),
      );
    } catch (e) {
      return FlowyResult.failure(FlowyError(msg: 'Failed to pin favorite: $e'));
    }

    return FlowyResult.success(null);
  }
}
