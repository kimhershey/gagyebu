import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_manager.dart';
import 'package:gagyebu/ai/llm/model_tier.dart';
import 'package:gagyebu/app/app.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/app/router.dart';
import 'package:gagyebu/data/db/database.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/features/models/model_providers.dart';
import 'package:gagyebu/features/models/models_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/model_manager_fakes.dart';
import 'home_stats_seed.dart';
import 'test_app.dart';

const textId = 'qwen3.5-2b-q4_k_m';

/// 설계서의 등급 표와 같은 카탈로그. 글 모델은 [server]의 파일을 가리킨다.
ModelCatalog catalogFor(FakeModelServer server, {String? textHash}) {
  ModelCatalogEntry entry(
    String id,
    ModelKind kind,
    String name, {
    required int memory,
    required Set<String> platforms,
    String? mmproj,
    bool downloadable = false,
  }) => ModelCatalogEntry(
    id: id,
    kind: kind,
    name: name,
    license: 'Apache-2.0',
    url: downloadable ? Uri.parse('https://models.example/$id.gguf') : null,
    sizeBytes: downloadable ? server.bytes.length : null,
    sha256: downloadable ? (textHash ?? server.sha256Hex) : null,
    minMemoryGb: memory,
    platforms: platforms,
    mmproj: mmproj,
  );

  return ModelCatalog(
    version: 1,
    models: [
      entry(
        textId,
        ModelKind.text,
        'Qwen3.5-2B',
        memory: 6,
        platforms: {'android', 'windows'},
        mmproj: 'qwen3.5-2b-mmproj',
        downloadable: true,
      ),
      entry(
        'qwen3.5-2b-mmproj',
        ModelKind.mmproj,
        'Qwen3.5-2B 이미지 입력(mmproj)',
        memory: 8,
        platforms: {'windows'},
      ),
      entry(
        'qwen3.5-4b-q4_k_m',
        ModelKind.vision,
        'Qwen3.5-4B',
        memory: 16,
        platforms: {'windows'},
        mmproj: 'qwen3.5-4b-mmproj',
      ),
      entry(
        'qwen3.5-4b-mmproj',
        ModelKind.mmproj,
        'Qwen3.5-4B 이미지 입력(mmproj)',
        memory: 16,
        platforms: {'windows'},
      ),
    ],
  );
}

class Harness {
  Harness(this.services, this.server, this.store, this.prefs);

  final AppServices services;
  final FakeModelServer server;
  final MemoryModelFileStore store;
  final MemoryDevicePrefs prefs;

  static Future<Harness> create() async => Harness(
    await createTestServices(),
    // 진행 표시가 한 번은 보이도록 1MB를 넘긴다.
    FakeModelServer(sampleBytes(3 * 1024 * 1024), chunkSize: 512 * 1024),
    MemoryModelFileStore(),
    MemoryDevicePrefs(),
  );

  Future<void> pump(
    WidgetTester tester, {
    DevicePlatform platform = DevicePlatform.android,
    int? memoryMb = 8 * 1024,
    ModelCatalog? catalog,
    http.Client? client,
    Size size = phone,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          clockProvider.overrideWithValue(() => testNow),
          devicePrefsProvider.overrideWithValue(prefs),
          devicePlatformProvider.overrideWithValue(platform),
          deviceMemoryReaderProvider.overrideWithValue(() async => memoryMb),
          modelCatalogProvider.overrideWith(
            (ref) async => catalog ?? catalogFor(server),
          ),
          modelFileStoreProvider.overrideWithValue(
            platform.runsLocalModels ? store : null,
          ),
          modelHttpClientProvider.overrideWithValue(client ?? server.client),
        ],
        child: GagyebuApp(
          router: createRouter(initialLocation: '/settings/models'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<ModelFileRecord>> records(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ModelsScreen)),
    );
    return container.read(modelFileRepositoryProvider).all();
  }
}

