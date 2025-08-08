import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/plugins/document/application/document_service.dart';
import 'package:appflowy/user/application/reminder/reminder_extension.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/date_time/time_format_ext.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:time/time.dart';

part 'notification_reminder_bloc.freezed.dart';

/// 通知提醒状态管理器
/// 
/// 主要功能：
/// 1. 处理提醒通知的显示逻辑
/// 2. 获取提醒关联的视图和内容
/// 3. 格式化提醒时间
/// 4. 支持文档和数据库两种类型的提醒
/// 
/// 设计思想：
/// - 根据视图类型不同处理不同的提醒内容
/// - 文档类型：获取具体的文档节点内容
/// - 数据库类型：使用提醒消息本身
/// - 支持定位到具体的文档块（blockId）
class NotificationReminderBloc
    extends Bloc<NotificationReminderEvent, NotificationReminderState> {
  NotificationReminderBloc() : super(NotificationReminderState.initial()) {
    on<NotificationReminderEvent>((event, emit) async {
      await event.when(
        /// 初始化事件处理
        initial: (reminder, dateFormat, timeFormat) async {
          // 保存提醒和格式设置
          this.reminder = reminder;
          this.dateFormat = dateFormat;
          this.timeFormat = timeFormat;

          // 触发重置事件加载数据
          add(const NotificationReminderEvent.reset());
        },
        /// 重置事件处理 - 加载提醒数据
        reset: () async {
          // 获取格式化的计划时间
          final scheduledAt = await _getScheduledAt(
            reminder,
            dateFormat,
            timeFormat,
          );
          // 获取关联的视图
          final view = await _getView(reminder);

          // 视图不存在时返回错误状态
          if (view == null) {
            emit(
              NotificationReminderState(
                scheduledAt: scheduledAt,
                pageTitle: '',
                reminderContent: '',
                isLocked: false,
                status: NotificationReminderStatus.error,
              ),
            );
            return;
          }

          final layout = view.layout;

          // 文档类型提醒 - 获取具体节点内容
          if (layout.isDocumentView) {
            final node = await _getContent(reminder);
            if (node != null) {
              emit(
                NotificationReminderState(
                  scheduledAt: scheduledAt,
                  pageTitle: view.nameOrDefault,
                  isLocked: view.isLocked,
                  view: view,
                  reminderContent: node.delta?.toPlainText() ?? '',
                  nodes: [node],
                  status: NotificationReminderStatus.loaded,
                  blockId: reminder.meta[ReminderMetaKeys.blockId],
                ),
              );
            }
          } 
          // 数据库类型提醒 - 使用消息本身
          else if (layout.isDatabaseView) {
            emit(
              NotificationReminderState(
                scheduledAt: scheduledAt,
                pageTitle: view.nameOrDefault,
                isLocked: view.isLocked,
                view: view,
                reminderContent: reminder.message,
                status: NotificationReminderStatus.loaded,
              ),
            );
          }
        },
      );
    });
  }

  /// 提醒对象
  late final ReminderPB reminder;
  
  /// 日期格式设置
  late final UserDateFormatPB dateFormat;
  
  /// 时间格式设置
  late final UserTimeFormatPB timeFormat;

  /// 获取格式化的计划时间
  /// 
  /// 将Unix时间戳转换为可读的时间字符串
  Future<String> _getScheduledAt(
    ReminderPB reminder,
    UserDateFormatPB dateFormat,
    UserTimeFormatPB timeFormat,
  ) async {
    return _formatTimestamp(
      reminder.scheduledAt.toInt() * 1000, // 转换为毫秒
      timeFormat: timeFormat,
      dateFormate: dateFormat,
    );
  }

  /// 获取提醒关联的视图
  Future<ViewPB?> _getView(ReminderPB reminder) async {
    return ViewBackendService.getView(reminder.objectId)
        .fold((s) => s, (_) => null);
  }

  /// 获取文档提醒的具体内容
  /// 
  /// 根据blockId找到文档中的具体节点
  Future<Node?> _getContent(ReminderPB reminder) async {
    // 从元数据中获取块ID
    final blockId = reminder.meta[ReminderMetaKeys.blockId];

    if (blockId == null) {
      return null;
    }

    // 打开文档
    final document = await DocumentService()
        .openDocument(
          documentId: reminder.objectId,
        )
        .fold((s) => s.toDocument(), (_) => null);

    if (document == null) {
      return null;
    }

    // 在文档树中查找节点
    final node = _searchById(document.root, blockId);

    if (node == null) {
      return null;
    }

    return node;
  }

  /// 递归搜索文档节点
  /// 
  /// 在文档树中递归查找指定ID的节点
  Node? _searchById(Node current, String id) {
    // 找到目标节点
    if (current.id == id) {
      return current;
    }

    // 递归搜索子节点
    if (current.children.isNotEmpty) {
      for (final child in current.children) {
        final node = _searchById(child, id);

        if (node != null) {
          return node;
        }
      }
    }

    return null;
  }

  /// 格式化时间戳
  /// 
  /// 根据时间差显示不同格式：
  /// - 刚刚：一分钟内
  /// - X分钟前：一小时内
  /// - 时间：当天
  /// - 日期：其他
  String _formatTimestamp(
    int timestamp, {
    required UserDateFormatPB dateFormate,
    required UserTimeFormatPB timeFormat,
  }) {
    final now = DateTime.now();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(dateTime);
    final String date;

    if (difference.inMinutes < 1) {
      // 刚刚
      date = LocaleKeys.sideBar_justNow.tr();
    } else if (difference.inHours < 1 && dateTime.isToday) {
      // 一小时内
      date = LocaleKeys.sideBar_minutesAgo
          .tr(namedArgs: {'count': difference.inMinutes.toString()});
    } else if (difference.inHours >= 1 && dateTime.isToday) {
      // 当天
      date = timeFormat.formatTime(dateTime);
    } else {
      // 其他日期
      date = dateFormate.formatDate(dateTime, false);
    }

    return date;
  }
}

/// 通知提醒事件
@freezed
class NotificationReminderEvent with _$NotificationReminderEvent {
  /// 初始化事件
  const factory NotificationReminderEvent.initial(
    ReminderPB reminder,
    UserDateFormatPB dateFormat,
    UserTimeFormatPB timeFormat,
  ) = _Initial;

  /// 重置事件
  const factory NotificationReminderEvent.reset() = _Reset;
}

/// 通知提醒状态枚举
enum NotificationReminderStatus {
  /// 初始状态
  initial,
  /// 加载中
  loading,
  /// 加载完成
  loaded,
  /// 错误状态
  error,
}

/// 通知提醒状态
@freezed
class NotificationReminderState with _$NotificationReminderState {
  const NotificationReminderState._();

  const factory NotificationReminderState({
    /// 计划时间（格式化后）
    required String scheduledAt,
    /// 页面标题
    required String pageTitle,
    /// 提醒内容
    required String reminderContent,
    /// 是否锁定
    required bool isLocked,
    /// 加载状态
    @Default(NotificationReminderStatus.initial)
    NotificationReminderStatus status,
    /// 文档节点列表
    @Default([]) List<Node> nodes,
    /// 文档块ID
    String? blockId,
    /// 关联视图
    ViewPB? view,
  }) = _NotificationReminderState;

  /// 创建初始状态
  factory NotificationReminderState.initial() =>
      const NotificationReminderState(
        scheduledAt: '',
        pageTitle: '',
        reminderContent: '',
        isLocked: false,
      );
}
