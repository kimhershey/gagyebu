/// SQLite 값과 Dart 값 사이의 변환기.
///
/// 날짜와 시각은 글자로 저장한다. 서버(PostgreSQL)와 주고받는 JSON 표현과 같아서
/// 동기화할 때 값이 달라지지 않는다.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/local_date.dart';
import '../../domain/enums.dart';

/// 시각 ↔ ISO 8601(UTC) 문자열.
class UtcDateTimeConverter extends TypeConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb).toUtc();

  @override
  String toSql(DateTime value) => value.toUtc().toIso8601String();
}

/// 날짜 ↔ 'YYYY-MM-DD'. 글자 순서가 날짜 순서와 같아 범위 조회에 그대로 쓴다.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toString();
}

/// 문자열 목록 ↔ JSON 배열.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// JSON 객체 ↔ 문자열.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map).cast<String, Object?>();

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}

class TxTypeConverter extends TypeConverter<TxType, String> {
  const TxTypeConverter();

  @override
  TxType fromSql(String fromDb) => TxType.fromCode(fromDb);

  @override
  String toSql(TxType value) => value.code;
}

class AccountKindConverter extends TypeConverter<AccountKind, String> {
  const AccountKindConverter();

  @override
  AccountKind fromSql(String fromDb) => AccountKind.fromCode(fromDb);

  @override
  String toSql(AccountKind value) => value.code;
}

class CategoryKindConverter extends TypeConverter<CategoryKind, String> {
  const CategoryKindConverter();

  @override
  CategoryKind fromSql(String fromDb) => CategoryKind.fromCode(fromDb);

  @override
  String toSql(CategoryKind value) => value.code;
}

class TxSourceConverter extends TypeConverter<TxSource, String> {
  const TxSourceConverter();

  @override
  TxSource fromSql(String fromDb) => TxSource.fromCode(fromDb);

  @override
  String toSql(TxSource value) => value.code;
}

class TxStatusConverter extends TypeConverter<TxStatus, String> {
  const TxStatusConverter();

  @override
  TxStatus fromSql(String fromDb) => TxStatus.fromCode(fromDb);

  @override
  String toSql(TxStatus value) => value.code;
}
