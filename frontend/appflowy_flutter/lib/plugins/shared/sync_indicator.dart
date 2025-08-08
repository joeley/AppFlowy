import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/application/sync/database_sync_bloc.dart';
import 'package:appflowy/plugins/document/application/document_sync_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-document/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/flowy_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 文档同步指示器 - 显示文档的同步状态
/// 
/// 主要功能：
/// 1. 实时显示文档同步状态
/// 2. 不同状态显示不同颜色
/// 3. 悬停显示详细信息
/// 
/// 状态颜色：
/// - 绿色：已同步
/// - 黄色：同步中
/// - 灰色：无网络连接
class DocumentSyncIndicator extends StatelessWidget {
  const DocumentSyncIndicator({
    super.key,
    required this.view, // 视图对象
  });

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 创建文档同步BLoC并初始化
      create: (context) =>
          DocumentSyncBloc(view: view)..add(const DocumentSyncEvent.initial()),
      child: BlocBuilder<DocumentSyncBloc, DocumentSyncBlocState>(
        builder: (context, state) {
          // 本地用户不显示同步指示器
          if (!state.shouldShowIndicator) {
            return const SizedBox.shrink();
          }
          final Color color;
          final String hintText;

          // 根据网络和同步状态设置颜色和提示文本
          if (!state.isNetworkConnected) {
            // 无网络连接
            color = Colors.grey;
            hintText = LocaleKeys.newSettings_syncState_noNetworkConnected.tr();
          } else {
            switch (state.syncState) {
              case DocumentSyncState.SyncFinished:
                // 同步完成
                color = Colors.green;
                hintText = LocaleKeys.newSettings_syncState_synced.tr();
                break;
              case DocumentSyncState.Syncing:
              case DocumentSyncState.InitSyncBegin:
                // 同步中
                color = Colors.yellow;
                hintText = LocaleKeys.newSettings_syncState_syncing.tr();
                break;
              default:
                return const SizedBox.shrink();
            }
          }

          // 返回圆形指示器带悬停提示
          return FlowyTooltip(
            message: hintText, // 悬停提示文本
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, // 圆形
                color: color,           // 状态颜色
              ),
              width: 8,
              height: 8,
            ),
          );
        },
      ),
    );
  }
}

/// 数据库同步指示器 - 显示数据库的同步状态
/// 
/// 与DocumentSyncIndicator类似，但针对数据库视图
/// 使用DatabaseSyncBloc代替DocumentSyncBloc
class DatabaseSyncIndicator extends StatelessWidget {
  const DatabaseSyncIndicator({
    super.key,
    required this.view, // 数据库视图
  });

  final ViewPB view;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // 创建数据库同步BLoC并初始化
      create: (context) =>
          DatabaseSyncBloc(view: view)..add(const DatabaseSyncEvent.initial()),
      child: BlocBuilder<DatabaseSyncBloc, DatabaseSyncBlocState>(
        builder: (context, state) {
          // 本地用户不显示同步指示器
          if (!state.shouldShowIndicator) {
            return const SizedBox.shrink();
          }
          final Color color;
          final String hintText;

          // 根据网络和同步状态设置颜色和提示文本
          if (!state.isNetworkConnected) {
            // 无网络连接
            color = Colors.grey;
            hintText = LocaleKeys.newSettings_syncState_noNetworkConnected.tr();
          } else {
            switch (state.syncState) {
              case DatabaseSyncState.SyncFinished:
                // 同步完成
                color = Colors.green;
                hintText = LocaleKeys.newSettings_syncState_synced.tr();
                break;
              case DatabaseSyncState.Syncing:
              case DatabaseSyncState.InitSyncBegin:
                // 同步中
                color = Colors.yellow;
                hintText = LocaleKeys.newSettings_syncState_syncing.tr();
                break;
              default:
                return const SizedBox.shrink();
            }
          }

          // 返回圆形指示器带悬停提示
          return FlowyTooltip(
            message: hintText, // 悬停提示文本
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle, // 圆形
                color: color,           // 状态颜色
              ),
              width: 8,
              height: 8,
            ),
          );
        },
      ),
    );
  }
}
