import 'package:bloc_test/bloc_test.dart';
import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/cubit/connectivity_cubit.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/features/faq/cubit/faq_cubit.dart';
import 'package:customer/features/faq/models/faq_model.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/cubits/forgot_password_cubit.dart';
import 'package:customer/features/auth/cubits/verify_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';

/// `MockCubit`s for cubits that a widget test needs to inject via
/// `BlocProvider<T>.value` instead of letting the widget build its own.
/// Populated per feature as its tests are written, not pre-populated for the
/// whole app.
class MockConnectivityCubit extends MockCubit<ConnectivityState>
    implements ConnectivityCubit {}

class MockFaqCubit extends MockCubit<PaginationState<FaqData>>
    implements FaqCubit {}

class MockBlogCubit extends MockCubit<PaginationState<Blog>>
    implements BlogCubit {}

class MockBlogCategoryCubit extends MockCubit<BlogCategoryState>
    implements BlogCategoryCubit {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockCountriesCubit extends MockCubit<CountriesState>
    implements CountriesCubit {}

class MockSignInCubit extends MockCubit<SignInState> implements SignInCubit {}

class MockCustomSmsSendPhoneOtpCubit
    extends MockCubit<CustomSmsSendPhoneOtpState>
    implements CustomSmsSendPhoneOtpCubit {}

class MockSignUpCubit extends MockCubit<SignUpState> implements SignUpCubit {}

class MockForgotPasswordCubit extends MockCubit<ForgotPasswordState>
    implements ForgotPasswordCubit {}

class MockVerifyOtpCubit extends MockCubit<VerifyOtpState>
    implements VerifyOtpCubit {}

class MockCustomSmsVerifyPhoneOtpCubit
    extends MockCubit<CustomSmsVerifyPhoneOtpState>
    implements CustomSmsVerifyPhoneOtpCubit {}
