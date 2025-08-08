import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_member_bloc.freezed.dart';

/// 聊天成员管理器 - 负责管理和缓存聊天参与者信息
/// 
/// 主要功能：
/// 1. 获取工作区成员信息
/// 2. 缓存成员信息避免重复请求
/// 3. 管理成员状态更新
/// 
/// 设计思想：
/// - 使用Map缓存成员信息，避免重复请求
/// - 通过用户ID查询成员详细信息
/// - 支持异步获取成员信息
class ChatMemberBloc extends Bloc<ChatMemberEvent, ChatMemberState> {
  ChatMemberBloc() : super(const ChatMemberState()) {
    on<ChatMemberEvent>(
      (event, emit) async {
        await event.when(
          /// 接收并存储成员信息
          receiveMemberInfo: (String id, WorkspaceMemberPB memberInfo) {
            // 创建新的Map避免直接修改状态
            final members = Map<String, ChatMember>.from(state.members);
            members[id] = ChatMember(info: memberInfo);
            emit(state.copyWith(members: members));
          },
          
          /// 获取成员信息
          getMemberInfo: (String userId) async {
            // 检查缓存，避免重复请求
            if (state.members.containsKey(userId)) {
              // 成员信息已存在
              // TODO: 后续可以添加防抖机制刷新成员信息
              return;
            }

            // 构建请求参数
            final payload = WorkspaceMemberIdPB(
              uid: Int64.parseInt(userId),
            );

            // 调用后端获取成员信息
            await UserEventGetMemberInfo(payload).send().then((result) {
              result.fold(
                (member) {
                  // 成功获取，触发接收事件
                  if (!isClosed) {
                    add(ChatMemberEvent.receiveMemberInfo(userId, member));
                  }
                },
                (err) => Log.error("Error getting member info: $err"),
              );
            });
          },
        );
      },
    );
  }
}

/// 聊天成员事件
/// 
/// 定义了成员管理相关的事件
@freezed
class ChatMemberEvent with _$ChatMemberEvent {
  /// 获取成员信息
  const factory ChatMemberEvent.getMemberInfo(
    String userId,
  ) = _GetMemberInfo;
  
  /// 接收成员信息
  const factory ChatMemberEvent.receiveMemberInfo(
    String id,
    WorkspaceMemberPB memberInfo,
  ) = _ReceiveMemberInfo;
}

/// 聊天成员状态
/// 
/// 存储所有已获取的成员信息
@freezed
class ChatMemberState with _$ChatMemberState {
  const factory ChatMemberState({
    /// 成员信息Map，键为用户ID
    @Default({}) Map<String, ChatMember> members,
  }) = _ChatMemberState;
}

/// 聊天成员实体
/// 
/// 封装成员信息和时间戳
/// 
/// 设计思想：
/// - 使用Equatable实现值比较
/// - 包含时间戳用于后续可能的缓存过期策略
/// - info包含成员的完整信息（名称、头像、角色等）
class ChatMember extends Equatable {
  ChatMember({
    required this.info,
  });
  
  /// 创建时间，用于缓存管理
  final DateTime _date = DateTime.now();
  
  /// 工作区成员信息
  final WorkspaceMemberPB info;

  @override
  List<Object?> get props => [_date, info];
}
