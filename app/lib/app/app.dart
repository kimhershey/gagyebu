import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/lock/app_lock_gate.dart';
import 'router.dart';
import 'theme/theme_setting.dart';

class GagyebuApp extends ConsumerStatefulWidget {
  const GagyebuApp({super.key, this.router});

  /// 시험에서 시작 주소를 바꿀 때 넘긴다.
  final GoRouter? router;

  @override
  ConsumerState<GagyebuApp> createState() => _GagyebuAppState();
}

class _GagyebuAppState extends ConsumerState<GagyebuApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeControllerProvider);
    // 설정에서 테마를 바꾸면 바로 다시 그린다.
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp.router(
        title: '가계부',
        debugShowCheckedModeBanner: false,
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: theme.mode,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
        // 앱 잠금이 켜져 있으면 화면 전체를 가린다.
        builder: (context, child) => AppLockGate(child: child!),
      ),
    );
  }
}
