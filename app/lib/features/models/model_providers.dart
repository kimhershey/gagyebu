/// 기기 안의 모델을 둘러싼 상태: 기기 사양, 카탈로그, 내려받은 파일, 로컬 엔진 주소
/// (`docs/SPEC.md` 5.4).
library;

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../ai/llm/model_catalog.dart';
import '../../ai/llm/model_file_store.dart';
import '../../ai/llm/model_file_store_factory.dart';
import '../../ai/llm/model_manager.dart';
import '../../ai/llm/model_tier.dart';
import '../../app/providers.dart';
import '../../data/prefs/device_prefs.dart';
import '../../data/repositories/model_file_repository.dart';

/// 앱에 든 카탈로그 사본.
const bundledCatalogAsset = 'assets/catalog/models.json';

/// 기기 설정의 키(`docs/SPEC.md` 3.1).
const modelEndpointKey = 'model.endpoint';

/// 로컬 엔진이 알려 준 모델 이름. 요청의 `model`과 거래의 `ai_model`에 쓴다.
const modelEndpointModelKey = 'model.endpoint.model';

/// 앱이 도는 플랫폼.
final devicePlatformProvider = Provider<DevicePlatform>((ref) {
  if (kIsWeb) return DevicePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => DevicePlatform.android,
    TargetPlatform.windows => DevicePlatform.windows,
    _ => DevicePlatform.other,
  };
});

/// 기기의 메모리(MB)를 읽는다. 읽지 못하면 null.
Future<int?> readDeviceMemoryMb() async {
  if (kIsWeb) return null;
  final info = DeviceInfoPlugin();
  final megabytes = switch (defaultTargetPlatform) {
    TargetPlatform.android => (await info.androidInfo).physicalRamSize,
    TargetPlatform.windows => (await info.windowsInfo).systemMemoryInMegabytes,
    _ => null,
  };
  return megabytes != null && megabytes > 0 ? megabytes : null;
}

/// 기기 메모리를 읽는 함수. 시험에서 바꿔 끼운다.
final deviceMemoryReaderProvider = Provider<Future<int?> Function()>(
  (ref) => readDeviceMemoryMb,
);

/// 기기 사양. 메모리를 읽지 못하면 "알 수 없음"(null)으로 둔다.
final deviceSpecProvider = FutureProvider<DeviceSpec>((ref) async {
  final platform = ref.watch(devicePlatformProvider);
  int? memory;
  if (platform.runsLocalModels) {
    try {
      memory = await ref.watch(deviceMemoryReaderProvider)();
    } on Object {
      // 플러그인이 없거나 OS가 알려 주지 않는다.
      memory = null;
    }
  }
  return DeviceSpec(platform: platform, memoryMb: memory);
});

/// 카탈로그와 모델 파일을 받는 HTTP 클라이언트.
final modelHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// 모델 카탈로그. 공개 저장소의 원본을 읽고, 못 읽으면 앱에 든 사본을 쓴다.
final modelCatalogProvider = FutureProvider<ModelCatalog>(
  (ref) => loadModelCatalog(
    client: ref.watch(modelHttpClientProvider),
    readBundled: () => rootBundle.loadString(bundledCatalogAsset),
  ),
);

/// 이 기기에 권하는 모델. 사양이나 카탈로그를 아직 못 읽었으면 null.
final modelRecommendationProvider = Provider<ModelRecommendation?>((ref) {
  final catalog = ref.watch(modelCatalogProvider).value;
  final spec = ref.watch(deviceSpecProvider).value;
  if (catalog == null || spec == null) return null;
  return recommendModels(catalog, spec);
});

/// 모델 파일의 기록(`model_files`).
final modelFileRepositoryProvider = Provider<ModelFileRepository>(
  (ref) => ModelFileRepository(ref.watch(repositoryProvider).db),
);

/// 모델 파일을 두는 곳. 웹에는 없다(null).
final modelFileStoreProvider = Provider<ModelFileStore?>((ref) {
  if (!modelFileStoreAvailable) return null;
  if (!ref.watch(devicePlatformProvider).runsLocalModels) return null;
  return createModelFileStore(
    () async => (await getApplicationSupportDirectory()).path,
  );
});

