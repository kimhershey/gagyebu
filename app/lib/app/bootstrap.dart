import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/connection/connection.dart';
import '../data/db/database.dart';
import '../data/repositories/ledger_repository.dart';
import 'app.dart';
import 'providers.dart';

/// 로컬 DB를 열고 가계부를 준비한다.
Future<AppServices> openAppServices() async {
  final opened = await openAppDatabase();
  final db = AppDatabase(opened.executor);
  final repository = LedgerRepository(db);
  final ledgerId = await repository.ensureLocalLedger();
  return AppServices(
    db: db,
    repository: repository,
    ledgerId: ledgerId,
    storage: opened.storage,
    persistent: opened.persistent,
  );
}

/// 앱에 넣은 글꼴의 라이선스를 라이선스 화면에 올린다.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Pretendard-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Pretendard'], text);
  });
}

/// 준비가 끝날 때까지 기다렸다가 앱을 띄운다.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppServices> _services = openAppServices();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services != null) {
          return ProviderScope(
            overrides: [appServicesProvider.overrideWithValue(services)],
            child: const GagyebuApp(),
          );
        }
        // 준비하는 동안에는 Navigator가 없는 맨 화면을 쓴다. 여기서 MaterialApp을 쓰면
        // 웹에서 주소가 '/'로 바뀌어, 주소로 바로 들어온 화면(#/transactions 등)을 잃는다.
        return _Splash(
          error: snapshot.hasError ? snapshot.error : null,
          stackTrace: kDebugMode ? snapshot.stackTrace : null,
          onRetry: () => setState(() {
            _services = openAppServices();
          }),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error, this.stackTrace, required this.onRetry});

  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error;
    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: failure == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        const Text('데이터를 열지 못했다'),
                        const SizedBox(height: 8),
                        Text('$failure', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: onRetry,
                          child: const Text('다시 시도'),
                        ),
                        if (stackTrace != null) Text('$stackTrace'),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
