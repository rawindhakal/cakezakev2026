import 'package:flutter/material.dart';

/// Central design token file for border radii — [Radius] and [BorderRadius] constants.
class AppRadius {
  AppRadius._();

  // Radius constants (use inside BorderRadius.only / vertical)
  static const Radius xxs = Radius.circular(2);
  static const Radius xs = Radius.circular(4);
  static const Radius rad6 = Radius.circular(6);
  static const Radius sm = Radius.circular(8);
  static const Radius rad10 = Radius.circular(10);
  static const Radius md = Radius.circular(12);
  static const Radius rad14 = Radius.circular(14);
  static const Radius lg = Radius.circular(16);
  static const Radius rad20 = Radius.circular(20);
  static const Radius xl = Radius.circular(24);
  static const Radius rad25 = Radius.circular(25);
  static const Radius xxl = Radius.circular(32);

  // BorderRadius (all sides)
  static const BorderRadius r2 = BorderRadius.all(xxs);
  static const BorderRadius r4 = BorderRadius.all(xs);
  static const BorderRadius r6 = BorderRadius.all(rad6);
  static const BorderRadius r8 = BorderRadius.all(sm);
  static const BorderRadius r10 = BorderRadius.all(rad10);
  static const BorderRadius r12 = BorderRadius.all(md);
  static const BorderRadius r14 = BorderRadius.all(rad14);
  static const BorderRadius r16 = BorderRadius.all(lg);
  static const BorderRadius r20 = BorderRadius.all(rad20);
  static const BorderRadius r24 = BorderRadius.all(xl);
  static const BorderRadius r25 = BorderRadius.all(rad25);
  static const BorderRadius r32 = BorderRadius.all(xxl);

  // Named custom
  static const BorderRadius top12 = BorderRadius.only(
    topLeft: md,
    topRight: md,
  );
  static const BorderRadius top20 = BorderRadius.only(
    topLeft: rad20,
    topRight: rad20,
  );
  static const BorderRadius bottom12 = BorderRadius.only(
    bottomLeft: md,
    bottomRight: md,
  );
  static const BorderRadius bottomSheetRadius = BorderRadius.only(
    topLeft: xl,
    topRight: xl,
  );
}
