import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/input_interpreter.dart';
import '../../ai/llm/llm_engine.dart';
import '../../ai/llm/local_model_engine.dart';
import '../../ai/parsed_transaction.dart';
import '../../ai/query/query_intent.dart';
import '../../ai/text/paste_parser.dart';
import '../../app/providers.dart';
import '../../domain/enums.dart';
import '../review/review_state.dart';

/// 밖에서 입력창에 채워 넣을 글(공유로 받은 글 등). 입력창이 가져가면 비운다.
class IncomingText extends Notifier<String?> {
  @override
  String? build() => null;

  /// 입력창에 채울 글을 올려 둔다.
  void offer(String text) => state = text;

  /// 올려 둔 글을 가져가고 비운다.
  String? take() {
    final text = state;
    state = null;
    return text;
  }
}

final incomingTextProvider = NotifierProvider<IncomingText, String?>(
  IncomingText.new,
);

/// 입력창이 받는 글의 최대 길이(글자 수). 넘으면 알리고 자른다.
const composerMaxLength = 20000;

/// 입력창의 예시 문장.
const composerExample = '어제 점심 9천원';

/// 입력창 가까이에 보여 주는 안내.
enum ComposerNotice {
  /// 한 건도 읽지 못했다. 직접 입력을 권한다.
  unreadable,

  /// 거래가 아닌 안내문뿐이었다.
  notTransaction,

  /// 해석하다가 실패했다(모델 오류 등).
  failed,

  /// 붙여넣으려 했는데 클립보드에 글이 없다.
  emptyClipboard,

  /// 글이 너무 길어 잘랐다.
  truncated,
}

/// 입력창이 화면에 청하는 이동. 화면(`ComposerBar`)이 듣고 옮긴다.
///
/// 요청마다 새 객체를 만든다(`const`로 만들지 않는다). 같은 요청이 이어져도 듣는 쪽이
/// 새 요청으로 알아봐야 한다.
sealed class ComposerEvent {}

/// 조회로 보이는 문장이라 조회 화면으로 보낸다.
class ComposerQueryEvent extends ComposerEvent {
  ComposerQueryEvent(this.question);

  final String question;
}

/// 초안을 검토함에 넣었다. 좁은 창이면 검토함 화면을 연다.
class ComposerReviewEvent extends ComposerEvent {
  ComposerReviewEvent();
}

/// 입력창의 상태. 글 자체는 [ComposerController.text]에 있다.
class ComposerState {
  const ComposerState({
    this.busy = false,
    this.done = 0,
    this.total = 0,
    this.notice,
    this.event,
  });

  /// 해석하는 중인지.
  final bool busy;

  /// 모델이 읽고 있는 건의 차례(1부터). 모델을 부르기 전이면 0.
  final int done;

  /// 모델에 넘길 건수. 모델이 없으면 0.
  final int total;

  final ComposerNotice? notice;

  /// 가장 최근의 이동 요청. 새 요청마다 새 객체다.
  final ComposerEvent? event;
}

/// 입력창에서 누른 키를 먼저 받아 볼 곳. 명령 목록이 화살표와 Enter를 가져가는 데 쓴다.
/// 돌려준 값이 [KeyEventResult.ignored]가 아니면 입력창은 그 키를 처리하지 않는다.
class ComposerKeyInterceptor
    extends Notifier<KeyEventResult Function(KeyEvent event)?> {
  @override
  KeyEventResult Function(KeyEvent event)? build() => null;

  void set(KeyEventResult Function(KeyEvent event)? handler) => state = handler;
}

final composerKeyInterceptorProvider =
    NotifierProvider<
      ComposerKeyInterceptor,
      KeyEventResult Function(KeyEvent event)?
    >(ComposerKeyInterceptor.new);

/// 조회로 보이는 문장인지 가리는 함수. 기본은 [looksLikeQuery]이고 시험에서 덮어쓴다.
final composerQueryDetectorProvider = Provider<bool Function(String text)>(
  (ref) => looksLikeQuery,
);

/// 입력창의 글과 진행 상태(`docs/SPEC.md` 7.5).
///
/// 글 칸의 컨트롤러와 초점을 여기서 든다. 창 너비가 바뀌면 뼈대가 입력창을 다른 자리에
/// 새로 그리는데, 그때도 적던 글이 남아야 하고, 명령창 단축키나 홈의 "입력하기"처럼
/// 입력창 밖에서도 글을 채우고 초점을 줄 수 있어야 하기 때문이다.
class ComposerController extends Notifier<ComposerState> {
  /// 글 칸의 컨트롤러와 초점. 입력창이 어느 자리에 그려지든 같은 것을 쓴다.
  late TextEditingController text;
  late FocusNode focusNode;
  final _parser = PasteParser();

