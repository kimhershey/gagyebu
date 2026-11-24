import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../common/widgets.dart';
import 'account_deletion.dart';
import 'sub_screen.dart';

/// 계정 화면: 이메일, 로그아웃, 계정 삭제(`docs/SPEC.md` 4.5).
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final deleter = ref.watch(accountDeleterProvider);
    final user = status.user;

    final List<Widget> body;
    if (status.phase == SyncPhase.unavailable) {
      body = const [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          message:
              '이 앱에는 로그인이 들어 있지 않습니다.\n'
              '가계부는 이 기기 안에만 저장되고, 계정이 없습니다.',
        ),
      ];
    } else if (user == null) {
      body = const [
        EmptyState(
          icon: Icons.person_off_outlined,
          message: '로그인하지 않았습니다.\n로그인 화면으로 이동합니다.',
        ),
      ];
    } else {
      body = [
        SectionCard(
          title: '로그인한 계정',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  user.email ?? '이메일이 없는 계정입니다',
                  key: const ValueKey('account-email'),
                ),
              ),
              const HintText(
                '로그아웃은 이 기기에서만 합니다. 기기의 가계부는 지우지 않고, 같은 계정으로 다시 로그인하면 이어서 씁니다.',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('account-sign-out'),
                onPressed: ref.read(syncControllerProvider.notifier).signOut,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
        if (status.phase == SyncPhase.differentAccount) ...[
          // 기기에 있는 것은 다른 계정의 가계부다. 탈퇴하면서 그것까지 지우지 않게,
          // 먼저 설정에서 어느 가계부를 쓸지 정하게 한다.
          const SizedBox(height: 12),
          const HintText(
            '이 기기에는 다른 계정의 가계부가 있습니다. 설정의 계정 칸에서 먼저 정리한 뒤에 '
            '계정을 삭제할 수 있습니다.',
            key: ValueKey('delete-blocked'),
          ),
        ]
        // 서버 쪽이 이어 주기 전에는 지울 길이 없으므로 보이지 않는다.
        else if (deleter != null) ...[
          const SizedBox(height: 12),
          _DeleteAccountCard(email: user.email, deleter: deleter),
        ],
      ];
    }
    return SubScreen(title: '계정', children: body);
  }
}

class _DeleteAccountCard extends ConsumerStatefulWidget {
  const _DeleteAccountCard({required this.email, required this.deleter});

  final String? email;
  final Future<void> Function() deleter;

  @override
  ConsumerState<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends ConsumerState<_DeleteAccountCard> {
  final _typed = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  /// 단추를 켜려면 그대로 적어야 하는 글. 이메일이 없는 계정이면 '계정 삭제'를 적는다.
  String get _phrase => widget.email ?? '계정 삭제';

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    // 끝나면 앱이 다시 열려 이 화면이 사라진다. 필요한 것을 미리 잡아 둔다.
    final db = ref.read(repositoryProvider).db;
    final controller = ref.read(syncControllerProvider.notifier);
    final restart = ref.read(appRestartProvider);
    try {
      await deleteAccountAndLocalData(
        deleteOnServer: widget.deleter,
        db: db,
        signOut: controller.signOut,
        restart: restart,
      );
    } on Object {
      // 서버에서 지우지 못했다. 기기의 것도 지우지 않았다.
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final email = widget.email;

    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('· '),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return SectionCard(
      title: '계정 삭제',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('계정을 삭제하면 아래가 모두 지워지고 되돌릴 수 없습니다.'),
          bullet('서버에 있는 가계부 전체(거래, 자산, 분류, 예산, 반복 거래, 월별 요약)'),
          bullet(email == null ? '로그인 계정' : '로그인 계정($email)'),
          bullet(
            pending > 0 ? '이 기기의 가계부와 아직 올리지 않은 변경 $pending건' : '이 기기의 가계부',
          ),
          bullet('이 기기의 작업 기록과 동기화 충돌 기록'),
          const SizedBox(height: 8),
          const HintText(
            '다른 기기에 받아 둔 가계부는 그 기기에서 로그아웃하거나 앱을 지워야 없어집니다. '
            '남겨 둘 내용이 있으면 먼저 파일로 내보내 두십시오.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('delete-export-first'),
              onPressed: _busy ? null : () => context.go('/settings/data'),
              child: const Text('내보내기로 가기'),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            key: const ValueKey('delete-email'),
            controller: _typed,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: email == null
                  ? "확인을 위해 '$_phrase'를 그대로 적어 주십시오"
                  : '확인을 위해 이메일을 그대로 적어 주십시오',
              hintText: _phrase,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_failed) ...[
            const SizedBox(height: 8),
            Text(
              '계정을 삭제하지 못했습니다. 아무것도 지워지지 않았습니다. '
              '인터넷 연결을 확인하고 다시 시도해 주십시오.',
              key: const ValueKey('delete-error'),
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('delete-account'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            // 적은 글이 꼭 같아야 켜진다.
            onPressed: !_busy && _typed.text.trim() == _phrase ? _delete : null,
            child: Text(_busy ? '삭제하는 중입니다' : '계정 삭제'),
          ),
        ],
      ),
    );
  }
}
