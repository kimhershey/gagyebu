import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../data/prefs/device_prefs.dart';
import '../../domain/enums.dart';
import '../composer/composer_state.dart';
import 'onboarding_queries.dart';
import 'storage_persist.dart';

/// 첫 실행 안내를 다시 보이지 않게 적어 두는 기기 설정의 키.
const onboardingDoneKey = 'onboarding.done';

/// 첫 실행 안내를 웹용(홈 화면에 추가)으로 보일지. 아니면 앱용(AI 모델 내려받기)이다.
final onboardingForWebProvider = Provider<bool>((ref) => kIsWeb);

/// 브라우저의 저장소 유지(`navigator.storage`). 시험에서 바꿔 끼운다.
class StoragePersistence {
  const StoragePersistence({required this.isPersisted, required this.request});

  /// 이미 허락받았는지.
  final Future<bool> Function() isPersisted;

  /// 유지를 청한다. 허락받았으면 true.
  final Future<bool> Function() request;
}

final storagePersistenceProvider = Provider<StoragePersistence>(
  (ref) => const StoragePersistence(
    isPersisted: isStoragePersisted,
    request: requestPersistentStorage,
  ),
);

/// 처음 들어온 사용자에게 할 일을 알려 주는 카드(`docs/SPEC.md` 7.19).
/// 보여 줄 것이 없으면 아무것도 그리지 않는다. 홈 화면 맨 위에 둔다.
///
/// ① 자산 등록하기 ② 결제 문자 붙여넣어 보기 ③ 앱은 AI 모델 내려받기, 웹은 홈 화면에 추가.
/// "닫기"를 누르거나 셋을 모두 끝내면 기기 설정에 적고 다시 보이지 않는다.
class OnboardingCard extends ConsumerStatefulWidget {
  const OnboardingCard({super.key});

  @override
  ConsumerState<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends ConsumerState<OnboardingCard> {
  late bool _hidden;

  /// 웹: 홈 화면에 추가하는 방법을 봤는지(또는 저장소 유지를 이미 허락받았는지).
  bool _installSeen = false;

  /// 다 끝나 닫는 일을 걸어 두었는지. 한 번만 건다.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _hidden =
        ref.read(devicePrefsProvider).getString(onboardingDoneKey) == 'true';
    if (!_hidden && ref.read(onboardingForWebProvider)) {
      ref.read(storagePersistenceProvider).isPersisted().then((persisted) {
        if (persisted && mounted) setState(() => _installSeen = true);
      }, onError: (Object _) {});
    }
  }

  Future<void> _close() async {
    setState(() => _hidden = true);
    await ref.read(devicePrefsProvider).setString(onboardingDoneKey, 'true');
  }

  /// 복사해 둔 글을 입력창에 채운다. 사용자가 확인하고 보낸다.
  Future<void> _paste() async {
    final messenger = ScaffoldMessenger.of(context);
    final incoming = ref.read(incomingTextProvider.notifier);
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } on Object {
      // 브라우저가 클립보드를 읽지 못하게 했다.
      text = null;
    }
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('복사해 둔 글이 없습니다. 결제 문자를 복사한 뒤 입력창에 붙여넣어 주십시오'),
        ),
      );
      return;
    }
    incoming.offer(text);
    messenger.showSnackBar(
      const SnackBar(content: Text('복사해 둔 글을 입력창에 채웠습니다. 확인하고 보내 주십시오')),
    );
  }

  /// 저장소 유지를 청하고, 홈 화면에 추가하는 방법을 보여 준다.
  Future<void> _install() async {
    var granted = false;
    try {
      granted = await ref.read(storagePersistenceProvider).request();
    } on Object {
      granted = false;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('홈 화면에 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('홈 화면에 추가하면 앱처럼 바로 열립니다.'),
              const SizedBox(height: 8),
              const Text('· iPhone · iPad(Safari): 공유 단추를 누르고 "홈 화면에 추가"'),
              const Text('· Android(Chrome): 메뉴에서 "홈 화면에 추가" 또는 "앱 설치"'),
              const Text('· PC(Chrome · Edge): 주소창 오른쪽의 설치 단추'),
              const SizedBox(height: 12),
              Text(
                granted
                    ? '이 브라우저가 가계부의 저장소를 지우지 않기로 했습니다.'
                    : '브라우저가 저장소를 계속 두겠다고 아직 정하지 않았습니다. 홈 화면에 '
                          '추가하면 허락되는 일이 많습니다. 저장소가 비워져도 로그인해 있으면 '
                          '가계부를 다시 받습니다.',
                key: const ValueKey('onboarding-persist-result'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('onboarding-install-ok'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _installSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final forWeb = ref.watch(onboardingForWebProvider);
    final accounts = ref.watch(accountsProvider).value;
    final hasTransactions = ref.watch(hasTransactionsProvider).value;
    final hasModel = forWeb ? false : ref.watch(hasReadyModelProvider).value;
    // 다 읽기 전에는 그리지 않는다. 끝낸 단계가 잠깐 안 끝낸 것처럼 보이지 않게 한다.
    if (accounts == null || hasTransactions == null || hasModel == null) {
      return const SizedBox.shrink();
    }

    // 현금은 처음부터 있다. 카드나 계좌를 하나라도 넣었으면 끝낸 것이다.
    final accountDone = accounts.any((a) => a.kind != AccountKind.cash);
    final thirdDone = forWeb ? _installSeen : hasModel;
    if (accountDone && hasTransactions && thirdDone) {
      if (!_finishing) {
        _finishing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
      }
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('onboarding-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '이렇게 시작해 보십시오',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  key: const ValueKey('onboarding-close'),
                  onPressed: _close,
                  child: const Text('닫기'),
                ),
              ],
            ),
            _Step(
              id: 'account',
              done: accountDone,
              title: '자산 등록하기',
              body: '카드와 계좌를 넣어 두면 결제 문자를 알아서 그 자산에 잇습니다',
              onTap: () => context.go('/accounts'),
            ),
            _Step(
              id: 'paste',
              done: hasTransactions,
              title: '결제 문자 붙여넣어 보기',
              body: '결제 문자를 복사해 입력창에 붙여넣으면 거래로 읽습니다',
              onTap: _paste,
            ),
            if (forWeb)
              _Step(
                id: 'install',
                done: thirdDone,
                title: '홈 화면에 추가하기',
                body: '앱처럼 바로 열리고, 브라우저가 가계부의 저장소를 지우지 않게 청합니다',
                onTap: _install,
              )
            else
              _Step(
                id: 'model',
                done: thirdDone,
                title: 'AI 모델 내려받기',
                body: '처음 보는 형식의 문자도 기기 안에서 읽습니다. 글은 기기 밖으로 나가지 않습니다',
                onTap: () => context.go('/settings/models'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 안내의 한 단계. 끝냈으면 표시가 바뀐다.
class _Step extends StatelessWidget {
  const _Step({
    required this.id,
    required this.done,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String id;
  final bool done;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      key: ValueKey('onboarding-step-$id'),
      dense: true,
      contentPadding: const EdgeInsets.only(right: 8),
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        key: ValueKey('onboarding-${done ? 'done' : 'todo'}-$id'),
        color: done ? context.tokens.ok : scheme.outline,
        // 색만으로 가르지 않는다. 읽어 주는 말도 붙인다.
        semanticLabel: done ? '끝냄' : '아직',
      ),
      title: Text(
        title,
        style: done
            ? TextStyle(color: scheme.onSurfaceVariant)
            : const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(done ? '끝냈습니다' : body),
      trailing: done ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
