import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/parsed_transaction.dart';
import '../../ai/vision/vision_rows.dart';
import '../../ai/vision/vision_text_parser.dart';
import '../../app/providers.dart';
import '../../domain/enums.dart';
import '../review/review_state.dart';
import 'dib.dart';
import 'image_intake.dart';

/// 이미지 한 장의 크기 한도. 휴대폰으로 찍은 영수증 사진(수 MB)은 넉넉히 들어간다.
const maxImageBytes = 20 * 1024 * 1024;

/// 대기열에 쌓을 수 있는 장수. 이미지를 메모리에 들고 있으므로 끝없이 받지 않는다.
const maxQueuedImages = 20;

/// 대기열에 있는 한 장의 상태.
enum PageStatus {
  /// 차례를 기다린다.
  waiting,

  /// 모델이 읽고 있다.
  reading,

  /// 다 읽었다. 거래를 찾지 못했을 수도 있다.
  done,

  /// 읽지 못했다.
  failed,
}

const _keep = Object();

/// 대기열의 한 장: 원본과, 읽어 낸 줄과, 사용자가 줄마다 정한 것.
class ImagePage {
  ImagePage({
    required this.id,
    required this.name,
    required this.bytes,
    this.status = PageStatus.waiting,
    this.extraction,
    this.modelName,
    this.excluded = const {},
    this.confirmed = const {},
  }) : checks = extraction?.verify() ?? const [];

  final int id;
  final String name;

  /// 원본. 메모리에만 있고 화면을 떠나면 버려진다.
  final Uint8List bytes;
  final PageStatus status;

  /// 읽어 낸 것. 화면에서 고친 값이 덮여 있다.
  final VisionExtraction? extraction;

  /// 이 장을 읽은 모델.
  final String? modelName;

  /// 사용자가 뺀 줄.
  final Set<int> excluded;

  /// 검산은 맞지 않지만 사용자가 원본과 견주어 맞다고 한 줄.
  final Set<int> confirmed;

  /// 줄마다의 검산 결과. 줄을 고칠 때마다 다시 셈한다.
  final List<VisionCheck> checks;

  List<VisionRow> get rows => extraction?.rows ?? const [];

  bool isIncluded(int index) => !excluded.contains(index);

  /// [index]번째 줄에 아직 풀리지 않은 "확인 필요"의 까닭.
  Set<VisionIssue> issuesOf(int index) {
    final issues = checks[index].issues;
    if (!confirmed.contains(index)) return issues;
    // 금액이 없는 줄은 맞다고 해도 저장할 수 없다. 채워야 풀린다.
    return issues.intersection(const {VisionIssue.amountMissing});
  }

  /// 포함한 줄 수.
  int get includedCount => rows.length - excluded.length;

  /// 포함했는데 "확인 필요"가 남은 줄 수.
  int get pendingCount {
    var count = 0;
    for (var i = 0; i < rows.length; i++) {
      if (isIncluded(i) && issuesOf(i).isNotEmpty) count++;
    }
    return count;
  }

  ImagePage copyWith({
    PageStatus? status,
    Object? extraction = _keep,
    Object? modelName = _keep,
    Set<int>? excluded,
    Set<int>? confirmed,
  }) => ImagePage(
    id: id,
    name: name,
    bytes: bytes,
    status: status ?? this.status,
    extraction: identical(extraction, _keep)
        ? this.extraction
        : extraction as VisionExtraction?,
    modelName: identical(modelName, _keep)
        ? this.modelName
        : modelName as String?,
    excluded: excluded ?? this.excluded,
    confirmed: confirmed ?? this.confirmed,
  );
}

/// 이미지 입력 화면의 상태.
class ImageInputState {
  const ImageInputState({
    this.pages = const [],
    this.selectedId,
    this.paused = false,
    this.sending = false,
    this.notice,
  });

  /// 대기열. 넣은 순서대로 한 장씩 읽는다.
  final List<ImagePage> pages;

  /// 화면에 펼쳐 보는 장.
  final int? selectedId;

  /// "그만"을 눌러 읽기를 멈췄는지.
  final bool paused;

  /// 검토함으로 보내는 중인지.
  final bool sending;

  /// 이미지를 넣다가 생긴 일의 알림(넣지 못한 파일 등). 다음에 이미지를 넣을 때 바뀐다.
  final String? notice;

  ImagePage? get selected {
    for (final page in pages) {
      if (page.id == selectedId) return page;
    }
    return null;
  }

  Iterable<ImagePage> get _read =>
      pages.where((p) => p.status == PageStatus.done);

  /// 검토함으로 보낼 줄 수.
  int get includedCount => _read.fold(0, (sum, p) => sum + p.includedCount);

