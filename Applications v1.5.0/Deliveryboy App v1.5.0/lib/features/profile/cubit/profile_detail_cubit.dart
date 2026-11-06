import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import '../../../features/auth/repositories/auth_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef ProfileDetailState = AsyncState<AuthModel>;
typedef ProfileDetailInitial = AsyncInitial<AuthModel>;
typedef ProfileDetailLoading = AsyncLoading<AuthModel>;
typedef ProfileDetailLoaded = AsyncLoaded<AuthModel>;
typedef ProfileDetailError = AsyncError<AuthModel>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Fetches and holds the rider's profile details.
class ProfileDetailCubit extends BaseAsyncCubit<AuthModel> {
  final AuthRepository _repository;

  ProfileDetailCubit({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  /// Applies an already-fetched profile (e.g. the response from a profile update) without hitting the API again.
  void setProfile(AuthModel profile) {
    emit(AsyncLoaded(profile));
  }

  /// Loads the current rider's profile from the server.
  Future<void> loadProfile() => run(() async {
    final userProfile = await _repository.getProfile();
    return AuthModel.fromJson(userProfile.toJson());
  });
}
