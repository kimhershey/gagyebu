import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme/tokens.dart';
import '../data/prefs/device_prefs.dart';

/// 앱의 버전(`1.2.0`, `1.2.0-beta.1`, `v1.2.0+7`). 크기를 견줄 수 있다.
///
/// 견주는 법은 유의적 버전을 따른다: 숫자를 앞에서부터 수로 견주고(1.10.0 > 1.9.0), 숫자가
/// 같으면 시험판 꼬리표(`-beta`)가 붙은 쪽이 낮다. `+` 뒤(빌드 번호)는 보지 않는다.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this._numbers, this._pre);

  final List<int> _numbers;

  /// 시험판 꼬리표를 점으로 나눈 것. 정식 버전이면 비어 있다.
  final List<String> _pre;

  /// 읽을 수 없는 글이면 null.
  static AppVersion? tryParse(String? text) {
    if (text == null) return null;
    var rest = text.trim();
    if (rest.startsWith('v') || rest.startsWith('V')) rest = rest.substring(1);
    final plus = rest.indexOf('+');
    if (plus >= 0) rest = rest.substring(0, plus);
    final dash = rest.indexOf('-');
    final core = dash >= 0 ? rest.substring(0, dash) : rest;
    final pre = dash >= 0 ? rest.substring(dash + 1) : '';
    if (dash >= 0 && pre.isEmpty) return null;
    final numbers = <int>[];
    for (final part in core.split('.')) {
      // 자릿수가 터무니없이 긴 값은 버전이 아니다(수로 바꾸다 넘치지 않게 한다).
      if (part.isEmpty || part.length > 9) return null;
      final number = int.tryParse(part);
      if (number == null || number < 0) return null;
      numbers.add(number);
    }
    if (numbers.length > 4) return null;
    final tags = pre.isEmpty ? const <String>[] : pre.split('.');
    if (tags.any((tag) => tag.isEmpty)) return null;
    return AppVersion._(numbers, tags);
  }

  bool get isPreRelease => _pre.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    // 1.2와 1.2.0은 같다.
    for (var i = 0; i < 4; i++) {
      final a = i < _numbers.length ? _numbers[i] : 0;
      final b = i < other._numbers.length ? other._numbers[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    if (_pre.isEmpty || other._pre.isEmpty) {
      // 꼬리표가 없는 쪽(정식 버전)이 높다.
      return (_pre.isEmpty ? 1 : 0) - (other._pre.isEmpty ? 1 : 0);
    }
    for (var i = 0; i < _pre.length && i < other._pre.length; i++) {
      final a = _pre[i];
      final b = other._pre[i];
      if (a == b) continue;
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      // 수끼리는 수로, 글끼리는 글로 견준다. 수는 글보다 낮다.
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.compareTo(b);
    }
    return _pre.length.compareTo(other._pre.length);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode {
    final numbers = [..._numbers];
    while (numbers.isNotEmpty && numbers.last == 0) {
      numbers.removeLast();
    }
    return Object.hash(Object.hashAll(numbers), Object.hashAll(_pre));
  }

  @override
  String toString() =>
      _numbers.join('.') + (_pre.isEmpty ? '' : '-${_pre.join('.')}');
}

/// 새 버전이 있다는 알림.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.current,
    required this.latest,
    required this.required,
    required this.download,
    this.notes,
  });

  /// 지금 깔린 버전과 새 버전(화면에 그대로 보여 준다).
  final String current;
  final String latest;

  /// 지금 버전이 `min`보다 낮아 꼭 올려야 하는지.
  final bool required;

  /// 이 플랫폼의 설치 파일을 받는 주소.
  final Uri download;

  /// 무엇이 바뀌었는지 한두 줄.
  final String? notes;
}

/// 저장소의 `catalog/version.json`을 읽어 새 버전이 있는지 본다(`docs/SPEC.md` 7.21).
///
/// - Windows · Android 앱에서만 한다. 웹은 새로 고치면 최신이라 아무것도 하지 않는다.
/// - 하루에 한 번만 묻는다. 그사이에는 마지막으로 받은 내용으로 판단한다(앱을 다시 켜도
///   알림이 남는다).
/// - 파일을 못 읽거나 내용이 이상하면 조용히 넘어간다.
class UpdateChecker {
  UpdateChecker({
    required this.prefs,
    required this.currentVersion,
    this._client,
    this.clock = DateTime.now,
  });

  final DevicePrefs prefs;

  /// 지금 깔린 앱의 버전. 알 수 없으면 null.
  final Future<String?> Function() currentVersion;
  final DateTime Function() clock;
  final http.Client? _client;

  /// 최신 버전을 적어 둔 공개 파일. 릴리스할 때 CI가 고친다.
  static final source = Uri.parse(
    'https://raw.githubusercontent.com/kimhershey/gagyebu/main/catalog/version.json',
  );

  /// 파일에 이 플랫폼의 주소가 없을 때 여는 곳.
  static final releases = Uri.parse(
    'https://github.com/kimhershey/gagyebu/releases/latest',
  );

  /// 기기 설정의 키: 마지막으로 물어본 때(UTC ISO 8601)와 그때 받은 파일.
  static const checkedAtKey = 'update.checkedAt';
  static const manifestKey = 'update.manifest';

  static const interval = Duration(days: 1);
  static const _timeout = Duration(seconds: 10);

