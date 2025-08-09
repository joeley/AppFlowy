// 媒体单元格管理的BLoC，用于处理媒体文件的添加和状态管理
import 'package:appflowy/plugins/database/application/cell/bloc/media_cell_bloc.dart';
// 文件处理工具类，提供文件上传的核心功能
import 'package:appflowy/plugins/document/presentation/editor_plugins/file/file_util.dart';
// 移动端文件上传菜单组件，提供统一的文件选择界面
import 'package:appflowy/plugins/document/presentation/editor_plugins/file/mobile_file_upload_menu.dart';
// XFile扩展方法，用于文件类型判断和处理
import 'package:appflowy/util/xfile_ext.dart';
// 文件上传类型的协议定义（本地文件、云文件、网络文件）
import 'package:appflowy_backend/protobuf/flowy-database2/file_entities.pbenum.dart';
// 媒体文件类型的协议定义（图片、视频、音频等）
import 'package:appflowy_backend/protobuf/flowy-database2/media_entities.pbenum.dart';
// 跨平台文件处理库，统一文件操作接口
import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
// 路由管理，用于弹窗的关闭操作
import 'package:go_router/go_router.dart';
// Provider状态管理，用于访问MediaCellBloc
import 'package:provider/provider.dart';

/// 移动端媒体上传底部弹出框内容组件
/// 
/// 设计思想：
/// 1. 提供统一的媒体文件上传入口，支持本地文件和网络链接两种方式
/// 2. 集成MediaCellBloc进行状态管理，确保上传后能正确更新UI
/// 3. 使用对话框上下文进行弹窗管理，避免上下文混乱
/// 
/// 使用场景：
/// - 数据库表格中的媒体单元格添加文件
/// - 文档编辑器中插入媒体文件
/// - 任何需要媒体文件上传的移动端场景
class MobileMediaUploadSheetContent extends StatelessWidget {
  const MobileMediaUploadSheetContent({super.key, required this.dialogContext});

  /// 对话框的上下文，用于控制弹窗的关闭
  /// 单独传入dialogContext是为了避免在异步操作中使用错误的BuildContext
  final BuildContext dialogContext;

  /// 构建媒体上传底部弹出框的UI
  /// 
  /// 返回一个包含文件上传菜单的容器，支持本地文件和网络链接两种上传方式
  @override
  Widget build(BuildContext context) {
    return Container(
      // 顶部留出12px的间距，符合移动端设计规范
      margin: const EdgeInsets.only(top: 12),
      // 限制弹窗高度，防止内容过多时超出屏幕
      constraints: const BoxConstraints(
        maxHeight: 340, // 最大高度340px，适合大多数手机屏幕
        minHeight: 80,  // 最小高度80px，确保基础内容可见
      ),
      // 使用MobileFileUploadMenu作为核心上传组件
      child: MobileFileUploadMenu(
        // 处理本地文件上传的回调函数
        onInsertLocalFile: (files) async {
          // 先关闭弹窗，避免上传过程中界面卡住
          dialogContext.pop();

          // 调用文件上传工具函数处理本地文件
          await insertLocalFiles(
            context,
            files,
            // 从MediaCellBloc获取用户配置信息，用于云存储配置
            userProfile: context.read<MediaCellBloc>().state.userProfile,
            // 获取当前行ID，用于文件关联
            documentId: context.read<MediaCellBloc>().rowId,
            // 上传成功后的回调处理
            onUploadSuccess: (file, path, isLocalMode) {
              final mediaCellBloc = context.read<MediaCellBloc>();
              // 检查BLoC是否已关闭，避免在已销毁的组件上操作
              if (mediaCellBloc.isClosed) {
                return;
              }

              // 向MediaCellBloc发送添加文件事件
              mediaCellBloc.add(
                MediaCellEvent.addFile(
                  url: path,                    // 文件路径或URL
                  name: file.name,             // 文件名
                  // 根据上传模式确定文件类型（本地文件或云文件）
                  uploadType: isLocalMode
                      ? FileUploadTypePB.LocalFile
                      : FileUploadTypePB.CloudFile,
                  // 转换文件类型为媒体文件类型枚举
                  fileType: file.fileType.toMediaFileTypePB(),
                ),
              );
            },
          );
        },
        // 处理网络文件插入的回调函数
        onInsertNetworkFile: (url) async => _onInsertNetworkFile(
          url,
          dialogContext,
          context,
        ),
      ),
    );
  }

  /// 处理网络文件插入逻辑
  /// 
  /// 设计思想：
  /// 1. 先进行URL有效性验证，确保是有效的网络链接
  /// 2. 通过URI解析提取文件信息（名称、类型等）
  /// 3. 智能推断文件类型，如果无法识别则标记为链接类型
  /// 4. 提供多层级的文件名提取策略，确保总能得到有意义的名称
  /// 
  /// 参数：
  /// - [url] 网络文件的URL地址
  /// - [dialogContext] 对话框上下文，用于关闭弹窗
  /// - [context] 组件上下文，用于访问MediaCellBloc
  Future<void> _onInsertNetworkFile(
    String url,
    BuildContext dialogContext,
    BuildContext context,
  ) async {
    // 先关闭弹窗，提供更好的用户体验
    dialogContext.pop();

    // 基础验证：检查URL是否为空
    if (url.isEmpty) return;
    
    // 尝试解析URL，验证其有效性
    final uri = Uri.tryParse(url);
    if (uri == null) {
      // URL格式无效，直接返回
      return;
    }

    // 创建虚拟文件对象用于类型检测
    // 注意：这里使用uri.path而不是完整URL，是为了利用文件扩展名进行类型判断
    final fakeFile = XFile(uri.path);
    MediaFileTypePB fileType = fakeFile.fileType.toMediaFileTypePB();
    
    // 智能类型推断：如果无法识别文件类型，则标记为链接
    // 这样可以保证所有网络资源都能被正确处理
    fileType =
        fileType == MediaFileTypePB.Other ? MediaFileTypePB.Link : fileType;

    // 多层级文件名提取策略
    // 1. 优先使用URL路径的最后一段作为文件名
    String name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : "";
    
    // 2. 如果最后一段为空且路径有多段，使用倒数第二段
    if (name.isEmpty && uri.pathSegments.length > 1) {
      name = uri.pathSegments[uri.pathSegments.length - 2];
    } 
    // 3. 如果都无法获取，使用域名作为文件名
    else if (name.isEmpty) {
      name = uri.host;
    }

    // 向MediaCellBloc发送添加网络文件事件
    context.read<MediaCellBloc>().add(
          MediaCellEvent.addFile(
            url: url,                               // 原始URL
            name: name,                            // 提取的文件名
            uploadType: FileUploadTypePB.NetworkFile, // 标记为网络文件类型
            fileType: fileType,                    // 推断的文件类型
          ),
        );
  }
}
