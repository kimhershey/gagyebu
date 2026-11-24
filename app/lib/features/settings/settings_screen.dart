import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../../platform/update_checker.dart';
import '../common/widgets.dart';
import 'manage_links_card.dart';
import 'sub_screen.dart';
import 'theme_card.dart';

/// 개인정보 처리방침(`docs/PRIVACY.md`)의 주소.
const privacyPolicyUrl =
    'https://github.com/kimhershey/gagyebu/blob/main/docs/PRIVACY.md';

/// 주소를 기기의 브라우저로 연다. 열었으면 true. 시험에서 바꿔 끼운다.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// 설정(`docs/SPEC.md` 7.20): 계정 → 화면 → 가계부 → 관리 → 정보.
///
/// 자산과 분류는 여기서 고치지 않는다. '관리'의 목록에서 그 화면으로 간다.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = WindowSize.of(context).isExpanded;
    const account = _AccountCard();
    const look = ThemeCard();
    const general = _GeneralCard();
    const manage = ManageLinksCard();
    const info = _InfoCard();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('설정', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const UpdateBanner(),
          if (wide)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      account,
                      SizedBox(height: 16),
                      look,
                      SizedBox(height: 16),
                      general,
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(children: [manage, SizedBox(height: 16), info]),
                ),
              ],
            )
          else ...const [
            account,
            SizedBox(height: 12),
            look,
            SizedBox(height: 12),
            general,
            SizedBox(height: 12),
            manage,
            SizedBox(height: 12),
            info,
          ],
        ],
      ),
    );
  }
}

/// 계정: 로그인 상태와 동기화 상태. 지금 동기화 · 로그아웃.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) =>
      const SectionCard(title: '계정', child: _AccountTile());
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final controller = ref.read(syncControllerProvider.notifier);
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, String subtitle, {Color? color}) =>
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(subtitle),
        );
    Widget actions(List<Widget> buttons) => Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: buttons),
    );

    switch (status.phase) {
      case SyncPhase.unavailable:
        return tile(
          Icons.cloud_off_outlined,
          '이 앱에는 로그인이 들어 있지 않습니다',
          pending == 0
              ? '가계부는 이 기기 안에만 저장됩니다'
              : '가계부는 이 기기 안에만 저장됩니다(올리지 않은 변경 $pending건)',
        );
      case SyncPhase.signedOut:
        // 로그아웃하면 곧 로그인 안내 화면으로 넘어간다.
        return tile(Icons.cloud_off_outlined, '로그인하지 않았습니다', '로그인 화면으로 이동합니다');
      case SyncPhase.differentAccount:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              Icons.warning_amber,
              '이 기기에는 다른 계정의 가계부가 있습니다',
              '${status.user?.email ?? '이 계정'}(으)로 계속하려면 이 기기의 가계부를 지우고 '
                  '계정의 가계부를 받아야 합니다.'
                  '${pending > 0 ? ' 아직 올리지 않은 변경 $pending건은 사라집니다.' : ''}',
              color: theme.colorScheme.error,
            ),
            actions([
              TextButton(
                onPressed: controller.signOut,
                child: const Text('로그아웃'),
              ),
              FilledButton.tonal(
                key: const ValueKey('replace-local'),
                onPressed: controller.replaceLocalLedger,
                child: const Text('지우고 받기'),
              ),
            ]),
          ],
        );
      case SyncPhase.syncing:
      case SyncPhase.idle:
      case SyncPhase.failed:
        final last = status.lastSyncedAt?.toLocal();
        final waiting = pending > 0 ? ' · 올릴 변경 $pending건' : '';
        final (icon, line) = switch (status.phase) {
          SyncPhase.syncing => (Icons.cloud_sync_outlined, '동기화하는 중입니다'),
          SyncPhase.failed => (
            Icons.cloud_off_outlined,
            // 예외 문구는 개발할 때만 보인다. 사용자에게는 무엇을 하면 되는지만 알린다.
            '동기화하지 못했습니다. 잠시 뒤 다시 시도합니다$waiting'
                '${kDebugMode && status.error != null ? '\n${status.error}' : ''}',
          ),
          _ => (
            Icons.cloud_done_outlined,
            last == null
                ? '동기화했습니다$waiting'
                : '${formatTimeOfDay(last)}에 동기화했습니다$waiting',
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile(
              icon,
              status.user?.email ?? '로그인했습니다',
              line,
              color: status.phase == SyncPhase.failed
                  ? theme.colorScheme.error
                  : null,
            ),
            actions([
              TextButton(
                key: const ValueKey('sync-now'),
                onPressed: status.phase == SyncPhase.syncing
                    ? null
                    : controller.syncNow,
                child: const Text('지금 동기화'),
              ),
              TextButton(
                key: const ValueKey('sign-out'),
                onPressed: controller.signOut,
                child: const Text('로그아웃'),
              ),
            ]),
          ],
        );
    }
  }
}

