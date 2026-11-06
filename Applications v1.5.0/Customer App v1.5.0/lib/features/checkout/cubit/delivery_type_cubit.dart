import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the checkout screen's active delivery/pickup selection so the
/// AppBar toggle can react to it without a full-screen `setState`.
class DeliveryTypeCubit extends Cubit<DeliveryType> {
  DeliveryTypeCubit(super.initialType);

  void select(DeliveryType type) => emit(type);
}
