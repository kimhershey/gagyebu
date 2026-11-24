import 'package:flutter_test/flutter_test.dart';
import 'package:gagyebu/ai/llm/model_catalog.dart';
import 'package:gagyebu/ai/llm/model_manager.dart';

import 'model_manager_fakes.dart';

void main() {
  late MemoryModelFileStore store;
  late MemoryModelFileRegistry registry;
  late FakeModelServer server;
  late ModelManager manager;
  var now = DateTime.utc(2026, 11, 17, 3);

  const path = '/models/test-model.gguf';
  const part = '/models/test-model.gguf.part';

  ModelManager managerFor(
    FakeModelServer server, {
    Duration stall = const Duration(seconds: 60),
  }) => ModelManager(
    store: store,
    registry: registry,
    client: server.client,
    clock: () => now,
    stallTimeout: stall,
    registryStep: 2000,
  );

  setUp(() {
    now = DateTime.utc(2026, 11, 17, 3);
    store = MemoryModelFileStore();
    registry = MemoryModelFileRegistry();
    server = FakeModelServer(sampleBytes(10000));
    manager = managerFor(server);
  });

  Matcher failsWith(ModelDownloadFailure failure) => throwsA(
    isA<ModelDownloadException>().having((e) => e.failure, 'failure', failure),
  );

  group('내려받기', () {
    test('끝까지 받아 해시를 확인하고 제 이름으로 둔다', () async {
      final progress = <(int, int?)>[];
      final record = await manager.download(
        entryFor(server),
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(record.status, ModelFileStatus.ready);
      expect(record.path, path);
      expect(record.sizeBytes, 10000);
      expect(record.downloadedBytes, 10000);
      expect(record.sha256, server.sha256Hex);
      expect(store.files[path], server.bytes);
      // 받는 동안 쓰던 임시 파일은 남지 않는다.
      expect(store.files.containsKey(part), isFalse);

      expect(registry.records['test-model']!.isReady, isTrue);
      expect(registry.records['test-model']!.kind, ModelKind.text);
      expect(registry.records['test-model']!.updatedAt, now);
      // 처음에는 '받는 중'으로 적고, 받는 동안 진행을 적는다.
      expect(registry.history.first.status, ModelFileStatus.downloading);
      expect(
        registry.history.where(
          (r) =>
              r.status == ModelFileStatus.downloading && r.downloadedBytes > 0,
        ),
        isNotEmpty,
      );

      // 진행은 줄지 않고 끝에서 전체와 같다.
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
      }
      expect(progress.first, (0, 10000));
      expect(progress.last, (10000, 10000));
      // 처음 받을 때는 Range를 보내지 않는다. 보내는 것은 GET 하나뿐이다.
      expect(server.requests.single.method, 'GET');
      expect(server.ranges, [null]);
      expect(manager.isDownloading('test-model'), isFalse);
    });

    test('끊기면 받은 데까지 남기고, 다음에는 그 뒤부터 이어받는다(HTTP Range)', () async {
      server.cutAfter = 4000;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.network),
      );
      expect(store.files[part], hasLength(4000));
      expect(store.files.containsKey(path), isFalse);
      final failed = registry.records['test-model']!;
      expect(failed.status, ModelFileStatus.failed);
      expect(failed.downloadedBytes, 4000);
      expect(failed.canResume, isTrue);

      server.cutAfter = null;
      final progress = <int>[];
      final record = await manager.download(
        entryFor(server),
        onProgress: (received, total) => progress.add(received),
      );
      expect(server.ranges, [null, 'bytes=4000-']);
      expect(record.isReady, isTrue);
      expect(store.files[path], server.bytes);
      // 이어받은 진행은 받아 둔 데서 시작한다.
      expect(progress.first, 4000);
      expect(progress.last, 10000);
    });

    test('여러 번 끊겨도 이어받아 끝낸다', () async {
      server.cutAfter = 3000;
      for (var i = 0; i < 3; i++) {
        await expectLater(
          manager.download(entryFor(server)),
          failsWith(ModelDownloadFailure.network),
        );
      }
      expect(store.files[part], hasLength(9000));
      server.cutAfter = null;
      await manager.download(entryFor(server));
      expect(server.ranges, [
        null,
        'bytes=3000-',
        'bytes=6000-',
        'bytes=9000-',
      ]);
      expect(store.files[path], server.bytes);
    });

    test('서버가 Range를 듣지 않으면 처음부터 다시 받는다', () async {
      store.files[part] = server.bytes.sublist(0, 4000);
      server.ignoreRange = true;
      final record = await manager.download(entryFor(server));
      expect(server.ranges, ['bytes=4000-']);
      expect(record.isReady, isTrue);
      // 앞의 4,000바이트가 두 번 들어가지 않았다.
      expect(store.files[path], server.bytes);
    });

    test('청한 자리와 다른 조각이 오면 받아 둔 것을 버린다', () async {
      store.files[part] = server.bytes.sublist(0, 4000);
      server.rangeSkew = 100;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.server),
      );
      expect(store.files, isEmpty);
      expect(registry.records['test-model']!.downloadedBytes, 0);
      // 다음에는 처음부터 받아 끝낸다.
      server.rangeSkew = 0;
      await manager.download(entryFor(server));
      expect(store.files[path], server.bytes);
    });

    test('다 받아 둔 임시 파일이 있으면 요청 없이 확인만 한다', () async {
      store.files[part] = [...server.bytes];
      final record = await manager.download(entryFor(server));
      expect(server.requests, isEmpty);
      expect(record.isReady, isTrue);
      expect(store.files[path], server.bytes);
    });

    test('카탈로그의 크기보다 많이 받아 둔 것은 버리고 처음부터 받는다', () async {
      store.files[part] = sampleBytes(12000, seed: 3);
      await manager.download(entryFor(server));
      expect(server.ranges, [null]);
      expect(store.files[path], server.bytes);
    });

    test('카탈로그에 크기가 없으면 서버가 알려 준 크기를 쓴다', () async {
      final totals = <int?>{};
      final record = await manager.download(
        entryFor(server, withSize: false),
        onProgress: (received, total) => totals.add(total),
      );
      expect(record.sizeBytes, 10000);
      expect(totals, {10000});

      // 서버도 알려 주지 않으면 모르는 채로 받고, 끝난 뒤의 크기를 적는다.
      store.files.clear();
      server.hideLength = true;
      final unknown = <int?>[];
      final again = await manager.download(
        entryFor(server, withSize: false),
        onProgress: (received, total) => unknown.add(total),
      );
      expect(unknown.first, isNull);
      expect(again.sizeBytes, 10000);
    });
  });

  group('해시 확인', () {
    test('받은 파일의 해시가 다르면 지우고 실패로 둔다', () async {
      final entry = entryFor(server, sha256Hex: 'a' * 64);
      await expectLater(
        manager.download(entry),
        failsWith(ModelDownloadFailure.hashMismatch),
      );
      // 틀린 파일은 어디에도 남지 않는다.
      expect(store.files, isEmpty);
      final record = registry.records['test-model']!;
      expect(record.status, ModelFileStatus.failed);
      expect(record.downloadedBytes, 0);
      expect(record.canResume, isFalse);
    });

    test('서버의 파일이 바뀌어 있었으면(내용이 다르면) 쓰지 않는다', () async {
      final entry = entryFor(server);
      // 카탈로그를 적은 뒤에 서버의 파일이 바뀌었다. 크기는 같다.
      server.bytes = sampleBytes(10000, seed: 99);
      await expectLater(
        manager.download(entry),
        failsWith(ModelDownloadFailure.hashMismatch),
      );
      expect(store.files, isEmpty);
    });

    test('해시는 대소문자를 가리지 않는다', () async {
      final entry = entryFor(server, sha256Hex: server.sha256Hex.toUpperCase());
      expect((await manager.download(entry)).isReady, isTrue);
    });
  });

  group('받을 수 없는 항목', () {
    test('주소나 해시가 없는 항목은 요청도 보내지 않는다', () async {
      for (final entry in [
        entryFor(server, withUrl: false),
        entryFor(server, withHash: false),
        entryFor(server, withUrl: false, withHash: false),
      ]) {
        expect(entry.isDownloadable, isFalse);
        await expectLater(
          manager.download(entry),
          failsWith(ModelDownloadFailure.notAvailable),
        );
      }
      expect(server.requests, isEmpty);
      expect(registry.records, isEmpty);
      expect(store.files, isEmpty);
    });

    test('서버가 파일을 주지 않으면(404) 실패로 둔다', () async {
      server.status = 404;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.server),
      );
      expect(registry.records['test-model']!.status, ModelFileStatus.failed);
      expect(store.files.containsKey(path), isFalse);
    });
  });

  group('저장 공간', () {
    test('공간이 모자라면 받기 전에 알린다', () async {
      store.free = 5000;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.insufficientSpace),
      );
      // 요청을 보내지 않았고 아무것도 쓰지 않았다.
      expect(server.requests, isEmpty);
      expect(store.files, isEmpty);
      expect(registry.records, isEmpty);
    });

    test('여유 공간(64MB)까지 남아야 받는다', () async {
      store.free = 10000 + ModelManager.spaceMargin - 1;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.insufficientSpace),
      );
      store.free = 10000 + ModelManager.spaceMargin;
      expect((await manager.download(entryFor(server))).isReady, isTrue);
    });

    test('이어받을 때는 남은 만큼만 있으면 된다', () async {
      store.files[part] = server.bytes.sublist(0, 9000);
      store.free = 1000 + ModelManager.spaceMargin;
      expect((await manager.download(entryFor(server))).isReady, isTrue);
    });

    test('빈 공간을 알 수 없으면 받아 본다', () async {
      store.free = null;
      expect((await manager.download(entryFor(server))).isReady, isTrue);
    });

    test('크기를 서버에서 알게 된 뒤에도 공간을 본다', () async {
      store.free = 5000;
      await expectLater(
        manager.download(entryFor(server, withSize: false)),
        failsWith(ModelDownloadFailure.insufficientSpace),
      );
      expect(store.files.containsKey(path), isFalse);
      expect(registry.records['test-model']!.status, ModelFileStatus.failed);
    });

    test('쓰다가 실패하면(디스크가 참) 저장 문제로 알린다', () async {
      store.failWritesAfter = 3500;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.storage),
      );
      expect(registry.records['test-model']!.status, ModelFileStatus.failed);
      expect(store.files.containsKey(path), isFalse);
    });
  });

  group('취소', () {
    test('받는 도중에 멈추면 받은 데까지 남고, 다시 받으면 이어받는다', () async {
      final token = ModelDownloadCancelToken();
      server.onChunk = (sent) {
        if (sent >= 3000) token.cancel();
      };
      await expectLater(
        manager.download(entryFor(server), cancelToken: token),
        failsWith(ModelDownloadFailure.cancelled),
      );
      final kept = store.files[part]!.length;
      expect(kept, inInclusiveRange(1000, 9000));
      expect(store.files.containsKey(path), isFalse);
      final record = registry.records['test-model']!;
      expect(record.status, ModelFileStatus.failed);
      expect(record.downloadedBytes, kept);
      expect(record.canResume, isTrue);
      expect(manager.isDownloading('test-model'), isFalse);

      server.onChunk = null;
      final done = await manager.download(entryFor(server));
      expect(server.ranges.last, 'bytes=$kept-');
      expect(done.isReady, isTrue);
      expect(store.files[path], server.bytes);
    });

    test('서버가 멈춰 있어도 바로 멈춘다', () async {
      server.stallAfter = 2000;
      final download = manager.download(entryFor(server));
      final expectation = expectLater(
        download,
        failsWith(ModelDownloadFailure.cancelled),
      );
      await pumpEventQueue();
      expect(manager.isDownloading('test-model'), isTrue);
      manager.cancel('test-model');
      await expectation;
      expect(store.files[part], hasLength(2000));
    });

    test('시작하기 전에 멈춘 것은 요청을 보내지 않는다', () async {
      final token = ModelDownloadCancelToken()..cancel();
      await expectLater(
        manager.download(entryFor(server), cancelToken: token),
        failsWith(ModelDownloadFailure.cancelled),
      );
      expect(server.requests, isEmpty);
    });

    test('오래 아무것도 오지 않으면 끊긴 것으로 본다', () async {
      server.stallAfter = 2000;
      final impatient = managerFor(
        server,
        stall: const Duration(milliseconds: 50),
      );
      await expectLater(
        impatient.download(entryFor(server)),
        failsWith(ModelDownloadFailure.network),
      );
      expect(store.files[part], hasLength(2000));
    });

    test('같은 모델을 겹쳐 받지 않는다', () async {
      server.stallAfter = 2000;
      final first = manager.download(entryFor(server));
      final firstDone = expectLater(
        first,
        failsWith(ModelDownloadFailure.cancelled),
      );
      await pumpEventQueue();
      expect(() => manager.download(entryFor(server)), throwsStateError);
      manager.cancel('test-model');
      await firstDone;
    });
  });

  group('지우기와 맞추기', () {
    test('지우면 파일과 기록이 없어진다', () async {
      await manager.download(entryFor(server));
      await manager.delete('test-model');
      expect(store.files, isEmpty);
      expect(registry.records, isEmpty);
    });

    test('받다 만 것도 지운다', () async {
      server.cutAfter = 4000;
      await expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.network),
      );
      await manager.delete('test-model');
      expect(store.files, isEmpty);
      expect(registry.records, isEmpty);
    });

    test('받는 중에 지우면 먼저 멈춘다', () async {
      server.stallAfter = 2000;
      final download = expectLater(
        manager.download(entryFor(server)),
        failsWith(ModelDownloadFailure.cancelled),
      );
      await pumpEventQueue();
      await manager.delete('test-model');
      await download;
      // 멈춘 내려받기가 뒤늦게 기록을 되살리지 않는다.
      expect(store.files, isEmpty);
      expect(registry.records, isEmpty);
    });

    test('앱이 받다가 꺼졌으면 실패로 고치고 이어받을 수 있게 둔다', () async {
      store.files[part] = server.bytes.sublist(0, 2500);
      await registry.put(
        ModelFileRecord(
          id: 'test-model',
          kind: ModelKind.text,
          fileName: 'test-model.gguf',
          path: path,
          sizeBytes: 10000,
          // 마지막으로 적은 진행은 실제보다 뒤처져 있다.
          downloadedBytes: 2000,
          sha256: server.sha256Hex,
          status: ModelFileStatus.downloading,
          updatedAt: now,
        ),
      );
      await manager.reconcile();
      final record = registry.records['test-model']!;
      expect(record.status, ModelFileStatus.failed);
      expect(record.downloadedBytes, 2500);
      expect(record.canResume, isTrue);
    });

    test('준비됐다고 적힌 파일이 없어졌으면 기록을 지운다', () async {
      await manager.download(entryFor(server));
      await manager.reconcile();
      expect(registry.records['test-model']!.isReady, isTrue);

      store.files.remove(path);
      await manager.reconcile();
      expect(registry.records, isEmpty);
    });
  });
}
