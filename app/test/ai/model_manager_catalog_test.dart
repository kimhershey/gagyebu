import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_file_store_io.dart';
import 'package:gagyebu/ai/llm/model_tier.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 설계서 5.4의 등급 표를 그대로 옮긴 카탈로그. 주소와 해시를 채운 것이다.
String catalogJson({bool filled = true}) => jsonEncode({
  'version': 1,
  'models': [
    {
      'id': 'qwen3.5-2b-q4_k_m',
      'kind': 'text',
      'name': 'Qwen3.5-2B',
      'license': 'Apache-2.0',
      'url': filled ? 'https://models.example/2b.gguf' : null,
      'size_bytes': filled ? 1374389534 : null,
      'sha256': filled ? 'a' * 64 : null,
      'min_memory_gb': 6,
      'platforms': ['android', 'windows'],
      'mmproj': 'qwen3.5-2b-mmproj',
    },
    {
      'id': 'qwen3.5-2b-mmproj',
      'kind': 'mmproj',
      'name': 'Qwen3.5-2B mmproj',
      'license': 'Apache-2.0',
      'url': filled ? 'https://models.example/2b-mmproj.gguf' : null,
      'size_bytes': null,
      'sha256': filled ? 'b' * 64 : null,
      'min_memory_gb': 8,
      'platforms': ['windows'],
      'mmproj': null,
    },
    {
      'id': 'qwen3.5-4b-q4_k_m',
      'kind': 'vision',
      'name': 'Qwen3.5-4B',
      'license': 'Apache-2.0',
      'url': filled ? 'https://models.example/4b.gguf' : null,
      'size_bytes': null,
      'sha256': filled ? 'c' * 64 : null,
      'min_memory_gb': 16,
      'platforms': ['windows'],
      'mmproj': 'qwen3.5-4b-mmproj',
    },
    {
      'id': 'qwen3.5-4b-mmproj',
      'kind': 'mmproj',
      'name': 'Qwen3.5-4B mmproj',
      'license': 'Apache-2.0',
      'url': filled ? 'https://models.example/4b-mmproj.gguf' : null,
      'size_bytes': null,
      'sha256': filled ? 'd' * 64 : null,
      'min_memory_gb': 16,
      'platforms': ['windows'],
      'mmproj': null,
    },
  ],
});

DeviceSpec phone(int? gb) => DeviceSpec(
  platform: DevicePlatform.android,
  memoryMb: gb == null ? null : gb * 1024,
);

DeviceSpec pc(int? gb) => DeviceSpec(
  platform: DevicePlatform.windows,
  memoryMb: gb == null ? null : gb * 1024,
);

