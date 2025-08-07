import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/appflowy_cloud_task.dart';
import 'package:appflowy/startup/tasks/deeplink/deeplink_handler.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/user/application/password/password_http_service.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart'
    show UserProfilePB;
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_bloc.freezed.dart';

/**
 * 登录页BLoC - 管理登录页的复杂业务逻辑
 * 
 * 这是一个复杂BLoC的典型示例，展示了：
 * 1. 多种登录方式的处理
 * 2. 表单验证和错误处理
 * 3. 异步操作的状态管理
 * 4. 外部事件监听（DeepLink）
 * 5. 依赖注入和服务交互
 */
class SignInBloc extends Bloc<SignInEvent, SignInState> {
  /**
   * 构造函数
   * 
   * @param authService 认证服务 - 通过依赖注入传入
   *                    负责实际的登录、注册等操作
   */
  SignInBloc(this.authService) : super(SignInState.initial()) {
    if (isAppFlowyCloudEnabled) {
      deepLinkStateListener =
          getIt<AppFlowyCloudDeepLink>().subscribeDeepLinkLoadingState((value) {
        if (isClosed) return;

        add(SignInEvent.deepLinkStateChange(value));
      });

      getAppFlowyCloudUrl().then((baseUrl) {
        passwordService = PasswordHttpService(
          baseUrl: baseUrl,
          authToken:
              '', // the user is not signed in yet, the auth token should be empty
        );
      });
    }

    /**
     * 注册事件处理器
     * 
     * 使用when方法进行模式匹配，处理各种事件
     * 每个事件对应一个用户操作或系统事件
     */
    on<SignInEvent>(
      (event, emit) async {
        await event.when(
          signInWithEmailAndPassword: (email, password) async =>
              _onSignInWithEmailAndPassword(
            emit,
            email: email,
            password: password,
          ),
          signInWithOAuth: (platform) async => _onSignInWithOAuth(
            emit,
            platform: platform,
          ),
          signInAsGuest: () async => _onSignInAsGuest(emit),
          signInWithMagicLink: (email) async => _onSignInWithMagicLink(
            emit,
            email: email,
          ),
          signInWithPasscode: (email, passcode) async => _onSignInWithPasscode(
            emit,
            email: email,
            passcode: passcode,
          ),
          deepLinkStateChange: (result) => _onDeepLinkStateChange(emit, result),
          cancel: () {
            emit(
              state.copyWith(
                isSubmitting: false,
                emailError: null,
                passwordError: null,
                successOrFail: null,
              ),
            );
          },
          emailChanged: (email) async {
            emit(
              state.copyWith(
                email: email,
                emailError: null,
                successOrFail: null,
              ),
            );
          },
          passwordChanged: (password) async {
            emit(
              state.copyWith(
                password: password,
                passwordError: null,
                successOrFail: null,
              ),
            );
          },
          switchLoginType: (type) {
            emit(state.copyWith(loginType: type));
          },
          forgotPassword: (email) => _onForgotPassword(emit, email: email),
          validateResetPasswordToken: (email, token) async =>
              _onValidateResetPasswordToken(
            emit,
            email: email,
            token: token,
          ),
          resetPassword: (email, newPassword) async => _onResetPassword(
            emit,
            email: email,
            newPassword: newPassword,
          ),
        );
      },
    );
  }

  final AuthService authService;
  PasswordHttpService? passwordService;
  VoidCallback? deepLinkStateListener;

  @override
  Future<void> close() {
    deepLinkStateListener?.call();
    if (isAppFlowyCloudEnabled && deepLinkStateListener != null) {
      getIt<AppFlowyCloudDeepLink>().unsubscribeDeepLinkLoadingState(
        deepLinkStateListener!,
      );
    }
    return super.close();
  }

