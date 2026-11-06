import 'package:flutter_bloc/flutter_bloc.dart';

// ── State ────────────────────────────────────────────────────────────────────
class NavState {
  final int currentIndex;
  const NavState(this.currentIndex);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState(0));

  void changeTab(int index) => emit(NavState(index));
}