void main() {
  final catalog = ModelCatalog.parse(catalogJson());

  group('카탈로그 읽기', () {
    test('설계서의 꼴을 읽는다', () {
      expect(catalog.version, 1);
      expect(catalog.models.map((m) => m.id), [
        'qwen3.5-2b-q4_k_m',
        'qwen3.5-2b-mmproj',
        'qwen3.5-4b-q4_k_m',
        'qwen3.5-4b-mmproj',
      ]);
      final text = catalog.byId('qwen3.5-2b-q4_k_m')!;
      expect(text.kind, ModelKind.text);
      expect(text.name, 'Qwen3.5-2B');
      expect(text.license, 'Apache-2.0');
      expect(text.url, Uri.parse('https://models.example/2b.gguf'));
      expect(text.sizeBytes, 1374389534);
      expect(text.sha256, 'a' * 64);
      expect(text.minMemoryGb, 6);
      expect(text.platforms, {'android', 'windows'});
      expect(text.mmproj, 'qwen3.5-2b-mmproj');
      expect(text.fileName, 'qwen3.5-2b-q4_k_m.gguf');
      expect(text.isDownloadable, isTrue);
      expect(catalog.byId('없는-모델'), isNull);
      expect(catalog.byId(null), isNull);
    });

    test('주소와 해시가 둘 다 있어야 받을 수 있다', () {
      ModelCatalogEntry parse(Map<String, Object?> extra) =>
          ModelCatalogEntry.tryParse({
            'id': 'm',
            'kind': 'text',
            'name': '모델',
            'min_memory_gb': 6,
            'platforms': ['android'],
            ...extra,
          })!;
      const url = 'https://models.example/m.gguf';
      final hash = 'e' * 64;
      expect(parse({'url': url, 'sha256': hash}).isDownloadable, isTrue);
      expect(parse({'url': url, 'sha256': null}).isDownloadable, isFalse);
      expect(parse({'url': null, 'sha256': hash}).isDownloadable, isFalse);
      expect(parse({}).isDownloadable, isFalse);
      // 평문 주소, 꼴이 틀린 해시는 없는 것으로 본다.
      expect(
        parse({'url': 'http://models.example/m.gguf', 'sha256': hash})
            .isDownloadable,
        isFalse,
      );
      expect(parse({'url': url, 'sha256': 'abc'}).isDownloadable, isFalse);
      expect(parse({'url': url, 'sha256': '…'}).isDownloadable, isFalse);
      // 대문자 해시는 소문자로 맞춘다.
      expect(parse({'url': url, 'sha256': 'E' * 64}).sha256, hash);
    });

    test('꼴이 틀린 항목은 그 항목만 버린다', () {
      final parsed = ModelCatalog.parse(
        jsonEncode({
          'version': 1,
          'models': [
            {'id': 'ok', 'kind': 'text', 'name': '좋은 항목'},
            {'id': '../밖으로', 'kind': 'text', 'name': '경로를 벗어나는 ID'},
            {'id': 'no-kind', 'name': '종류 없음'},
            {'id': 'bad-kind', 'kind': 'audio', 'name': '모르는 종류'},
            {'id': 'ok', 'kind': 'text', 'name': '겹친 ID'},
            '글자',
            null,
          ],
        }),
      );
      expect(parsed.models.map((m) => m.name), ['좋은 항목']);
      expect(parsed.models.single.platforms, isEmpty);
      expect(parsed.models.single.minMemoryGb, 0);
    });

    test('카탈로그가 아니거나 모르는 판이면 받지 않는다', () {
      expect(() => ModelCatalog.parse('[]'), throwsFormatException);
      expect(() => ModelCatalog.parse('{'), throwsFormatException);
      expect(
        () => ModelCatalog.parse('{"version":2,"models":[]}'),
        throwsFormatException,
      );
      expect(() => ModelCatalog.parse('{"version":1}'), throwsFormatException);
    });
  });

  group('카탈로그를 어디서 읽나', () {
    test('공개 저장소의 원본을 먼저 읽는다', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(catalogJson()), 200);
      });
      final loaded = await loadModelCatalog(
        client: client,
        readBundled: () async => fail('사본을 읽으면 안 된다'),
      );
      expect(loaded.models, hasLength(4));
      expect(requests.single.url, defaultCatalogUri);
      // 읽기만 한다. 보내는 내용이 없다.
      expect(requests.single.method, 'GET');
      expect(requests.single.body, isEmpty);
    });

    test('원본을 못 읽으면 앱에 든 사본을 쓴다', () async {
      for (final client in [
        MockClient((request) async => http.Response('없다', 404)),
        MockClient((request) async => throw http.ClientException('오프라인')),
        MockClient((request) async => http.Response('<html>', 200)),
        MockClient((request) async => http.Response('{"version":9}', 200)),
      ]) {
        final loaded = await loadModelCatalog(
          client: client,
          readBundled: () async => catalogJson(filled: false),
        );
        expect(loaded.models, hasLength(4));
        expect(loaded.models.every((m) => !m.isDownloadable), isTrue);
      }
    });

    test('둘 다 못 읽으면 빈 카탈로그다', () async {
      final loaded = await loadModelCatalog(
        client: MockClient((request) async => http.Response('', 500)),
        readBundled: () async => throw StateError('자산이 없다'),
      );
      expect(loaded.models, isEmpty);
    });

    test('앱에 든 사본은 저장소의 원본과 같고, 읽을 수 있다', () {
      final original = File('../catalog/models.json').readAsStringSync();
      final bundled = File('assets/catalog/models.json').readAsStringSync();
      expect(bundled, original);
      final parsed = ModelCatalog.parse(bundled);
      expect(parsed.models, isNotEmpty);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/catalog/models.json'),
      );
      // mmproj가 가리키는 항목은 카탈로그에 있어야 한다.
      for (final model in parsed.models) {
        if (model.mmproj != null) {
          expect(parsed.byId(model.mmproj)?.kind, ModelKind.mmproj);
        }
      }
    });
  });

  group('등급 고르기', () {
    ModelRecommendation pick(DeviceSpec spec) => recommendModels(catalog, spec);

    test('휴대폰: 6GB 이상이면 글 모델, 그보다 작으면 규칙만', () {
      for (final gb in [6, 8, 12]) {
        final r = pick(phone(gb));
        expect(r.reason, RecommendationReason.matched, reason: '$gb GB');
        expect(r.text?.id, 'qwen3.5-2b-q4_k_m');
        // 휴대폰에서는 이미지 입력을 쓰지 않는다.
        expect(r.vision, isNull);
        expect(r.projector, isNull);
        expect(r.files.map((f) => f.id), ['qwen3.5-2b-q4_k_m']);
      }
      for (final gb in [3, 4]) {
        final r = pick(phone(gb));
        expect(r.reason, RecommendationReason.lowMemory);
        expect(r.text, isNull);
        expect(r.files, isEmpty);
      }
    });

    test('PC 8–15GB: 글도 이미지도 2B(mmproj와 함께)', () {
      for (final gb in [8, 12, 15]) {
        final r = pick(pc(gb));
        expect(r.text?.id, 'qwen3.5-2b-q4_k_m', reason: '$gb GB');
        expect(r.vision?.id, 'qwen3.5-2b-q4_k_m');
        expect(r.projector?.id, 'qwen3.5-2b-mmproj');
        expect(r.files.map((f) => f.id), [
          'qwen3.5-2b-q4_k_m',
          'qwen3.5-2b-mmproj',
        ]);
      }
    });

    test('PC 16GB 이상: 글은 2B, 이미지는 4B(mmproj와 함께)', () {
      for (final gb in [16, 32, 64]) {
        final r = pick(pc(gb));
        expect(r.text?.id, 'qwen3.5-2b-q4_k_m', reason: '$gb GB');
        expect(r.vision?.id, 'qwen3.5-4b-q4_k_m');
        expect(r.projector?.id, 'qwen3.5-4b-mmproj');
        expect(r.files, hasLength(3));
      }
    });

    test('PC 8GB 미만: 글 모델까지만, 이미지는 없다', () {
      final r = pick(pc(6));
      expect(r.text?.id, 'qwen3.5-2b-q4_k_m');
      expect(r.vision, isNull);
      expect(pick(pc(4)).reason, RecommendationReason.lowMemory);
    });

    test('OS가 알려 주는 메모리는 조금 모자라게 나온다. 올림해서 본다', () {
      // '6GB' 휴대폰이 5,600MB쯤, '8GB' PC가 7,900MB쯤으로 나온다.
      expect(
        const DeviceSpec(
          platform: DevicePlatform.android,
          memoryMb: 5600,
        ).memoryGb,
        6,
      );
      expect(
        pick(const DeviceSpec(platform: DevicePlatform.android, memoryMb: 5600))
            .text
            ?.id,
        'qwen3.5-2b-q4_k_m',
      );
      expect(
        pick(const DeviceSpec(platform: DevicePlatform.windows, memoryMb: 7900))
            .projector
            ?.id,
        'qwen3.5-2b-mmproj',
      );
      expect(
        pick(const DeviceSpec(platform: DevicePlatform.android, memoryMb: 3700))
            .text,
        isNull,
      );
    });

    test('메모리를 읽지 못하면 가장 작은 글 모델만 권한다', () {
      for (final spec in [phone(null), pc(null)]) {
        final r = pick(spec);
        expect(r.reason, RecommendationReason.memoryUnknown);
        expect(r.text?.id, 'qwen3.5-2b-q4_k_m');
        expect(r.vision, isNull);
      }
      // 글 모델이 여럿이면 필요한 메모리가 가장 작은 것.
      final two = ModelCatalog.parse(
        jsonEncode({
          'version': 1,
          'models': [
            {
              'id': 'big',
              'kind': 'text',
              'name': '큰 것',
              'min_memory_gb': 12,
              'platforms': ['android'],
            },
            {
              'id': 'small',
              'kind': 'text',
              'name': '작은 것',
              'min_memory_gb': 4,
              'platforms': ['android'],
            },
          ],
        }),
      );
      expect(recommendModels(two, phone(null)).text?.id, 'small');
      // 메모리를 알면 돌릴 수 있는 것 가운데 가장 큰 것.
      expect(recommendModels(two, phone(8)).text?.id, 'small');
      expect(recommendModels(two, phone(12)).text?.id, 'big');
    });

    test('웹과 그 밖의 플랫폼에는 권하지 않는다', () {
      for (final platform in [DevicePlatform.web, DevicePlatform.other]) {
        final r = pick(DeviceSpec(platform: platform, memoryMb: 32768));
        expect(r.reason, RecommendationReason.unsupportedPlatform);
        expect(r.files, isEmpty);
      }
    });

    test('카탈로그에 이 플랫폼의 모델이 없으면 그렇게 알린다', () {
      expect(
        recommendModels(ModelCatalog.empty, phone(8)).reason,
        RecommendationReason.nothingListed,
      );
    });
  });

  test('df의 출력에서 남은 공간을 읽는다', () {
    expect(
      parseDfAvailable(
        'Filesystem     1K-blocks     Used Available Use% Mounted on\n'
        '/dev/block/dm-8 112345678 82345678  30000000  74% /data\n',
      ),
      30000000 * 1024,
    );
    expect(parseDfAvailable(''), isNull);
    expect(parseDfAvailable('Filesystem 1K-blocks Used Available'), isNull);
    expect(parseDfAvailable('머리줄\n알 수 없는 꼴'), isNull);
  });
}
