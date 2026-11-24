import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../common/widgets.dart';

/// 설정의 '관리' 칸: 탭에 없는 화면으로 가는 목록.
class ManageLinksCard extends StatelessWidget {
  const ManageLinksCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(String key, IconData icon, String title, String path) =>
        ListTile(
          key: ValueKey('link-$key'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(path),
        );
    return SectionCard(
      title: '관리',
      child: Column(
        children: [
          link(
            'accounts',
            Icons.account_balance_wallet_outlined,
            '자산',
            '/accounts',
          ),
          link('categories', Icons.label_outline, '분류', '/categories'),
          link('budget', Icons.donut_large_outlined, '예산', '/budget'),
          link('recurring', Icons.event_repeat, '반복 거래', '/recurring'),
          link('history', Icons.history, '작업 기록', '/history'),
          link('data', Icons.import_export, '내보내기 · 가져오기', '/settings/data'),
          link('conflicts', Icons.call_split, '동기화 충돌', '/settings/conflicts'),
          link('lock', Icons.lock_outline, '앱 잠금', '/settings/lock'),
          // 웹 앱에는 기기 안의 모델이 없다.
          if (!kIsWeb)
            link('models', Icons.memory_outlined, 'AI 모델', '/settings/models'),
          link('account', Icons.person_outline, '계정', '/settings/account'),
        ],
      ),
    );
  }
}
