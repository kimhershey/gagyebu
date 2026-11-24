/// 기기 사양에 맞는 모델을 고른다(`docs/SPEC.md` 5.4의 등급 표).
library;

import 'model_catalog.dart';

/// 앱이 도는 플랫폼. 카탈로그의 `platforms` 값과 맞춘다.
enum DevicePlatform {
  android('android'),
  windows('windows'),

  /// 웹 앱. 기기 안의 모델이 없다.
  web('web'),

  /// 그 밖(개발용 Linux · macOS). 배포 대상이 아니라 모델을 권하지 않는다.
  other('other');

  const DevicePlatform(this.code);
  final String code;

  /// 기기 안의 모델을 쓸 수 있는 플랫폼인지.
  bool get runsLocalModels => this == android || this == windows;
}

/// 기기 사양.
class DeviceSpec {
  const DeviceSpec({required this.platform, this.memoryMb});

  final DevicePlatform platform;

  /// 기기의 메모리(MB). 읽지 못했으면 null.
  final int? memoryMb;

  /// 메모리를 흔히 부르는 크기(GB)로. OS가 알려 주는 값은 조금 모자라게 나온다
  /// ('6GB' 휴대폰이 5,600MB쯤). 그래서 올림한다.
  int? get memoryGb => memoryMb == null ? null : (memoryMb! / 1024).ceil();

  @override
  bool operator ==(Object other) =>
      other is DeviceSpec &&
      other.platform == platform &&
      other.memoryMb == memoryMb;

  @override
  int get hashCode => Object.hash(platform, memoryMb);

  @override
  String toString() => 'DeviceSpec(${platform.code}, $memoryMb MB)';
}

/// 권하는 모델이 그렇게 정해진 까닭.
enum RecommendationReason {
  /// 사양에 맞는 모델을 골랐다.
  matched,

  /// 메모리를 읽지 못해 가장 작은 모델을 골랐다.
  memoryUnknown,

  /// 메모리가 모자라 권할 모델이 없다. 규칙만으로 쓴다.
  lowMemory,

  /// 이 플랫폼에는 기기 안의 모델이 없다(웹).
  unsupportedPlatform,

  /// 카탈로그에 이 플랫폼의 모델이 없다.
  nothingListed,
}

/// 기기에 권하는 모델.
class ModelRecommendation {
  const ModelRecommendation({
    required this.reason,
    this.text,
    this.vision,
    this.projector,
  });

  final RecommendationReason reason;

  /// 글을 읽는 모델. 없으면 규칙만으로 쓴다.
  final ModelCatalogEntry? text;

  /// 이미지를 읽는 모델. [text]와 같은 모델일 수 있다. [projector]와 함께 쓴다.
  final ModelCatalogEntry? vision;

  /// [vision]과 함께 쓰는 mmproj.
  final ModelCatalogEntry? projector;

  /// 권하는 파일들. 겹치는 것은 한 번만.
  List<ModelCatalogEntry> get files {
    final seen = <String>{};
    return [
      for (final entry in [text, vision, projector])
        if (entry != null && seen.add(entry.id)) entry,
    ];
  }
}

/// [spec]의 기기에 맞는 모델을 [catalog]에서 고른다.
///
/// 모델마다 필요한 메모리(`min_memory_gb`)가 적혀 있다. 기기의 메모리로 돌릴 수 있는
/// 것 가운데 가장 큰 것을 고른다. 메모리를 읽지 못했으면 가장 작은 글 모델만 권한다.
/// 이미지 모델은 mmproj까지 그 기기에서 쓸 수 있어야 권한다.
ModelRecommendation recommendModels(ModelCatalog catalog, DeviceSpec spec) {
  if (!spec.platform.runsLocalModels) {
    return const ModelRecommendation(
      reason: RecommendationReason.unsupportedPlatform,
    );
  }
  bool here(ModelCatalogEntry entry) =>
      entry.platforms.contains(spec.platform.code);
  final texts = [
    for (final entry in catalog.models)
      if (entry.kind == ModelKind.text && here(entry)) entry,
  ];
  if (texts.isEmpty) {
    return const ModelRecommendation(
      reason: RecommendationReason.nothingListed,
    );
  }

  final memory = spec.memoryGb;
  if (memory == null) {
    final smallest = texts.reduce(
      (a, b) => b.minMemoryGb < a.minMemoryGb ? b : a,
    );
    return ModelRecommendation(
      reason: RecommendationReason.memoryUnknown,
      text: smallest,
    );
  }

  bool fits(ModelCatalogEntry entry) => entry.minMemoryGb <= memory;

  /// 돌릴 수 있는 것 가운데 가장 큰 것. 같으면 카탈로그에 먼저 적힌 것.
  ModelCatalogEntry? largest(Iterable<ModelCatalogEntry> entries) {
    ModelCatalogEntry? best;
    for (final entry in entries) {
      if (!fits(entry)) continue;
      if (best == null || entry.minMemoryGb > best.minMemoryGb) best = entry;
    }
    return best;
  }

  ModelCatalogEntry? projectorOf(ModelCatalogEntry model) {
    final projector = catalog.byId(model.mmproj);
    if (projector == null || projector.kind != ModelKind.mmproj) return null;
    return here(projector) && fits(projector) ? projector : null;
  }

  final text = largest(texts);
  // 이미지: 이미지 전용 모델이 먼저고, 없으면 mmproj가 있는 글 모델을 함께 쓴다.
  final vision =
      largest([
        for (final entry in catalog.models)
          if (entry.kind == ModelKind.vision &&
              here(entry) &&
              projectorOf(entry) != null)
            entry,
      ]) ??
      largest([
        for (final entry in texts)
          if (projectorOf(entry) != null) entry,
      ]);

  return ModelRecommendation(
    reason: text == null
        ? RecommendationReason.lowMemory
        : RecommendationReason.matched,
    text: text,
    vision: vision,
    projector: vision == null ? null : projectorOf(vision),
  );
}
