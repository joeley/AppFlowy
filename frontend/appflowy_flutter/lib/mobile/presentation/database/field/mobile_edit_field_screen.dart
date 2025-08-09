// 导入国际化键值定义
import 'package:appflowy/generated/locale_keys.g.dart';
// 导入移动端应用栏组件
import 'package:appflowy/mobile/presentation/base/app_bar/app_bar.dart';
// 导入移动端字段编辑器组件
import 'package:appflowy/mobile/presentation/database/field/mobile_full_field_editor.dart';
// 导入字段信息数据结构
import 'package:appflowy/plugins/database/application/field/field_info.dart';
// 导入字段后端服务
import 'package:appflowy/plugins/database/domain/field_backend_service.dart';
// 导入字段通用服务
import 'package:appflowy/plugins/database/domain/field_service.dart';
// 导入字段可见性扩展工具
import 'package:appflowy/plugins/database/widgets/setting/field_visibility_extension.dart';
// 导入国际化支持库
import 'package:easy_localization/easy_localization.dart';
// 导入Flutter Material设计组件
import 'package:flutter/material.dart';
// 导入路由导航库
import 'package:go_router/go_router.dart';

/**
 * 移动端编辑字段属性屏幕
 * 
 * 设计思想：
 * 1. 提供一个完整的字段编辑界面，支持字段的全部属性修改
 * 2. 集成多种字段操作：编辑、隐藏/显示、复制、删除
 * 3. 实时同步更新到后端，确保数据一致性
 * 4. 支持PopScope处理，保证数据安全返回
 * 5. 区分主字段和普通字段，防止误操作
 * 
 * 功能特点：
 * - 字段名称和类型的修改
 * - 字段类型特定属性的设置
 * - 字段可见性管理
 * - 字段复制和删除操作
 * - 实时预览和保存
 * 
 * 使用场景：
 * - 修改现有字段的名称或类型
 * - 调整字段的显示属性
 * - 管理数据库表格的列结构
 */
class MobileEditPropertyScreen extends StatefulWidget {
  const MobileEditPropertyScreen({
    super.key,
    required this.viewId, // 必需的视图 ID，用于确定字段属于哪个视图
    required this.field,  // 必需的字段信息，包含字段的所有属性和元数据
  });

  final String viewId;   // 视图的唯一标识符
  final FieldInfo field; // 要编辑的字段信息对象

  // 路由配置常量
  static const routeName = '/edit_property'; // 路由名称
  static const argViewId = 'view_id';        // 视图 ID 参数名
  static const argField = 'field';           // 字段对象参数名

  @override
  State<MobileEditPropertyScreen> createState() =>
      _MobileEditPropertyScreenState();
}

class _MobileEditPropertyScreenState extends State<MobileEditPropertyScreen> {
  late final FieldBackendService fieldService; // 字段后端服务，处理与后端的数据交互
  late FieldOptionValues _fieldOptionValues;   // 当前的字段选项值，存储编辑中的属性

  @override
  void initState() {
    super.initState();
    
    // 从现有字段创建字段选项值
    _fieldOptionValues = FieldOptionValues.fromField(field: widget.field.field);
    
    // 初始化后端服务，绑定当前视图和字段
    fieldService = FieldBackendService(
      viewId: widget.viewId,
      fieldId: widget.field.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 缓存常用的ID值，提高可读性
    final viewId = widget.viewId;
    final fieldId = widget.field.id;

    // 使用PopScope处理返回操作，确保数据安全返回
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // 如果还没有完成pop操作，手动返回编辑后的值
        if (!didPop) {
          context.pop(_fieldOptionValues);
        }
      },
      child: Scaffold(
        // 构建应用栏
        appBar: FlowyAppBar(
          titleText: LocaleKeys.grid_field_editProperty.tr(), // 国际化标题文本
          onTapLeading: () => context.pop(_fieldOptionValues), // 点击返回时携带编辑结果
        ),
        // 构建主体内容
        body: MobileFieldEditor(
          mode: FieldOptionMode.edit,  // 设置为编辑模式
          isPrimary: widget.field.isPrimary, // 标记是否为主字段（影响操作权限）
          defaultValues: FieldOptionValues.fromField(field: widget.field.field), // 设置默认值
          // 根据字段状态配置可用的操作
          actions: [
            // 根据当前可见性状态决定显示隐藏还是显示操作
            widget.field.visibility?.isVisibleState() ?? true
                ? FieldOptionAction.hide  // 当前可见，显示隐藏操作
                : FieldOptionAction.show, // 当前隐藏，显示显示操作
            FieldOptionAction.duplicate, // 复制操作
            FieldOptionAction.delete,    // 删除操作
          ],
          // 字段选项变更回调，实时同步到后端
          onOptionValuesChanged: (fieldOptionValues) async {
            // 更新字段名称
            await fieldService.updateField(name: fieldOptionValues.name);

            // 更新字段类型
            await FieldBackendService.updateFieldType(
              viewId: widget.viewId,
              fieldId: widget.field.id,
              fieldType: fieldOptionValues.type,
            );

            // 更新字段类型特定的选项数据
            final data = fieldOptionValues.getTypeOptionData();
            if (data != null) {
              await FieldBackendService.updateFieldTypeOption(
                viewId: widget.viewId,
                fieldId: widget.field.id,
                typeOptionData: data,
              );
            }
            
            // 更新局部状态
            setState(() {
              _fieldOptionValues = fieldOptionValues;
            });
          },
          // 字段操作回调，处理删除、复制、隐藏/显示等操作
          onAction: (action) {
            // 创建字段服务实例
            final service = FieldServices(
              viewId: viewId,
              fieldId: fieldId,
            );
            
            // 根据操作类型执行相应的处理逻辑
            switch (action) {
              case FieldOptionAction.delete:
                // 删除操作：删除后直接返回，不携带数据
                fieldService.delete();
                context.pop();
                return; // 提前返回，避免执行后面的pop
              case FieldOptionAction.duplicate:
                // 复制操作
                fieldService.duplicate();
                break;
              case FieldOptionAction.hide:
                // 隐藏操作
                service.hide();
                break;
              case FieldOptionAction.show:
                // 显示操作
                service.show();
                break;
            }
            // 除删除操作外，其他操作后都返回编辑结果
            context.pop(_fieldOptionValues);
          },
        ),
      ),
    );
  }
}