/// 모델 파일을 내려받고 지우는 관리자. 모델을 둘 수 없는 플랫폼에서는 null.
final modelManagerProvider = Provider<ModelManager?>((ref) {
  final store = ref.watch(modelFileStoreProvider);
  if (store == null) return null;
  return ModelManager(
    store: store,
    registry: ref.watch(modelFileRepositoryProvider),
    client: ref.watch(modelHttpClientProvider),
    clock: ref.watch(clockProvider),
  );
});

/// 기기에 있는 모델 파일들. 처음 읽기 전에 기록과 파일을 한 번 맞춘다(앱이 받다가
/// 꺼졌거나 파일이 사라진 경우).
final modelFilesProvider = StreamProvider<List<ModelFileRecord>>((ref) async* {
  final manager = ref.watch(modelManagerProvider);
  if (manager == null) {
    yield const [];
    return;
  }
  try {
    await manager.reconcile();
  } on Object {
    // 맞추지 못해도 기록은 보여 준다.
  }
  yield* ref.watch(modelFileRepositoryProvider).watch();
});

/// 받고 있는 파일 하나의 진행.
@immutable
class ModelDownloadState {
  const ModelDownloadState({
    required this.received,
    this.total,
    this.failure,
    this.running = true,
  });

  final int received;

  /// 전체 크기. 아직 모르면 null.
  final int? total;

  /// 실패한 까닭. 실패하지 않았으면 null.
  final ModelDownloadFailure? failure;

  /// 지금 받고 있는지.
  final bool running;

  /// 0–1. 전체 크기를 모르면 null.
  double? get fraction =>
      total == null || total! <= 0 ? null : (received / total!).clamp(0, 1);
}

/// 내려받기의 진행 상태(모델 ID → 진행)와 시작 · 취소 · 지우기.
class ModelDownloads extends Notifier<Map<String, ModelDownloadState>> {
  @override
  Map<String, ModelDownloadState> build() => const {};

  void _set(String id, ModelDownloadState value) =>
      state = {...state, id: value};

  /// [entry]를 내려받는다. 끝나면 true, 실패했거나 멈췄으면 false다. 까닭은 상태의
  /// `failure`에 남는다.
  Future<bool> start(ModelCatalogEntry entry) async {
    final manager = ref.read(modelManagerProvider);
    if (manager == null || manager.isDownloading(entry.id)) return false;
    _set(entry.id, const ModelDownloadState(received: 0));
    var lastShown = 0;
    try {
      await manager.download(
        entry,
        onProgress: (received, total) {
          // 조각마다 화면을 다시 그리지 않는다. 1MB마다, 그리고 끝에서 알린다.
          if (received - lastShown < 1024 * 1024 && received != total) return;
          lastShown = received;
          if (!ref.mounted) return;
          _set(entry.id, ModelDownloadState(received: received, total: total));
        },
      );
      if (ref.mounted) state = {...state}..remove(entry.id);
      return true;
    } on ModelDownloadException catch (error) {
      if (ref.mounted) {
        _set(
          entry.id,
          ModelDownloadState(
            received: state[entry.id]?.received ?? 0,
            total: state[entry.id]?.total,
            failure: error.failure,
            running: false,
          ),
        );
      }
      return false;
    } on Object {
      if (ref.mounted) {
        _set(
          entry.id,
          const ModelDownloadState(
            received: 0,
            failure: ModelDownloadFailure.storage,
            running: false,
          ),
        );
      }
      return false;
    }
  }

  /// 받고 있는 [id]를 멈춘다.
  void cancel(String id) => ref.read(modelManagerProvider)?.cancel(id);

  /// [id]의 파일과 기록을 지운다.
  Future<void> delete(String id) async {
    await ref.read(modelManagerProvider)?.delete(id);
    if (ref.mounted) state = {...state}..remove(id);
  }

  /// 실패 표시를 지운다.
  void dismiss(String id) => state = {...state}..remove(id);
}

final modelDownloadsProvider =
    NotifierProvider<ModelDownloads, Map<String, ModelDownloadState>>(
      ModelDownloads.new,
    );

/// 사용자가 띄운 로컬 엔진의 주소(Windows, 선택).
@immutable
class ModelEndpoint {
  const ModelEndpoint({required this.uri, this.modelName});

  final Uri uri;