  /// 해석을 시작할 때마다 올린다. "그만"을 누르거나 새로 시작하면 앞선 해석의 결과를 버린다.
  int _run = 0;

  /// 밖에서 채워 넣은 글의 출처(공유). 사용자가 보내면 그 출처로 적는다.
  TxSource? _filledSource;

  /// 안내를 띄웠을 때의 글. 글이 달라지면 안내를 거둔다.
  String? _noticeText;

  @override
  ComposerState build() {
    final controller = TextEditingController()..addListener(_onTextChanged);
    final node = FocusNode(debugLabel: 'composer', onKeyEvent: _onKey);
    text = controller;
    focusNode = node;
    ref.onDispose(() {
      // 하던 해석이 있으면 그 결과를 버리게 한다.
      _run++;
      controller.dispose();
      node.dispose();
    });
    return const ComposerState();
  }

  void _onTextChanged() {
    if (text.text.isEmpty) _filledSource = null;
    if (state.notice != null && text.text != _noticeText) {
      state = ComposerState(
        busy: state.busy,
        done: state.done,
        total: state.total,
        event: state.event,
      );
    }
  }

  void _notify(ComposerNotice notice) {
    _noticeText = text.text;
    state = ComposerState(notice: notice, event: state.event);
  }

  /// 안내를 거둔다.
  void dismissNotice() {
    if (state.notice == null) return;
    state = ComposerState(
      busy: state.busy,
      done: state.done,
      total: state.total,
      event: state.event,
    );
  }

  /// PC의 Enter는 보내기, Shift+Enter는 줄바꿈이다.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final intercepted = ref.read(composerKeyInterceptorProvider)?.call(event);
    if (intercepted != null && intercepted != KeyEventResult.ignored) {
      return intercepted;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    // Shift+Enter는 줄바꿈, Ctrl/⌘+Enter는 검토함의 "모두 승인하고 저장"이 쓴다.
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // 한글을 조합하는 중의 Enter는 글자를 확정하는 키다. 보내지 않는다.
    if (text.value.composing.isValid) return KeyEventResult.ignored;
    // '>'로 시작하면 명령만 찾는 글이다. 거래로 해석하지 않는다.
    if (text.text.trimLeft().startsWith('>')) return KeyEventResult.handled;
    submit(fromKeyboard: true);
    return KeyEventResult.handled;
  }

  /// 글 칸에 초점을 준다.
  void requestFocus() => focusNode.requestFocus();

  /// 글을 채우고 초점을 준다. 보내는 것은 사용자가 한다.
  ///
  /// [source]는 공유로 받은 글처럼 출처를 따로 적어야 할 때 넘긴다.
  void fill(String value, {TxSource? source}) {
    final clipped = clipToMaxLength(value);
    text.value = TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
    _filledSource = source;
    if (clipped.length != value.length) _notify(ComposerNotice.truncated);
    requestFocus();
  }

  /// 글을 지운다.
  void clear() {
    text.clear();
    _filledSource = null;
  }

