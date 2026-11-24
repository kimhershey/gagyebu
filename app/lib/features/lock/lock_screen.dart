import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../common/widgets.dart';
import '../settings/sub_screen.dart';
import 'app_lock.dart';

/// 지금 하고 있는 일.
enum _Mode { idle, enabling, changing, disabling }

/// 앱 잠금 설정 화면(`docs/SPEC.md` 7.17): 켜기(번호 두 번), 바꾸기, 끄기, 생체 인증.
class LockSettingsScreen extends ConsumerStatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  ConsumerState<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends ConsumerState<LockSettingsScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  _Mode _mode = _Mode.idle;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _start(_Mode mode) => setState(() {
    _mode = mode;
    _error = null;
    _current.clear();
    _next.clear();
    _confirm.clear();
  });

  /// 지금 번호를 확인한다. 틀렸거나 기다려야 하면 알릴 말을 돌려준다. 맞으면 null.
  Future<String?> _checkCurrent(AppLock lock) async {
    final result = await lock.unlock(_current.text);
    if (result == UnlockResult.ok) return null;
    final wait = lock.waitRemaining;
    if (wait > Duration.zero) {
      return '다섯 번 틀렸습니다. ${wait.inSeconds + 1}초 뒤에 다시 해 주십시오';
    }
    return '지금 번호가 맞지 않습니다';
  }

  Future<void> _save() async {
    final lock = ref.read(appLockProvider);
    final messenger = ScaffoldMessenger.of(context);
    final mode = _mode;
    if (mode != _Mode.disabling) {
      if (!AppLock.isValidPin(_next.text)) {
        setState(() => _error = '새 번호는 숫자 4–6자리로 정해 주십시오');
        return;
      }
      if (_next.text != _confirm.text) {
        setState(() => _error = '두 번 넣은 번호가 서로 다릅니다');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    if (mode != _Mode.enabling) error = await _checkCurrent(lock);
    if (error == null) {
      if (mode == _Mode.disabling) {
        await lock.clear();
      } else {
        await lock.setPin(_next.text);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _mode = _Mode.idle;
    });
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (mode) {
            _Mode.disabling => '앱 잠금을 껐습니다',
            _Mode.changing => '잠금 번호를 바꿨습니다',
            _ => '앱 잠금을 켰습니다',
          }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lock = ref.watch(appLockProvider);
    final biometricAuth = ref.watch(biometricAuthProvider);
    final enabled = lock.isEnabled;

    Widget pinField(String key, String label, TextEditingController c) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: ValueKey(key),
            controller: c,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(AppLock.maxLength),
            ],
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => _save(),
          ),
        );

    final Widget body;
    if (_mode == _Mode.idle) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(enabled ? Icons.lock_outline : Icons.lock_open),
            title: Text(
              enabled ? '앱 잠금이 켜져 있습니다' : '앱 잠금이 꺼져 있습니다',
              key: const ValueKey('lock-status'),
            ),
            subtitle: const Text('앱을 켤 때와, 다른 앱에 갔다가 1분 넘어 돌아올 때 잠금 번호를 묻습니다'),
          ),
          const SizedBox(height: 4),
          if (!enabled)
            FilledButton(
              key: const ValueKey('lock-enable'),
              onPressed: () => _start(_Mode.enabling),
              child: const Text('잠금 켜기'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  key: const ValueKey('lock-change'),
                  onPressed: () => _start(_Mode.changing),
                  child: const Text('번호 바꾸기'),
                ),
                TextButton(
                  key: const ValueKey('lock-disable'),
                  onPressed: () => _start(_Mode.disabling),
                  child: const Text('잠금 끄기'),
                ),
              ],
            ),
          // 이 기기에서 생체 인증을 쓸 수 있을 때만 보인다.
          if (enabled && biometricAuth != null)
            SwitchListTile(
              key: const ValueKey('lock-biometric'),
              contentPadding: EdgeInsets.zero,
              title: const Text('생체 인증으로도 풀기'),
              subtitle: const Text('지문이나 얼굴로 잠금을 풉니다. 번호로도 풀 수 있습니다'),
              value: lock.biometricEnabled,
              onChanged: (value) async {
                await lock.setBiometric(value);
                if (mounted) setState(() {});
              },
            ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (_mode) {
            _Mode.enabling => '잠금 번호를 숫자 4–6자리로 정하고, 한 번 더 넣어 주십시오.',
            _Mode.changing => '지금 번호를 넣고, 새 번호를 두 번 넣어 주십시오.',
            _ => '잠금을 끄려면 지금 번호를 넣어 주십시오.',
          }),
          const SizedBox(height: 12),
          if (_mode != _Mode.enabling)
            pinField('lock-current-pin', '지금 번호', _current),
          if (_mode != _Mode.disabling) ...[
            pinField('lock-new-pin', '새 번호(숫자 4–6자리)', _next),
            pinField('lock-confirm-pin', '새 번호 한 번 더', _confirm),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                key: const ValueKey('lock-error'),
                style: TextStyle(color: scheme.error),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                key: const ValueKey('lock-cancel'),
                onPressed: _busy ? null : () => _start(_Mode.idle),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const ValueKey('lock-save'),
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? '확인하는 중입니다'
                      : switch (_mode) {
                          _Mode.disabling => '잠금 끄기',
                          _Mode.changing => '번호 바꾸기',
                          _ => '잠금 켜기',
                        },
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SubScreen(
      title: '앱 잠금',
      children: [
        SectionCard(title: '잠금 번호', child: body),
        const SizedBox(height: 12),
        SectionCard(
          title: '알아 둘 것',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '화면만 가립니다. 기기의 파일은 암호화하지 않습니다.',
                key: ValueKey('lock-notice'),
              ),
              const SizedBox(height: 6),
              Text(
                '잠금 번호는 이 기기에만 두고 서버로 보내지 않습니다. 기기마다 따로 정합니다.\n'
                '번호를 잊으면 잠금 화면에서 "번호를 잊었습니다"를 눌러 로그아웃한 뒤 다시 '
                '로그인하면 됩니다. 잠금이 꺼지고, 기기의 가계부는 그대로 있습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
