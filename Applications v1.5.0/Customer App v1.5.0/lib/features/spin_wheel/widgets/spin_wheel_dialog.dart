import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:customer/commons/utils/app_haptics.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/utils/color_utils.dart';
import 'package:customer/features/main/cubit/nav_cubit.dart';
import 'package:customer/features/spin_wheel/cubit/spin_action_cubit.dart';
import 'package:customer/features/spin_wheel/cubit/spin_wheel_config_cubit.dart';
import 'package:customer/features/spin_wheel/models/spin_wheel_model.dart';
import 'package:customer/features/spin_wheel/repositories/spin_wheel_repository.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_balance_chip.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_board.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_close_button.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_confetti.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_countdown.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_hub.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_painters.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_palette.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_prize_labels.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_result_card.dart';
import 'package:customer/features/spin_wheel/widgets/spin_wheel_title.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Full-screen "spin the wheel" dialog.
///
/// What comes from where:
///  - Segments, colors, icons, campaign name and spin availability come from
///    the `spin_wheel` config API ([SpinWheelConfigCubit]).
///  - The result of a spin comes from the `spin_wheel/spin` API
///    ([SpinActionCubit]); the wheel then animates to land on that segment.
///  - The top-right total comes from the `rewards` API summary.
///
/// Screen layout, back to front: dark gradient background -> title + board
/// (wheel, tray, SPIN button / countdown) -> close button and wallet chip ->
/// confetti -> error banner. The result card is NOT part of this dialog: once
/// the wheel stops the dialog closes and the card opens in its own dialog.
///
/// Building blocks live in their own files: [SpinWheelBoard],
/// [SpinWheelPainter], [SpinWheelPointer], [SpinWheelPrizeLabels],
/// [SpinWheelHub], [SpinWheelTitle], [SpinWheelCountdown],
/// [SpinWheelBalanceChip], [SpinWheelResultCard], [SpinWheelCloseButton].
class SpinWheelDialog extends StatefulWidget {
  /// Fires once per successful spin that wins a real prize (never for
  /// "no_luck"). Lets a caller that already shows a rewards list (the My
  /// Rewards screen) prepend the new reward immediately, without a refetch.
  /// Also marks that the dialog was opened FROM My Rewards (see
  /// [_SpinWheelDialogState._openMyRewards]).
  final void Function(SpinReward reward)? onRewardWon;

  const SpinWheelDialog({super.key, this.onRewardWon});

  /// Shows the dialog at most once per calendar day. Call from HomeScreen
  /// after the layout loads. Does nothing unless the settings API's
  /// `spin_wheel_available` flag is on, so the backend can disable the whole
  /// feature without an app update.
  static void maybeShow(BuildContext context) {
    final settings = SettingsHiveBox.instance.getAppSettings();
    if (settings?.spinWheelAvailable != 1) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (SettingsHiveBox.instance.spinWheelLastShownDate == today) return;
    SettingsHiveBox.instance.setSpinWheelLastShownDate(today);
    show(context);
  }

