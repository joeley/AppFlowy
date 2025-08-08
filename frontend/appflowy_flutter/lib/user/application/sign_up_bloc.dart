import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_up_bloc.freezed.dart';

class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  SignUpBloc(this.authService) : super(SignUpState.initial()) {
    _dispatch();
  }

  final AuthService authService;

  /**
   * 事件分发器 - 注册所有事件处理器
   * 
   * 使用map模式匹配来处理不同类型的事件。
   * 每个事件都对应一个用户操作或UI交互。
   * 
   * 注册的事件处理器：
   * 1. signUpWithUserEmailAndPassword - 执行注册操作
   * 2. emailChanged - 邮箱输入变化
   * 3. passwordChanged - 密码输入变化  
   * 4. repeatPasswordChanged - 确认密码输入变化
   */
  void _dispatch() {
    on<SignUpEvent>(
      (event, emit) async {
        await event.map(
          /* 用户点击注册按钮事件
           * 触发完整的注册流程，包括验证和API调用
           */
          signUpWithUserEmailAndPassword: (e) async {
            await _performActionOnSignUp(emit);
          },
          /* 邮箱输入框内容变化事件
           * 实时更新状态，清除之前的错误信息
           * 为用户提供流畅的输入体验
           */
          emailChanged: (_EmailChanged value) async {
            emit(
              state.copyWith(
                email: value.email,  // 更新邮箱值
                emailError: null,    // 清除邮箱错误
                successOrFail: null, // 重置操作结果
              ),
            );
          },
          /* 密码输入框内容变化事件
           * 实时更新密码状态，清除相关错误信息
           */
          passwordChanged: (_PasswordChanged value) async {
            emit(
              state.copyWith(
                password: value.password, // 更新密码值
                passwordError: null,      // 清除密码错误
                successOrFail: null,      // 重置操作结果
              ),
            );
          },
          /* 确认密码输入框内容变化事件
           * 这是注册页面特有的功能，确保密码输入一致性
           */
          repeatPasswordChanged: (_RepeatPasswordChanged value) async {
            emit(
              state.copyWith(
                repeatedPassword: value.password, // 更新确认密码值
                repeatPasswordError: null,        // 清除确认密码错误
                successOrFail: null,              // 重置操作结果
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _performActionOnSignUp(Emitter<SignUpState> emit) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        successOrFail: null,
      ),
    );

    final password = state.password;
    final repeatedPassword = state.repeatedPassword;
    if (password == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          passwordError: LocaleKeys.signUp_emptyPasswordError.tr(),
        ),
      );
      return;
    }

    if (repeatedPassword == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          repeatPasswordError: LocaleKeys.signUp_repeatPasswordEmptyError.tr(),
        ),
      );
      return;
    }

    if (password != repeatedPassword) {
      emit(
        state.copyWith(
          isSubmitting: false,
          repeatPasswordError: LocaleKeys.signUp_unmatchedPasswordError.tr(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        passwordError: null,
        repeatPasswordError: null,
      ),
    );

    final result = await authService.signUp(
      name: state.email ?? '',
      password: state.password ?? '',
      email: state.email ?? '',
    );
    emit(
      result.fold(
        (profile) => state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.success(profile),
          emailError: null,
          passwordError: null,
          repeatPasswordError: null,
        ),
        (error) => stateFromCode(error),
      ),
    );
  }

  SignUpState stateFromCode(FlowyError error) {
    switch (error.code) {
      case ErrorCode.EmailFormatInvalid:
        return state.copyWith(
          isSubmitting: false,
          emailError: error.msg,
          passwordError: null,
          successOrFail: null,
        );
      case ErrorCode.PasswordFormatInvalid:
        return state.copyWith(
          isSubmitting: false,
          passwordError: error.msg,
          emailError: null,
          successOrFail: null,
        );
      default:
        return state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.failure(error),
        );
    }
  }
}

@freezed
class SignUpEvent with _$SignUpEvent {
  const factory SignUpEvent.signUpWithUserEmailAndPassword() =
      SignUpWithUserEmailAndPassword;
  const factory SignUpEvent.emailChanged(String email) = _EmailChanged;
  const factory SignUpEvent.passwordChanged(String password) = _PasswordChanged;
  const factory SignUpEvent.repeatPasswordChanged(String password) =
      _RepeatPasswordChanged;
}

@freezed
class SignUpState with _$SignUpState {
  const factory SignUpState({
    String? email,
    String? password,
    String? repeatedPassword,
    required bool isSubmitting,
    required String? passwordError,
    required String? repeatPasswordError,
    required String? emailError,
    required FlowyResult<UserProfilePB, FlowyError>? successOrFail,
  }) = _SignUpState;

  factory SignUpState.initial() => const SignUpState(
        isSubmitting: false,
        passwordError: null,
        repeatPasswordError: null,
        emailError: null,
        successOrFail: null,
      );
}