  /// 포함한 줄 가운데 "확인 필요"가 남은 줄 수. 남아 있으면 보내지 않는다.
  int get pendingCount => _read.fold(0, (sum, p) => sum + p.pendingCount);

  /// 아직 읽지 않은 장수.
  int get unreadCount => pages
      .where(
        (p) => p.status == PageStatus.waiting || p.status == PageStatus.reading,
      )
      .length;

  bool get reading => pages.any((p) => p.status == PageStatus.reading);

  /// 읽기가 끝났거나 멈췄고, 보낼 줄이 있고, 확인할 줄이 남지 않았을 때 보낼 수 있다.
  bool get canSend =>
      !sending &&
      includedCount > 0 &&
      pendingCount == 0 &&
      (unreadCount == 0 || paused);

  ImageInputState copyWith({
    List<ImagePage>? pages,
    Object? selectedId = _keep,
    bool? paused,
    bool? sending,
    Object? notice = _keep,
  }) => ImageInputState(
    pages: pages ?? this.pages,
    selectedId: identical(selectedId, _keep)
        ? this.selectedId
        : selectedId as int?,
    paused: paused ?? this.paused,
    sending: sending ?? this.sending,
    notice: identical(notice, _keep) ? this.notice : notice as String?,
  );
}

/// 이미지 대기열을 한 장씩 읽고, 읽은 줄의 포함 · 고친 값을 들고 있다.
///
/// 화면이 닫히면 이 상태도 함께 버려진다(autoDispose). 이미지는 여기에만 있으므로 그때
/// 메모리에서 사라진다(`docs/SPEC.md` 1.2).
class ImageInputController extends Notifier<ImageInputState> {
  int _nextId = 0;

  /// 엔진이 지금 읽고 있는 장. 엔진은 도중에 멈출 수 없어서 "그만"을 눌러도 끝까지 읽는다.
  /// 그 답은 버리고, 다 읽은 뒤에야 다음 장을 넘긴다(한 번에 한 장만 읽게 한다).
  int? _flightId;
  bool _pumping = false;

  @override
  ImageInputState build() => const ImageInputState();

  /// 이미지를 대기열 끝에 넣고 읽기 시작한다. 이미지가 아닌 것과 너무 큰 것은 넣지 않는다.
  void add(Iterable<PickedImage> images) {
    final pages = [...state.pages];
    var notImage = 0;
    var tooLarge = 0;
    var overflow = 0;
    int? firstAdded;
    for (final image in images) {
      if (sniffImageFormat(image.bytes) == null) {
        notImage++;
      } else if (image.bytes.length > maxImageBytes) {
        tooLarge++;
      } else if (pages.length >= maxQueuedImages) {
        overflow++;
      } else {
        final id = _nextId++;
        firstAdded ??= id;
        pages.add(ImagePage(id: id, name: image.name, bytes: image.bytes));
      }
    }
    final problems = [
      if (notImage > 0) '이미지가 아닌 파일 $notImage개는 넣지 않았습니다.',
      if (tooLarge > 0) '20MB를 넘는 이미지 $tooLarge장은 넣지 않았습니다.',
      if (overflow > 0) '한 번에 $maxQueuedImages장까지 읽습니다. $overflow장은 넣지 않았습니다.',
    ];
    state = state.copyWith(
      pages: pages,
      selectedId: state.selected == null ? firstAdded : state.selectedId,
      // 새로 넣었으면 다시 읽기 시작한다.
      paused: firstAdded == null ? state.paused : false,
      notice: problems.isEmpty ? null : problems.join(' '),
    );
    _continue();
  }

  /// 화면이 알릴 말을 남긴다(클립보드에 이미지가 없을 때 등).
  void notify(String message) => state = state.copyWith(notice: message);

  void select(int id) => state = state.copyWith(selectedId: id);

  /// 읽기를 멈춘다. 읽던 장은 기다림으로 돌아가고, 늦게 오는 답은 버린다.
  void stop() {
    state = state.copyWith(
      paused: true,
      pages: [
        for (final p in state.pages)
          p.status == PageStatus.reading
              ? p.copyWith(status: PageStatus.waiting)
              : p,
      ],
    );
  }

  /// 멈춘 읽기를 이어 간다.
  void resume() {
    state = state.copyWith(paused: false);
    _continue();
  }

  /// 읽지 못했거나 잘못 읽은 장을 다시 읽는다. 고쳐 둔 값은 버린다.
  void retry(int id) {
    final page = _page(id);
    if (page == null || page.status == PageStatus.reading) return;
    _replace(
      id,
      (p) => ImagePage(id: p.id, name: p.name, bytes: p.bytes),
      paused: false,
    );
    _continue();
  }

