import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/parsed_transaction.dart';
import '../../app/providers.dart';
import '../../core/local_date.dart';
import '../../data/repositories/input_batch_repository.dart';
import '../../domain/enums.dart';
import 'review_draft.dart';

export 'review_draft.dart' show ReviewDraft;

const _keep = Object();

/// 검토함에 올라와 있는 초안 묶음(`docs/SPEC.md` 7.6).
class ReviewState {
  const ReviewState({
    this.drafts = const [],
    this.notices = const [],
    this.unknown = const [],
    this.expanded,
    this.focused = 0,
    this.saving = false,
    this.saveFailed = false,
  });

  /// 거래로 읽은 건. 건마다 포함 여부와 고친 값을 든다.
  final List<ReviewDraft> drafts;

  /// 거래가 아닌 안내문. 저장하지 않는다.
  final List<NonTransactionItem> notices;

  /// 읽지 못한 글. 직접 입력으로 넘길 수 있다.
  final List<UnrecognizedItem> unknown;

  /// 편집 칸을 펼친 건. 없으면 null.
  final int? expanded;

  /// 키보드로 고른 건.
  final int focused;

  /// 저장하는 중인지.
  final bool saving;

  /// 방금 저장에 실패했는지. 검토함이 저장 단추 위에 알린다. 무엇이든 바꾸면 풀린다.
  final bool saveFailed;

  /// 저장될 건수.
  int get savableCount => drafts.where((d) => d.canSave).length;

  /// 포함했지만 채울 것이 남은 건수. 하나라도 있으면 저장하지 않는다(조용히 빠뜨리지 않게).
  int get blockedCount => drafts.where((d) => d.blocksSave).length;

  /// 포함한 건 가운데 '확인 필요'가 남은 건수.
  int get needsReviewCount =>
      drafts.where((d) => d.include && d.needsReview).length;

  bool get canSave => !saving && savableCount > 0 && blockedCount == 0;

  /// 맨 위의 한 줄 요약: "6건 읽음 · 1건 확인 필요 · 안내문 2건 제외".
  String get summary => [
    '${drafts.length}건 읽음',
    if (needsReviewCount > 0) '$needsReviewCount건 확인 필요',
    if (notices.isNotEmpty) '안내문 ${notices.length}건 제외',
    if (unknown.isNotEmpty) '읽지 못함 ${unknown.length}건',
  ].join(' · ');

  ReviewState copyWith({
    List<ReviewDraft>? drafts,
    List<UnrecognizedItem>? unknown,
    Object? expanded = _keep,
    int? focused,
    bool? saving,
    bool saveFailed = false,
  }) => ReviewState(
    drafts: drafts ?? this.drafts,
    notices: notices,
    unknown: unknown ?? this.unknown,
    expanded: identical(expanded, _keep) ? this.expanded : expanded as int?,
    focused: focused ?? this.focused,
    saving: saving ?? this.saving,
    saveFailed: saveFailed,
  );
}

/// 저장한 결과. 화면이 달을 옮기고 "되돌리기" 알림을 띄우는 데 쓴다.
class SavedReview {
  const SavedReview({
    required this.batchId,
    required this.count,
    required this.firstDate,
  });

  final String batchId;
  final int count;

  /// 저장한 첫 건의 날짜.
  final LocalDate firstDate;
}

/// 검토 중인 묶음을 들고 있다. 검토하는 것이 없으면 null이다.
///
/// 입력창, 이미지 입력, 가져오기가 [open]으로 초안을 올린다. 검토함 화면은 이 상태만
/// 그리므로 창 크기에 따라 자리가 바뀌어도(옆 칸 ↔ 전체 화면) 내용이 남는다.
class ReviewSession extends Notifier<ReviewState?> {
  @override
  ReviewState? build() => null;

  /// 해석한 초안을 검토함에 올린다. 이미 검토 중이면 뒤에 덧붙인다(검토하던 것을 말없이
  /// 버리지 않는다).
  ///
  /// 초안마다 자산을 맞추고 분류를 짐작하고 중복 · 취소 대상을 찾는다([buildReviewDraft]).
  Future<void> open({
    required Iterable<ParsedTransaction> transactions,
    required TxSource source,
    Iterable<NonTransactionItem> notices = const [],
    Iterable<UnrecognizedItem> unknown = const [],
  }) async {
    final repository = ref.read(repositoryProvider);
    final ledgerId = ref.read(ledgerIdProvider);
    final today = ref.read(todayProvider);
    final accounts = await repository.accounts(ledgerId);
    final categories = await repository.categories(ledgerId);
    final profile = await repository.profile(ledgerId);

    final added = <ReviewDraft>[];
    for (final parsed in transactions) {
      added.add(
        await buildReviewDraft(
          repository: repository,
          ledgerId: ledgerId,
          parsed: parsed,
          source: source,
          accounts: accounts,
          categories: categories,
          defaultAccountId: profile?.defaultAccountId,
          today: today,
        ),
      );
    }

    // 초안을 만드는 사이에 앱이 다시 열렸으면(가계부가 바뀌었으면) 올리지 않는다.
    if (!ref.mounted) return;
    final current = state;
    final drafts = [...?current?.drafts];
    for (final draft in added) {
      // 같은 글을 두 번 붙여넣은 경우: 앞선 건과 같으면 뒤의 것을 기본 제외로 둔다.
      final key = draft.dedupKey;
      final repeated =
          key != null &&
          !draft.parsed.isCancel &&
          drafts.any((d) => !d.parsed.isCancel && d.dedupKey == key);
      drafts.add(
        repeated
            ? draft.copyWith(duplicates: draft.duplicates + 1, include: false)
            : draft,
      );
    }
    final allNotices = [...?current?.notices, ...notices];
    final allUnknown = [...?current?.unknown, ...unknown];
    if (drafts.isEmpty && allNotices.isEmpty && allUnknown.isEmpty) return;
    state = ReviewState(
      drafts: drafts,
      notices: allNotices,
      unknown: allUnknown,
      // 한 건뿐이면 고칠 칸을 바로 보여 준다.
      expanded: drafts.length == 1 ? 0 : current?.expanded,
      focused: current?.focused ?? 0,
    );
  }

