/// 기기 안에서 돌릴 모델의 카탈로그(`docs/SPEC.md` 5.4). 저장소의
/// `catalog/models.json`을 읽은 것이다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 카탈로그의 원본 주소. 공개 저장소의 파일을 그대로 읽기만 한다(아무것도 보내지 않는다).
final defaultCatalogUri = Uri.parse(
  'https://raw.githubusercontent.com/kimhershey/gagyebu/main/catalog/models.json',
);

/// 모델 파일의 종류. `model_files.kind`에 적는 값과 같다.
enum ModelKind {
  /// 글을 읽는 모델
  text('text'),

  /// 이미지를 읽는 모델(mmproj와 함께 쓴다)
  vision('vision'),

  /// 이미지를 모델이 읽을 수 있게 바꾸는 파일
  mmproj('mmproj');

  const ModelKind(this.code);
  final String code;

  static ModelKind? fromCode(Object? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// 카탈로그의 모델 하나.
class ModelCatalogEntry {
  const ModelCatalogEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.license,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.minMemoryGb,
    required this.platforms,
    this.mmproj,
  });

  /// 카탈로그의 ID. `model_files.id`와 거래의 `ai_model`에 적힌다.
  final String id;
  final ModelKind kind;

  /// 화면에 보이는 이름.
  final String name;
  final String license;

  /// 내려받을 주소. 확인하지 못했으면 null.
  final Uri? url;

  /// 파일 크기(바이트). 확인하지 못했으면 null.
  final int? sizeBytes;

  /// 파일의 SHA-256(소문자 16진수 64자). 확인하지 못했으면 null.
  final String? sha256;

  /// 이 모델을 돌리는 데 필요한 기기 메모리(GB).
  final int minMemoryGb;

  /// 쓸 수 있는 플랫폼(`android`, `windows`).
  final Set<String> platforms;

  /// 이미지를 읽을 때 함께 쓰는 mmproj의 ID. 없으면 null.
  final String? mmproj;

  /// 내려받을 수 있는지. 주소와 해시가 둘 다 있어야 한다. 해시 없이 받으면 받은
  /// 파일이 맞는지 확인할 길이 없어서 받지 않는다.
  bool get isDownloadable => url != null && sha256 != null;

  /// 저장할 파일 이름. ID에서 만든다(주소의 이름을 믿지 않는다).
  String get fileName => '$id.gguf';

  /// 한 항목을 읽는다. 꼴이 맞지 않으면 null(그 항목만 버린다).
  static ModelCatalogEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = ModelKind.fromCode(json['kind']);
    final name = json['name'];
    if (id is! String || !_safeId.hasMatch(id) || kind == null) return null;
    if (name is! String || name.isEmpty) return null;

    final rawUrl = json['url'];
    final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    // 평문 주소로는 받지 않는다.
    final url = uri != null && uri.isScheme('https') && uri.host.isNotEmpty
        ? uri
        : null;
    final rawHash = json['sha256'];
    final hash = rawHash is String && _sha256.hasMatch(rawHash.toLowerCase())
        ? rawHash.toLowerCase()
        : null;
    final size = json['size_bytes'];
    final memory = json['min_memory_gb'];
    final platforms = json['platforms'];
    final mmproj = json['mmproj'];
    return ModelCatalogEntry(
      id: id,
      kind: kind,
      name: name,
      license: json['license'] is String ? json['license'] as String : '',
      url: url,
      sizeBytes: size is int && size > 0 ? size : null,
      sha256: hash,
      minMemoryGb: memory is num && memory > 0 ? memory.ceil() : 0,
      platforms: {
        if (platforms is List)
          for (final p in platforms)
            if (p is String) p,
      },
      mmproj: mmproj is String && mmproj.isNotEmpty ? mmproj : null,
    );
  }

  /// ID는 파일 이름이 된다. 경로를 벗어나는 글자를 받지 않는다.
  static final _safeId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$');
  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  @override
  String toString() => 'ModelCatalogEntry($id)';
}

/// 모델 카탈로그.
class ModelCatalog {
  const ModelCatalog({required this.version, required this.models});

  /// 빈 카탈로그. 원본도 사본도 읽지 못했을 때 쓴다.
  static const empty = ModelCatalog(version: 0, models: []);

  final int version;
  final List<ModelCatalogEntry> models;

  ModelCatalogEntry? byId(String? id) {
    if (id == null) return null;
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }

  /// JSON 글을 읽는다. 카탈로그의 꼴이 아니면 [FormatException].
  ///
  /// 이 앱이 모르는 판(`version`)이면 받지 않는다. 항목의 꼴이 달라졌을 수 있다.
  factory ModelCatalog.parse(String text) {
    final Object? json = jsonDecode(text);
    if (json is! Map) throw const FormatException('카탈로그가 JSON 객체가 아니다');
    final version = json['version'];
    if (version != supportedVersion) {
      throw FormatException('모르는 카탈로그 판이다: $version');
    }
    final list = json['models'];
    if (list is! List) throw const FormatException('"models" 배열이 없다');
    final models = <ModelCatalogEntry>[];
    final seen = <String>{};
    for (final item in list) {
      final entry = ModelCatalogEntry.tryParse(item);
      if (entry != null && seen.add(entry.id)) models.add(entry);
    }
    return ModelCatalog(version: supportedVersion, models: models);
  }

  /// 이 앱이 읽을 수 있는 카탈로그 판.
  static const supportedVersion = 1;
}

/// 카탈로그를 읽는다: 공개 저장소의 원본을 먼저, 못 읽으면 앱에 든 사본을 쓴다.
///
/// [readBundled]는 앱에 든 사본의 글을 준다. 둘 다 못 읽으면 빈 카탈로그다(모델 없이도
/// 앱은 규칙만으로 돈다).
Future<ModelCatalog> loadModelCatalog({
  required http.Client client,
  required Future<String> Function() readBundled,
  Uri? remote,
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    final response = await client
        .get(remote ?? defaultCatalogUri)
        .timeout(timeout);
    if (response.statusCode == 200) {
      return ModelCatalog.parse(utf8.decode(response.bodyBytes));
    }
  } on Object {
    // 서버에 닿지 않거나 내용이 깨졌다. 앱에 든 사본으로 간다.
  }
  try {
    return ModelCatalog.parse(await readBundled());
  } on Object {
    return ModelCatalog.empty;
  }
}
