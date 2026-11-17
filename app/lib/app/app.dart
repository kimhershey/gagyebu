import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'router.dart';

const _seed = Color(0xFF2F6FED);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    // 한글 글꼴을 앱에 넣어, 웹에서도 외부 글꼴 서버 없이 같은 모양으로 보이게 한다.
    fontFamily: 'Pretendard',
    visualDensity: VisualDensity.standard,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}

class GagyebuApp extends StatefulWidget {
  const GagyebuApp({super.key, this.router});

  /// 시험에서 시작 주소를 바꿀 때 넘긴다.
  final GoRouter? router;

  @override
  State<GagyebuApp> createState() => _GagyebuAppState();
}

class _GagyebuAppState extends State<GagyebuApp> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '가계부',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    );
  }
}
