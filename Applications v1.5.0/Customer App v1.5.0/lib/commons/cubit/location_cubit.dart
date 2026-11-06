import 'package:flutter_bloc/flutter_bloc.dart';

/// Broadcasts "user location changed" so tabs other than Home (which loads
/// its own layout directly) can also refresh location-dependent data.
/// State is just a bump counter — no location payload, listeners re-read
/// current location from SettingsHiveBox themselves.
class LocationCubit extends Cubit<int> {
  LocationCubit() : super(0);

  void notifyLocationChanged() => emit(state + 1);
}