  /// 이 플랫폼에서 확인하는지와, 파일에서 읽을 주소의 이름.
  static String? get platformKey {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.windows => 'windows',
      _ => null,
    };
  }

  /// 새 버전이 있으면 알려 준다. 없거나 알 수 없으면 null.
  Future<UpdateInfo?> check() async {
    final platform = platformKey;
    if (platform == null) return null;
    try {
      final current = AppVersion.tryParse(await currentVersion());
      if (current == null) return null;
      final manifest = await _manifest();
      if (manifest == null) return null;
      return _judge(manifest, current, platform);
    } catch (e) {
      // 알림은 없어도 되는 것이다. 어떤 실패도 앱을 막지 않는다.
      debugPrint('업데이트를 확인하지 못했다: $e');
      return null;
    }
  }

  /// 오늘 이미 물었으면 그때 받은 것을, 아니면 새로 받아 돌려준다.
  Future<Map<String, Object?>?> _manifest() async {
    final now = clock().toUtc();
    final checkedAt = DateTime.tryParse(prefs.getString(checkedAtKey) ?? '');
    final cached = _decode(prefs.getString(manifestKey));
    // 기기의 시계가 뒤로 갔으면(마지막으로 본 때가 앞날이면) 다시 묻는다.
    final fresh =
        checkedAt != null &&
        !checkedAt.isAfter(now) &&
        now.difference(checkedAt) < interval;
    if (fresh) return cached;

    final fetched = await _fetch();
    // 못 읽었으면 본 것으로 치지 않는다. 다음에 앱을 켤 때 다시 묻는다.
    if (fetched == null) return cached;
    await prefs.setString(checkedAtKey, now.toIso8601String());
    await prefs.setString(manifestKey, jsonEncode(fetched));
    return fetched;
  }

  Future<Map<String, Object?>?> _fetch() async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(source).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return _decode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('버전 파일을 읽지 못했다: $e');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static Map<String, Object?>? _decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final value = jsonDecode(text);
      return value is Map ? value.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }

  static UpdateInfo? _judge(
    Map<String, Object?> manifest,
    AppVersion current,
    String platform,
  ) {
    final latestText = manifest['latest'];
    final latest = AppVersion.tryParse(
      latestText is String ? latestText : null,
    );
    if (latest == null || !(latest > current)) return null;
    final minText = manifest['min'];
    final min = AppVersion.tryParse(minText is String ? minText : null);
    final notes = manifest['notes'];
    return UpdateInfo(
      current: '$current',
      latest: '$latest',
      required: min != null && current < min,
      download: _download(manifest[platform]),
      notes: notes is String && notes.trim().isNotEmpty ? notes.trim() : null,
    );
  }

  /// 파일에 적힌 주소. https가 아니면(잘못 적혔거나 누가 바꿔치기했으면) 열지 않고 릴리스
  /// 페이지로 보낸다.
  static Uri _download(Object? value) {
    final uri = value is String ? Uri.tryParse(value.trim()) : null;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return releases;
    }
    return uri;
  }
}

/// 지금 깔린 앱의 버전(`pubspec.yaml`의 version에서 빌드 번호를 뺀 것). 알 수 없으면 null.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (e) {
    debugPrint('앱 버전을 읽지 못했다: $e');
    return null;
  }
});

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => UpdateChecker(
    prefs: ref.watch(devicePrefsProvider),
    currentVersion: () => ref.read(appVersionProvider.future),
  ),
);

/// 새 버전 알림. 앱을 켠 뒤 처음 볼 때 한 번 확인하고, 앱이 떠 있는 동안 그 답을 쓴다.
final updateInfoProvider = FutureProvider<UpdateInfo?>(
  (ref) => ref.watch(updateCheckerProvider).check(),
);

/// 내려받기 주소를 기기의 브라우저로 여는 함수. 시험에서 바꿔 끼운다.
final updateLauncherProvider = Provider<Future<bool> Function(Uri url)>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// 새 버전이 있으면 알려 주는 띠(`docs/SPEC.md` 7.21). 없으면 아무것도 그리지 않는다.
///
/// 누르면 이 플랫폼의 설치 파일 주소를 브라우저로 연다. 지금 버전이 너무 낮으면 꼭 올려야
/// 한다고 적는다(앱을 막지는 않는다).
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Uri url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await ref.read(updateLauncherProvider)(url);
    } catch (e) {
      debugPrint('내려받기 주소를 열지 못했다: $e');
    }
    if (!opened) {
      messenger?.showSnackBar(const SnackBar(content: Text('브라우저를 열지 못했습니다')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateInfoProvider).value;
    if (info == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final urgent = info.required;
    final accent = urgent ? tokens.warn : theme.colorScheme.primary;
    final notes = info.notes;
    return Padding(
      // 띠가 있을 때만 아래 내용과 사이를 띄운다.
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: const ValueKey('update-banner'),
        color: urgent ? tokens.warnSoft : tokens.accentSoft,
        borderRadius: BorderRadius.circular(tokens.radius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                urgent ? Icons.warning_amber_outlined : Icons.system_update_alt,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgent ? '꼭 업데이트해야 합니다' : '새 버전이 나왔습니다',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      urgent
                          ? '지금 버전(${info.current})은 더 지원하지 않습니다. '
                                '새 버전은 ${info.latest}입니다'
                          : '지금 버전은 ${info.current}, 새 버전은 ${info.latest}입니다',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (notes != null)
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('update-download'),
                onPressed: () => _open(context, ref, info.download),
                child: const Text('내려받기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
