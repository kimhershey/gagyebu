import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/llm/model_catalog.dart';
import '../../ai/llm/model_manager.dart';
import '../../ai/llm/model_tier.dart';
import '../../app/theme/tokens.dart';
import '../common/widgets.dart';
import 'model_providers.dart';

/// 바이트 수를 읽기 쉬운 크기로. 1374389534 → '1.28GB', 52428800 → '50MB'
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)}GB';
  if (bytes >= mb) return '${(bytes / mb).round()}MB';
  return '${(bytes / 1024).ceil()}KB';
}

/// 실패한 까닭을 화면의 말로. 예외 문구를 그대로 보이지 않는다.
String downloadFailureMessage(ModelDownloadFailure failure) =>
    switch (failure) {
      ModelDownloadFailure.notAvailable => '아직 내려받을 수 없는 모델입니다.',
      ModelDownloadFailure.insufficientSpace =>
        '저장 공간이 모자랍니다. 공간을 비운 뒤에 다시 받아 주세요.',
      ModelDownloadFailure.network => '연결이 끊겼습니다. 받은 데까지는 남아 있어 이어받을 수 있습니다.',
      ModelDownloadFailure.server => '서버에서 파일을 받지 못했습니다. 잠시 뒤에 다시 해 주세요.',
      ModelDownloadFailure.hashMismatch => '받은 파일이 등록된 것과 달라 지웠습니다. 다시 받아 주세요.',
      ModelDownloadFailure.storage => '파일을 저장하지 못했습니다. 저장 공간을 확인해 주세요.',
      ModelDownloadFailure.cancelled => '내려받기를 멈췄습니다. 받은 데까지는 남아 있습니다.',
    };

String _kindLabel(ModelKind kind) => switch (kind) {
  ModelKind.text => '글 읽기',
  ModelKind.vision => '이미지 읽기',
  ModelKind.mmproj => '이미지 입력 보조 파일',
};

