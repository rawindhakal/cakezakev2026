import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // Circular Radius
  static const Radius xs = Radius.circular(4);
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(16);
  static const Radius xl = Radius.circular(24);
  static const Radius xxl = Radius.circular(32);

  // BorderRadius – all sides
  static const BorderRadius r2 = BorderRadius.all(Radius.circular(2));
  static const BorderRadius r3 = BorderRadius.all(Radius.circular(3));
  static const BorderRadius r4 = BorderRadius.all(xs);
  static const BorderRadius r6 = BorderRadius.all(Radius.circular(6));
  static const BorderRadius r8 = BorderRadius.all(sm);
  static const BorderRadius r9 = BorderRadius.all(Radius.circular(9));
  static const BorderRadius r10 = BorderRadius.all(Radius.circular(10));
  static const BorderRadius r12 = BorderRadius.all(md);
  static const BorderRadius r14 = BorderRadius.all(Radius.circular(14));
  static const BorderRadius r16 = BorderRadius.all(lg);
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(20));
  static const BorderRadius r24 = BorderRadius.all(xl);
  static const BorderRadius r28 = BorderRadius.all(Radius.circular(28));
  static const BorderRadius r32 = BorderRadius.all(xxl);
  static const BorderRadius r11 = BorderRadius.all(Radius.circular(11));

  // Pill / fully-rounded (large radius so any bar/chip reads as a pill)
  static const BorderRadius pill = BorderRadius.all(Radius.circular(100));

  // Top-only
  static const BorderRadius top10 = BorderRadius.only(
    topLeft: Radius.circular(10),
    topRight: Radius.circular(10),
  );
  static const BorderRadius top12 = BorderRadius.only(
    topLeft: md,
    topRight: md,
  );
  static const BorderRadius top14 = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(14),
  );
  static const BorderRadius top16 = BorderRadius.only(
    topLeft: lg,
    topRight: lg,
  );
  static const BorderRadius top20 = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
  );
  static const BorderRadius top32 = BorderRadius.only(
    topLeft: xxl,
    topRight: xxl,
  );

  // Bottom-only
  static const BorderRadius bottom10 = BorderRadius.only(
    bottomLeft: Radius.circular(10),
    bottomRight: Radius.circular(10),
  );
  static const BorderRadius bottom12 = BorderRadius.only(
    bottomLeft: md,
    bottomRight: md,
  );
  static const BorderRadius bottom16 = BorderRadius.only(
    bottomLeft: lg,
    bottomRight: lg,
  );

  // Specific shapes
  // Rounds the "inner" (start-facing) edge of a side-pinned element
  // (e.g. a selection indicator pinned to the end edge of a list item).
  // Directional so it mirrors correctly under RTL.
  static const BorderRadiusDirectional left30 = BorderRadiusDirectional.only(
    topStart: Radius.circular(30),
    bottomStart: Radius.circular(30),
  );
  static const BorderRadiusDirectional right12 = BorderRadiusDirectional.only(
    topEnd: md,
    bottomEnd: md,
  );
  static const BorderRadiusDirectional diagonal12 =
      BorderRadiusDirectional.only(topStart: md, bottomEnd: md);
  static const BorderRadius bottomLeft10 = BorderRadius.only(
    bottomLeft: Radius.circular(10),
  );
  static const BorderRadius bottomRight6 = BorderRadius.only(
    bottomRight: Radius.circular(6),
  );
  static const BorderRadius bottomRight10 = BorderRadius.only(
    bottomRight: Radius.circular(10),
  );

  // Named aliases
  static const BorderRadius cardRadius = BorderRadius.all(lg);
  static const BorderRadius buttonRadius = BorderRadius.all(md);
  static const BorderRadius bottomSheetRadius = BorderRadius.only(
    topLeft: xl,
    topRight: xl,
  );
}