  Future<void> _onDeepLinkStateChange(
    Emitter<SignInState> emit,
    DeepLinkResult result,
  ) async {
    final deepLinkState = result.state;

    switch (deepLinkState) {
      case DeepLinkState.none:
        break;
      case DeepLinkState.loading:
        emit(
          state.copyWith(
            isSubmitting: true,
            emailError: null,
            passwordError: null,
            successOrFail: null,
          ),
        );
      case DeepLinkState.finish:
        final newState = result.result?.fold(
          (s) => state.copyWith(
            isSubmitting: false,
            successOrFail: FlowyResult.success(s),
          ),
          (f) => _stateFromCode(f),
        );
        if (newState != null) {
          emit(newState);
        }
      case DeepLinkState.error:
        emit(state.copyWith(isSubmitting: false));
    }
  }

  Future<void> _onSignInWithEmailAndPassword(
    Emitter<SignInState> emit, {
    required String email,
    required String password,
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        emailError: null,
        passwordError: null,
        successOrFail: null,
      ),
    );
    final result = await authService.signInWithEmailPassword(
      email: email,
      password: password,
    );
    emit(
      result.fold(
        (gotrueTokenResponse) {
          getIt<AppFlowyCloudDeepLink>().passGotrueTokenResponse(
            gotrueTokenResponse,
          );
          return state.copyWith(
            isSubmitting: false,
          );
        },
        (error) => _stateFromCode(error),
      ),
    );
  }

  Future<void> _onSignInWithOAuth(
    Emitter<SignInState> emit, {
    required String platform,
  }) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        emailError: null,
        passwordError: null,
        successOrFail: null,
      ),
    );

    final result = await authService.signUpWithOAuth(platform: platform);
    emit(
      result.fold(
        (userProfile) => state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.success(userProfile),
        ),
        (error) => _stateFromCode(error),
      ),
    );
  }

  Future<void> _onSignInWithMagicLink(
    Emitter<SignInState> emit, {
    required String email,
  }) async {
    if (state.isSubmitting) {
      Log.error('Sign in with magic link is already in progress');
      return;
    }

    Log.info('Sign in with magic link: $email');

    emit(
      state.copyWith(
        isSubmitting: true,
        emailError: null,
        passwordError: null,
        successOrFail: null,
      ),
    );

    final result = await authService.signInWithMagicLink(email: email);

    emit(
      result.fold(
        (userProfile) => state.copyWith(
          isSubmitting: false,
        ),
        (error) => _stateFromCode(error),
      ),
    );
  }

  Future<void> _onSignInWithPasscode(
    Emitter<SignInState> emit, {
    required String email,
    required String passcode,
  }) async {
    if (state.isSubmitting) {
      Log.error('Sign in with passcode is already in progress');
      return;
    }

    Log.info('Sign in with passcode: $email, $passcode');

    emit(
      state.copyWith(
        isSubmitting: true,
        emailError: null,
        passwordError: null,
        successOrFail: null,
      ),
    );

    final result = await authService.signInWithPasscode(
      email: email,
      passcode: passcode,
    );

    emit(
      result.fold(
        (gotrueTokenResponse) {
          getIt<AppFlowyCloudDeepLink>().passGotrueTokenResponse(
            gotrueTokenResponse,
          );
          return state.copyWith(
            isSubmitting: false,
          );
        },
        (error) => _stateFromCode(error),
      ),
    );
  }

  Future<void> _onSignInAsGuest(
    Emitter<SignInState> emit,
  ) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        emailError: null,
        passwordError: null,
        successOrFail: null,
      ),
    );

    final result = await authService.signUpAsGuest();
    emit(
      result.fold(
        (userProfile) => state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.success(userProfile),
        ),
        (error) => _stateFromCode(error),
      ),
    );
  }

  Future<void> _onForgotPassword(
    Emitter<SignInState> emit, {
    required String email,
  }) async {
    if (state.isSubmitting) {
      Log.error('Forgot password is already in progress');
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        forgotPasswordSuccessOrFail: null,
        validateResetPasswordTokenSuccessOrFail: null,
        resetPasswordSuccessOrFail: null,
      ),
    );

    final result = await passwordService?.forgotPassword(email: email);

    result?.fold(
      (success) {
        emit(
          state.copyWith(
            isSubmitting: false,
            forgotPasswordSuccessOrFail: FlowyResult.success(true),
          ),
        );
      },
      (error) {
        emit(
          state.copyWith(
            isSubmitting: false,
            forgotPasswordSuccessOrFail: FlowyResult.failure(error),
          ),
        );
      },
    );
  }

  Future<void> _onValidateResetPasswordToken(
    Emitter<SignInState> emit, {
    required String email,
    required String token,
  }) async {
    if (state.isSubmitting) {
      Log.error('Validate reset password token is already in progress');
      return;
    }

    Log.info('Validate reset password token: $email, $token');

    emit(
      state.copyWith(
        isSubmitting: true,
        validateResetPasswordTokenSuccessOrFail: null,
        resetPasswordSuccessOrFail: null,
      ),
    );

    final result = await passwordService?.verifyResetPasswordToken(
      email: email,
      token: token,
    );

    result?.fold(
      (authToken) {
        Log.info('Validate reset password token success: $authToken');

        passwordService?.authToken = authToken;

        emit(
          state.copyWith(
            isSubmitting: false,
            validateResetPasswordTokenSuccessOrFail: FlowyResult.success(true),
          ),
        );
      },
      (error) {
        Log.error('Validate reset password token failed: $error');

        emit(
          state.copyWith(
            isSubmitting: false,
            validateResetPasswordTokenSuccessOrFail: FlowyResult.failure(error),
          ),
        );
      },
    );
  }

  Future<void> _onResetPassword(
    Emitter<SignInState> emit, {
    required String email,
    required String newPassword,
  }) async {
    if (state.isSubmitting) {
      Log.error('Reset password is already in progress');
      return;
    }

    Log.info('Reset password: $email, ${newPassword.hashCode}');

    emit(
      state.copyWith(
        isSubmitting: true,
        resetPasswordSuccessOrFail: null,
      ),
    );

    final result = await passwordService?.setupPassword(
      newPassword: newPassword,
    );

    result?.fold(
      (success) {
        Log.info('Reset password success');
        emit(
          state.copyWith(
            isSubmitting: false,
            resetPasswordSuccessOrFail: FlowyResult.success(true),
          ),
        );
      },
      (error) {
        Log.error('Reset password failed: $error');
        emit(
          state.copyWith(
            isSubmitting: false,
            resetPasswordSuccessOrFail: FlowyResult.failure(error),
          ),
        );
      },
    );
  }

  SignInState _stateFromCode(FlowyError error) {
    Log.error('SignInState _stateFromCode: ${error.msg}');

    switch (error.code) {
      case ErrorCode.EmailFormatInvalid:
        return state.copyWith(
          isSubmitting: false,
          emailError: error.msg,
          passwordError: null,
        );
      case ErrorCode.PasswordFormatInvalid:
        return state.copyWith(
          isSubmitting: false,
          passwordError: error.msg,
          emailError: null,
        );
      case ErrorCode.UserUnauthorized:
        final errorMsg = error.msg;
        String msg = LocaleKeys.signIn_generalError.tr();
        if (errorMsg.contains('rate limit') ||
            errorMsg.contains('For security purposes')) {
          msg = LocaleKeys.signIn_tooFrequentVerificationCodeRequest.tr();
        } else if (errorMsg.contains('invalid')) {
          msg = LocaleKeys.signIn_tokenHasExpiredOrInvalid.tr();
        } else if (errorMsg.contains('Invalid login credentials')) {
          msg = LocaleKeys.signIn_invalidLoginCredentials.tr();
        }
        return state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.failure(
            FlowyError(msg: msg),
          ),
        );
      default:
        return state.copyWith(
          isSubmitting: false,
          successOrFail: FlowyResult.failure(
            FlowyError(msg: LocaleKeys.signIn_generalError.tr()),
          ),
        );
    }
  }
}

