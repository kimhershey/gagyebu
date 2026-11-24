import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/llm_engine.dart';
import 'package:gagyebu/ai/llm/local_model_engine.dart';
import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_manager.dart';
import 'package:gagyebu/ai/llm/model_tier.dart';
import 'package:gagyebu/ai/llm/openai_compatible_engine.dart';
import 'package:gagyebu/ai/vision/vision_engine.dart';
import 'package:gagyebu/app/providers.dart';
import 'package:gagyebu/data/prefs/device_prefs.dart';
import 'package:gagyebu/features/models/model_providers.dart';

import '../ai/model_manager_catalog_test.dart' show catalogJson;
import '../ai/model_manager_fakes.dart';
import 'test_app.dart';

const text2b = 'qwen3.5-2b-q4_k_m';
const mmproj2b = 'qwen3.5-2b-mmproj';
const vision4b = 'qwen3.5-4b-q4_k_m';
const mmproj4b = 'qwen3.5-4b-mmproj';

class Setup {
  Setup(this.services, this.container, this.store, this.log);

  final AppServices services;
  final ProviderContainer container;
  final MemoryModelFileStore store;

  /// 가짜 런타임에 일어난 일.
  final List<String> log;

  /// [id]의 파일이 다 받아져 있는 것으로 만든다.
  Future<void> ready(String id, ModelKind kind) async {
    final path = '/models/$id.gguf';
    store.files[path] = [1, 2, 3];
    await container
        .read(modelFileRepositoryProvider)
        .put(
          ModelFileRecord(
            id: id,
            kind: kind,
            fileName: '$id.gguf',
            path: path,
            sizeBytes: 3,
            downloadedBytes: 3,
            sha256: 'a' * 64,
            status: ModelFileStatus.ready,
            updatedAt: testNow.toUtc(),
          ),
        );
    await pumpEventQueue();
  }

  LlmEngine? get llm => container.read(llmEngineProvider);
  VisionEngine? get vision => container.read(visionEngineProvider);
}

Future<Setup> setUpWith({
  DevicePlatform platform = DevicePlatform.android,
  Map<String, String> prefs = const {},
  bool runtime = true,
}) async {
  final services = await createTestServices();
  final store = MemoryModelFileStore();
  final log = <String>[];
  final container = ProviderContainer(
    overrides: [
      appServicesProvider.overrideWithValue(services),
      clockProvider.overrideWithValue(() => testNow),
      devicePrefsProvider.overrideWithValue(MemoryDevicePrefs(prefs)),
      devicePlatformProvider.overrideWithValue(platform),
      modelCatalogProvider.overrideWith(
        (ref) async => ModelCatalog.parse(catalogJson()),
      ),
      modelFileStoreProvider.overrideWithValue(
        platform.runsLocalModels ? store : null,
      ),
      localModelRuntimeFactoryProvider.overrideWithValue(
        runtime ? (spec) => FakeRuntime(spec, log) : null,
      ),
    ],
  );
  // 화면이 보고 있는 것처럼 붙들어 둔다. 그래야 파일이 바뀐 것을 따라간다.
  container
    ..listen(llmEngineProvider, (_, _) {})
    ..listen(visionEngineProvider, (_, _) {});
  addTearDown(() async {
    container.dispose();
    await services.db.close();
  });
  await pumpEventQueue();
  return Setup(services, container, store, log);
}