  /// 클립보드의 글을 채운다. 글이 없으면 그렇게 알린다.
  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text ?? '';
    if (value.trim().isEmpty) {
      _notify(ComposerNotice.emptyClipboard);
      return;
    }
    fill(value);
  }

  /// 글 칸의 길이 제한에 걸려 잘랐을 때 글 칸이 부른다.
  void noteTruncated(String clipped) {
    _noticeText = clipped;
    state = ComposerState(
      busy: state.busy,
      done: state.done,
      total: state.total,
      notice: ComposerNotice.truncated,
      event: state.event,
    );
  }

  /// 하던 해석을 그만둔다. 글은 그대로 남는다.
  void stop() {
    if (!state.busy) return;
    _run++;
    // 기기 안의 모델은 생성까지 멈춘다. 멈춘 요청은 예외로 끝나고, 아래 submit()이
    // 차례 번호가 바뀐 것을 보고 조용히 넘어간다.
    final Object? engine = ref.read(llmEngineProvider);
    if (engine is CancellableEngine) engine.cancelAll();
    state = ComposerState(event: state.event);
  }

  /// 글을 보낸다: 조회로 보이면 조회 화면으로, 아니면 해석해서 검토함에 넣는다.
  ///
  /// [fromKeyboard]는 Enter 키로 보냈을 때 true다. 한글을 조합하는 중이면 보내지 않는다.
  /// 보내기 단추는 조합 중이어도 보낸다(휴대폰의 한글 자판은 마지막 글자를 조합 상태로
  /// 둔 채 단추를 누르게 된다).
  Future<void> submit({bool fromKeyboard = false}) async {
    if (state.busy) return;
    if (fromKeyboard && text.value.composing.isValid) return;
    final input = text.text.trim();
    if (input.isEmpty) {
      requestFocus();
      return;
    }

    if (ref.read(composerQueryDetectorProvider)(input)) {
      clear();
      state = ComposerState(event: ComposerQueryEvent(input));
      return;
    }

    final run = ++_run;
    final shared = _filledSource;
    state = ComposerState(busy: true, event: state.event);
    try {
      final repository = ref.read(repositoryProvider);
      final ledgerId = ref.read(ledgerIdProvider);
      final today = ref.read(todayProvider);
      final categories = await repository.categories(ledgerId);
      if (run != _run) return;

      // 모델이 있으면 규칙이 못 읽은 덩어리만 모델로 간다. 그 수가 진행 표시의 분모다.
      final engine = ref.read(llmEngineProvider);
      LlmEngine? counting;
      if (engine != null) {
        final total = _parser
            .parse(input, today: today)
            .whereType<UnrecognizedItem>()
            .length;
        var started = 0;
        counting = _WatchedEngine(
          engine,
          onStart: () {
            if (run != _run) throw const _Stopped();
            started++;
            state = ComposerState(
              busy: true,
              // 답이 틀려 다시 묻는 경우가 있어 건수를 넘지 않게 한다.
              done: math.min(started, math.max(total, 1)),
              total: math.max(total, 1),
              event: state.event,
            );
          },
        );
      }

      final interpreted = await interpretInput(
        input,
        today: today,
        engine: counting,
        parser: _parser,
        expenseCategories: [
          for (final c in categories)
            if (c.kind == CategoryKind.expense) c.name,
        ],
        incomeCategories: [
          for (final c in categories)
            if (c.kind == CategoryKind.income) c.name,
        ],
      );
      if (run != _run) return;

      final items = interpreted.items;
      final transactions = interpreted.transactions.toList();
      if (transactions.isEmpty) {
        // 한 건도 못 읽었다. 글은 남겨 두어 고쳐서 다시 보낼 수 있게 한다.
        final onlyNotices =
            items.isNotEmpty && items.every((i) => i is NonTransactionItem);
        _noticeText = text.text;
        state = ComposerState(
          notice: onlyNotices
              ? ComposerNotice.notTransaction
              // 모델이 답을 내지 못해 비었으면 글 탓이 아니다. 다시 해 보라고 알린다.
              : interpreted.engineFailed
              ? ComposerNotice.failed
              : ComposerNotice.unreadable,
          event: state.event,
        );
        return;
      }

      await ref
          .read(reviewSessionProvider.notifier)
          .open(
            transactions: transactions,
            notices: items.whereType<NonTransactionItem>(),
            unknown: items.whereType<UnrecognizedItem>(),
            source:
                shared ??
                (interpreted.fromSentence ? TxSource.nl : TxSource.paste),
          );
      if (!ref.mounted) return;
      clear();
      state = ComposerState(event: ComposerReviewEvent());
    } on _Stopped {
      // "그만"을 눌렀다. 상태는 stop()이 이미 되돌렸다.
    } catch (_) {
      if (run != _run) return;
      _noticeText = text.text;
      state = ComposerState(notice: ComposerNotice.failed, event: state.event);
    }
  }
}

final composerControllerProvider =
    NotifierProvider<ComposerController, ComposerState>(ComposerController.new);

/// [value]가 [composerMaxLength]자를 넘으면 잘라 준다. 글자(이모지, 조합 글자)의 중간에서
/// 자르지 않는다.
String clipToMaxLength(String value) {
  // 코드 단위 수가 글자 수보다 적을 수는 없으므로 대부분은 여기서 끝난다.
  if (value.length <= composerMaxLength) return value;
  final characters = value.characters;
  if (characters.length <= composerMaxLength) return value;
  return characters.take(composerMaxLength).toString();
}

/// 입력창에 초점을 준다. [text]가 있으면 그 글을 채운다.
///
/// 상태 제공자를 읽을 `ref`가 없는 곳(뼈대의 함수, 대화상자)에서 쓴다.
void focusComposer(BuildContext context, {String? text}) {
  final controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(composerControllerProvider.notifier);
  if (text != null && text.trim().isNotEmpty) {
    controller.fill(text);
  } else {
    controller.requestFocus();
  }
}

/// "그만"을 누른 뒤에 모델을 더 부르지 않게 끊는 데 쓴다.
class _Stopped implements Exception {
  const _Stopped();
}

/// 모델을 부를 때마다 알려 주는 껍데기. 진행 표시와 "그만"에 쓴다.
class _WatchedEngine implements LlmEngine {
  _WatchedEngine(this._inner, {required this.onStart});

  final LlmEngine _inner;
  final void Function() onStart;

  @override
  String get modelName => _inner.modelName;

  @override
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  }) {
    onStart();
    return _inner.generateJson(
      system: system,
      user: user,
      schema: schema,
      grammar: grammar,
      maxTokens: maxTokens,
    );
  }
}