/// AI 모델 화면. `docs/SPEC.md` 5.4.
///
/// 기기 사양과 권하는 모델을 보여 주고, 모델을 내려받고 지운다. 사용자가 누르기 전에는
/// 아무것도 받지 않는다.
class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final platform = ref.watch(devicePlatformProvider);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('models-back'),
                    tooltip: '설정으로',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('AI 모델', style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (platform == DevicePlatform.web)
                const _WebNotice()
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '모르는 형식의 결제 문자와 이미지를 이 기기 안에서 읽는 모델입니다. '
                    '붙여넣은 글과 이미지는 기기 밖으로 나가지 않습니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _DeviceCard(),
                if (platform.runsLocalModels) ...[
                  const SizedBox(height: 12),
                  const _ModelsCard(),
                ],
                if (platform != DevicePlatform.android) ...[
                  const SizedBox(height: 12),
                  const _EndpointCard(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WebNotice extends StatelessWidget {
  const _WebNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      key: const ValueKey('models-web-notice'),
      title: '웹 앱에는 기기 안의 모델이 없습니다',
      child: Text(
        '결제 문자와 한 줄 문장은 규칙으로 읽습니다. 규칙이 모르는 형식의 문자는 '
        'Windows · Android 앱에서, 이미지는 Windows 앱에서 읽을 수 있습니다.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 기기 사양과 권하는 모델.
class _DeviceCard extends ConsumerWidget {
  const _DeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spec = ref.watch(deviceSpecProvider).value;
    final recommendation = ref.watch(modelRecommendationProvider);
    if (spec == null) {
      return const SectionCard(
        title: '이 기기',
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final memory = spec.memoryGb;
    return SectionCard(
      key: const ValueKey('models-device'),
      title: '이 기기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              switch (spec.platform) {
                DevicePlatform.android => 'Android',
                DevicePlatform.windows => 'Windows PC',
                DevicePlatform.web => '웹',
                DevicePlatform.other => '그 밖의 기기',
              },
              memory == null ? '메모리 알 수 없음' : '메모리 ${memory}GB',
            ].join(' · '),
            key: const ValueKey('models-device-spec'),
          ),
          const SizedBox(height: 6),
          Text(
            _recommendationText(spec, recommendation),
            key: const ValueKey('models-recommendation'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _recommendationText(DeviceSpec spec, ModelRecommendation? r) {
    if (!spec.platform.runsLocalModels) {
      return '이 기기에서는 모델을 내려받아 돌리지 않습니다. 규칙으로 읽습니다.';
    }
    if (r == null) return '권하는 모델을 알아보고 있습니다.';
    final text = r.text;
    final vision = r.vision;
    switch (r.reason) {
      case RecommendationReason.matched:
        return [
          '권하는 모델은 ${text!.name}입니다.',
          if (vision != null && vision.id != text.id)
            '이미지 입력에는 ${vision.name} 모델을 권합니다.'
          else if (vision != null)
            '보조 파일을 함께 받으면 이미지도 읽습니다.',
        ].join(' ');
      case RecommendationReason.memoryUnknown:
        return '메모리를 읽지 못해 가장 작은 모델(${text!.name})을 권합니다.';
      case RecommendationReason.lowMemory:
        return '메모리가 모자라 모델을 권하지 않습니다. 규칙으로 읽습니다.';
      case RecommendationReason.nothingListed:
        return '이 기기에서 쓸 수 있는 모델이 목록에 없습니다.';
      case RecommendationReason.unsupportedPlatform:
        return '이 기기에서는 모델을 내려받아 돌리지 않습니다. 규칙으로 읽습니다.';
    }
  }
}

/// 카탈로그의 모델 목록.
class _ModelsCard extends ConsumerWidget {
  const _ModelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(devicePlatformProvider);
    final catalog = ref.watch(modelCatalogProvider);
    final files = ref.watch(modelFilesProvider).value ?? const [];
    final recommended = {
      ...?ref.watch(modelRecommendationProvider)?.files.map((f) => f.id),
    };
    final entries = [
      for (final entry in catalog.value?.models ?? const <ModelCatalogEntry>[])
        if (entry.platforms.contains(platform.code)) entry,
    ];
    // 카탈로그에서 빠진 모델의 파일이 기기에 남아 있을 수 있다. 지울 수 있게 보여 준다.
    final listed = {...?catalog.value?.models.map((m) => m.id)};
    final orphans = catalog.value == null
        ? const <ModelFileRecord>[]
        : [
            for (final file in files)
              if (!listed.contains(file.id)) file,
          ];
    final Widget body;
    if (catalog.isLoading && catalog.value == null) {
      body = const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (entries.isEmpty && orphans.isEmpty) {
      body = EmptyState(
        key: const ValueKey('models-empty'),
        icon: Icons.cloud_off_outlined,
        message: '모델 목록을 읽지 못했습니다.\n인터넷 연결을 확인하고 다시 읽어 주세요.',
        action: OutlinedButton(
          key: const ValueKey('models-reload'),
          onPressed: () => ref.invalidate(modelCatalogProvider),
          child: const Text('다시 읽기'),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final (index, entry) in entries.indexed) ...[
            if (index > 0) const Divider(height: 24),
            _ModelTile(
              entry: entry,
              record: files.where((f) => f.id == entry.id).firstOrNull,
              recommended: recommended.contains(entry.id),
            ),
          ],
          for (final file in orphans) ...[
            if (entries.isNotEmpty || file != orphans.first)
              const Divider(height: 24),
            _OrphanTile(record: file),
          ],
        ],
      );
    }
    return SectionCard(title: '모델', child: body);
  }
}

/// 모델 하나: 이름, 크기, 상태, 내려받기 · 취소 · 지우기.
class _ModelTile extends ConsumerWidget {
  const _ModelTile({
    required this.entry,
    required this.record,
    required this.recommended,
  });

  final ModelCatalogEntry entry;

  /// 기기에 있는 파일의 기록. 받은 적이 없으면 null.
  final ModelFileRecord? record;
  final bool recommended;

  String get _id => entry.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final download = ref.watch(modelDownloadsProvider.select((m) => m[_id]));
    final record = this.record;
    final size = entry.sizeBytes ?? (record?.sizeBytes ?? 0);

    final List<Widget> status;
    final List<Widget> actions;
    if (download != null && download.running) {
      final total = download.total;
      final fraction = download.fraction;
      final progress = [
        formatBytes(download.received),
        if (total != null) formatBytes(total),
      ].join(' / ');
      final percent = fraction == null ? '' : ' (${(fraction * 100).round()}%)';
      status = [
        Semantics(
          label: '${entry.name} 받는 중 $progress$percent',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: ValueKey('model-progress-$_id'),
              value: fraction,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('받는 중 · $progress$percent', style: tokens.amountStyle(muted)),
      ];
      actions = [
        OutlinedButton(
          key: ValueKey('model-cancel-$_id'),
          onPressed: () =>
              ref.read(modelDownloadsProvider.notifier).cancel(_id),
          child: const Text('취소'),
        ),
      ];
    } else if (record != null && record.isReady) {
      status = [
        Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: tokens.ok),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '준비됨 · ${formatBytes(record.sizeBytes)}',
                key: ValueKey('model-ready-$_id'),
              ),
            ),
          ],
        ),
      ];
      actions = [_deleteButton(context, ref)];
    } else {
      final failure = download?.failure;
      final partial = record != null && record.canResume;
      status = [
        if (failure != null)
          Text(
            downloadFailureMessage(failure),
            key: ValueKey('model-failure-$_id'),
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.warn),
          )
        else if (partial)
          Text(
            '받다가 멈췄습니다 · ${formatBytes(record.downloadedBytes)} 받음',
            key: ValueKey('model-partial-$_id'),
          )
        else if (!entry.isDownloadable)
          Text(
            '아직 내려받을 수 없습니다. 모델 파일의 주소와 확인값이 등록되면 받을 수 있습니다.',
            key: ValueKey('model-unavailable-$_id'),
            style: muted,
          ),
      ];
      actions = [
        FilledButton.tonal(
          key: ValueKey('model-download-$_id'),
          // 주소와 해시가 둘 다 있어야 받는다.
          onPressed: entry.isDownloadable
              ? () => _startDownload(context, ref, resume: partial)
              : null,
          child: Text(partial ? '이어받기' : '내려받기'),
        ),
        if (record != null) _deleteButton(context, ref),
      ];
    }

    return Column(
      key: ValueKey('model-tile-$_id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(entry.name, style: theme.textTheme.titleSmall),
            if (recommended)
              Container(
                key: ValueKey('model-recommended-$_id'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accentSoft,
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
                child: Text('권장', style: theme.textTheme.labelSmall),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          [
            _kindLabel(entry.kind),
            size > 0 ? formatBytes(size) : '크기 확인 전',
            if (entry.minMemoryGb > 0) '메모리 ${entry.minMemoryGb}GB 이상',
            if (entry.license.isNotEmpty) entry.license,
          ].join(' · '),
          style: muted,
        ),
        if (status.isNotEmpty) ...[const SizedBox(height: 8), ...status],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: actions),
      ],
    );
  }

  Widget _deleteButton(BuildContext context, WidgetRef ref) => TextButton(
    key: ValueKey('model-delete-$_id'),
    onPressed: () => _confirmDelete(context, ref),
    child: const Text('지우기'),
  );

  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref, {
    required bool resume,
  }) async {
    final size = entry.sizeBytes;
    // 어떤 연결을 쓰는지 알 수 없다. 크기를 알리고 한 번 묻는다.
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(resume ? '이어서 받을까요?' : '내려받을까요?'),
        content: Text(
          [
            size == null
                ? '${entry.name} 모델을 내려받습니다.'
                : '${entry.name} 모델(${formatBytes(size)})을 내려받습니다.',
            '모바일 데이터를 쓰고 있다면 요금이 나올 수 있습니다. Wi-Fi에서 받기를 권합니다.',
          ].join(' '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('model-download-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(resume ? '이어받기' : '내려받기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await ref.read(modelDownloadsProvider.notifier).start(entry);
    if (!done || !context.mounted) return;

    // 같은 일을 하는 옛 모델이 남아 있으면 지울지 묻는다. 저절로 지우지 않는다.
    final others = [
      for (final file in await ref.read(modelFileRepositoryProvider).all())
        if (file.isReady && file.kind == entry.kind && file.id != _id) file,
    ];
    if (others.isEmpty || !context.mounted) return;
    final catalog = ref.read(modelCatalogProvider).value;
    final names = [
      for (final file in others) catalog?.byId(file.id)?.name ?? file.id,
    ].join(', ');
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전에 받은 모델을 지울까요?'),
        content: Text('${entry.name} 모델을 받았습니다. 전에 받은 모델($names)은 지워도 됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('남겨 두기'),
          ),
          FilledButton(
            key: const ValueKey('model-remove-old-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    for (final file in others) {
      await ref.read(modelDownloadsProvider.notifier).delete(file.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모델을 지울까요?'),
        content: Text('${entry.name}의 파일을 이 기기에서 지웁니다. 다시 쓰려면 다시 받아야 합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('model-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(modelDownloadsProvider.notifier).delete(_id);
  }
}

/// 카탈로그에 없는 모델의 파일. 지우는 것만 할 수 있다.
class _OrphanTile extends ConsumerWidget {
  const _OrphanTile({required this.record});

  final ModelFileRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = record.isReady ? record.sizeBytes : record.downloadedBytes;
    return Column(
      key: ValueKey('model-orphan-${record.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.id, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          [
            '지금 목록에 없는 모델',
            _kindLabel(record.kind),
            if (size > 0) formatBytes(size),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: ValueKey('model-delete-${record.id}'),
          onPressed: () =>
              ref.read(modelDownloadsProvider.notifier).delete(record.id),
          child: const Text('지우기'),
        ),
      ],
    );
  }
}

/// 사용자가 이 컴퓨터에 띄운 로컬 엔진의 주소(선택).
class _EndpointCard extends ConsumerStatefulWidget {
  const _EndpointCard();

  @override
  ConsumerState<_EndpointCard> createState() => _EndpointCardState();
}

class _EndpointCardState extends ConsumerState<_EndpointCard> {
  late final TextEditingController _controller;
  String? _message;
  bool _warning = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(modelEndpointProvider)?.uri.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String message, {bool warning = false}) => setState(() {
    _message = message;
    _warning = warning;
  });

  /// 칸에 적힌 주소를 읽는다. 쓸 수 없으면 까닭을 알리고 null을 준다.
  Uri? _read() {
    final parsed = parseModelEndpoint(_controller.text);
    switch (parsed.problem) {
      case EndpointProblem.malformed:
        _say('주소를 http://127.0.0.1:8088 꼴로 적어 주세요.', warning: true);
      case EndpointProblem.notLocal:
        _say(
          '이 컴퓨터의 주소(127.0.0.1)만 쓸 수 있습니다. 붙여넣은 글이 다른 기기로 '
          '나가지 않게 하려는 것입니다.',
          warning: true,
        );
      case null:
        break;
    }
    return parsed.uri;
  }

  Future<void> _save() async {
    final uri = _read();
    if (uri == null) return;
    await ref.read(modelEndpointProvider.notifier).save(uri);
    if (!mounted) return;
    _controller.text = uri.toString();
    _say('저장했습니다. 이제 이 서버로 읽습니다.');
  }

  Future<void> _check() async {
    final uri = _read();
    if (uri == null) return;
    setState(() => _checking = true);
    final result = await checkModelEndpoint(
      ref.read(modelHttpClientProvider),
      uri,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    if (!result.ok) {
      _say('연결하지 못했습니다. 서버가 켜져 있는지 확인해 주세요.', warning: true);
      return;
    }
    final name = result.modelName;
    // 저장해 둔 주소를 확인한 것이면 서버가 알려 준 모델 이름을 적어 둔다.
    if (name != null && ref.read(modelEndpointProvider)?.uri == uri) {
      await ref.read(modelEndpointProvider.notifier).rememberModel(name);
      if (!mounted) return;
    }
    _say(name == null ? '연결됐습니다.' : '연결됐습니다 · 모델: $name');
  }

  Future<void> _clear() async {
    await ref.read(modelEndpointProvider.notifier).clear();
    if (!mounted) return;
    _controller.clear();
    _say('주소를 지웠습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final saved = ref.watch(modelEndpointProvider);
    return SectionCard(
      key: const ValueKey('models-endpoint'),
      title: '로컬 엔진 주소(선택)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'llama.cpp의 llama-server처럼 이 컴퓨터에 직접 띄운 서버에 연결합니다. '
            '주소를 저장해 두면 내려받은 모델 대신 그 서버로 읽습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('model-endpoint-field'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '로컬 엔진 주소',
              hintText: 'http://127.0.0.1:8088',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonal(
                key: const ValueKey('model-endpoint-save'),
                onPressed: _save,
                child: const Text('저장'),
              ),
              OutlinedButton(
                key: const ValueKey('model-endpoint-check'),
                onPressed: _checking ? null : _check,
                child: Text(_checking ? '확인하는 중' : '연결 확인'),
              ),
              if (saved != null)
                TextButton(
                  key: const ValueKey('model-endpoint-clear'),
                  onPressed: _clear,
                  child: const Text('지우기'),
                ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              key: const ValueKey('model-endpoint-message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _warning ? tokens.warn : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
