// 导入移动端应用栏组件
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
// 导入移动端日历事件空状态组件
import 'package:appflowy/mobile/presentation/database/mobile_calendar_events_empty.dart';
// 导入数据库行缓存管理类
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
// 导入日历功能的Bloc状态管理
import 'package:appflowy/plugins/database/calendar/application/calendar_bloc.dart';
// 导入日历事件卡片组件
import 'package:appflowy/plugins/database/calendar/presentation/calendar_event_card.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端日历事件列表屏幕
/// 
/// 这是AppFlowy日历视图的移动端子页面，专门用于显示指定日期的所有事件。
/// 设计思想：
/// 1. 展示特定日期的所有日历事件，方便用户查看当日详情
/// 2. 集成浮动操作按钮，可快速创建新事件
/// 3. 实时监听新事件的创建，动态更新列表
/// 4. 支持空状态显示，提供友好的用户体验
/// 
/// 主要功能：
/// - 显示指定日期的所有事件
/// - 快速创建新事件
/// - 实时事件更新
/// - 空状态处理
class MobileCalendarEventsScreen extends StatefulWidget {
  const MobileCalendarEventsScreen({
    super.key,
    required this.calendarBloc,
    required this.date,
    required this.events,
    required this.rowCache,
    required this.viewId,
  });

  /// 日历Bloc状态管理器，管理日历事件的业务逻辑
  final CalendarBloc calendarBloc;
  /// 当前显示的日期，用于筛选当日事件
  final DateTime date;
  /// 当日的日历事件列表
  final List<CalendarDayEvent> events;
  /// 数据库行数据缓存，用于高效的数据访问
  final RowCache rowCache;
  /// 日历视图的唯一标识符
  final String viewId;

  /// 路由名称，用于导航系统
  static const routeName = '/calendar_events';

  /// GoRouter路由参数键名定义
  static const calendarBlocKey = 'calendar_bloc';
  static const calendarDateKey = 'date';
  static const calendarEventsKey = 'events';
  static const calendarRowCacheKey = 'row_cache';
  static const calendarViewIdKey = 'view_id';

  @override
  State<MobileCalendarEventsScreen> createState() =>
      _MobileCalendarEventsScreenState();
}

/// 移动端日历事件屏幕的状态管理类
class _MobileCalendarEventsScreenState
    extends State<MobileCalendarEventsScreen> {
  /// 局部事件列表，初始化为传入的事件数据，可动态更新
  late final List<CalendarDayEvent> _events = widget.events;

  /// 构建屏幕的主UI结构
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 浮动操作按钮，用于快速创建新事件
      floatingActionButton: FloatingActionButton(
        // 为测试和自动化提供的唯一标识
        key: const Key('add_event_fab'),
        elevation: 6,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        // 点击时发送创建事件的指令到CalendarBloc
        onPressed: () =>
            widget.calendarBloc.add(CalendarEvent.createEvent(widget.date)),
        // 显示加号图标
        child: const Text('+'),
      ),
      // 应用栏，显示当前日期
      appBar: FlowyAppBar(
        // 使用本地化日期格式显示当前日期
        titleText: DateFormat.yMMMMd(context.locale.toLanguageTag())
            .format(widget.date),
      ),
      // 主体内容，传入CalendarBloc实例
      body: BlocProvider<CalendarBloc>.value(
        // 传入已存在的CalendarBloc实例
        value: widget.calendarBloc,
        // 使用BlocBuilder监听状态变化
        child: BlocBuilder<CalendarBloc, CalendarState>(
          // 只有当新事件发生变化且新事件的日期与当前日期匹配时才重建
          buildWhen: (p, c) =>
              p.newEvent != c.newEvent &&
              c.newEvent?.date.withoutTime == widget.date,
          // 构建事件列表UI
          builder: (context, state) {
            // 如果有新事件且不在现有列表中且日期匹配，则添加到列表
            if (state.newEvent?.event != null &&
                _events
                    .none((e) => e.eventId == state.newEvent!.event!.eventId) &&
                state.newEvent!.date.withoutTime == widget.date) {
              _events.add(state.newEvent!.event!);
            }

            // 如果没有事件，显示空状态组件
            if (_events.isEmpty) {
              return const MobileCalendarEventsEmpty();
            }

            // 返回可滚动的事件列表
            return SingleChildScrollView(
              // 主体列表容器
              child: Column(
                // 列表内容
                children: [
                  // 顶部间距
                  const VSpace(10),
                  // 将事件列表映射为事件卡片组件
                  ..._events.map((event) {
                    // 创建事件卡片组件
                    return EventCard(
                      // 传入数据库控制器
                      databaseController:
                          widget.calendarBloc.databaseController,
                      // 传入事件数据
                      event: event,
                      // 设置布局约束
                      constraints: const BoxConstraints.expand(),
                      // 禁用自动编辑模式
                      autoEdit: false,
                      // 禁用拖拽功能
                      isDraggable: false,
                      // 设置卡片内边距
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                    );
                  }),
                  // 底部间距，给浮动按钮留出空间
                  const VSpace(24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
