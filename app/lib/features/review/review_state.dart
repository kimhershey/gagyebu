import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 검토함에 올라와 있는 초안 묶음(`docs/SPEC.md` 7.6).
class ReviewState {
  const ReviewState();
}

/// 검토 중인 묶음을 들고 있다. 검토하는 것이 없으면 null이다.
class ReviewSession extends Notifier<ReviewState?> {
  @override
  ReviewState? build() => null;
}

final reviewSessionProvider = NotifierProvider<ReviewSession, ReviewState?>(
  ReviewSession.new,
);

/// 검토 중인 묶음이 있는지. 뼈대가 검토함 칸을 보일지 정하는 데 쓴다.
final reviewActiveProvider = Provider<bool>(
  (ref) => ref.watch(reviewSessionProvider) != null,
);
