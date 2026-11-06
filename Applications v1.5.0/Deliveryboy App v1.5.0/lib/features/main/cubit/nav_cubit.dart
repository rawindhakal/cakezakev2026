import 'package:flutter_bloc/flutter_bloc.dart';

// ── State ────────────────────────────────────────────────────────────────────
/// Holds the currently selected bottom navigation tab index.
class NavState {
  final int currentIndex;
  const NavState(this.currentIndex);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Tracks which bottom navigation tab is currently active.
class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState(0));

  /// Switches the active bottom navigation tab.
  void changeTab(int index) => emit(NavState(index));
}