/// 가계부: 월 시작일.
class _GeneralCard extends ConsumerWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDay = ref.watch(monthStartDayProvider);
    return SectionCard(
      title: '가계부',
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('월 시작일'), HintText('급여일에 맞추면 그날부터 한 달로 집계합니다')],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            key: const ValueKey('month-start-day'),
            value: startDay,
            items: [
              for (var day = 1; day <= 28; day++)
                DropdownMenuItem(value: day, child: Text('$day일')),
            ],
            onChanged: (day) {
              if (day == null) return;
              ref
                  .read(repositoryProvider)
                  .setMonthStartDay(ref.read(ledgerIdProvider), day);
            },
          ),
        ],
      ),
    );
  }
}

/// 정보: 저장 위치, 오픈소스 라이선스, 개인정보 처리방침.
class _InfoCard extends ConsumerWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    final theme = Theme.of(context);
    final started = services.startedAt?.toLocal();
    return SectionCard(
      title: '정보',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HintText('저장 위치'),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              services.persistent ? Icons.save_outlined : Icons.warning_amber,
              color: services.persistent ? null : theme.colorScheme.error,
            ),
            title: Text(services.storage),
            subtitle: Text(
              [
                if (!services.persistent)
                  '이 브라우저는 저장소를 허용하지 않아 창을 닫으면 내용이 사라집니다'
                else if (services.server == null)
                  kIsWeb
                      ? '이 브라우저에만 저장됩니다. 다른 기기나 다른 브라우저에서는 보이지 않습니다'
                      : '이 기기에만 저장됩니다'
                else
                  // 로그인하는 빌드에서는 서버를 거쳐 다른 기기와 맞춘다.
                  kIsWeb
                      ? '이 브라우저에 저장하고, 로그인한 계정의 다른 기기와 동기화합니다'
                      : '이 기기에 저장하고, 로그인한 계정의 다른 기기와 동기화합니다',
                // 들어올 때마다 날짜가 오늘로 바뀌어 있으면 브라우저가 저장소를 비운 것이다.
                if (services.persistent && started != null)
                  '${started.year}년 ${started.month}월 ${started.day}일부터 '
                      '여기에 저장하고 있습니다',
              ].join('\n'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                key: const ValueKey('open-licenses'),
                onPressed: () =>
                    showLicensePage(context: context, applicationName: '가계부'),
                child: const Text('오픈소스 라이선스'),
              ),
              TextButton(
                key: const ValueKey('open-privacy'),
                onPressed: () => _openPrivacy(context, ref),
                child: const Text('개인정보 처리방침'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(linkOpenerProvider)(Uri.parse(privacyPolicyUrl));
    } on Object {
      opened = false;
    }
    if (!opened) {
      // 브라우저를 열지 못한 기기에서는 주소를 보여 준다.
      messenger.showSnackBar(
        const SnackBar(content: Text('브라우저를 열지 못했습니다. 주소: $privacyPolicyUrl')),
      );
    }
  }
}
