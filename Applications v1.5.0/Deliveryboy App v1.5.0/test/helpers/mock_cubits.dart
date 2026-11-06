import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/cubit/country_settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/cubit/zones_cubit.dart';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/language_cubit.dart';
import 'package:deliveryboy/core/localization/cubit/localization_cubit.dart';
import 'package:deliveryboy/features/cash_collection/cubit/cash_collection_cubit.dart';
import 'package:deliveryboy/features/cash_collection/models/cash_collection_model.dart';
import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/salary/cubit/salary_cubit.dart';
import 'package:deliveryboy/features/settlement_history/cubit/settlement_history_cubit.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/features/salary/models/salary_model.dart';
import 'package:deliveryboy/features/wallet/cubit/wallet_cubit.dart';
import 'package:deliveryboy/features/wallet/cubit/withdrawal_cubit.dart';
import 'package:deliveryboy/features/wallet/models/withdrawal_request_model.dart';
import 'package:deliveryboy/features/home/cubit/dashboard_cubit.dart';
import 'package:deliveryboy/features/home/cubit/delivery_boy_status_cubit.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_cubit.dart';
import 'package:deliveryboy/features/notifications/cubit/notification_save_cubit.dart';
import 'package:deliveryboy/core/theme/cubit/theme_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/update_fcm_token_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_detail_cubit.dart';
import 'package:deliveryboy/features/profile/cubit/profile_update_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/forgot_password_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/auth/cubit/sign_up_cubit.dart';

class MockSignInCubit extends MockCubit<SignInState> implements SignInCubit {}

class MockSignUpCubit extends MockCubit<SignUpState> implements SignUpCubit {}

class MockForgotPasswordCubit extends MockCubit<ForgotPasswordState>
    implements ForgotPasswordCubit {}

class MockCountrySettingsCubit extends MockCubit<CountrySettingsState>
    implements CountrySettingsCubit {}

class MockCountriesCubit extends MockCubit<CountriesState>
    implements CountriesCubit {}

class MockZonesCubit extends MockCubit<ZonesState> implements ZonesCubit {}

class MockConnectivityCubit extends MockCubit<ConnectivityState>
    implements ConnectivityCubit {}

class MockLanguageCubit extends MockCubit<LanguageState>
    implements LanguageCubit {}

class MockLocalizationCubit extends MockCubit<LocalizationState>
    implements LocalizationCubit {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockDashboardCubit extends MockCubit<DashboardState>
    implements DashboardCubit {}

class MockDeliveryBoyStatusCubit extends MockCubit<DeliveryBoyStatusState>
    implements DeliveryBoyStatusCubit {}

class MockProfileDetailCubit extends MockCubit<ProfileDetailState>
    implements ProfileDetailCubit {}

class MockProfileUpdateCubit extends MockCubit<ProfileUpdateState>
    implements ProfileUpdateCubit {}

class MockThemeCubit extends MockCubit<ThemeState> implements ThemeCubit {}

class MockUpdateFcmTokenCubit extends MockCubit<UpdateFcmTokenState>
    implements UpdateFcmTokenCubit {}

class MockCashCollectionCubit
    extends MockCubit<PaginationState<CashCollectionModel>>
    implements CashCollectionCubit {}

class MockWalletCubit extends MockCubit<PaginationState<WithdrawRequests>>
    implements WalletCubit {}

class MockWithdrawalCubit extends MockCubit<AsyncState<()>>
    implements WithdrawalCubit {}

class MockSalaryCubit extends MockCubit<PaginationState<SalaryModel>>
    implements SalaryCubit {}

class MockSettlementHistoryCubit
    extends MockCubit<PaginationState<SettlementHistoryData>>
    implements SettlementHistoryCubit {}

class MockNotificationCubit extends MockCubit<NotificationState>
    implements NotificationCubit {}

class MockNotificationSaveCubit extends MockCubit<NotificationSaveState>
    implements NotificationSaveCubit {}
