/// AppFlowy移动端字段选择器列表组件
/// 
/// 这个文件实现了一个可滚动的字段选择器界面，
/// 用于在数据库的各种操作中选择字段（比如排序、筛选等）

import 'package:appflowy/mobile/presentation/base/app_bar/app_bar_actions.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_option_tile.dart';
import 'package:appflowy/plugins/base/drag_handler.dart';
import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_info.dart';
import 'package:appflowy/plugins/database/grid/presentation/widgets/header/desktop_field_cell.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 移动端字段选择器列表组件
/// 
/// 这个组件提供了一个类似于底部弹窗的界面，用于选择数据库中的字段。
/// 主要特点：
/// - 使用DraggableScrollableSheet实现可拖拽尺寸的底部弹窗
/// - 支持通过filterBy函数过滤特定类型的字段
/// - 提供完整的选择交互体验（单选、确认、取消）
/// - 适配移动端的触摸交互模式
/// 
/// 设计思想：
/// - 采用构建时过滤的方式，避免运行时重复过滤
/// - 使用StatefulWidget管理选中状态，支持选择变更
/// - 提供类型安全的API设计
class MobileFieldPickerList extends StatefulWidget {
  MobileFieldPickerList({
    super.key,
    required this.title,              // 弹窗标题
    required this.selectedFieldId,    // 当前选中的字段ID
    required FieldController fieldController, // 字段控制器
    required bool Function(FieldInfo fieldInfo) filterBy, // 字段过滤条件
  }) : fields = fieldController.fieldInfos.where(filterBy).toList(); // 构建时过滤字段列表

  /// 弹窗标题文本
  final String title;
  
  /// 当前选中的字段ID，可能为空
  final String? selectedFieldId;
  
  /// 过滤后的字段列表
  final List<FieldInfo> fields;

  @override
  State<MobileFieldPickerList> createState() => _MobileFieldPickerListState();
}

/// 字段选择器的状态类
/// 管理用户的选择状态
class _MobileFieldPickerListState extends State<MobileFieldPickerList> {
  /// 新选中的字段ID，用于跟踪用户的当前选择
  String? newFieldId;

  @override
  void initState() {
    super.initState();
    // 初始化时设置为当前选中的字段ID
    newFieldId = widget.selectedFieldId;
  }

  /// 构建字段选择器的UI
  /// 使用DraggableScrollableSheet实现可拖拽的底部弹窗
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,            // 不展开到全屏
      snap: true,               // 开启吸附效果
      initialChildSize: 0.98,   // 初始大小为屏幕的98%
      minChildSize: 0.98,       // 最小大小
      maxChildSize: 0.98,       // 最大大小
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min, // 列高度自适应
          children: [
            const DragHandle(), // 拖拽手柄
            // 自定义头部，包含返回按钮、标题和完成按钮
            _Header(
              title: widget.title,
              onDone: (context) => context.pop(newFieldId), // 完成时返回选中的字段ID
            ),
            // 可滚动的字段列表
            SingleChildScrollView(
              controller: scrollController, // 使用DraggableScrollableSheet提供的滚动控制器
              child: ListView.builder(
                shrinkWrap: true,                    // 高度自适应内容
                itemCount: widget.fields.length,     // 列表项数量
                itemBuilder: (context, index) => _FieldButton(
                  field: widget.fields[index],       // 当前字段信息
                  showTopBorder: index == 0,         // 第一个项显示上边框
                  isSelected: widget.fields[index].id == newFieldId, // 是否选中
                  onSelect: (fieldId) => setState(() => newFieldId = fieldId), // 选中回调
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 自定义头部组件
/// 
/// 类似于showMobileBottomSheet中的头部，但允许在关闭弹窗时返回一个值。
/// 包含返回按钮、标题和完成按钮的横向布局。
class _Header extends StatelessWidget {
  const _Header({
    required this.title,   // 头部标题文本
    required this.onDone,  // 点击完成按钮的回调
  });

  /// 头部标题文本
  final String title;
  
  /// 点击完成按钮的回调函数
  final void Function(BuildContext context) onDone;

  /// 构建头部UI
  /// 使用Stack实现按钮和标题的绝对定位
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0), // 底部间距
      child: SizedBox(
        height: 44.0,        // 固定头部高度
        child: Stack(
          children: [
            // 左侧返回按钮
            const Align(
              alignment: Alignment.centerLeft,
              child: AppBarBackButton(),
            ),
            // 中间标题
            Align(
              child: FlowyText.medium(
                title,
                fontSize: 16.0,
              ),
            ),
            // 右侧完成按钮
            Align(
              alignment: Alignment.centerRight,
              child: AppBarDoneButton(
                onTap: () => onDone(context), // 执行完成操作
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 字段按钮组件
/// 
/// 用于显示单个字段的选择按钮，包含字段图标、名称和选中状态。
/// 使用FlowyOptionTile.checkbox实现统一的选项样式。
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.field,          // 字段信息对象
    required this.isSelected,     // 是否选中状态
    required this.onSelect,       // 选中回调函数
    required this.showTopBorder,  // 是否显示上边框
  });

  /// 字段信息对象，包含字段的所有元数据
  final FieldInfo field;
  
  /// 当前字段是否处于选中状态
  final bool isSelected;
  
  /// 选中字段时的回调函数，传入字段ID
  final void Function(String fieldId) onSelect;
  
  /// 是否显示上边框（通常只有第一个项显示）
  final bool showTopBorder;

  /// 构建字段按钮的UI
  /// 使用FlowyOptionTile.checkbox实现统一的选项样式
  @override
  Widget build(BuildContext context) {
    return FlowyOptionTile.checkbox(
      text: field.name,                    // 字段名称
      isSelected: isSelected,              // 选中状态
      leftIcon: FieldIcon(                // 左侧字段类型图标
        fieldInfo: field,
        dimension: 20,                     // 图标尺寸 20x20
      ),
      showTopBorder: showTopBorder,       // 是否显示上边框
      onTap: () => onSelect(field.id),    // 点击时调用选中回调
    );
  }
}
