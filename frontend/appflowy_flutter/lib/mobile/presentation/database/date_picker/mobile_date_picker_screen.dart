// 导入本地化键值对，用于多语言支持
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
import 'package:appflowy/plugins/base/drag_handler.dart';
import 'package:appflowy/plugins/database/application/cell/bloc/date_cell_editor_bloc.dart';
import 'package:appflowy/plugins/database/application/cell/cell_controller_builder.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/mobile_date_picker.dart';
import 'package:appflowy/workspace/presentation/widgets/date_picker/widgets/mobile_date_header.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 移动端日期单元格编辑屏幕
/// 
/// 这是AppFlowy移动端数据库功能中的核心组件之一，专门用于编辑数据库表格中的日期类型单元格。
/// 设计思想：
/// 1. 支持全屏和非全屏两种显示模式，适应不同的使用场景
/// 2. 使用Bloc架构管理状态，实现业务逻辑与UI的分离
/// 3. 集成提醒功能，用户可以为日期设置提醒
/// 4. 支持日期范围选择和时间选择，提供完整的日期时间编辑能力
/// 
/// 主要功能：
/// - 单日期选择
/// - 日期范围选择  
/// - 时间选择开关
/// - 提醒设置
/// - 清除日期功能
class MobileDateCellEditScreen extends StatefulWidget {
  const MobileDateCellEditScreen({
    super.key,
    required this.controller,
    this.showAsFullScreen = true,
  });

  /// 日期单元格控制器，负责处理日期数据的读取和保存
  final DateCellController controller;
  /// 是否以全屏模式显示，默认为true
  /// true: 使用Scaffold全屏显示
  /// false: 使用DraggableScrollableSheet底部弹窗显示
  final bool showAsFullScreen;

  /// 路由名称，用于导航系统
  static const routeName = '/edit_date_cell';

  /// GoRouter路由参数键名 - 日期单元格控制器
  /// 类型：DateCellController
  static const dateCellController = 'date_cell_controller';

  /// GoRouter路由参数键名 - 是否全屏显示
  /// 类型：bool，默认值为true
  static const fullScreen = 'full_screen';

  @override
  State<MobileDateCellEditScreen> createState() =>
      _MobileDateCellEditScreenState();
}

/// 移动端日期单元格编辑屏幕的状态管理类
class _MobileDateCellEditScreenState extends State<MobileDateCellEditScreen> {
  /// 构建UI的主入口方法
  /// 根据showAsFullScreen属性决定使用全屏还是底部弹窗模式
  @override
  Widget build(BuildContext context) =>
      widget.showAsFullScreen ? _buildFullScreen() : _buildNotFullScreen();

  /// 构建全屏模式的UI
  /// 使用Scaffold作为容器，包含应用栏和日期选择器
  Widget _buildFullScreen() {
    return Scaffold(
      appBar: FlowyAppBar(titleText: LocaleKeys.titleBar_date.tr()),
      body: _buildDatePicker(),
    );
  }

  /// 构建非全屏模式的UI（底部弹窗模式）
  /// 使用DraggableScrollableSheet创建可拖拽的底部弹窗
  Widget _buildNotFullScreen() {
    return DraggableScrollableSheet(
      expand: false,
      snap: true,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      snapSizes: const [0.4, 0.7, 1.0],
      builder: (_, controller) => Material(
        color: Colors.transparent,
        child: ListView(
          controller: controller,
          children: [
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: DragHandle()),
            ),
            const MobileDateHeader(),
            _buildDatePicker(),
          ],
        ),
      ),
    );
  }

  /// 构建日期选择器组件
  /// 这是整个屏幕的核心组件，集成了Bloc状态管理
  Widget _buildDatePicker() {
    return BlocProvider(
      create: (_) => DateCellEditorBloc(
        reminderBloc: getIt<ReminderBloc>(),
        cellController: widget.controller,
      ),
      child: BlocBuilder<DateCellEditorBloc, DateCellEditorState>(
        builder: (context, state) {
          final dateCellBloc = context.read<DateCellEditorBloc>();
          return MobileAppFlowyDatePicker(
            dateTime: state.dateTime,
            endDateTime: state.endDateTime,
            isRange: state.isRange,
            includeTime: state.includeTime,
            dateFormat: state.dateTypeOptionPB.dateFormat,
            timeFormat: state.dateTypeOptionPB.timeFormat,
            reminderOption: state.reminderOption,
            onDaySelected: (selectedDay) {
              dateCellBloc.add(DateCellEditorEvent.updateDateTime(selectedDay));
            },
            onRangeSelected: (start, end) {
              dateCellBloc.add(DateCellEditorEvent.updateDateRange(start, end));
            },
            onIsRangeChanged: (value, dateTime, endDateTime) {
              dateCellBloc.add(
                DateCellEditorEvent.setIsRange(value, dateTime, endDateTime),
              );
            },
            onIncludeTimeChanged: (value, dateTime, endDateTime) {
              dateCellBloc.add(
                DateCellEditorEvent.setIncludeTime(
                  value,
                  dateTime,
                  endDateTime,
                ),
              );
            },
            onClearDate: () {
              dateCellBloc.add(const DateCellEditorEvent.clearDate());
            },
            onReminderSelected: (option) {
              dateCellBloc.add(DateCellEditorEvent.setReminderOption(option));
            },
          );
        },
      ),
    );
  }
}