  /// Opens the dialog directly (e.g. from a "Play Now" button), skipping the
  /// once-per-day check in [maybeShow].
  static void show(
    BuildContext context, {
    void Function(SpinReward reward)? onRewardWon,
    NavCubit? navCubit,
  }) {
    // The dialog is a separate route, so it can't see the main screen's
    // NavCubit on its own. Grab it here (null if the caller isn't under the
    // main screen) and hand it in, so "Shop Now" can switch to the Home tab.
    // A caller that already holds it (the "Spin Again" reopen) passes it in.
    if (navCubit == null) {
      try {
        navCubit = context.read<NavCubit>();
      } catch (_) {}
    }
    showDialog(
      context: context,
      barrierColor: SpinWheelPalette.backgroundTop,
      // Let the dialog's own gradient run under the status/nav bars; the
      // content keeps its own SafeArea.
      useSafeArea: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SpinActionCubit()),
          BlocProvider(create: (_) => SpinWheelConfigCubit()..load()),
          if (navCubit != null) BlocProvider<NavCubit>.value(value: navCubit),
        ],
        child: SpinWheelDialog(onRewardWon: onRewardWon),
      ),
    );
  }

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with TickerProviderStateMixin {
  // ── Layout ────────────────────────────────────────────────────────────────
  // The wheel is capped so it doesn't balloon on tablets.
  static const _wheelWidthFraction = 0.78; // of screen width
  static const _wheelMaxSize = 320.0;

  // ── Spin animation ────────────────────────────────────────────────────────
  // Phase 1 loops fast while the spin API call is in flight; phase 2 lands on
  // the winning segment after the response arrives.
  static const _loopDuration = Duration(milliseconds: 700);
  static const _landDuration = Duration(milliseconds: 1800);
  static const _extraLandingTurns = 4; // full turns added for a real "spin"
  // Pause after the wheel stops (confetti plays) before the result opens.
  static const _resultCardDelay = Duration(milliseconds: 900);

  // Pin wobble while spinning: `sin(controllerValue * frequency) * amplitude`.
  static const _pinWobbleFrequency = 46.0;
  static const _pinWobbleAmplitude = 0.07; // radians

  // ── Colors ────────────────────────────────────────────────────────────────
  // Values live in AppColors (spinWheel* section); these are short aliases.
  // Used as fallbacks and for confetti — the wheel's real ring / slice /
  // label colors come from the config API's `campaign.theme` and segments.
  static const _cream = AppColors.spinWheelCream;
  static const _gold = AppColors.spinWheelGold;
  static const _confettiColors = [
    _cream,
    _gold,
    AppColors.spinWheelCrimson,
    AppColors.green,
    AppColors.spinWheelConfettiBlue,
  ];

  // ── Controllers & animation ───────────────────────────────────────────────
  final _soundPlayer = AudioPlayer();
  late final AnimationController _controller; // wheel rotation
  late Animation<double> _rotation;
  // Slice boundary last passed while the wheel decelerates — each new one
  // fires a detent tick, like a real prize wheel's pointer clicking pegs.
  // Null outside the landing phase (the fast loop would just buzz).
  int? _lastTickSlice;
  // Confetti burst on a win; runs once per result.
  late final AnimationController _celebrationController;
  late final List<ConfettiParticle> _confettiParticles;

  // ── Wheel config (filled from SpinWheelConfigCubit) ───────────────────────
  // Segment order matches the backend array index-for-index, so the
  // `segment_index` returned by the spin API lands on the right slice.
  List<SpinSegment> _segments = [];
  List<Color> _sliceColors = [];
  bool _canSpin = true;
  String _spinsReason = ''; // why spinning is blocked (from the API)
  // Ring color — campaign.theme.border_color. Also drives the hub.
  Color _ringColor = _gold;
  // Pin color — campaign.theme.pointer_color. Falls back to the ring color
  // when absent.
  Color _pointerColor = _gold;
  // Divider-line color (the spokes between slices) — campaign.theme.line_color.
  Color _lineColor = _gold;
  // Glossy slice shine only when campaign.theme.segment_fill == "glossy".
  bool _segmentsGlossy = false;
  // Wheel-centre image — campaign.theme.hub_icon_url. Empty → default star.
  String _hubIconUrl = '';
  // Title line colors — theme.title_color / title_color_2. Null → defaults.
  Color? _titleColor;
  Color? _titleColor2;

  // ── Spin state ────────────────────────────────────────────────────────────
  bool _spinning = false;
  SpinResultData? _apiResult;
  bool _celebrationIsWin = false;

  // The result card opens a beat after the wheel stops, once this dialog has
  // closed itself (see [_showResult]).
  Timer? _resultCardTimer;

  // ── Blocked-tap banner ────────────────────────────────────────────────────
  // Shown INSIDE the dialog rather than as a SnackBar: a SnackBar attaches to
  // the Scaffold behind this full-screen dialog's barrier and would render
  // underneath it, unseen.
  String? _blockedMessage;
  Timer? _blockedMessageTimer;

  // ── "Next spin in" countdown ──────────────────────────────────────────────
  // Anchored to the API's seconds-remaining offset (`next_spin_in_seconds`),
  // not the absolute `next_spin_at`, so a wrong device clock can't skew it.
  // [_remaining] updates every second and is listened to only by the
  // countdown widget; [_countdownActive] flips (with a rebuild) just when the
  // countdown starts or ends.
  final ValueNotifier<Duration> _remaining = ValueNotifier(Duration.zero);
  bool _countdownActive = false;
  Timer? _countdownTimer;

  // ── Wallet chip ───────────────────────────────────────────────────────────
  // Wallet-won total for the top-right chip: the `rewards` API summary, the
  // same figure as the "Wallet Rewards" card on My Rewards. Null until loaded.
  final ValueNotifier<num?> _walletWon = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    unawaited(_loadWalletWon());
    unawaited(_preloadSpinSound());

    _controller = AnimationController(vsync: this, duration: _landDuration);
    _rotation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _controller.addListener(_onWheelTick);
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Fixed, seeded particles (not regenerated per spin): fall column, drift,
    // color and speed stay stable across replays; only the reveal is new.
    // They fall from above the screen past the wheel, across the full width.
    final rand = math.Random(7);
    _confettiParticles = List.generate(36, (i) {
      return ConfettiParticle(
        startXFrac: rand.nextDouble(),
        fallSpeed: 520 + rand.nextDouble() * 260,
        driftAmplitude: 14 + rand.nextDouble() * 22,
        driftPhase: rand.nextDouble() * 2 * math.pi,
        size: 6 + rand.nextDouble() * 6,
        color: _confettiColors[i % _confettiColors.length],
        spin: (rand.nextDouble() - 0.5) * 10,
        delayFrac: rand.nextDouble() * 0.35,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _celebrationController.dispose();
    _blockedMessageTimer?.cancel();
    _countdownTimer?.cancel();
    _resultCardTimer?.cancel();
    _soundPlayer.dispose();
    _walletWon.dispose();
    _remaining.dispose();
    super.dispose();
  }

  // ── Sound ─────────────────────────────────────────────────────────────────

  /// Loads the spin sound up front so SPIN only has to resume it. Calling
  /// play(AssetSource) on tap loaded the asset first, so the sound started
  /// noticeably after the wheel. ReleaseMode.stop keeps the source loaded
  /// after stop(), ready for the next spin. lowLatency (SoundPool on Android)
  /// starts short effects near-instantly, unlike MediaPlayer.
  Future<void> _preloadSpinSound() async {
    try {
      await _soundPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _soundPlayer.setReleaseMode(ReleaseMode.stop);
      // AssetSource paths are relative to the assets/ folder itself (per
      // audioplayers), unlike AssetsConstants' other paths which include it.
      await _soundPlayer.setSource(
        AssetSource(AssetsConstants.spinSound.replaceFirst('assets/', '')),
      );
    } catch (_) {
      // Sound is optional; the wheel still spins without it.
    }
  }

  /// No seek: an awaited seek delayed the start, and stop() already rewinds.
  Future<void> _playSpinSound() async {
    try {
      await _soundPlayer.resume();
    } catch (_) {}
  }

  // ── Wallet chip ───────────────────────────────────────────────────────────

  /// Fetches the wallet-won total for the chip. Skipped for guests; if the
  /// request fails the chip simply stays hidden.
  Future<void> _loadWalletWon() async {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    try {
      final response = await SpinWheelRepository().getRewards(limit: 1);
      if (mounted) _walletWon.value = response.data?.summary?.walletWon;
    } catch (_) {
      // Intentionally ignored — see doc comment.
    }
  }

  /// Chip tap: closes the dialog and opens My Rewards. When the dialog was
  /// opened FROM My Rewards (its caller passes [SpinWheelDialog.onRewardWon])
  /// it only closes, so My Rewards isn't stacked on top of itself.
  void _openMyRewards() {
    final navigator = Navigator.of(context);
    final fromRewards = widget.onRewardWon != null;
    navigator.pop();
    if (!fromRewards) navigator.pushNamed(RouteNames.spinWheelRewards);
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  void _showBlockedMessage(String message) {
    _blockedMessageTimer?.cancel();
    setState(() => _blockedMessage = message);
    _blockedMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _blockedMessage = null);
    });
  }

  // ── Countdown ─────────────────────────────────────────────────────────────

  /// (Re)starts the countdown from the API's `next_spin_in_seconds`. A null or
  /// non-positive value clears it.
  void _syncCountdown(int? nextSpinInSeconds) {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    if (nextSpinInSeconds == null || nextSpinInSeconds <= 0) {
      _remaining.value = Duration.zero;
      setState(() => _countdownActive = false);
      return;
    }
    final target = DateTime.now().add(Duration(seconds: nextSpinInSeconds));
    _tickCountdown(target);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(target),
    );
  }

  void _tickCountdown(DateTime target) {
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _remaining.value = Duration.zero;
      if (mounted) setState(() => _countdownActive = false);
      return;
    }
    _remaining.value = remaining;
    if (!_countdownActive && mounted) setState(() => _countdownActive = true);
  }

  // ── Spinning ──────────────────────────────────────────────────────────────

  /// Wraps [angle] into [0, 2*pi).
  double _wrapTo2Pi(double angle) =>
      angle - (2 * math.pi) * (angle / (2 * math.pi)).floorToDouble();

  /// SPIN button handler. Order matters: login check first, then wheel data,
  /// then the quota, then the spin itself.
  Future<void> _spin() async {
    if (_spinning) return;

    // Checked before the segment / quota guards: a guest tapping SPIN should
    // always be sent to login, even if the wheel config didn't load for them.
    if (!AuthHiveBox.instance.isLoggedIn) {
      AppNavigator.pop(context);
      AppNavigator.pushNamed(context, RouteNames.login);
      return;
    }

    if (_segments.isEmpty) return;
    if (!_canSpin) {
      // Blocked by the wheel's own can_spin (from the initial config, or
      // updated after a spin used up the quota): tell the user why instead of
      // silently doing nothing.
      if (_spinsReason.isNotEmpty) _showBlockedMessage(_spinsReason);
      return;
    }

    setState(() {
      _spinning = true;
      _apiResult = null;
      _celebrationIsWin = false;
    });

    AppHaptics.impact();
    unawaited(_playSpinSound());

    // Phase 1: spin in a fast linear loop for as long as the API call takes.
    // repeat() replays this 0 -> 2*pi tween without ever completing, so the
    // wheel's on-screen angle is always `controller.value * 2*pi`.
    _rotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller
      ..duration = _loopDuration
      ..reset()
      ..repeat();

    await context.read<SpinActionCubit>().spin();
  }

  /// Phase 2: decelerates from wherever the loop left off and stops with
  /// segment [rawIndex] under the top pointer, then shows the result.
  void _landOnSegment(int rawIndex) {
    _controller.stop();

    final index = rawIndex.clamp(0, _segments.length - 1);
    final currentTotal = _controller.value * 2 * math.pi;

    // SpinWheelPainter draws slice i over [i*segment - pi/2, (i+1)*segment -
    // pi/2], so its CENTER is at (i + 0.5) * segment - pi/2, not i * segment.
    // To bring slice `index` under the fixed top pointer the wheel must rotate
    // back by that center angle (the -pi/2 cancels: the pointer is at -pi/2).
    final segment = 2 * math.pi / _segments.length;
    final targetCenterAngle = (index + 0.5) * segment;
    // Stop somewhere inside the slice, not always dead centre.
    final randomOffsetInSlice =
        (math.Random().nextDouble() - 0.5) * segment * 0.6;
    final targetMod = _wrapTo2Pi(-(targetCenterAngle + randomOffsetInSlice));

    // Keep rotating forward (never backward) from the loop's current phase,
    // plus a few extra turns so the deceleration reads as a proper spin.
    final currentMod = _wrapTo2Pi(currentTotal);
    final delta = _wrapTo2Pi(targetMod - currentMod);
    final endAngle = currentTotal + delta + (2 * math.pi * _extraLandingTurns);

    _lastTickSlice = (currentTotal / segment).floor();
    setState(() {
      _rotation = Tween<double>(begin: currentTotal, end: endAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
    });
    _controller
      ..duration = _landDuration
      ..reset()
      ..forward().whenComplete(_onWheelStopped);
  }

  void _onWheelTick() {
    final last = _lastTickSlice;
    if (last == null || _segments.isEmpty) return;
    final slice = (_rotation.value / (2 * math.pi / _segments.length)).floor();
    if (slice != last) {
      _lastTickSlice = slice;
      AppHaptics.tick();
    }
  }

  /// Runs once the wheel has fully stopped.
  void _onWheelStopped() {
    _lastTickSlice = null;
    unawaited(_soundPlayer.stop());
    if (!mounted) return;
    setState(() => _spinning = false);

    _celebrationIsWin = _apiResult?.isWin ?? false;
    if (_celebrationIsWin) AppHaptics.success();
    _celebrationController
      ..reset()
      ..forward();

    // A wallet win changes the chip's total, so refetch the summary.
    unawaited(_loadWalletWon());

    // Reported here, not when the API responds: the response usually arrives
    // well before the wheel stops, and adding the reward to a list that early
    // made it visibly pop in while the wheel was still spinning. Never for
    // "no_luck" (no `reward` block anyway, but this also guards a backend that
    // sends one regardless of reward_type).
    final wonReward = _apiResult?.reward;
    if (wonReward != null && _apiResult?.isNoLuck != true) {
      widget.onRewardWon?.call(wonReward);
    }

    // Closes this dialog and opens the result card on its own. Done last so
    // the callbacks above run while this State is still alive.
    final result = _apiResult;
    if (result != null) {
      _resultCardTimer?.cancel();
      _resultCardTimer = Timer(_resultCardDelay, () {
        if (mounted) _showResult(result);
      });
    }
  }

  /// Closes the wheel dialog and shows the result card in a dialog of its own.
  ///
  /// The navigator's own context is used for the new dialog (this widget's
  /// context dies with the pop). "Spin Again" reopens the wheel (the user taps to spin);
  /// "Shop Now" (no spins left) unwinds to the main screen's Home tab.
  void _showResult(SpinResultData result) {
    final navigator = Navigator.of(context);
    final navContext = navigator.context;
    final canSpinAgain = _canSpin;
    final onRewardWon = widget.onRewardWon;
    final prizeIconUrl =
        result.segmentIndex >= 0 && result.segmentIndex < _segments.length
        ? _segments[result.segmentIndex].iconUrl
        : null;
    NavCubit? navCubit;
    try {
      navCubit = context.read<NavCubit>();
    } catch (_) {}

    // pushReplacement swaps this dialog for the card in one step (a plain
    // pop + showDialog left the wheel dialog visible behind the card).
    navigator.pushReplacement(
      DialogRoute<void>(
        context: context,
        barrierColor: SpinWheelPalette.resultScrim,
        barrierDismissible: false,
        builder: (dialogContext) => Center(
          child: Material(
            type: MaterialType.transparency,
            child: SpinWheelResultCard(
              result: result,
              prizeIconUrl: prizeIconUrl,
              canSpinAgain: canSpinAgain,
              onClose: () => Navigator.of(dialogContext).pop(),
              onSpinAgain: () {
                Navigator.of(dialogContext).pop();
                SpinWheelDialog.show(
                  navContext,
                  onRewardWon: onRewardWon,
                  navCubit: navCubit,
                );
              },
              onShopNow: () {
                Navigator.of(
                  dialogContext,
                ).popUntil(ModalRoute.withName(RouteNames.main));
                navCubit?.changeTab(0);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleSpinFailure(String message) {
    _controller.stop();
    unawaited(_soundPlayer.stop());
    setState(() => _spinning = false);
    _showBlockedMessage(message);
  }

  // ── Bloc listeners ────────────────────────────────────────────────────────

  /// Hex string -> Color, or null when empty/invalid (caller keeps its default).
  Color? _parseOrNull(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    const probe = Color(0x00000000);
    final c = parseHexColor(hex, fallback: probe);
    return c == probe ? null : c;
  }

  /// Applies the config API response: segments, quota and campaign theme.
  void _onConfigLoaded(SpinWheelConfigLoaded state) {
    final data = state.data;
    final theme = data.campaign?.theme;
    // Re-theme the board (purple) and SPIN button (gold) from the API before
    // the rebuild below; invalid/empty colors fall back to the defaults.
    SpinWheelPurple.apply(_parseOrNull(theme?.bgColor));
    SpinWheelPurple.light = _parseOrNull(theme?.lightColor) ?? AppColors.white;
    SpinWheelGold.apply(_parseOrNull(theme?.buttonColor));
    setState(() {
      _segments = data.segments;
      _sliceColors = [
        for (final s in data.segments) parseHexColor(s.color, fallback: _cream),
      ];
      _canSpin = data.spins?.canSpin ?? true;
      _spinsReason = data.spins?.reason ?? '';
      _ringColor = theme?.borderColor != null
          ? parseHexColor(theme!.borderColor, fallback: _gold)
          : _gold;
      _lineColor = theme?.lineColor != null && theme!.lineColor.isNotEmpty
          ? parseHexColor(theme.lineColor, fallback: _ringColor)
          : _ringColor;
      _pointerColor =
          theme?.pointerColor != null && theme!.pointerColor.isNotEmpty
          ? parseHexColor(theme.pointerColor, fallback: _ringColor)
          : _ringColor;
      _segmentsGlossy = theme?.segmentFill == 'glossy';
      _hubIconUrl = theme?.hubIconUrl ?? '';
      _titleColor = _parseOrNull(theme?.titleColor);
      _titleColor2 = _parseOrNull(theme?.titleColor2);
    });
    _syncCountdown(data.spins?.nextSpinInSeconds);
  }

  /// Applies the spin API response: stores the result and lands the wheel.
  void _onSpinSucceeded(SpinResultData result) {
    _apiResult = result;
    // The spin API returns its own `spins` block (quota AFTER this spin).
    // Refreshing the gate from it blocks a second tap (with the backend's own
    // reason) the moment the quota runs out, without re-fetching the config.
    final updatedSpins = result.spins;
    if (updatedSpins != null) {
      _canSpin = updatedSpins.canSpin;
      _spinsReason = updatedSpins.reason;
    }
    // Warm the result card's hero icon while the wheel is still landing, so
    // the card opens with the image already decoded.
    final index = result.segmentIndex;
    if (index >= 0 && index < _segments.length) {
      unawaited(
        AppNetworkImage.precache(
          context,
          _segments[index].iconUrl.trim(),
          height: SpinWheelResultCard.heroIconSize,
        ).catchError((_) {}),
      );
    }
    _landOnSegment(result.segmentIndex);
    if (updatedSpins != null) _syncCountdown(updatedSpins.nextSpinInSeconds);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wheelSize = math.min(
      context.screenWidth * _wheelWidthFraction,
      _wheelMaxSize,
    );
    return BlocListener<SpinActionCubit, SpinActionState>(
      listener: (context, state) {
        if (state is SpinActionSuccess) {
          _onSpinSucceeded(state.result);
        } else if (state is SpinActionError) {
          _handleSpinFailure(state.message);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Status + nav bars take the dialog's dark ends so the screen reads
        // as one continuous background.
        value: SystemUiOverlayStyle(
          statusBarColor: SpinWheelPalette.backgroundTop,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: SpinWheelPalette.backgroundBottom,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Dialog(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          shadowColor: AppColors.transparent,
          elevation: 0,
          // Full-screen with no inset: a centred inset would centre the
          // content box vertically and leave the close button far below the
          // status bar. SafeArea + SizedBox.expand anchor it to the real top.
          insetPadding: EdgeInsets.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: SpinWheelPalette.backgroundColors,
                stops: SpinWheelPalette.backgroundStops,
              ),
            ),
            child: SafeArea(
              child: SizedBox.expand(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ThemeConstants.paddingL,
                        ),
                        child:
                            BlocConsumer<
                              SpinWheelConfigCubit,
                              SpinWheelConfigState
                            >(
                              listener: (context, state) {
                                if (state is SpinWheelConfigLoaded) {
                                  _onConfigLoaded(state);
                                }
                              },
                              builder: (context, state) =>
                                  _buildBody(context, state, wheelSize),
                            ),
                      ),
                    ),
                    PositionedDirectional(
                      top: ThemeConstants.paddingS,
                      start: ThemeConstants.paddingL,
                      child: SpinWheelCloseButton(
                        onTap: () => AppNavigator.pop(context),
                      ),
                    ),
                    PositionedDirectional(
                      top: ThemeConstants.paddingS,
                      end: ThemeConstants.paddingL,
                      child: SpinWheelBalanceChip(
                        amount: _walletWon,
                        onTap: _openMyRewards,
                      ),
                    ),
                    // Falls from above the screen past the wheel on a win.
                    // IgnorePointer so it never eats taps while it fades out.
                    if (_celebrationIsWin)
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _celebrationController,
                          builder: (context, _) => CustomPaint(
                            size: Size(
                              context.screenWidth,
                              context.screenHeight,
                            ),
                            painter: ConfettiPainter(
                              progress: _celebrationController.value,
                              particles: _confettiParticles,
                              startY: -20,
                              endY: context.screenHeight,
                            ),
                          ),
                        ),
                      ),
                    if (_blockedMessage != null) _buildBanner(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Centre column: title plus either a loader, an error with retry, or the
  /// board with the wheel — depending on the config API's state.
  Widget _buildBody(
    BuildContext context,
    SpinWheelConfigState state,
    double wheelSize,
  ) {
    if (state is SpinWheelConfigLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpinWheelTitle(),
          SizedBox(height: wheelSize * 0.2),
          const CircularProgressIndicator(color: _gold),
        ],
      );
    }
    if (state is SpinWheelConfigError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: wheelSize * 0.12),
          Container(
            width: wheelSize * 0.34,
            height: wheelSize * 0.34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.14),
              border: Border.all(
                color: _gold.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Center(
              child: AppSvgIcon(
                state.requiresLogin
                    ? AssetsConstants.userIcon
                    : AssetsConstants.locationOffIcon,
                size: wheelSize * 0.15,
                color: _gold,
              ),
            ),
          ),
          const SizedBox(height: ThemeConstants.spaceL),
          AppText(
            state.message,
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onPrimary),
          ),
          const SizedBox(height: ThemeConstants.spaceL),
          if (state.requiresLogin)
            AppButton(
              label: context.translate(LanguageLabelKeys.login),
              onPressed: () {
                AppNavigator.pop(context);
                AppNavigator.pushNamed(context, RouteNames.login);
              },
              backgroundColor: _gold,
              fullWidth: false,
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingXXL,
              ),
            )
          else
            TextButton(
              onPressed: () => context.read<SpinWheelConfigCubit>().load(),
              child: AppText(
                context.translate(LanguageLabelKeys.retry),
                style: context.tt.bodyMedium?.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
    }

    final campaign = (state as SpinWheelConfigLoaded).data.campaign;
    // The pin overhangs the top of the wheel (Clip.none). This gap keeps it
    // from colliding with the title above.
    final pinOverhang = SpinWheelPointer.overhangFor(wheelSize);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpinWheelTitle(
          title: campaign?.name,
          topColor: _titleColor,
          bottomColor: _titleColor2,
        ),
        SizedBox(height: wheelSize * 0.05 + pinOverhang),
        SpinWheelBoard(
          wheelSize: wheelSize,
          spinLabel: (campaign?.theme?.buttonText ?? '').trim().isNotEmpty
              ? campaign!.theme!.buttonText.trim()
              : context.translate(LanguageLabelKeys.spinButtonLabel),
          onSpinTap: _spin,
          animate: _spinning,
          countdown: (!_canSpin && _countdownActive)
              ? SpinWheelCountdown(remaining: _remaining)
              : null,
          child: _buildWheel(context, wheelSize, pinOverhang),
        ),
        SizedBox(height: wheelSize * 0.1),
      ],
    );
  }

  /// The wheel: rotating disc + prize labels, then the fixed pin and hub.
  Widget _buildWheel(
    BuildContext context,
    double wheelSize,
    double pinOverhang,
  ) {
    return SizedBox(
      width: wheelSize,
      height: wheelSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // The disc is the AnimatedBuilder's `child`, so it is built once
          // and only re-transformed each frame.
          AnimatedBuilder(
            animation: _rotation,
            builder: (context, child) =>
                Transform.rotate(angle: _rotation.value, child: child),
            // Cached as its own layer: spinning only re-transforms it.
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.square(wheelSize),
                painter: SpinWheelPainter(
                  sliceColors: _sliceColors,
                  ringColor: _ringColor,
                  lineColor: _lineColor,
                  glossy: _segmentsGlossy,
                ),
              ),
            ),
          ),
          SpinWheelPrizeLabels(
            segments: _segments,
            rotation: _rotation,
            wheelSize: wheelSize,
          ),
          // Fixed pin at the top. While spinning it wobbles as if ticking
          // against the slice dividers passing under it.
          Positioned(
            top: -pinOverhang,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => RepaintBoundary(
                child: SpinWheelPointer(
                  wheelSize: wheelSize,
                  ringColor: _pointerColor,
                  wiggleAngle: _spinning
                      ? math.sin(_controller.value * _pinWobbleFrequency) *
                            _pinWobbleAmplitude
                      : 0.0,
                ),
              ),
            ),
          ),
          SpinWheelHub(
            wheelSize: wheelSize,
            ringColor: _ringColor,
            iconUrl: _hubIconUrl,
          ),
        ],
      ),
    );
  }

  /// Error / "no spins left" banner near the bottom of the dialog.
  Widget _buildBanner(BuildContext context) {
    return Positioned(
      left: ThemeConstants.paddingL,
      right: ThemeConstants.paddingL,
      bottom: context.bottomSafePadding + ThemeConstants.paddingXXL,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
            vertical: ThemeConstants.paddingM,
          ),
          decoration: AppDecorations.shadowedCard(
            color: context.cs.error,
            shadowColor: context.cs.shadow.withValues(alpha: 0.35),
          ),
          child: AppText(
            _blockedMessage!,
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(
              color: context.cs.onError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