  /// 대기열에서 뺀다. 이미지도 함께 버린다.
  void remove(int id) {
    final index = state.pages.indexWhere((p) => p.id == id);
    if (index < 0) return;
    final pages = [...state.pages]..removeAt(index);
    state = state.copyWith(
      pages: pages,
      selectedId: state.selectedId != id
          ? state.selectedId
          : (pages.isEmpty ? null : pages[index.clamp(0, pages.length - 1)].id),
      paused: pages.isEmpty ? false : state.paused,
    );
    _pump();
  }

  /// 줄을 포함하거나 뺀다.
  void setIncluded(int pageId, int index, bool include) => _replace(
    pageId,
    (p) => p.copyWith(
      excluded: include
          ? p.excluded.difference({index})
          : {...p.excluded, index},
    ),
  );

  /// 줄의 값을 고친다. 검산을 다시 하고, 맞다고 해 둔 표시는 푼다(값이 달라졌다).
  void editRow(
    int pageId,
    int index,
    VisionRow Function(VisionRow row) change,
  ) {
    _replace(pageId, (p) {
      final extraction = p.extraction;
      if (extraction == null || index < 0 || index >= p.rows.length) return p;
      return p.copyWith(
        extraction: extraction.withRow(index, change(p.rows[index])),
        confirmed: p.confirmed.difference({index}),
      );
    });
  }

  /// 원본과 견주어 맞다고 확인한다. "확인 필요" 표시를 푼다.
  void confirmRow(int pageId, int index) =>
      _replace(pageId, (p) => p.copyWith(confirmed: {...p.confirmed, index}));

  /// 포함한 줄을 검토함에 올린다. 올린 건수를 돌려준다.
  ///
  /// 자산 매칭 · 분류 짐작 · 중복 확인은 검토함이 한다. 올리지 못하면 예외를 다시 던지고
  /// 읽은 내용은 그대로 둔다.
  Future<int> send() async {
    if (!state.canSend) return 0;
    final transactions = <ParsedTransaction>[
      for (final page in state.pages)
        if (page.status == PageStatus.done)
          ...page.extraction!.toTransactions(
            modelName: page.modelName ?? '',
            only: {
              for (var i = 0; i < page.rows.length; i++)
                if (page.isIncluded(i)) i,
            },
          ),
    ];
    state = state.copyWith(sending: true);
    try {
      await ref
          .read(reviewSessionProvider.notifier)
          .open(transactions: transactions, source: TxSource.image);
    } finally {
      if (ref.mounted) state = state.copyWith(sending: false);
    }
    return transactions.length;
  }

  ImagePage? _page(int id) {
    for (final page in state.pages) {
      if (page.id == id) return page;
    }
    return null;
  }

  void _replace(
    int id,
    ImagePage Function(ImagePage page) change, {
    bool? paused,
  }) {
    state = state.copyWith(
      pages: [for (final p in state.pages) p.id == id ? change(p) : p],
      paused: paused,
    );
  }

  /// 멈췄던 읽기를 잇는다.
  void _continue() {
    // 그만둔 장을 엔진이 아직 읽고 있으면 새로 시키지 않고 그 답을 받는다.
    final flight = _flightId;
    if (!state.paused &&
        flight != null &&
        _page(flight)?.status == PageStatus.waiting) {
      _replace(flight, (p) => p.copyWith(status: PageStatus.reading));
    }
    _pump();
  }

  /// 기다리는 장을 차례로 읽는다. 한 번에 한 장만 엔진에 넘긴다.
  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (ref.mounted && !state.paused) {
        final engine = ref.read(visionEngineProvider);
        final next = state.pages
            .where((p) => p.status == PageStatus.waiting)
            .firstOrNull;
        if (engine == null || next == null) return;

        _replace(next.id, (p) => p.copyWith(status: PageStatus.reading));
        _flightId = next.id;
        VisionParseResult? result;
        try {
          result = await VisionTextParser(engine)
              .parse(next.bytes, today: ref.read(todayProvider));
        } catch (_) {
          // 엔진이 실패했다(메모리 부족, 모델 파일 손상 등). 읽지 못함으로 둔다.
          result = null;
        }
        _flightId = null;
        if (!ref.mounted) return;
        // 읽는 사이에 "그만"을 눌렀거나 이 장을 지웠으면 답을 버린다.
        if (_page(next.id)?.status != PageStatus.reading) continue;

        final extraction = result?.extraction;
        _replace(
          next.id,
          (p) => extraction == null
              ? p.copyWith(status: PageStatus.failed)
              : p.copyWith(
                  status: PageStatus.done,
                  extraction: extraction,
                  modelName: result!.modelName,
                ),
        );
      }
    } finally {
      _pumping = false;
    }
  }
}

final imageInputControllerProvider =
    NotifierProvider.autoDispose<ImageInputController, ImageInputState>(
      ImageInputController.new,
    );