void main() {
  test('모델을 내려받기 전에는 엔진이 없다(규칙만으로 읽는다)', () async {
    for (final platform in DevicePlatform.values) {
      final s = await setUpWith(platform: platform);
      expect(s.llm, isNull, reason: platform.name);
      expect(s.vision, isNull, reason: platform.name);
    }
  });

  test('휴대폰: 글 모델이 준비되면 그 모델로 도는 엔진을 준다', () async {
    final s = await setUpWith();
    await s.ready(text2b, ModelKind.text);
    final engine = s.llm;
    expect(engine, isA<LocalModelEngine>());
    expect(engine!.modelName, text2b);
    final local = engine as LocalModelEngine;
    expect(local.spec.modelPath, '/models/$text2b.gguf');
    // 휴대폰에서는 이미지를 쓰지 않는다.
    expect(local.readsImages, isFalse);
    expect(s.vision, isNull);
    // 올리는 것은 처음 쓸 때다.
    expect(s.log, isEmpty);
    expect(
      await engine.generateJson(system: '규칙', user: '물음', schema: const {}),
      '물음',
    );
    expect(s.log, ['load', 'generate:물음']);
  });

  test('받다 만 파일로는 엔진을 만들지 않는다', () async {
    final s = await setUpWith();
    await s.container
        .read(modelFileRepositoryProvider)
        .put(
          ModelFileRecord(
            id: text2b,
            kind: ModelKind.text,
            fileName: '$text2b.gguf',
            path: '/models/$text2b.gguf',
            sizeBytes: 10,
            downloadedBytes: 4,
            sha256: 'a' * 64,
            status: ModelFileStatus.failed,
            updatedAt: testNow.toUtc(),
          ),
        );
    await pumpEventQueue();
    expect(s.llm, isNull);
  });

  test('PC: mmproj까지 준비되면 같은 엔진이 글과 이미지를 함께 읽는다', () async {
    final s = await setUpWith(platform: DevicePlatform.windows);
    await s.ready(text2b, ModelKind.text);
    expect(s.llm, isNotNull);
    expect(s.vision, isNull);

    await s.ready(mmproj2b, ModelKind.mmproj);
    final llm = s.llm! as LocalModelEngine;
    expect(llm.spec.projectorPath, '/models/$mmproj2b.gguf');
    // 같은 모델을 메모리에 두 번 올리지 않는다.
    expect(identical(s.vision, llm), isTrue);
  });

  test('PC 16GB: 이미지 전용 모델이 준비되면 이미지는 그 모델로 읽는다', () async {
    final s = await setUpWith(platform: DevicePlatform.windows);
    await s.ready(text2b, ModelKind.text);
    await s.ready(vision4b, ModelKind.vision);
    // mmproj가 없으면 아직 이미지를 읽지 못한다.
    expect(s.vision, isNull);

    await s.ready(mmproj4b, ModelKind.mmproj);
    expect(s.llm!.modelName, text2b);
    expect(s.vision!.modelName, vision4b);
    expect(
      (s.vision! as LocalModelEngine).spec.projectorPath,
      '/models/$mmproj4b.gguf',
    );
    expect(identical(s.vision, s.llm), isFalse);
  });

  test('휴대폰에서는 mmproj가 있어도 이미지 엔진을 주지 않는다', () async {
    final s = await setUpWith();
    await s.ready(text2b, ModelKind.text);
    await s.ready(mmproj2b, ModelKind.mmproj);
    expect(s.llm, isNotNull);
    expect(s.vision, isNull);
  });

  test('글 모델이 여럿이면 나중에 받은 것을 쓴다', () async {
    final s = await setUpWith();
    await s.ready(text2b, ModelKind.text);
    s.store.files['/models/newer.gguf'] = [1];
    await s.container
        .read(modelFileRepositoryProvider)
        .put(
          ModelFileRecord(
            id: 'newer',
            kind: ModelKind.text,
            fileName: 'newer.gguf',
            path: '/models/newer.gguf',
            sizeBytes: 1,
            downloadedBytes: 1,
            sha256: 'b' * 64,
            status: ModelFileStatus.ready,
            updatedAt: testNow.toUtc().add(const Duration(days: 1)),
          ),
        );
    await pumpEventQueue();
    expect(s.llm!.modelName, 'newer');
  });

  test('모델을 지우면 엔진도 없어지고 모델을 내린다', () async {
    final s = await setUpWith();
    await s.ready(text2b, ModelKind.text);
    final engine = s.llm!;
    await engine.generateJson(system: '', user: '물음', schema: const {});

    await s.container.read(modelDownloadsProvider.notifier).delete(text2b);
    await pumpEventQueue();
    expect(s.llm, isNull);
    expect(s.log, contains('unload'));
    expect(s.store.files, isEmpty);
  });

  test('파일이 사라진 모델은 처음 읽을 때 기록에서 지운다', () async {
    final services = await createTestServices();
    addTearDown(services.db.close);
    // 지난번에 준비됐다고 적어 두었지만 파일이 없다(사용자가 폴더를 비웠다).
    await services.db.customStatement(
      "INSERT INTO model_files (id, kind, file_name, path, size_bytes, "
      "downloaded_bytes, sha256, status, updated_at) VALUES "
      "('$text2b', 'text', '$text2b.gguf', '/models/$text2b.gguf', 3, 3, "
      "'${'a' * 64}', 'ready', '2026-11-17T03:00:00.000Z')",
    );
    final container = ProviderContainer(
      overrides: [
        appServicesProvider.overrideWithValue(services),
        devicePlatformProvider.overrideWithValue(DevicePlatform.android),
        modelFileStoreProvider.overrideWithValue(MemoryModelFileStore()),
        localModelRuntimeFactoryProvider.overrideWithValue(
          (spec) => FakeRuntime(spec, []),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(llmEngineProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(llmEngineProvider), isNull);
    expect(await container.read(modelFileRepositoryProvider).all(), isEmpty);
  });

  test('런타임이 없는 플랫폼에서는 파일이 있어도 엔진이 없다', () async {
    final s = await setUpWith(runtime: false);
    await s.ready(text2b, ModelKind.text);
    expect(s.llm, isNull);
    expect(s.vision, isNull);
  });

  group('로컬 엔진 주소', () {
    test('적어 둔 주소가 있으면 그 서버로 읽는다', () async {
      final s = await setUpWith(
        platform: DevicePlatform.windows,
        prefs: {
          modelEndpointKey: 'http://127.0.0.1:8088',
          modelEndpointModelKey: 'my-model',
        },
      );
      await s.ready(text2b, ModelKind.text);
      final engine = s.llm;
      expect(engine, isA<OpenAiCompatibleEngine>());
      expect(engine!.modelName, 'my-model');
    });

    test('모델 이름을 아직 모르면 기본 이름을 쓴다', () async {
      final s = await setUpWith(
        platform: DevicePlatform.windows,
        prefs: {modelEndpointKey: 'http://localhost:8088'},
      );
      expect(s.llm!.modelName, 'local-server');
    });

    test('이 컴퓨터의 주소가 아니면 쓰지 않는다', () async {
      // 누가 설정 파일을 고쳐 다른 기기의 주소를 넣어도 원문을 보내지 않는다.
      for (final address in [
        'http://192.168.0.10:8088',
        'https://llm.example.com',
        'ftp://127.0.0.1',
        '',
      ]) {
        final s = await setUpWith(
          platform: DevicePlatform.windows,
          prefs: {modelEndpointKey: address},
        );
        expect(s.llm, isNull, reason: address);
      }
    });

    test('웹에서는 주소가 있어도 쓰지 않는다', () async {
      final s = await setUpWith(
        platform: DevicePlatform.web,
        prefs: {modelEndpointKey: 'http://127.0.0.1:8088'},
      );
      expect(s.llm, isNull);
    });

    test('주소를 읽는다', () {
      Uri? ok(String text) => parseModelEndpoint(text).uri;
      expect(ok('http://127.0.0.1:8088'), Uri.parse('http://127.0.0.1:8088'));
      expect(ok('127.0.0.1:8088'), Uri.parse('http://127.0.0.1:8088'));
      expect(ok(' localhost:1234/ '), Uri.parse('http://localhost:1234'));
      expect(ok('http://[::1]:8088'), Uri.parse('http://[::1]:8088'));
      // 경로는 엔진이 붙인다.
      expect(
        ok('http://127.0.0.1:8088/v1/chat/completions'),
        Uri.parse('http://127.0.0.1:8088'),
      );
      expect(
        parseModelEndpoint('http://10.0.0.5:8088').problem,
        EndpointProblem.notLocal,
      );
      expect(
        parseModelEndpoint('http://127.0.0.1.evil.example').problem,
        EndpointProblem.notLocal,
      );
      expect(parseModelEndpoint('').problem, EndpointProblem.malformed);
      expect(
        parseModelEndpoint('file:///etc').problem,
        EndpointProblem.malformed,
      );
    });
  });
}
