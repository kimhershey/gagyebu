import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import 'app_lock.dart';

/// 앱 잠금이 켜져 있으면 [child] 대신 잠금 화면을 보여 준다(`docs/SPEC.md` 7.17).
///
/// 앱을 켤 때와, 뒤로 보냈다가 1분 넘어 돌아올 때 잠근다. 잠긴 동안에도 [child]는 그대로
/// 살려 둔다(보던 화면과 적던 글이 남게). 다만 그리지 않고, 누르거나 글을 넣을 수 없게 한다.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;

  /// 앱이 뒤로 간 때. 앞에 있는 동안에는 null이다.
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    _locked = ref.read(appLockProvider).isEnabled;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = ref.read(clockProvider)();
    switch (state) {
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt == null || _locked) return;
        if (ref.read(appLockProvider).isEnabled &&
            now.difference(leftAt) > AppLock.relockAfter) {
          setState(() => _locked = true);
        }
      case AppLifecycleState.inactive:
        // 창이 초점만 잃은 것이다(다른 창을 눌렀거나 알림을 내렸다). 화면은 보이고 있다.
        break;
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _leftAt ??= now;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 잠겼을 때와 아닐 때 [child]의 자리가 같아야 상태가 남는다.
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !_locked,
          child: ExcludeFocus(
            excluding: _locked,
            child: Offstage(offstage: _locked, child: widget.child),
          ),
        ),
        if (_locked)
          LockScreen(
            key: const ValueKey('lock-screen'),
            onUnlocked: () => setState(() => _locked = false),
          ),
      ],
    );
  }
}