@freezed
class SignInEvent with _$SignInEvent {
  // Sign in methods
  const factory SignInEvent.signInWithEmailAndPassword({
    required String email,
    required String password,
  }) = SignInWithEmailAndPassword;
  const factory SignInEvent.signInWithOAuth({
    required String platform,
  }) = SignInWithOAuth;
  const factory SignInEvent.signInAsGuest() = SignInAsGuest;
  const factory SignInEvent.signInWithMagicLink({
    required String email,
  }) = SignInWithMagicLink;
  const factory SignInEvent.signInWithPasscode({
    required String email,
    required String passcode,
  }) = SignInWithPasscode;

  // Event handlers
  const factory SignInEvent.emailChanged({
    required String email,
  }) = EmailChanged;
  const factory SignInEvent.passwordChanged({
    required String password,
  }) = PasswordChanged;
  const factory SignInEvent.deepLinkStateChange(DeepLinkResult result) =
      DeepLinkStateChange;

  const factory SignInEvent.cancel() = Cancel;
  const factory SignInEvent.switchLoginType(LoginType type) = SwitchLoginType;

  // password
  const factory SignInEvent.forgotPassword({
    required String email,
  }) = ForgotPassword;

  const factory SignInEvent.validateResetPasswordToken({
    required String email,
    required String token,
  }) = ValidateResetPasswordToken;

