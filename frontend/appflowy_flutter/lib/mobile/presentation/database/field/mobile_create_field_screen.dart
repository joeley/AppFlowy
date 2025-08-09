// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端应用栏组件
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
// 导入移动端字段编辑器组件
import 'package:appflowy/mobile/presentation/database/field/mobile_full_field_editor.dart';
// 导入字段类型扩展工具
import 'package:appflowy/util/field_type_extension.dart';
// 导入后端字段实体定义
import 'package:appflowy_backend/protobuf/flowy-database2/field_entities.pbenum.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入AppFlowy基础UI组件库
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';
// 导入路由导航库
import 'package:go_router/go_router.dart';

/**
 * 移动端新建字段属性屏幕
 * 
 * 设计思想：
 * 1. 提供一个完整的新建字段的界面
 * 2. 集成字段编辑器，支持字段名称、类型等属性的设置
 * 3. 遵循移动端设计规范，提供友好的用户体验
 * 4. 支持预设字段类型，简化创建流程
 * 
 * 功能特点：
 * - 定制化的应用栏，包含取消和保存操作
 * - 完整的字段编辑器功能
 * - 实时的属性更新和预览
 * - 支持多种字段类型（文本、数字、选择等）
 * 
 * 使用场景：
 * - 在数据库表格中添加新列
 * - 创建自定义字段类型
 * - 设置字段的初始属性
 */
class MobileNewPropertyScreen extends StatefulWidget {
  const MobileNewPropertyScreen({
    super.key,
    required this.viewId,  // 必需的视图 ID，用于确定字段属于哪个视图
    this.fieldType,        // 可选的预设字段类型，用于快速创建特定类型的字段
  });

  final String viewId;        // 视图的唯一标识符
  final FieldType? fieldType; // 预设的字段类型（可选）

  // 路由配置常量
  static const routeName = '/new_property';      // 路由名称
  static const argViewId = 'view_id';           // 视图 ID 参数名
  static const argFieldTypeId = 'field_type_id'; // 字段类型 ID 参数名

  @override
  State<MobileNewPropertyScreen> createState() =>
      _MobileNewPropertyScreenState();
}

class _MobileNewPropertyScreenState extends State<MobileNewPropertyScreen> {
  late FieldOptionValues optionValues; // 字段选项值，存储字段的所有属性信息

  @override
  void initState() {
    super.initState();

    // 使用预设的字段类型，如果没有则默认为富文本类型
    final type = widget.fieldType ?? FieldType.RichText;
    
    // 初始化字段选项值
    optionValues = FieldOptionValues(
      type: type,        // 设置字段类型
      icon: "",          // 初始时没有图标
      name: type.i18n,   // 使用字段类型的国际化名称作为默认名称
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 构建应用栏
      appBar: FlowyAppBar(
        centerTitle: true, // 标题居中显示
        titleText: LocaleKeys.grid_field_newProperty.tr(), // 国际化标题文本
        leadingType: FlowyAppBarLeadingType.cancel,        // 左侧显示取消按钮
        actions: [
          // 右侧显示保存按钮
          _SaveButton(
            onSave: () {
              // 保存时将字段选项值返回给上一个页面
              context.pop(optionValues);
            },
          ),
        ],
      ),
      // 构建主体内容
      body: MobileFieldEditor(
        mode: FieldOptionMode.add,  // 设置为新增模式
        defaultValues: optionValues, // 传入初始值
        // 字段选项变更回调，实时更新局部状态
        onOptionValuesChanged: (optionValues) {
          this.optionValues = optionValues;
        },
      ),
    );
  }
}

/**
 * 私有的保存按钮组件
 * 
 * 设计思想：
 * 1. 封装保存操作的视觉表现和交互逻辑
 * 2. 提供统一的按钮样式和颜色
 * 3. 支持点击交互，触发保存操作
 * 
 * 使用场景：
 * - 作为应用栏右侧的保存按钮
 * - 提供明确的保存操作入口
 */
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onSave, // 保存按钮点击回调函数
  });

  final VoidCallback onSave; // 保存操作回调函数

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 设置右侧内边距，与屏幕边缘保持适当距离
      padding: const EdgeInsets.only(right: 16.0),
      child: Align(
        child: GestureDetector(
          onTap: onSave, // 点击时触发保存操作
          child: FlowyText.medium(
            LocaleKeys.button_save.tr(),        // 国际化的保存文本
            color: const Color(0xFF00ADDC),     // 使用主色色系的蓝色，突出保存操作
          ),
        ),
      ),
    );
  }
}
