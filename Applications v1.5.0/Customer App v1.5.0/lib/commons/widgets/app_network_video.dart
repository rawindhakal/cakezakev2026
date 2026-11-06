import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lets an ancestor switch off playback for a whole subtree — e.g. the
/// product detail pager keeps neighbouring products mounted, and only the
/// active one may play its gallery video.
class MediaPlaybackScope extends InheritedWidget {
  const MediaPlaybackScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MediaPlaybackScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(MediaPlaybackScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Network video sized like an image (honours [fit]).
///
/// With [play] false it is a still: the first frame plus a play badge. With
/// [play] true it plays (looped) whenever it is actually on screen — paused
/// while its route is covered, its [MediaPlaybackScope] is off, or the app
/// is in the background.
class AppNetworkVideo extends StatefulWidget {
  const AppNetworkVideo({
    super.key,
    required this.url,
    this.play = false,
    this.muted = true,
    this.showControls = false,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  final String url;
  final bool play;
  final bool muted;

  /// Tap to pause/resume, plus a progress bar and a mute toggle. Leave off
  /// where the parent handles taps itself (e.g. the detail gallery opens the
  /// full-screen viewer).
  final bool showControls;
  final BoxFit fit;

  /// Shown until the first frame is ready.
  final Widget? placeholder;

  @override
  State<AppNetworkVideo> createState() => _AppNetworkVideoState();
}

class _AppNetworkVideoState extends State<AppNetworkVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _userPaused = false;
  bool _muted = true;
  bool _visible = true;
  bool _appResumed = true;
  bool _wasPlaying = false;
  bool _wasBuffering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = widget.muted;
    _init();
  }

  void _init() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      _failed = true;
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      // Muted autoplay must not stop whatever audio the user is listening to.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: widget.muted),
    );
    _controller = controller;
    controller
        .initialize()
        .then((_) async {
          if (!mounted || _controller != controller) return;
          await controller.setLooping(true);
          await controller.setVolume(_muted ? 0 : 1);
          if (!mounted) return;
          setState(() {});
          _sync();
        })
        .catchError((Object _) {
          if (mounted && _controller == controller) {
            setState(() => _failed = true);
          }
        });
    controller.addListener(_onTick);
  }

  void _onTick() {
    // The controller notifies on every position update; only the play badge
    // and buffering spinner depend on it (the frame repaints via its texture).
    final v = _controller?.value;
    if (v == null || !mounted) return;
    if (v.isPlaying != _wasPlaying || v.isBuffering != _wasBuffering) {
      setState(() {
        _wasPlaying = v.isPlaying;
        _wasBuffering = v.isBuffering;
      });
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    c?.removeListener(_onTick);
    c?.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode goes off when a route covers this one (e.g. the full-screen
    // viewer pushed over the detail page).
    _visible =
        TickerMode.valuesOf(context).enabled && MediaPlaybackScope.of(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant AppNetworkVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _failed = false;
      _userPaused = false;
      _init();
      return;
    }
    // Swiped back onto this page — start playing again.
    if (widget.play && !oldWidget.play) _userPaused = false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final shouldPlay = widget.play && _visible && _appResumed && !_userPaused;
    if (shouldPlay && !c.value.isPlaying) {
      c.play();
    } else if (!shouldPlay && c.value.isPlaying) {
      c.pause();
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _userPaused = c.value.isPlaying;
    if (!_userPaused && c.value.position >= c.value.duration) {
      c.seekTo(Duration.zero);
    }
    _sync();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed || c == null || !c.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.placeholder ?? _placeholder(context),
          if (!_failed && widget.play) const LoadingWidget(),
          if (!widget.play) const Center(child: _PlayBadge()),
        ],
      );
    }

    final size = c.value.size;
    final video = ClipRect(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(c),
        ),
      ),
    );

    final showBadge = !c.value.isPlaying && !c.value.isBuffering;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        video,
        if (c.value.isBuffering && widget.play) const LoadingWidget(),
        if (showBadge) const Center(child: _PlayBadge()),
        if (widget.showControls) ...[
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              colors: VideoProgressColors(
                playedColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          PositionedDirectional(
            end: 8,
            bottom: 16,
            child: IconButton.filled(
              onPressed: _toggleMute,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );

    if (!widget.showControls) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: content,
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const AppSvgIcon(
        AssetsConstants.playIcon,
        color: Colors.white,
        bakeTint: true,
        size: 20,
      ),
    );
  }
}