  const factory SignInEvent.resetPassword({
    required String email,
    required String newPassword,
  }) = ResetPassword;
}

// we support sign in directly without sign up, but we want to allow the users to sign up if they want to
// this type is only for the UI to know which form to show
enum LoginType {
  signIn,
  signUp,
}

/**
 * 登录页状态 - 包含所有UI需要的数据
 * 
 * 这个状态类展示了复杂表单的状态管理
 * 每个属性都对应UI的一个方面
 */
@freezed
class SignInState with _$SignInState {
  const factory SignInState({
    /**
     * 邮箱输入框的值
     * 可空，表示用户可能还没有输入
     */
    String? email,
    
    /**
     * 密码输入框的值
     * 可空，表示用户可能还没有输入
     */
    String? password,
    
    /**
     * 是否正在提交
     * true时UI应该显示加载动画并禁用表单
     * 防止重复提交
     */
    required bool isSubmitting,
    
    /**
     * 密码错误信息
     * 用于显示在密码输入框下方
     * null表示没有错误
     */
    required String? passwordError,
    
    /**
     * 邮箱错误信息
     * 用于显示在邮箱输入框下方
     * null表示没有错误
     */
    required String? emailError,
    
    /**
     * 登录操作的结果
     * FlowyResult是一个Either类型：
     * - 成功：UserProfilePB（用户信息）
     * - 失败：FlowyError（错误信息）
     * null表示还没有进行登录操作
     */
    required FlowyResult<UserProfilePB, FlowyError>? successOrFail,
    
    /**
     * 忘记密码操作的结果
     * 成功返回true，失败返回错误
     */
    required FlowyResult<bool, FlowyError>? forgotPasswordSuccessOrFail,
    
    /**
     * 验证重置密码令牌的结果
     * 用于确认重置密码链接是否有效
     */
    required FlowyResult<bool, FlowyError>?
        validateResetPasswordTokenSuccessOrFail,
    
    /**
     * 重置密码操作的结果
     * 成功返回true，失败返回错误
     */
    required FlowyResult<bool, FlowyError>? resetPasswordSuccessOrFail,
    
    /**
     * 登录类型
     * 默认为登录模式，也可以是注册模式
     * @Default注解设置默认值
     */
    @Default(LoginType.signIn) LoginType loginType,
  }) = _SignInState;

  /**
   * 初始状态工厂方法
   * 
   * 设置所有字段的初始值：
   * - 未提交
   * - 无错误
   * - 无操作结果
   */
  factory SignInState.initial() => const SignInState(
        isSubmitting: false,
        passwordError: null,
        emailError: null,
        successOrFail: null,
        forgotPasswordSuccessOrFail: null,
        validateResetPasswordTokenSuccessOrFail: null,
        resetPasswordSuccessOrFail: null,
      );
}
