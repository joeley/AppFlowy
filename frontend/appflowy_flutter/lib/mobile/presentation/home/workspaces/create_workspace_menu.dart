import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

/// 编辑工作区名称类型枚举
/// 
/// 用于区分创建新工作区和编辑现有工作区名称
enum EditWorkspaceNameType {
  /// 创建新工作区
  create,
  /// 编辑现有工作区
  edit;

  /// 获取标题文本
  String get title {
    switch (this) {
      case EditWorkspaceNameType.create:
        return LocaleKeys.workspace_create.tr();           // 创建工作区
      case EditWorkspaceNameType.edit:
        return LocaleKeys.workspace_renameWorkspace.tr();  // 重命名工作区
    }
  }

  /// 获取操作按钮文本
  String get actionTitle {
    switch (this) {
      case EditWorkspaceNameType.create:
        return LocaleKeys.workspace_create.tr();    // 创建
      case EditWorkspaceNameType.edit:
        return LocaleKeys.button_confirm.tr();      // 确认
    }
  }
}

/// 编辑工作区名称底部弹出菜单
/// 
/// 功能说明：
/// 1. 支持创建新工作区和编辑现有工作区名称
/// 2. 提供表单验证功能，确保名称的有效性
/// 3. 支持自定义验证规则和错误显示
/// 
/// 设计思想：
/// - 使用底部弹出样式提供友好的用户体验
/// - 通过枚举区分不同的操作模式
/// - 支持灵活的验证机制
class EditWorkspaceNameBottomSheet extends StatefulWidget {
  const EditWorkspaceNameBottomSheet({
    super.key,
    required this.type,
    required this.onSubmitted,
    required this.workspaceName,
    this.hintText,
    this.validator,
    this.validatorBuilder,
  });

  /// 编辑类型（创建或编辑）
  final EditWorkspaceNameType type;
  /// 提交回调函数
  final void Function(String) onSubmitted;

  /// 工作区名称（如果不为空，将作为文本框的初始值）
  final String? workspaceName;

  /// 提示文本
  final String? hintText;

  /// 自定义验证函数
  final String? Function(String?)? validator;

  /// 自定义验证组件构建器
  final WidgetBuilder? validatorBuilder;

  @override
  State<EditWorkspaceNameBottomSheet> createState() =>
      _EditWorkspaceNameBottomSheetState();
}

class _EditWorkspaceNameBottomSheetState
    extends State<EditWorkspaceNameBottomSheet> {
  /// 文本输入控制器
  late final TextEditingController _textFieldController;

  /// 表单验证的全局Key
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 初始化文本控制器，如果有现有名称则设为初始值
    _textFieldController = TextEditingController(
      text: widget.workspaceName,
    );
  }

  @override
  void dispose() {
    // 释放文本控制器资源
    _textFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,  // 最小化垂直尺寸
      children: <Widget>[
        // 表单组件
        Form(
          key: _formKey,
          child: TextFormField(
            autofocus: true,                    // 自动获取焦点
            controller: _textFieldController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText:
                  widget.hintText ?? LocaleKeys.workspace_defaultName.tr(),  // 默认提示文本
            ),
            // 输入验证逻辑
            validator: widget.validator ??
                (value) {
                  if (value == null || value.isEmpty) {
                    return LocaleKeys.workspace_workspaceNameCannotBeEmpty.tr();  // 名称不能为空
                  }
                  return null;  // 验证通过
                },
            onEditingComplete: _onSubmit,  // 输入完成时提交
          ),
        ),
        // 如果有自定义验证组件则显示
        if (widget.validatorBuilder != null) ...[
          const VSpace(4),
          widget.validatorBuilder!(context),
          const VSpace(4),
        ],
        const VSpace(16),
        // 主要操作按钮（创建或确认）
        SizedBox(
          width: double.infinity,  // 占满宽度
          child: PrimaryRoundedButton(
            text: widget.type.actionTitle,  // 根据类型显示不同文本
            fontSize: 16,
            margin: const EdgeInsets.symmetric(
              vertical: 16,
            ),
            onTap: _onSubmit,  // 点击提交
          ),
        ),
      ],
    );
  }

  /// 提交表单
  /// 
  /// 验证表单数据并调用回调函数
  void _onSubmit() {
    // 只有验证通过才执行提交操作
    if (_formKey.currentState!.validate()) {
      final value = _textFieldController.text;
      widget.onSubmitted.call(value);  // 调用回调函数
    }
  }
}
