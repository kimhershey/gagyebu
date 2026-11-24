import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';

/// 로그인 안내 화면들이 함께 쓰는 틀: 가운데에 놓인 좁은 한 칸.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그인이 끝나면 안내 화면에서 나가게 하는 상태.
///
/// 로그인은 화면 밖에서 끝난다: Google 로그인은 다른 페이지에 다녀오고, 첫 로그인이면 앱이
/// 새 가계부로 다시 열린다. 그래서 단추를 누른 자리에서가 아니라 로그인 상태를 보고 나간다.
mixin LeaveWhenSignedIn<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _leaving = false;

  /// 로그인했으면 다음 프레임에 나가고 true를 돌려준다. 그동안은 진행 표시를 그리면 된다.
  bool leaveIfSignedIn(SyncStatus status) {
    if (!status.signedIn) return false;
    if (!_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(welcomeGateProvider).value = false;
        // 설정에서 들어왔으면 설정으로, 시작 화면이었으면 가계부로 간다.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(
            status.phase == SyncPhase.differentAccount ? '/settings' : '/',
          );
        }
      });
    }
    return true;
  }
}
