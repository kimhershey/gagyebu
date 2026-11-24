import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:gagyebu/ai/vision/vision_engine.dart';
import 'package:gagyebu/features/image_input/image_intake.dart';

/// 1×1 PNG. 화면이 이미지로 알아보고 그릴 수 있는 가장 작은 원본이다.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

PickedImage picked(String name) => PickedImage(name: name, bytes: tinyPng);

/// 정해 둔 답을 차례로 돌려주는 가짜 이미지 모델.
class FakeVisionEngine implements VisionEngine {
  FakeVisionEngine(this.answers);

  final List<Object> answers;
  final List<Uint8List> images = [];

  int get calls => images.length;

  @override
  String get modelName => 'fake-vlm';

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) async {
    images.add(image);
    final answer = answers[images.length - 1];
    return answer is String ? answer : jsonEncode(answer);
  }
}

/// 시험이 놓아줄 때까지 답하지 않는 가짜 이미지 모델. 대기열과 "그만"을 보는 데 쓴다.
class HeldVisionEngine implements VisionEngine {
  final List<Completer<String>> calls = [];

  @override
  String get modelName => 'held-vlm';

  @override
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  }) {
    final call = Completer<String>();
    calls.add(call);
    return call.future;
  }
}

/// 파일 고르기와 클립보드를 흉내 낸다.
class FakeImageIntake implements ImageIntake {
  FakeImageIntake({
    this.files = const [],
    this.clipboard,
    this.canReadClipboard = true,
  });

  List<PickedImage> files;
  PickedImage? clipboard;

  @override
  bool canReadClipboard;

  @override
  Future<List<PickedImage>> pickFiles() async => files;

  @override
  Future<PickedImage?> readClipboard() async => clipboard;
}

Map<String, Object?> visionRow({
  String? d = '11.15',
  String? t,
  String? a = '10,000',
  String? io = 'out',
  String? who = '한빛서점',
  String? bal,
}) => {'d': d, 't': t, 'a': a, 'io': io, 'who': who, 'bal': bal};

Map<String, Object?> statementAnswer(List<Map<String, Object?>> rows) => {
  'kind': 'statement',
  'shop': null,
  'rows': rows,
  'total': null,
};

Map<String, Object?> receiptAnswer(
  List<Map<String, Object?>> rows, {
  String? shop = '새봄커피',
  String? total,
}) => {'kind': 'receipt', 'shop': shop, 'rows': rows, 'total': total};

/// 잔액이 이어지는 거래내역 화면(최근이 위).
final consistentStatement = statementAnswer([
  visionRow(t: '19:20', a: '-15,000', who: '한빛서점', bal: '985,000'),
  visionRow(t: '09:00', a: '+500,000', io: 'in', who: '김한빛', bal: '1,000,000'),
  visionRow(d: '11.14', a: '8,000', who: '새봄분식', bal: '500,000'),
]);

/// 가운데 줄의 금액을 잘못 읽은 거래내역 화면.
final brokenStatement = statementAnswer([
  visionRow(a: '15,000', who: '한빛서점', bal: '985,000'),
  visionRow(a: '600,000', io: 'in', who: '김한빛', bal: '1,000,000'),
  visionRow(d: '11.14', a: '8,000', who: '새봄분식', bal: '500,000'),
  visionRow(d: '11.14', a: '2,000', who: '새봄문구', bal: '508,000'),
]);

/// 품목의 합(9,500)이 총액(8,500)과 다른 영수증.
final mismatchedReceipt = receiptAnswer([
  visionRow(d: '2026-11-15', t: '13:05', a: '4,500', who: '아메리카노'),
  visionRow(d: null, a: '5,000', who: '카페라떼'),
], total: '8,500');