  /// 서버가 알려 준 모델 이름. "연결 확인"을 하기 전에는 null.
  final String? modelName;
}

/// 주소가 왜 쓸 수 없는지.
enum EndpointProblem {
  /// 주소의 꼴이 아니다.
  malformed,

  /// 이 컴퓨터의 주소가 아니다. 원문이 기기 밖으로 나가게 되므로 받지 않는다.
  notLocal,
}

/// 로컬 엔진의 주소를 읽는다. 쓸 수 있는 주소면 [Uri], 아니면 까닭을 준다.
///
/// 주소는 이 컴퓨터(127.0.0.1 · localhost · ::1)여야 한다. 붙여넣은 원문이 이 주소로
/// 가므로, 다른 기기의 주소를 받으면 "원문은 기기 밖으로 나가지 않는다"는 원칙이
/// 깨진다.
({Uri? uri, EndpointProblem? problem}) parseModelEndpoint(String text) {
  var value = text.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) {
    return (uri: null, problem: EndpointProblem.malformed);
  }
  if (!value.contains('://')) value = 'http://$value';
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      uri.host.isEmpty) {
    return (uri: null, problem: EndpointProblem.malformed);
  }
  const local = {'127.0.0.1', 'localhost', '::1'};
  if (!local.contains(uri.host.toLowerCase())) {
    return (uri: null, problem: EndpointProblem.notLocal);
  }
  // 경로는 엔진이 붙인다(`/v1/chat/completions`).
  return (
    uri: Uri(scheme: uri.scheme, host: uri.host, port: uri.port),
    problem: null,
  );
}

/// 기기 설정에 적어 둔 로컬 엔진 주소. 없으면 null.
class ModelEndpointController extends Notifier<ModelEndpoint?> {
  DevicePrefs get _prefs => ref.read(devicePrefsProvider);

  @override
  ModelEndpoint? build() {
    final prefs = ref.watch(devicePrefsProvider);
    final saved = prefs.getString(modelEndpointKey);
    if (saved == null) return null;
    final uri = parseModelEndpoint(saved).uri;
    if (uri == null) return null;
    return ModelEndpoint(
      uri: uri,
      modelName: prefs.getString(modelEndpointModelKey),
    );
  }

  /// 주소를 적어 둔다. 사용자가 직접 적은 것만 넘긴다.
  Future<void> save(Uri uri) async {
    await _prefs.setString(modelEndpointKey, uri.toString());
    await _prefs.remove(modelEndpointModelKey);
    state = ModelEndpoint(uri: uri);
  }

  /// 서버가 알려 준 모델 이름을 적어 둔다.
  Future<void> rememberModel(String name) async {
    final current = state;
    if (current == null) return;
    await _prefs.setString(modelEndpointModelKey, name);
    state = ModelEndpoint(uri: current.uri, modelName: name);
  }

  Future<void> clear() async {
    await _prefs.remove(modelEndpointKey);
    await _prefs.remove(modelEndpointModelKey);
    state = null;
  }
}

final modelEndpointProvider =
    NotifierProvider<ModelEndpointController, ModelEndpoint?>(
      ModelEndpointController.new,
    );

/// 로컬 엔진에 닿는지 확인한 결과.
@immutable
class EndpointCheck {
  const EndpointCheck({required this.ok, this.modelName});

  final bool ok;

  /// 서버가 알려 준 첫 모델의 이름.
  final String? modelName;
}

/// [uri]의 서버에 모델 목록(`/v1/models`)을 물어 닿는지 확인한다. 원문은 보내지 않는다.
Future<EndpointCheck> checkModelEndpoint(
  http.Client client,
  Uri uri, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final response = await client
        .get(uri.resolve('/v1/models'))
        .timeout(timeout);
    if (response.statusCode != 200) return const EndpointCheck(ok: false);
    return EndpointCheck(ok: true, modelName: _firstModelName(response.body));
  } on Object {
    return const EndpointCheck(ok: false);
  }
}

String? _firstModelName(String body) {
  // 꼴: {"data":[{"id":"…"}]}. 이름을 못 읽어도 연결은 된 것이다.
  final match = RegExp(r'"id"\s*:\s*"([^"\\]{1,120})"').firstMatch(body);
  return match?.group(1);
}