/// 잠금 화면: 번호판으로 잠금 번호를 받는다.
///
/// 화면 이동(Navigator) 바깥에 뜨므로 대화상자와 풍선 도움말을 쓰지 않는다.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _focus = FocusNode(debugLabel: 'lock-screen');
  String _pin = '';
  String? _message;
  bool _checking = false;

  /// '번호를 잊었습니다'를 눌러 로그아웃할지 묻는 중인지.
  bool _confirmingForget = false;

  /// 기다리는 동안 남은 시간을 다시 그리게 하는 시계.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (ref.read(appLockProvider).waitRemaining > Duration.zero) {
        _startTicker();
      } else {
        _tryBiometric();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (ref.read(appLockProvider).waitRemaining == Duration.zero) {
        timer.cancel();
        setState(() => _message = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _tryBiometric() async {
    final authenticate = ref.read(biometricAuthProvider);
    final lock = ref.read(appLockProvider);
    if (authenticate == null || !lock.biometricEnabled || _checking) return;
    var passed = false;
    try {
      passed = await authenticate();
    } on Object {
      // 기기가 생체 인증을 띄우지 못했다. 번호로 푼다.
      passed = false;
    }
    if (passed && mounted) widget.onUnlocked();
  }

  void _digit(String digit) {
    if (_checking || _pin.length >= AppLock.maxLength) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
  }

  void _backspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final lock = ref.read(appLockProvider);
    if (_checking || lock.waitRemaining > Duration.zero) return;
    if (_pin.length < AppLock.minLength) {
      setState(() => _message = '숫자 4–6자리를 넣어 주십시오');
      return;
    }
    final pin = _pin;
    setState(() {
      _checking = true;
      _message = null;
    });
    final result = await lock.unlock(pin);
    if (!mounted) return;
    if (result == UnlockResult.ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _checking = false;
      _pin = '';
      if (lock.waitRemaining > Duration.zero) {
        _message = null;
        _startTicker();
      } else {
        _message =
            '번호가 맞지 않습니다. ${lock.attemptsLeft}번 더 틀리면 '
            '${AppLock.waitAfterFailures.inSeconds}초 동안 기다려야 합니다';
      }
    });
  }

  Future<void> _forget() async {
    final controller = ref.read(syncControllerProvider.notifier);
    await ref.read(appLockProvider).clear();
    try {
      await controller.signOut();
    } on Object {
      // 서버에 닿지 못해도 잠금은 이미 꺼졌다. 화면은 로그인 상태를 따라간다.
    }
    if (mounted) widget.onUnlocked();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _confirmingForget) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null && RegExp(r'^[0-9]$').hasMatch(character)) {
      _digit(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lock = ref.watch(appLockProvider);
    final status = ref.watch(syncControllerProvider);
    final biometric =
        ref.watch(biometricAuthProvider) != null && lock.biometricEnabled;
    final wait = lock.waitRemaining;
    final waiting = wait > Duration.zero;
    // 로그인이 없는 빌드에는 로그아웃으로 푸는 길이 없다.
    final canForget = status.phase != SyncPhase.unavailable;

    final Widget panel;
    if (_confirmingForget) {
      panel = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '로그아웃하고 잠금을 풉니다',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '로그아웃하면 앱 잠금이 꺼집니다. 기기의 가계부는 그대로 있고, 다시 로그인하면 '
            '이어서 쓸 수 있습니다. 잠금은 설정에서 다시 켭니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                key: const ValueKey('lock-forgot-cancel'),
                onPressed: () => setState(() => _confirmingForget = false),
                child: const Text('돌아가기'),
              ),
              FilledButton(
                key: const ValueKey('lock-forgot-confirm'),
                onPressed: _forget,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ],
      );
    } else {
      panel = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '잠금 번호를 넣어 주십시오',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _PinDots(length: _pin.length),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Center(
              child: _checking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : waiting
                  ? Text(
                      '다섯 번 틀렸습니다. ${_seconds(wait)}초 뒤에 다시 넣을 수 있습니다',
                      key: const ValueKey('lock-wait'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    )
                  : Text(
                      _message ?? '',
                      key: const ValueKey('lock-message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          _PinPad(
            enabled: !_checking && !waiting,
            onDigit: _digit,
            onBackspace: _backspace,
            onSubmit: _submit,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (biometric)
                TextButton(
                  key: const ValueKey('lock-biometric-unlock'),
                  onPressed: _checking ? null : _tryBiometric,
                  child: const Text('생체 인증으로 풀기'),
                ),
              if (canForget)
                TextButton(
                  key: const ValueKey('lock-forgot'),
                  onPressed: _checking
                      ? null
                      : () => setState(() => _confirmingForget = true),
                  child: const Text('번호를 잊었습니다'),
                ),
            ],
          ),
        ],
      );
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 남은 시간을 올림한 초. 29.2초 남았으면 30초로 보인다.
  static int _seconds(Duration left) =>
      (left.inMilliseconds / 1000).ceil().clamp(1, 1 << 30);
}

/// 넣은 자릿수만큼 채워지는 점. 번호는 보이지 않는다.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$length자리 넣음',
      child: Row(
        key: const ValueKey('pin-dots'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < AppLock.maxLength; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < length ? scheme.primary : null,
                border: Border.all(
                  color: i < length ? scheme.primary : scheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 숫자 번호판. 맨 아랫줄은 지우기 · 0 · 확인이다.
class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget cell(Widget child) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(height: 56, child: child),
      ),
    );
    // 글자를 키워도 단추 밖으로 나가지 않게 줄여 넣는다.
    Widget fitted(String text, {TextStyle? style}) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
    );
    Widget digit(String d) => cell(
      OutlinedButton(
        key: ValueKey('pin-$d'),
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: enabled ? () => onDigit(d) : null,
        child: fitted(d, style: theme.textTheme.titleLarge),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) digit(d)]),
        Row(
          children: [
            cell(
              TextButton(
                key: const ValueKey('pin-back'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: enabled ? onBackspace : null,
                child: fitted('지우기'),
              ),
            ),
            digit('0'),
            cell(
              FilledButton(
                key: const ValueKey('pin-ok'),
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: enabled ? onSubmit : null,
                child: fitted('확인'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