/// 내려받기처럼 화면 밖에서 도는 일이 끝나도록 시간을 조금씩 보낸다.
Future<void> letRun(WidgetTester tester, {int steps = 40}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// [key]의 위젯이 화면에 들어오게 한다. 목록은 화면 근처의 것만 그리므로, 아래쪽
/// 카드는 내려 보아야 찾을 수 있다.
Future<Finder> reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ModelsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(await reveal(tester, key));
  await tester.pump();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

void main() {
  testWidgets('웹에서는 기기 안의 모델이 없다고 알린다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester, platform: DevicePlatform.web);
    expect(find.text('웹 앱에는 기기 안의 모델이 없습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('models-device')), findsNothing);
    expect(find.byKey(const ValueKey('model-tile-$textId')), findsNothing);
    expect(find.byKey(const ValueKey('models-endpoint')), findsNothing);
    await disposeApp(tester, h.services);
  });

  testWidgets('기기 사양과 권하는 모델을 보여 준다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester);
    expect(textOf(tester, 'models-device-spec'), 'Android · 메모리 8GB');
    expect(textOf(tester, 'models-recommendation'), '권하는 모델은 Qwen3.5-2B입니다.');
    // 휴대폰에서는 휴대폰용 모델만 보인다.
    expect(find.byKey(const ValueKey('model-tile-$textId')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model-tile-qwen3.5-4b-q4_k_m')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('model-recommended-$textId')),
      findsOneWidget,
    );
    expect(find.textContaining('글 읽기 · 3MB · 메모리 6GB 이상'), findsOneWidget);
    // 휴대폰에는 로컬 엔진 주소가 없다.
    expect(find.byKey(const ValueKey('models-endpoint')), findsNothing);
    // 누르기 전에는 아무것도 받지 않는다.
    expect(h.server.requests, isEmpty);
    await disposeApp(tester, h.services);
  });

  testWidgets('메모리를 읽지 못하면 "알 수 없음"으로 두고 가장 작은 모델을 권한다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester, memoryMb: null);
    expect(textOf(tester, 'models-device-spec'), 'Android · 메모리 알 수 없음');
    expect(
      textOf(tester, 'models-recommendation'),
      '메모리를 읽지 못해 가장 작은 모델(Qwen3.5-2B)을 권합니다.',
    );
    await disposeApp(tester, h.services);
  });

  testWidgets('메모리가 모자라면 권하지 않는다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester, memoryMb: 3700);
    expect(textOf(tester, 'models-device-spec'), 'Android · 메모리 4GB');
    expect(textOf(tester, 'models-recommendation'), contains('규칙으로 읽습니다'));
    expect(
      find.byKey(const ValueKey('model-recommended-$textId')),
      findsNothing,
    );
    await disposeApp(tester, h.services);
  });

  testWidgets('PC 16GB에는 이미지 모델까지 권한다', (tester) async {
    final h = await Harness.create();
    await h.pump(
      tester,
      platform: DevicePlatform.windows,
      memoryMb: 16 * 1024,
      size: desktop,
    );
    expect(textOf(tester, 'models-device-spec'), 'Windows PC · 메모리 16GB');
    expect(
      textOf(tester, 'models-recommendation'),
      '권하는 모델은 Qwen3.5-2B입니다. 이미지 입력에는 Qwen3.5-4B 모델을 권합니다.',
    );
    for (final id in [textId, 'qwen3.5-4b-q4_k_m', 'qwen3.5-4b-mmproj']) {
      expect(find.byKey(ValueKey('model-recommended-$id')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('model-recommended-qwen3.5-2b-mmproj')),
      findsNothing,
    );
    expect(await reveal(tester, 'models-endpoint'), findsOneWidget);
    await disposeApp(tester, h.services);
  });

  testWidgets('주소와 해시가 없는 항목은 내려받기가 꺼져 있다(저장소의 카탈로그)', (tester) async {
    final h = await Harness.create();
    final shipped = ModelCatalog.parse(
      File('assets/catalog/models.json').readAsStringSync(),
    );
    await h.pump(
      tester,
      platform: DevicePlatform.windows,
      memoryMb: 16 * 1024,
      catalog: shipped,
      size: desktop,
    );
    for (final entry in shipped.models) {
      if (entry.isDownloadable) continue;
      expect(
        find.byKey(ValueKey('model-unavailable-${entry.id}')),
        findsOneWidget,
      );
      expect(enabled(tester, 'model-download-${entry.id}'), isFalse);
      expect(find.textContaining('크기 확인 전'), findsWidgets);
    }
    await disposeApp(tester, h.services);
  });

  testWidgets('크기를 알리고 물은 뒤에 내려받고, 진행을 보여 주고, 지울 수 있다', (tester) async {
    final h = await Harness.create();
    // 중간에 멈춰 세워 진행 표시를 본다.
    h.server.stallAfter = 2 * 1024 * 1024;
    await h.pump(tester);
    expect(enabled(tester, 'model-download-$textId'), isTrue);

    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    // 어떤 연결인지 알 수 없으므로 크기를 알리고 한 번 묻는다.
    expect(find.text('내려받을까요?'), findsOneWidget);
    expect(find.textContaining('Qwen3.5-2B 모델(3MB)을 내려받습니다.'), findsOneWidget);
    expect(find.textContaining('모바일 데이터'), findsOneWidget);
    expect(h.server.requests, isEmpty);

    await tapKey(tester, 'model-download-confirm');
    await letRun(tester);
    expect(
      find.byKey(const ValueKey('model-progress-$textId')),
      findsOneWidget,
    );
    expect(find.textContaining('받는 중 · 2MB / 3MB (67%)'), findsOneWidget);
    expect(find.byKey(const ValueKey('model-cancel-$textId')), findsOneWidget);
    expect(
      (await h.records(tester)).single.status,
      ModelFileStatus.downloading,
    );

    // 멈춘 뒤 이어받아 끝낸다.
    await tapKey(tester, 'model-cancel-$textId');
    await letRun(tester);
    expect(
      textOf(tester, 'model-failure-$textId'),
      '내려받기를 멈췄습니다. 받은 데까지는 남아 있습니다.',
    );
    expect(find.text('이어받기'), findsOneWidget);
    h.server.stallAfter = null;
    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    expect(find.text('이어서 받을까요?'), findsOneWidget);
    await tapKey(tester, 'model-download-confirm');
    await letRun(tester);

    expect(textOf(tester, 'model-ready-$textId'), '준비됨 · 3MB');
    expect(h.server.ranges, [null, 'bytes=2097152-']);
    expect(h.store.files['/models/$textId.gguf'], h.server.bytes);
    final ready = (await h.records(tester)).single;
    expect(ready.isReady, isTrue);
    expect(ready.sha256, h.server.sha256Hex);

    // 지우기는 한 번 묻는다.
    await tapKey(tester, 'model-delete-$textId');
    await tester.pumpAndSettle();
    expect(find.text('모델을 지울까요?'), findsOneWidget);
    await tapKey(tester, 'model-delete-confirm');
    await letRun(tester);
    expect(await h.records(tester), isEmpty);
    expect(h.store.files, isEmpty);
    expect(find.text('내려받기'), findsOneWidget);
    await disposeApp(tester, h.services);
  });

  testWidgets('새 모델을 받으면 같은 일을 하던 옛 모델을 지울지 묻는다', (tester) async {
    final h = await Harness.create();
    // 카탈로그에서 빠진 옛 글 모델이 기기에 남아 있다.
    h.store.files['/models/old-text.gguf'] = [1, 2, 3];
    await h.services.db
        .into(h.services.db.modelFiles)
        .insert(
          ModelFilesCompanion.insert(
            id: 'old-text',
            kind: 'text',
            fileName: 'old-text.gguf',
            path: '/models/old-text.gguf',
            sizeBytes: 3,
            sha256: 'a' * 64,
            status: 'ready',
            updatedAt: testNow.toUtc(),
          ),
        );
    await h.pump(tester);
    // 목록에 없는 모델도 기기에 있으면 보여 준다(지울 수 있게).
    expect(find.byKey(const ValueKey('model-orphan-old-text')), findsOneWidget);
    expect(find.textContaining('지금 목록에 없는 모델'), findsOneWidget);
    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    await tapKey(tester, 'model-download-confirm');
    await letRun(tester);
    await tester.pumpAndSettle();

    // 저절로 지우지 않고 묻는다.
    expect(find.text('전에 받은 모델을 지울까요?'), findsOneWidget);
    expect(h.store.files.containsKey('/models/old-text.gguf'), isTrue);
    await tapKey(tester, 'model-remove-old-confirm');
    await letRun(tester, steps: 10);
    expect((await h.records(tester)).map((r) => r.id), [textId]);
    expect(h.store.files.keys, ['/models/$textId.gguf']);
    expect(find.byKey(const ValueKey('model-orphan-old-text')), findsNothing);
    await disposeApp(tester, h.services);
  });

  testWidgets('묻는 창에서 취소하면 받지 않는다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester);
    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    await letRun(tester, steps: 5);
    expect(h.server.requests, isEmpty);
    expect(await h.records(tester), isEmpty);
    await disposeApp(tester, h.services);
  });

  testWidgets('해시가 다르면 지우고 그렇게 알린다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester, catalog: catalogFor(h.server, textHash: 'f' * 64));
    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    await tapKey(tester, 'model-download-confirm');
    await letRun(tester);
    expect(
      textOf(tester, 'model-failure-$textId'),
      '받은 파일이 등록된 것과 달라 지웠습니다. 다시 받아 주세요.',
    );
    // 예외 문구를 그대로 보이지 않는다.
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('hashMismatch'), findsNothing);
    expect(h.store.files, isEmpty);
    expect((await h.records(tester)).single.status, ModelFileStatus.failed);
    await disposeApp(tester, h.services);
  });

  testWidgets('저장 공간이 모자라면 받기 전에 알린다', (tester) async {
    final h = await Harness.create();
    h.store.free = 1024;
    await h.pump(tester);
    await tapKey(tester, 'model-download-$textId');
    await tester.pumpAndSettle();
    await tapKey(tester, 'model-download-confirm');
    await letRun(tester);
    expect(
      textOf(tester, 'model-failure-$textId'),
      '저장 공간이 모자랍니다. 공간을 비운 뒤에 다시 받아 주세요.',
    );
    expect(h.server.requests, isEmpty);
    await disposeApp(tester, h.services);
  });

  testWidgets('앱이 받다가 꺼졌던 파일은 이어받을 수 있게 보인다', (tester) async {
    final h = await Harness.create();
    h.store.files['/models/$textId.gguf.part'] = h.server.bytes.sublist(
      0,
      1024 * 1024,
    );
    await h.services.db
        .into(h.services.db.modelFiles)
        .insert(
          ModelFilesCompanion.insert(
            id: textId,
            kind: 'text',
            fileName: '$textId.gguf',
            path: '/models/$textId.gguf',
            sizeBytes: h.server.bytes.length,
            sha256: h.server.sha256Hex,
            status: 'downloading',
            updatedAt: testNow.toUtc(),
          ),
        );
    await h.pump(tester);
    await letRun(tester, steps: 5);
    expect(textOf(tester, 'model-partial-$textId'), '받다가 멈췄습니다 · 1MB 받음');
    expect(find.text('이어받기'), findsOneWidget);
    expect(find.byKey(const ValueKey('model-delete-$textId')), findsOneWidget);
    await disposeApp(tester, h.services);
  });

  testWidgets('모델 목록을 읽지 못했으면 그렇게 말하고 다시 읽게 한다', (tester) async {
    final h = await Harness.create();
    await h.pump(tester, catalog: ModelCatalog.empty);
    expect(find.byKey(const ValueKey('models-empty')), findsOneWidget);
    expect(find.textContaining('모델 목록을 읽지 못했습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('models-reload')), findsOneWidget);
    await disposeApp(tester, h.services);
  });

  group('로컬 엔진 주소(Windows)', () {
    Future<Harness> open(WidgetTester tester, {http.Client? client}) async {
      final h = await Harness.create();
      await h.pump(
        tester,
        platform: DevicePlatform.windows,
        memoryMb: 16 * 1024,
        client: client,
        size: desktop,
      );
      return h;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(
        await reveal(tester, 'model-endpoint-field'),
        text,
      );
    }

    testWidgets('이 컴퓨터의 주소만 받는다', (tester) async {
      final h = await open(tester);
      await type(tester, 'http://192.168.0.10:8088');
      await tapKey(tester, 'model-endpoint-save');
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'model-endpoint-message'),
        contains('이 컴퓨터의 주소(127.0.0.1)만 쓸 수 있습니다'),
      );
      expect(h.prefs.getString(modelEndpointKey), isNull);

      await type(tester, 'https://llm.example.com');
      await tapKey(tester, 'model-endpoint-save');
      await tester.pumpAndSettle();
      expect(h.prefs.getString(modelEndpointKey), isNull);

      await type(tester, '주소가 아닌 글');
      await tapKey(tester, 'model-endpoint-save');
      await tester.pumpAndSettle();
      expect(textOf(tester, 'model-endpoint-message'), contains('꼴로 적어 주세요'));
      expect(h.prefs.getString(modelEndpointKey), isNull);
      await disposeApp(tester, h.services);
    });

    testWidgets('주소를 저장하고, 연결을 확인하고, 지운다', (tester) async {
      final asked = <Uri>[];
      final client = MockClient((request) async {
        asked.add(request.url);
        return http.Response('{"data":[{"id":"qwen3.5-2b-q4_k_m"}]}', 200);
      });
      final h = await open(tester, client: client);
      await reveal(tester, 'model-endpoint-field');
      expect(find.byKey(const ValueKey('model-endpoint-clear')), findsNothing);

      // 머리말을 빼고 적어도 받는다.
      await type(tester, '127.0.0.1:8088');
      await tapKey(tester, 'model-endpoint-save');
      await tester.pumpAndSettle();
      expect(h.prefs.getString(modelEndpointKey), 'http://127.0.0.1:8088');
      expect(textOf(tester, 'model-endpoint-message'), contains('저장했습니다'));
      // 저장만으로는 서버에 아무것도 보내지 않는다.
      expect(asked, isEmpty);

      await tapKey(tester, 'model-endpoint-check');
      await tester.pumpAndSettle();
      expect(asked, [Uri.parse('http://127.0.0.1:8088/v1/models')]);
      expect(
        textOf(tester, 'model-endpoint-message'),
        '연결됐습니다 · 모델: qwen3.5-2b-q4_k_m',
      );
      expect(h.prefs.getString(modelEndpointModelKey), 'qwen3.5-2b-q4_k_m');

      await tapKey(tester, 'model-endpoint-clear');
      await tester.pumpAndSettle();
      expect(h.prefs.getString(modelEndpointKey), isNull);
      expect(h.prefs.getString(modelEndpointModelKey), isNull);
      expect(find.byKey(const ValueKey('model-endpoint-clear')), findsNothing);
      await disposeApp(tester, h.services);
    });

    testWidgets('서버에 닿지 않으면 그렇게 알린다', (tester) async {
      final client = MockClient(
        (request) async => throw http.ClientException('connection refused'),
      );
      final h = await open(tester, client: client);
      await type(tester, 'http://localhost:9999');
      await tapKey(tester, 'model-endpoint-check');
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'model-endpoint-message'),
        '연결하지 못했습니다. 서버가 켜져 있는지 확인해 주세요.',
      );
      expect(find.textContaining('connection refused'), findsNothing);
      await disposeApp(tester, h.services);
    });
  });

  group('네 화면 크기와 큰 글자에서 넘치지 않는다', () {
    for (final (name, size) in [
      ('휴대폰', phone),
      ('큰 휴대폰', largePhone),
      ('폴더블', foldable),
      ('PC', desktop),
    ]) {
      testWidgets(name, (tester) async {
        for (final platform in [DevicePlatform.windows, DevicePlatform.web]) {
          final h = await Harness.create();
          h.prefs.setString(modelEndpointKey, 'http://127.0.0.1:8088');
          await h.pump(
            tester,
            platform: platform,
            memoryMb: 16 * 1024,
            size: size,
            textScale: 2,
          );
          await expectNoOverflowWhileScrolling(tester, ModelsScreen);
          await disposeApp(tester, h.services);
        }
      });
    }
  });
}