  /// [index]번째 건을 고친다. 고친 건은 '확인 필요' 표시가 풀린다.
  void edit(int index, ReviewDraft Function(ReviewDraft draft) change) {
    final current = state;
    if (current == null || index < 0 || index >= current.drafts.length) return;
    final drafts = [...current.drafts];
    drafts[index] = change(drafts[index]).copyWith(edited: true);
    state = current.copyWith(drafts: drafts);
  }

  /// 고치지 않고 그대로 맞다고 확인한다. '확인 필요' 표시만 푼다.
  void confirm(int index) => edit(index, (d) => d);

  /// 포함 · 제외를 정한다.
  void setInclude(int index, bool include) {
    final current = state;
    if (current == null || index < 0 || index >= current.drafts.length) return;
    final drafts = [...current.drafts];
    drafts[index] = drafts[index].copyWith(include: include);
    state = current.copyWith(drafts: drafts);
  }

  void toggleInclude(int index) {
    final drafts = state?.drafts;
    if (drafts == null || index < 0 || index >= drafts.length) return;
    setInclude(index, !drafts[index].include);
  }

  /// 편집 칸을 펼치거나 접는다. 한 번에 한 건만 펼친다.
  void toggleExpanded(int index) {
    final current = state;
    if (current == null || index < 0 || index >= current.drafts.length) return;
    state = current.copyWith(
      expanded: current.expanded == index ? null : index,
      focused: index,
    );
  }

  /// 키보드로 고른 건을 [delta]만큼 옮긴다.
  void moveFocus(int delta) {
    final current = state;
    if (current == null || current.drafts.isEmpty) return;
    final next = (current.focused + delta).clamp(0, current.drafts.length - 1);
    state = current.copyWith(focused: next);
  }

  void setFocused(int index) {
    final current = state;
    if (current == null || index < 0 || index >= current.drafts.length) return;
    if (current.focused != index) state = current.copyWith(focused: index);
  }

  /// 읽지 못한 글을 목록에서 뺀다(직접 입력으로 넘긴 뒤).
  void dropUnknown(int index) {
    final current = state;
    if (current == null || index < 0 || index >= current.unknown.length) return;
    final unknown = [...current.unknown]..removeAt(index);
    if (current.drafts.isEmpty && current.notices.isEmpty && unknown.isEmpty) {
      state = null;
    } else {
      state = current.copyWith(unknown: unknown);
    }
  }

  /// 포함한 건을 한 트랜잭션으로 저장하고 검토를 끝낸다.
  ///
  /// 저장할 것이 없거나 채울 것이 남은 건이 있으면 아무것도 하지 않고 null을 준다.
  /// 저장에 실패하면 한 건도 저장되지 않고 검토 중인 내용이 그대로 남는다(예외를 다시 던진다).
  Future<SavedReview?> saveAll() async {
    final current = state;
    if (current == null || !current.canSave) return null;
    final included = [
      for (final d in current.drafts)
        if (d.canSave) d,
    ];
    state = current.copyWith(saving: true);
    try {
      final saved = await ref.read(inputBatchRepositoryProvider).saveBatch(
        ref.read(ledgerIdProvider),
        [for (final d in included) d.toEntry()],
        source: included.first.source,
      );
      if (ref.mounted) state = null;
      return SavedReview(
        batchId: saved.batchId,
        count: saved.itemCount,
        firstDate: included.first.date,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state?.copyWith(saving: false, saveFailed: true);
      }
      rethrow;
    }
  }

  /// 검토하던 것을 버린다.
  void discard() => state = null;
}

final reviewSessionProvider = NotifierProvider<ReviewSession, ReviewState?>(
  ReviewSession.new,
);

/// 검토 중인 묶음이 있는지. 뼈대가 검토함 칸을 보일지 정하는 데 쓴다.
final reviewActiveProvider = Provider<bool>(
  (ref) => ref.watch(reviewSessionProvider) != null,
);
