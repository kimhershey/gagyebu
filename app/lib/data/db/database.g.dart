// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LedgersTable extends Ledgers with TableInfo<$LedgersTable, LedgerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($LedgersTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LedgersTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LedgersTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LedgersTable.$converterdeletedAtn);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('KRW'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ownerId,
    name,
    currency,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledgers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $LedgersTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $LedgersTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $LedgersTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $LedgersTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
    );
  }

  @override
  $LedgersTable createAlias(String alias) {
    return $LedgersTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class LedgerRow extends DataClass implements Insertable<LedgerRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;

  /// 인증 사용자 ID. 로그인 전의 로컬 가계부는 null.
  final String? ownerId;
  final String name;
  final String currency;
  const LedgerRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.ownerId,
    required this.name,
    required this.currency,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $LedgersTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $LedgersTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $LedgersTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $LedgersTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  LedgersCompanion toCompanion(bool nullToAbsent) {
    return LedgersCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      name: Value(name),
      currency: Value(currency),
    );
  }

  factory LedgerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ownerId': serializer.toJson<String?>(ownerId),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
    };
  }

  LedgerRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> ownerId = const Value.absent(),
    String? name,
    String? currency,
  }) => LedgerRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ownerId: ownerId.present ? ownerId.value : this.ownerId,
    name: name ?? this.name,
    currency: currency ?? this.currency,
  );
  LedgerRow copyWithCompanion(LedgersCompanion data) {
    return LedgerRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ownerId,
    name,
    currency,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.currency == this.currency);
}

class LedgersCompanion extends UpdateCompanion<LedgerRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> ownerId;
  final Value<String> name;
  final Value<String> currency;
  final Value<int> rowid;
  const LedgersCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgersCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.ownerId = const Value.absent(),
    required String name,
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name);
  static Insertable<LedgerRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgersCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? ownerId,
    Value<String>? name,
    Value<String>? currency,
    Value<int>? rowid,
  }) {
    return LedgersCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $LedgersTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $LedgersTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $LedgersTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $LedgersTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgersCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($ProfilesTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProfilesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProfilesTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ProfilesTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthStartDayMeta = const VerificationMeta(
    'monthStartDay',
  );
  @override
  late final GeneratedColumn<int> monthStartDay = GeneratedColumn<int>(
    'month_start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _defaultAccountIdMeta = const VerificationMeta(
    'defaultAccountId',
  );
  @override
  late final GeneratedColumn<String> defaultAccountId = GeneratedColumn<String>(
    'default_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    displayName,
    monthStartDay,
    defaultAccountId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('month_start_day')) {
      context.handle(
        _monthStartDayMeta,
        monthStartDay.isAcceptableOrUnknown(
          data['month_start_day']!,
          _monthStartDayMeta,
        ),
      );
    }
    if (data.containsKey('default_account_id')) {
      context.handle(
        _defaultAccountIdMeta,
        defaultAccountId.isAcceptableOrUnknown(
          data['default_account_id']!,
          _defaultAccountIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $ProfilesTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $ProfilesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $ProfilesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $ProfilesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      monthStartDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_start_day'],
      )!,
      defaultAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_account_id'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;
  final String? displayName;

  /// 월 시작일(1–28).
  final int monthStartDay;
  final String? defaultAccountId;
  const ProfileRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    this.displayName,
    required this.monthStartDay,
    this.defaultAccountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $ProfilesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $ProfilesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $ProfilesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $ProfilesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['month_start_day'] = Variable<int>(monthStartDay);
    if (!nullToAbsent || defaultAccountId != null) {
      map['default_account_id'] = Variable<String>(defaultAccountId);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      monthStartDay: Value(monthStartDay),
      defaultAccountId: defaultAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAccountId),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      monthStartDay: serializer.fromJson<int>(json['monthStartDay']),
      defaultAccountId: serializer.fromJson<String?>(json['defaultAccountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'displayName': serializer.toJson<String?>(displayName),
      'monthStartDay': serializer.toJson<int>(monthStartDay),
      'defaultAccountId': serializer.toJson<String?>(defaultAccountId),
    };
  }

  ProfileRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    Value<String?> displayName = const Value.absent(),
    int? monthStartDay,
    Value<String?> defaultAccountId = const Value.absent(),
  }) => ProfileRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    displayName: displayName.present ? displayName.value : this.displayName,
    monthStartDay: monthStartDay ?? this.monthStartDay,
    defaultAccountId: defaultAccountId.present
        ? defaultAccountId.value
        : this.defaultAccountId,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      monthStartDay: data.monthStartDay.present
          ? data.monthStartDay.value
          : this.monthStartDay,
      defaultAccountId: data.defaultAccountId.present
          ? data.defaultAccountId.value
          : this.defaultAccountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('displayName: $displayName, ')
          ..write('monthStartDay: $monthStartDay, ')
          ..write('defaultAccountId: $defaultAccountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    displayName,
    monthStartDay,
    defaultAccountId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.displayName == this.displayName &&
          other.monthStartDay == this.monthStartDay &&
          other.defaultAccountId == this.defaultAccountId);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<String?> displayName;
  final Value<int> monthStartDay;
  final Value<String?> defaultAccountId;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.monthStartDay = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    this.displayName = const Value.absent(),
    this.monthStartDay = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? displayName,
    Expression<int>? monthStartDay,
    Expression<String>? defaultAccountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (displayName != null) 'display_name': displayName,
      if (monthStartDay != null) 'month_start_day': monthStartDay,
      if (defaultAccountId != null) 'default_account_id': defaultAccountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<String?>? displayName,
    Value<int>? monthStartDay,
    Value<String?>? defaultAccountId,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      displayName: displayName ?? this.displayName,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $ProfilesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $ProfilesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $ProfilesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $ProfilesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (monthStartDay.present) {
      map['month_start_day'] = Variable<int>(monthStartDay.value);
    }
    if (defaultAccountId.present) {
      map['default_account_id'] = Variable<String>(defaultAccountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('displayName: $displayName, ')
          ..write('monthStartDay: $monthStartDay, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($AccountsTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AccountsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AccountsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($AccountsTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountKind>($AccountsTable.$converterkind);
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> matchHints =
      GeneratedColumn<String>(
        'match_hints',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($AccountsTable.$convertermatchHints);
  static const VerificationMeta _openingBalanceMeta = const VerificationMeta(
    'openingBalance',
  );
  @override
  late final GeneratedColumn<int> openingBalance = GeneratedColumn<int>(
    'opening_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _billingDayMeta = const VerificationMeta(
    'billingDay',
  );
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
    'billing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentAccountIdMeta = const VerificationMeta(
    'paymentAccountId',
  );
  @override
  late final GeneratedColumn<String> paymentAccountId = GeneratedColumn<String>(
    'payment_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    name,
    kind,
    institution,
    matchHints,
    openingBalance,
    billingDay,
    paymentAccountId,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    }
    if (data.containsKey('opening_balance')) {
      context.handle(
        _openingBalanceMeta,
        openingBalance.isAcceptableOrUnknown(
          data['opening_balance']!,
          _openingBalanceMeta,
        ),
      );
    }
    if (data.containsKey('billing_day')) {
      context.handle(
        _billingDayMeta,
        billingDay.isAcceptableOrUnknown(data['billing_day']!, _billingDayMeta),
      );
    }
    if (data.containsKey('payment_account_id')) {
      context.handle(
        _paymentAccountIdMeta,
        paymentAccountId.isAcceptableOrUnknown(
          data['payment_account_id']!,
          _paymentAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $AccountsTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $AccountsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $AccountsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $AccountsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $AccountsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      ),
      matchHints: $AccountsTable.$convertermatchHints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}match_hints'],
        )!,
      ),
      openingBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_balance'],
      )!,
      billingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_day'],
      ),
      paymentAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_account_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
  static TypeConverter<AccountKind, String> $converterkind =
      const AccountKindConverter();
  static TypeConverter<List<String>, String> $convertermatchHints =
      const StringListConverter();
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;
  final String name;
  final AccountKind kind;
  final String? institution;

  /// 원문의 카드 · 계좌 표기와 맞춰 보는 식별 문구.
  final List<String> matchHints;
  final int openingBalance;
  final int? billingDay;
  final String? paymentAccountId;
  final int sortOrder;
  const AccountRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.name,
    required this.kind,
    this.institution,
    required this.matchHints,
    required this.openingBalance,
    this.billingDay,
    this.paymentAccountId,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $AccountsTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $AccountsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $AccountsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $AccountsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>($AccountsTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || institution != null) {
      map['institution'] = Variable<String>(institution);
    }
    {
      map['match_hints'] = Variable<String>(
        $AccountsTable.$convertermatchHints.toSql(matchHints),
      );
    }
    map['opening_balance'] = Variable<int>(openingBalance);
    if (!nullToAbsent || billingDay != null) {
      map['billing_day'] = Variable<int>(billingDay);
    }
    if (!nullToAbsent || paymentAccountId != null) {
      map['payment_account_id'] = Variable<String>(paymentAccountId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      name: Value(name),
      kind: Value(kind),
      institution: institution == null && nullToAbsent
          ? const Value.absent()
          : Value(institution),
      matchHints: Value(matchHints),
      openingBalance: Value(openingBalance),
      billingDay: billingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(billingDay),
      paymentAccountId: paymentAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentAccountId),
      sortOrder: Value(sortOrder),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<AccountKind>(json['kind']),
      institution: serializer.fromJson<String?>(json['institution']),
      matchHints: serializer.fromJson<List<String>>(json['matchHints']),
      openingBalance: serializer.fromJson<int>(json['openingBalance']),
      billingDay: serializer.fromJson<int?>(json['billingDay']),
      paymentAccountId: serializer.fromJson<String?>(json['paymentAccountId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<AccountKind>(kind),
      'institution': serializer.toJson<String?>(institution),
      'matchHints': serializer.toJson<List<String>>(matchHints),
      'openingBalance': serializer.toJson<int>(openingBalance),
      'billingDay': serializer.toJson<int?>(billingDay),
      'paymentAccountId': serializer.toJson<String?>(paymentAccountId),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  AccountRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    String? name,
    AccountKind? kind,
    Value<String?> institution = const Value.absent(),
    List<String>? matchHints,
    int? openingBalance,
    Value<int?> billingDay = const Value.absent(),
    Value<String?> paymentAccountId = const Value.absent(),
    int? sortOrder,
  }) => AccountRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    institution: institution.present ? institution.value : this.institution,
    matchHints: matchHints ?? this.matchHints,
    openingBalance: openingBalance ?? this.openingBalance,
    billingDay: billingDay.present ? billingDay.value : this.billingDay,
    paymentAccountId: paymentAccountId.present
        ? paymentAccountId.value
        : this.paymentAccountId,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      matchHints: data.matchHints.present
          ? data.matchHints.value
          : this.matchHints,
      openingBalance: data.openingBalance.present
          ? data.openingBalance.value
          : this.openingBalance,
      billingDay: data.billingDay.present
          ? data.billingDay.value
          : this.billingDay,
      paymentAccountId: data.paymentAccountId.present
          ? data.paymentAccountId.value
          : this.paymentAccountId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('institution: $institution, ')
          ..write('matchHints: $matchHints, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentAccountId: $paymentAccountId, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    name,
    kind,
    institution,
    matchHints,
    openingBalance,
    billingDay,
    paymentAccountId,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.institution == this.institution &&
          other.matchHints == this.matchHints &&
          other.openingBalance == this.openingBalance &&
          other.billingDay == this.billingDay &&
          other.paymentAccountId == this.paymentAccountId &&
          other.sortOrder == this.sortOrder);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<String> name;
  final Value<AccountKind> kind;
  final Value<String?> institution;
  final Value<List<String>> matchHints;
  final Value<int> openingBalance;
  final Value<int?> billingDay;
  final Value<String?> paymentAccountId;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.institution = const Value.absent(),
    this.matchHints = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentAccountId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required String name,
    required AccountKind kind,
    this.institution = const Value.absent(),
    this.matchHints = const Value.absent(),
    this.openingBalance = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.paymentAccountId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? institution,
    Expression<String>? matchHints,
    Expression<int>? openingBalance,
    Expression<int>? billingDay,
    Expression<String>? paymentAccountId,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (institution != null) 'institution': institution,
      if (matchHints != null) 'match_hints': matchHints,
      if (openingBalance != null) 'opening_balance': openingBalance,
      if (billingDay != null) 'billing_day': billingDay,
      if (paymentAccountId != null) 'payment_account_id': paymentAccountId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<String>? name,
    Value<AccountKind>? kind,
    Value<String?>? institution,
    Value<List<String>>? matchHints,
    Value<int>? openingBalance,
    Value<int?>? billingDay,
    Value<String?>? paymentAccountId,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      institution: institution ?? this.institution,
      matchHints: matchHints ?? this.matchHints,
      openingBalance: openingBalance ?? this.openingBalance,
      billingDay: billingDay ?? this.billingDay,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $AccountsTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $AccountsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $AccountsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $AccountsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $AccountsTable.$converterkind.toSql(kind.value),
      );
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (matchHints.present) {
      map['match_hints'] = Variable<String>(
        $AccountsTable.$convertermatchHints.toSql(matchHints.value),
      );
    }
    if (openingBalance.present) {
      map['opening_balance'] = Variable<int>(openingBalance.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (paymentAccountId.present) {
      map['payment_account_id'] = Variable<String>(paymentAccountId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('institution: $institution, ')
          ..write('matchHints: $matchHints, ')
          ..write('openingBalance: $openingBalance, ')
          ..write('billingDay: $billingDay, ')
          ..write('paymentAccountId: $paymentAccountId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($CategoriesTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CategoriesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CategoriesTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($CategoriesTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CategoryKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    kind,
    name,
    parentId,
    icon,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $CategoriesTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $CategoriesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $CategoriesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $CategoriesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      kind: $CategoriesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
  static TypeConverter<CategoryKind, String> $converterkind =
      const CategoryKindConverter();
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;
  final CategoryKind kind;
  final String name;
  final String? parentId;
  final String? icon;
  final int sortOrder;
  const CategoryRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.kind,
    required this.name,
    this.parentId,
    this.icon,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $CategoriesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $CategoriesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $CategoriesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $CategoriesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind),
      );
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      kind: Value(kind),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      kind: serializer.fromJson<CategoryKind>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'kind': serializer.toJson<CategoryKind>(kind),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CategoryRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    CategoryKind? kind,
    String? name,
    Value<String?> parentId = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    int? sortOrder,
  }) => CategoryRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    kind,
    name,
    parentId,
    icon,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<CategoryKind> kind;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required CategoryKind kind,
    required String name,
    this.parentId = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       kind = Value(kind),
       name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<CategoryKind>? kind,
    Value<String>? name,
    Value<String?>? parentId,
    Value<String?>? icon,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $CategoriesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $CategoriesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $CategoriesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $CategoriesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoriesTable.$converterkind.toSql(kind.value),
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerTransactionsTable extends LedgerTransactions
    with TableInfo<$LedgerTransactionsTable, TxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($LedgerTransactionsTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LedgerTransactionsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LedgerTransactionsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LedgerTransactionsTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxType>($LedgerTransactionsTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> occurredOn =
      GeneratedColumn<String>(
        'occurred_on',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($LedgerTransactionsTable.$converteroccurredOn);
  static const VerificationMeta _occurredTimeMeta = const VerificationMeta(
    'occurredTime',
  );
  @override
  late final GeneratedColumn<String> occurredTime = GeneratedColumn<String>(
    'occurred_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalAmountMeta = const VerificationMeta(
    'originalAmount',
  );
  @override
  late final GeneratedColumn<double> originalAmount = GeneratedColumn<double>(
    'original_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiverMeta = const VerificationMeta(
    'receiver',
  );
  @override
  late final GeneratedColumn<String> receiver = GeneratedColumn<String>(
    'receiver',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($LedgerTransactionsTable.$convertertags);
  static const VerificationMeta _installmentMonthsMeta = const VerificationMeta(
    'installmentMonths',
  );
  @override
  late final GeneratedColumn<int> installmentMonths = GeneratedColumn<int>(
    'installment_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceAfterMeta = const VerificationMeta(
    'balanceAfter',
  );
  @override
  late final GeneratedColumn<int> balanceAfter = GeneratedColumn<int>(
    'balance_after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> canceledAt =
      GeneratedColumn<String>(
        'canceled_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>(
        $LedgerTransactionsTable.$convertercanceledAtn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<TxSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('manual'),
      ).withConverter<TxSource>($LedgerTransactionsTable.$convertersource);
  static const VerificationMeta _aiModelMeta = const VerificationMeta(
    'aiModel',
  );
  @override
  late final GeneratedColumn<String> aiModel = GeneratedColumn<String>(
    'ai_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('confirmed'),
      ).withConverter<TxStatus>($LedgerTransactionsTable.$converterstatus);
  static const VerificationMeta _dedupKeyMeta = const VerificationMeta(
    'dedupKey',
  );
  @override
  late final GeneratedColumn<String> dedupKey = GeneratedColumn<String>(
    'dedup_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    type,
    occurredOn,
    occurredTime,
    amount,
    currency,
    originalAmount,
    accountId,
    toAccountId,
    sender,
    receiver,
    categoryId,
    memo,
    tags,
    installmentMonths,
    balanceAfter,
    canceledAt,
    source,
    aiModel,
    status,
    dedupKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('occurred_time')) {
      context.handle(
        _occurredTimeMeta,
        occurredTime.isAcceptableOrUnknown(
          data['occurred_time']!,
          _occurredTimeMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('original_amount')) {
      context.handle(
        _originalAmountMeta,
        originalAmount.isAcceptableOrUnknown(
          data['original_amount']!,
          _originalAmountMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    }
    if (data.containsKey('receiver')) {
      context.handle(
        _receiverMeta,
        receiver.isAcceptableOrUnknown(data['receiver']!, _receiverMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('installment_months')) {
      context.handle(
        _installmentMonthsMeta,
        installmentMonths.isAcceptableOrUnknown(
          data['installment_months']!,
          _installmentMonthsMeta,
        ),
      );
    }
    if (data.containsKey('balance_after')) {
      context.handle(
        _balanceAfterMeta,
        balanceAfter.isAcceptableOrUnknown(
          data['balance_after']!,
          _balanceAfterMeta,
        ),
      );
    }
    if (data.containsKey('ai_model')) {
      context.handle(
        _aiModelMeta,
        aiModel.isAcceptableOrUnknown(data['ai_model']!, _aiModelMeta),
      );
    }
    if (data.containsKey('dedup_key')) {
      context.handle(
        _dedupKeyMeta,
        dedupKey.isAcceptableOrUnknown(data['dedup_key']!, _dedupKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $LedgerTransactionsTable.$converterclientUpdatedAt
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}client_updated_at'],
            )!,
          ),
      createdAt: $LedgerTransactionsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $LedgerTransactionsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $LedgerTransactionsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      type: $LedgerTransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      occurredOn: $LedgerTransactionsTable.$converteroccurredOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}occurred_on'],
        )!,
      ),
      occurredTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_time'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      originalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}original_amount'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      ),
      receiver: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receiver'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      tags: $LedgerTransactionsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      installmentMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installment_months'],
      ),
      balanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_after'],
      ),
      canceledAt: $LedgerTransactionsTable.$convertercanceledAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}canceled_at'],
        ),
      ),
      source: $LedgerTransactionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      aiModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_model'],
      ),
      status: $LedgerTransactionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      dedupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedup_key'],
      ),
    );
  }

  @override
  $LedgerTransactionsTable createAlias(String alias) {
    return $LedgerTransactionsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
  static TypeConverter<TxType, String> $convertertype = const TxTypeConverter();
  static TypeConverter<LocalDate, String> $converteroccurredOn =
      const LocalDateConverter();
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<DateTime, String> $convertercanceledAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $convertercanceledAtn =
      NullAwareTypeConverter.wrap($convertercanceledAt);
  static TypeConverter<TxSource, String> $convertersource =
      const TxSourceConverter();
  static TypeConverter<TxStatus, String> $converterstatus =
      const TxStatusConverter();
}

class TxRow extends DataClass implements Insertable<TxRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;
  final TxType type;
  final LocalDate occurredOn;

  /// 'HH:mm'. 원문에 없으면 null.
  final String? occurredTime;

  /// 원 단위 정수. 방향은 type이 정하고 값은 양수다. 부분 취소와 환불만 음수다.
  final int amount;
  final String? currency;
  final double? originalAmount;
  final String accountId;
  final String? toAccountId;
  final String? sender;
  final String? receiver;
  final String? categoryId;
  final String? memo;
  final List<String> tags;
  final int? installmentMonths;
  final int? balanceAfter;
  final DateTime? canceledAt;
  final TxSource source;
  final String? aiModel;
  final TxStatus status;
  final String? dedupKey;
  const TxRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.type,
    required this.occurredOn,
    this.occurredTime,
    required this.amount,
    this.currency,
    this.originalAmount,
    required this.accountId,
    this.toAccountId,
    this.sender,
    this.receiver,
    this.categoryId,
    this.memo,
    required this.tags,
    this.installmentMonths,
    this.balanceAfter,
    this.canceledAt,
    required this.source,
    this.aiModel,
    required this.status,
    this.dedupKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterclientUpdatedAt.toSql(
          clientUpdatedAt,
        ),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $LedgerTransactionsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    {
      map['type'] = Variable<String>(
        $LedgerTransactionsTable.$convertertype.toSql(type),
      );
    }
    {
      map['occurred_on'] = Variable<String>(
        $LedgerTransactionsTable.$converteroccurredOn.toSql(occurredOn),
      );
    }
    if (!nullToAbsent || occurredTime != null) {
      map['occurred_time'] = Variable<String>(occurredTime);
    }
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || originalAmount != null) {
      map['original_amount'] = Variable<double>(originalAmount);
    }
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || receiver != null) {
      map['receiver'] = Variable<String>(receiver);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    {
      map['tags'] = Variable<String>(
        $LedgerTransactionsTable.$convertertags.toSql(tags),
      );
    }
    if (!nullToAbsent || installmentMonths != null) {
      map['installment_months'] = Variable<int>(installmentMonths);
    }
    if (!nullToAbsent || balanceAfter != null) {
      map['balance_after'] = Variable<int>(balanceAfter);
    }
    if (!nullToAbsent || canceledAt != null) {
      map['canceled_at'] = Variable<String>(
        $LedgerTransactionsTable.$convertercanceledAtn.toSql(canceledAt),
      );
    }
    {
      map['source'] = Variable<String>(
        $LedgerTransactionsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || aiModel != null) {
      map['ai_model'] = Variable<String>(aiModel);
    }
    {
      map['status'] = Variable<String>(
        $LedgerTransactionsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || dedupKey != null) {
      map['dedup_key'] = Variable<String>(dedupKey);
    }
    return map;
  }

  LedgerTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LedgerTransactionsCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      type: Value(type),
      occurredOn: Value(occurredOn),
      occurredTime: occurredTime == null && nullToAbsent
          ? const Value.absent()
          : Value(occurredTime),
      amount: Value(amount),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      originalAmount: originalAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(originalAmount),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      sender: sender == null && nullToAbsent
          ? const Value.absent()
          : Value(sender),
      receiver: receiver == null && nullToAbsent
          ? const Value.absent()
          : Value(receiver),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      tags: Value(tags),
      installmentMonths: installmentMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(installmentMonths),
      balanceAfter: balanceAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceAfter),
      canceledAt: canceledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(canceledAt),
      source: Value(source),
      aiModel: aiModel == null && nullToAbsent
          ? const Value.absent()
          : Value(aiModel),
      status: Value(status),
      dedupKey: dedupKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupKey),
    );
  }

  factory TxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TxRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      type: serializer.fromJson<TxType>(json['type']),
      occurredOn: serializer.fromJson<LocalDate>(json['occurredOn']),
      occurredTime: serializer.fromJson<String?>(json['occurredTime']),
      amount: serializer.fromJson<int>(json['amount']),
      currency: serializer.fromJson<String?>(json['currency']),
      originalAmount: serializer.fromJson<double?>(json['originalAmount']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      sender: serializer.fromJson<String?>(json['sender']),
      receiver: serializer.fromJson<String?>(json['receiver']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      memo: serializer.fromJson<String?>(json['memo']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      installmentMonths: serializer.fromJson<int?>(json['installmentMonths']),
      balanceAfter: serializer.fromJson<int?>(json['balanceAfter']),
      canceledAt: serializer.fromJson<DateTime?>(json['canceledAt']),
      source: serializer.fromJson<TxSource>(json['source']),
      aiModel: serializer.fromJson<String?>(json['aiModel']),
      status: serializer.fromJson<TxStatus>(json['status']),
      dedupKey: serializer.fromJson<String?>(json['dedupKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'type': serializer.toJson<TxType>(type),
      'occurredOn': serializer.toJson<LocalDate>(occurredOn),
      'occurredTime': serializer.toJson<String?>(occurredTime),
      'amount': serializer.toJson<int>(amount),
      'currency': serializer.toJson<String?>(currency),
      'originalAmount': serializer.toJson<double?>(originalAmount),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'sender': serializer.toJson<String?>(sender),
      'receiver': serializer.toJson<String?>(receiver),
      'categoryId': serializer.toJson<String?>(categoryId),
      'memo': serializer.toJson<String?>(memo),
      'tags': serializer.toJson<List<String>>(tags),
      'installmentMonths': serializer.toJson<int?>(installmentMonths),
      'balanceAfter': serializer.toJson<int?>(balanceAfter),
      'canceledAt': serializer.toJson<DateTime?>(canceledAt),
      'source': serializer.toJson<TxSource>(source),
      'aiModel': serializer.toJson<String?>(aiModel),
      'status': serializer.toJson<TxStatus>(status),
      'dedupKey': serializer.toJson<String?>(dedupKey),
    };
  }

  TxRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    TxType? type,
    LocalDate? occurredOn,
    Value<String?> occurredTime = const Value.absent(),
    int? amount,
    Value<String?> currency = const Value.absent(),
    Value<double?> originalAmount = const Value.absent(),
    String? accountId,
    Value<String?> toAccountId = const Value.absent(),
    Value<String?> sender = const Value.absent(),
    Value<String?> receiver = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    List<String>? tags,
    Value<int?> installmentMonths = const Value.absent(),
    Value<int?> balanceAfter = const Value.absent(),
    Value<DateTime?> canceledAt = const Value.absent(),
    TxSource? source,
    Value<String?> aiModel = const Value.absent(),
    TxStatus? status,
    Value<String?> dedupKey = const Value.absent(),
  }) => TxRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    type: type ?? this.type,
    occurredOn: occurredOn ?? this.occurredOn,
    occurredTime: occurredTime.present ? occurredTime.value : this.occurredTime,
    amount: amount ?? this.amount,
    currency: currency.present ? currency.value : this.currency,
    originalAmount: originalAmount.present
        ? originalAmount.value
        : this.originalAmount,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    sender: sender.present ? sender.value : this.sender,
    receiver: receiver.present ? receiver.value : this.receiver,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    memo: memo.present ? memo.value : this.memo,
    tags: tags ?? this.tags,
    installmentMonths: installmentMonths.present
        ? installmentMonths.value
        : this.installmentMonths,
    balanceAfter: balanceAfter.present ? balanceAfter.value : this.balanceAfter,
    canceledAt: canceledAt.present ? canceledAt.value : this.canceledAt,
    source: source ?? this.source,
    aiModel: aiModel.present ? aiModel.value : this.aiModel,
    status: status ?? this.status,
    dedupKey: dedupKey.present ? dedupKey.value : this.dedupKey,
  );
  TxRow copyWithCompanion(LedgerTransactionsCompanion data) {
    return TxRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      occurredOn: data.occurredOn.present
          ? data.occurredOn.value
          : this.occurredOn,
      occurredTime: data.occurredTime.present
          ? data.occurredTime.value
          : this.occurredTime,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      originalAmount: data.originalAmount.present
          ? data.originalAmount.value
          : this.originalAmount,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      sender: data.sender.present ? data.sender.value : this.sender,
      receiver: data.receiver.present ? data.receiver.value : this.receiver,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      memo: data.memo.present ? data.memo.value : this.memo,
      tags: data.tags.present ? data.tags.value : this.tags,
      installmentMonths: data.installmentMonths.present
          ? data.installmentMonths.value
          : this.installmentMonths,
      balanceAfter: data.balanceAfter.present
          ? data.balanceAfter.value
          : this.balanceAfter,
      canceledAt: data.canceledAt.present
          ? data.canceledAt.value
          : this.canceledAt,
      source: data.source.present ? data.source.value : this.source,
      aiModel: data.aiModel.present ? data.aiModel.value : this.aiModel,
      status: data.status.present ? data.status.value : this.status,
      dedupKey: data.dedupKey.present ? data.dedupKey.value : this.dedupKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TxRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('occurredTime: $occurredTime, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('originalAmount: $originalAmount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('sender: $sender, ')
          ..write('receiver: $receiver, ')
          ..write('categoryId: $categoryId, ')
          ..write('memo: $memo, ')
          ..write('tags: $tags, ')
          ..write('installmentMonths: $installmentMonths, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('canceledAt: $canceledAt, ')
          ..write('source: $source, ')
          ..write('aiModel: $aiModel, ')
          ..write('status: $status, ')
          ..write('dedupKey: $dedupKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    type,
    occurredOn,
    occurredTime,
    amount,
    currency,
    originalAmount,
    accountId,
    toAccountId,
    sender,
    receiver,
    categoryId,
    memo,
    tags,
    installmentMonths,
    balanceAfter,
    canceledAt,
    source,
    aiModel,
    status,
    dedupKey,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.occurredOn == this.occurredOn &&
          other.occurredTime == this.occurredTime &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.originalAmount == this.originalAmount &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.sender == this.sender &&
          other.receiver == this.receiver &&
          other.categoryId == this.categoryId &&
          other.memo == this.memo &&
          other.tags == this.tags &&
          other.installmentMonths == this.installmentMonths &&
          other.balanceAfter == this.balanceAfter &&
          other.canceledAt == this.canceledAt &&
          other.source == this.source &&
          other.aiModel == this.aiModel &&
          other.status == this.status &&
          other.dedupKey == this.dedupKey);
}

class LedgerTransactionsCompanion extends UpdateCompanion<TxRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<TxType> type;
  final Value<LocalDate> occurredOn;
  final Value<String?> occurredTime;
  final Value<int> amount;
  final Value<String?> currency;
  final Value<double?> originalAmount;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<String?> sender;
  final Value<String?> receiver;
  final Value<String?> categoryId;
  final Value<String?> memo;
  final Value<List<String>> tags;
  final Value<int?> installmentMonths;
  final Value<int?> balanceAfter;
  final Value<DateTime?> canceledAt;
  final Value<TxSource> source;
  final Value<String?> aiModel;
  final Value<TxStatus> status;
  final Value<String?> dedupKey;
  final Value<int> rowid;
  const LedgerTransactionsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.occurredOn = const Value.absent(),
    this.occurredTime = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.originalAmount = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.sender = const Value.absent(),
    this.receiver = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.memo = const Value.absent(),
    this.tags = const Value.absent(),
    this.installmentMonths = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.canceledAt = const Value.absent(),
    this.source = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.status = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerTransactionsCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required TxType type,
    required LocalDate occurredOn,
    this.occurredTime = const Value.absent(),
    required int amount,
    this.currency = const Value.absent(),
    this.originalAmount = const Value.absent(),
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.sender = const Value.absent(),
    this.receiver = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.memo = const Value.absent(),
    this.tags = const Value.absent(),
    this.installmentMonths = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.canceledAt = const Value.absent(),
    this.source = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.status = const Value.absent(),
    this.dedupKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       type = Value(type),
       occurredOn = Value(occurredOn),
       amount = Value(amount),
       accountId = Value(accountId);
  static Insertable<TxRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? type,
    Expression<String>? occurredOn,
    Expression<String>? occurredTime,
    Expression<int>? amount,
    Expression<String>? currency,
    Expression<double>? originalAmount,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<String>? sender,
    Expression<String>? receiver,
    Expression<String>? categoryId,
    Expression<String>? memo,
    Expression<String>? tags,
    Expression<int>? installmentMonths,
    Expression<int>? balanceAfter,
    Expression<String>? canceledAt,
    Expression<String>? source,
    Expression<String>? aiModel,
    Expression<String>? status,
    Expression<String>? dedupKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (occurredOn != null) 'occurred_on': occurredOn,
      if (occurredTime != null) 'occurred_time': occurredTime,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (originalAmount != null) 'original_amount': originalAmount,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (sender != null) 'sender': sender,
      if (receiver != null) 'receiver': receiver,
      if (categoryId != null) 'category_id': categoryId,
      if (memo != null) 'memo': memo,
      if (tags != null) 'tags': tags,
      if (installmentMonths != null) 'installment_months': installmentMonths,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (canceledAt != null) 'canceled_at': canceledAt,
      if (source != null) 'source': source,
      if (aiModel != null) 'ai_model': aiModel,
      if (status != null) 'status': status,
      if (dedupKey != null) 'dedup_key': dedupKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerTransactionsCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<TxType>? type,
    Value<LocalDate>? occurredOn,
    Value<String?>? occurredTime,
    Value<int>? amount,
    Value<String?>? currency,
    Value<double?>? originalAmount,
    Value<String>? accountId,
    Value<String?>? toAccountId,
    Value<String?>? sender,
    Value<String?>? receiver,
    Value<String?>? categoryId,
    Value<String?>? memo,
    Value<List<String>>? tags,
    Value<int?>? installmentMonths,
    Value<int?>? balanceAfter,
    Value<DateTime?>? canceledAt,
    Value<TxSource>? source,
    Value<String?>? aiModel,
    Value<TxStatus>? status,
    Value<String?>? dedupKey,
    Value<int>? rowid,
  }) {
    return LedgerTransactionsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      occurredOn: occurredOn ?? this.occurredOn,
      occurredTime: occurredTime ?? this.occurredTime,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      originalAmount: originalAmount ?? this.originalAmount,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      categoryId: categoryId ?? this.categoryId,
      memo: memo ?? this.memo,
      tags: tags ?? this.tags,
      installmentMonths: installmentMonths ?? this.installmentMonths,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      canceledAt: canceledAt ?? this.canceledAt,
      source: source ?? this.source,
      aiModel: aiModel ?? this.aiModel,
      status: status ?? this.status,
      dedupKey: dedupKey ?? this.dedupKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterclientUpdatedAt.toSql(
          clientUpdatedAt.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $LedgerTransactionsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $LedgerTransactionsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $LedgerTransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (occurredOn.present) {
      map['occurred_on'] = Variable<String>(
        $LedgerTransactionsTable.$converteroccurredOn.toSql(occurredOn.value),
      );
    }
    if (occurredTime.present) {
      map['occurred_time'] = Variable<String>(occurredTime.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (originalAmount.present) {
      map['original_amount'] = Variable<double>(originalAmount.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (receiver.present) {
      map['receiver'] = Variable<String>(receiver.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $LedgerTransactionsTable.$convertertags.toSql(tags.value),
      );
    }
    if (installmentMonths.present) {
      map['installment_months'] = Variable<int>(installmentMonths.value);
    }
    if (balanceAfter.present) {
      map['balance_after'] = Variable<int>(balanceAfter.value);
    }
    if (canceledAt.present) {
      map['canceled_at'] = Variable<String>(
        $LedgerTransactionsTable.$convertercanceledAtn.toSql(canceledAt.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $LedgerTransactionsTable.$convertersource.toSql(source.value),
      );
    }
    if (aiModel.present) {
      map['ai_model'] = Variable<String>(aiModel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $LedgerTransactionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (dedupKey.present) {
      map['dedup_key'] = Variable<String>(dedupKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('occurredOn: $occurredOn, ')
          ..write('occurredTime: $occurredTime, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('originalAmount: $originalAmount, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('sender: $sender, ')
          ..write('receiver: $receiver, ')
          ..write('categoryId: $categoryId, ')
          ..write('memo: $memo, ')
          ..write('tags: $tags, ')
          ..write('installmentMonths: $installmentMonths, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('canceledAt: $canceledAt, ')
          ..write('source: $source, ')
          ..write('aiModel: $aiModel, ')
          ..write('status: $status, ')
          ..write('dedupKey: $dedupKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($BudgetsTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($BudgetsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($BudgetsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($BudgetsTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    month,
    categoryId,
    amount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $BudgetsTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $BudgetsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $BudgetsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $BudgetsTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;

  /// 'YYYY-MM'
  final String month;

  /// 비면 전체 예산.
  final String? categoryId;
  final int amount;
  const BudgetRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.month,
    this.categoryId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $BudgetsTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $BudgetsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $BudgetsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $BudgetsTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    map['month'] = Variable<String>(month);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount'] = Variable<int>(amount);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      month: Value(month),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amount: Value(amount),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      month: serializer.fromJson<String>(json['month']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<int>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'month': serializer.toJson<String>(month),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<int>(amount),
    };
  }

  BudgetRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    String? month,
    Value<String?> categoryId = const Value.absent(),
    int? amount,
  }) => BudgetRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    month: month ?? this.month,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amount: amount ?? this.amount,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      month: data.month.present ? data.month.value : this.month,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('month: $month, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    month,
    categoryId,
    amount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.month == this.month &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<String> month;
  final Value<String?> categoryId;
  final Value<int> amount;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.month = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required String month,
    this.categoryId = const Value.absent(),
    required int amount,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       month = Value(month),
       amount = Value(amount);
  static Insertable<BudgetRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? month,
    Expression<String>? categoryId,
    Expression<int>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (month != null) 'month': month,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<String>? month,
    Value<String?>? categoryId,
    Value<int>? amount,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      month: month ?? this.month,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $BudgetsTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $BudgetsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $BudgetsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $BudgetsTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('month: $month, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringRulesTable extends RecurringRules
    with TableInfo<$RecurringRulesTable, RecurringRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($RecurringRulesTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RecurringRulesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RecurringRulesTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($RecurringRulesTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, Object?>, String>
  template =
      GeneratedColumn<String>(
        'template',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Map<String, Object?>>(
        $RecurringRulesTable.$convertertemplate,
      );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalCountMeta = const VerificationMeta(
    'intervalCount',
  );
  @override
  late final GeneratedColumn<int> intervalCount = GeneratedColumn<int>(
    'interval_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> nextRunOn =
      GeneratedColumn<String>(
        'next_run_on',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>($RecurringRulesTable.$converternextRunOn);
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate?, String> endOn =
      GeneratedColumn<String>(
        'end_on',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<LocalDate?>($RecurringRulesTable.$converterendOnn);
  static const VerificationMeta _autoPostMeta = const VerificationMeta(
    'autoPost',
  );
  @override
  late final GeneratedColumn<bool> autoPost = GeneratedColumn<bool>(
    'auto_post',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_post" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    template,
    frequency,
    intervalCount,
    nextRunOn,
    endOn,
    autoPost,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('interval_count')) {
      context.handle(
        _intervalCountMeta,
        intervalCount.isAcceptableOrUnknown(
          data['interval_count']!,
          _intervalCountMeta,
        ),
      );
    }
    if (data.containsKey('auto_post')) {
      context.handle(
        _autoPostMeta,
        autoPost.isAcceptableOrUnknown(data['auto_post']!, _autoPostMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $RecurringRulesTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $RecurringRulesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $RecurringRulesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $RecurringRulesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      template: $RecurringRulesTable.$convertertemplate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}template'],
        )!,
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      intervalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_count'],
      )!,
      nextRunOn: $RecurringRulesTable.$converternextRunOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}next_run_on'],
        )!,
      ),
      endOn: $RecurringRulesTable.$converterendOnn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_on'],
        ),
      ),
      autoPost: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_post'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $RecurringRulesTable createAlias(String alias) {
    return $RecurringRulesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
  static TypeConverter<Map<String, Object?>, String> $convertertemplate =
      const JsonMapConverter();
  static TypeConverter<LocalDate, String> $converternextRunOn =
      const LocalDateConverter();
  static TypeConverter<LocalDate, String> $converterendOn =
      const LocalDateConverter();
  static TypeConverter<LocalDate?, String?> $converterendOnn =
      NullAwareTypeConverter.wrap($converterendOn);
}

class RecurringRuleRow extends DataClass
    implements Insertable<RecurringRuleRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;
  final Map<String, Object?> template;

  /// weekly · monthly · yearly
  final String frequency;
  final int intervalCount;
  final LocalDate nextRunOn;
  final LocalDate? endOn;
  final bool autoPost;
  final bool isActive;
  const RecurringRuleRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.template,
    required this.frequency,
    required this.intervalCount,
    required this.nextRunOn,
    this.endOn,
    required this.autoPost,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $RecurringRulesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $RecurringRulesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $RecurringRulesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $RecurringRulesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    {
      map['template'] = Variable<String>(
        $RecurringRulesTable.$convertertemplate.toSql(template),
      );
    }
    map['frequency'] = Variable<String>(frequency);
    map['interval_count'] = Variable<int>(intervalCount);
    {
      map['next_run_on'] = Variable<String>(
        $RecurringRulesTable.$converternextRunOn.toSql(nextRunOn),
      );
    }
    if (!nullToAbsent || endOn != null) {
      map['end_on'] = Variable<String>(
        $RecurringRulesTable.$converterendOnn.toSql(endOn),
      );
    }
    map['auto_post'] = Variable<bool>(autoPost);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  RecurringRulesCompanion toCompanion(bool nullToAbsent) {
    return RecurringRulesCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      template: Value(template),
      frequency: Value(frequency),
      intervalCount: Value(intervalCount),
      nextRunOn: Value(nextRunOn),
      endOn: endOn == null && nullToAbsent
          ? const Value.absent()
          : Value(endOn),
      autoPost: Value(autoPost),
      isActive: Value(isActive),
    );
  }

  factory RecurringRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringRuleRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      template: serializer.fromJson<Map<String, Object?>>(json['template']),
      frequency: serializer.fromJson<String>(json['frequency']),
      intervalCount: serializer.fromJson<int>(json['intervalCount']),
      nextRunOn: serializer.fromJson<LocalDate>(json['nextRunOn']),
      endOn: serializer.fromJson<LocalDate?>(json['endOn']),
      autoPost: serializer.fromJson<bool>(json['autoPost']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'template': serializer.toJson<Map<String, Object?>>(template),
      'frequency': serializer.toJson<String>(frequency),
      'intervalCount': serializer.toJson<int>(intervalCount),
      'nextRunOn': serializer.toJson<LocalDate>(nextRunOn),
      'endOn': serializer.toJson<LocalDate?>(endOn),
      'autoPost': serializer.toJson<bool>(autoPost),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  RecurringRuleRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    Map<String, Object?>? template,
    String? frequency,
    int? intervalCount,
    LocalDate? nextRunOn,
    Value<LocalDate?> endOn = const Value.absent(),
    bool? autoPost,
    bool? isActive,
  }) => RecurringRuleRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    template: template ?? this.template,
    frequency: frequency ?? this.frequency,
    intervalCount: intervalCount ?? this.intervalCount,
    nextRunOn: nextRunOn ?? this.nextRunOn,
    endOn: endOn.present ? endOn.value : this.endOn,
    autoPost: autoPost ?? this.autoPost,
    isActive: isActive ?? this.isActive,
  );
  RecurringRuleRow copyWithCompanion(RecurringRulesCompanion data) {
    return RecurringRuleRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      template: data.template.present ? data.template.value : this.template,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      intervalCount: data.intervalCount.present
          ? data.intervalCount.value
          : this.intervalCount,
      nextRunOn: data.nextRunOn.present ? data.nextRunOn.value : this.nextRunOn,
      endOn: data.endOn.present ? data.endOn.value : this.endOn,
      autoPost: data.autoPost.present ? data.autoPost.value : this.autoPost,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRuleRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('template: $template, ')
          ..write('frequency: $frequency, ')
          ..write('intervalCount: $intervalCount, ')
          ..write('nextRunOn: $nextRunOn, ')
          ..write('endOn: $endOn, ')
          ..write('autoPost: $autoPost, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    template,
    frequency,
    intervalCount,
    nextRunOn,
    endOn,
    autoPost,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringRuleRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.template == this.template &&
          other.frequency == this.frequency &&
          other.intervalCount == this.intervalCount &&
          other.nextRunOn == this.nextRunOn &&
          other.endOn == this.endOn &&
          other.autoPost == this.autoPost &&
          other.isActive == this.isActive);
}

class RecurringRulesCompanion extends UpdateCompanion<RecurringRuleRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<Map<String, Object?>> template;
  final Value<String> frequency;
  final Value<int> intervalCount;
  final Value<LocalDate> nextRunOn;
  final Value<LocalDate?> endOn;
  final Value<bool> autoPost;
  final Value<bool> isActive;
  final Value<int> rowid;
  const RecurringRulesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.template = const Value.absent(),
    this.frequency = const Value.absent(),
    this.intervalCount = const Value.absent(),
    this.nextRunOn = const Value.absent(),
    this.endOn = const Value.absent(),
    this.autoPost = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringRulesCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required Map<String, Object?> template,
    required String frequency,
    this.intervalCount = const Value.absent(),
    required LocalDate nextRunOn,
    this.endOn = const Value.absent(),
    this.autoPost = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       template = Value(template),
       frequency = Value(frequency),
       nextRunOn = Value(nextRunOn);
  static Insertable<RecurringRuleRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? template,
    Expression<String>? frequency,
    Expression<int>? intervalCount,
    Expression<String>? nextRunOn,
    Expression<String>? endOn,
    Expression<bool>? autoPost,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (template != null) 'template': template,
      if (frequency != null) 'frequency': frequency,
      if (intervalCount != null) 'interval_count': intervalCount,
      if (nextRunOn != null) 'next_run_on': nextRunOn,
      if (endOn != null) 'end_on': endOn,
      if (autoPost != null) 'auto_post': autoPost,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringRulesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<Map<String, Object?>>? template,
    Value<String>? frequency,
    Value<int>? intervalCount,
    Value<LocalDate>? nextRunOn,
    Value<LocalDate?>? endOn,
    Value<bool>? autoPost,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return RecurringRulesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      template: template ?? this.template,
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      nextRunOn: nextRunOn ?? this.nextRunOn,
      endOn: endOn ?? this.endOn,
      autoPost: autoPost ?? this.autoPost,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $RecurringRulesTable.$converterclientUpdatedAt.toSql(
          clientUpdatedAt.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $RecurringRulesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $RecurringRulesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $RecurringRulesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (template.present) {
      map['template'] = Variable<String>(
        $RecurringRulesTable.$convertertemplate.toSql(template.value),
      );
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (intervalCount.present) {
      map['interval_count'] = Variable<int>(intervalCount.value);
    }
    if (nextRunOn.present) {
      map['next_run_on'] = Variable<String>(
        $RecurringRulesTable.$converternextRunOn.toSql(nextRunOn.value),
      );
    }
    if (endOn.present) {
      map['end_on'] = Variable<String>(
        $RecurringRulesTable.$converterendOnn.toSql(endOn.value),
      );
    }
    if (autoPost.present) {
      map['auto_post'] = Variable<bool>(autoPost.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringRulesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('template: $template, ')
          ..write('frequency: $frequency, ')
          ..write('intervalCount: $intervalCount, ')
          ..write('nextRunOn: $nextRunOn, ')
          ..write('endOn: $endOn, ')
          ..write('autoPost: $autoPost, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryRulesTable extends CategoryRules
    with TableInfo<$CategoryRulesTable, CategoryRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($CategoryRulesTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CategoryRulesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CategoryRulesTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($CategoryRulesTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hitCountMeta = const VerificationMeta(
    'hitCount',
  );
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
    'hit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    pattern,
    categoryId,
    hitCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('hit_count')) {
      context.handle(
        _hitCountMeta,
        hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $CategoryRulesTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $CategoryRulesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $CategoryRulesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $CategoryRulesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      hitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hit_count'],
      )!,
    );
  }

  @override
  $CategoryRulesTable createAlias(String alias) {
    return $CategoryRulesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class CategoryRuleRow extends DataClass implements Insertable<CategoryRuleRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;

  /// 상대방 문자열(정규화한 값)
  final String pattern;
  final String categoryId;
  final int hitCount;
  const CategoryRuleRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.pattern,
    required this.categoryId,
    required this.hitCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $CategoryRulesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $CategoryRulesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $CategoryRulesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $CategoryRulesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    map['pattern'] = Variable<String>(pattern);
    map['category_id'] = Variable<String>(categoryId);
    map['hit_count'] = Variable<int>(hitCount);
    return map;
  }

  CategoryRulesCompanion toCompanion(bool nullToAbsent) {
    return CategoryRulesCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      pattern: Value(pattern),
      categoryId: Value(categoryId),
      hitCount: Value(hitCount),
    );
  }

  factory CategoryRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRuleRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      pattern: serializer.fromJson<String>(json['pattern']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'pattern': serializer.toJson<String>(pattern),
      'categoryId': serializer.toJson<String>(categoryId),
      'hitCount': serializer.toJson<int>(hitCount),
    };
  }

  CategoryRuleRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    String? pattern,
    String? categoryId,
    int? hitCount,
  }) => CategoryRuleRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    pattern: pattern ?? this.pattern,
    categoryId: categoryId ?? this.categoryId,
    hitCount: hitCount ?? this.hitCount,
  );
  CategoryRuleRow copyWithCompanion(CategoryRulesCompanion data) {
    return CategoryRuleRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRuleRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('pattern: $pattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('hitCount: $hitCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    pattern,
    categoryId,
    hitCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRuleRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.pattern == this.pattern &&
          other.categoryId == this.categoryId &&
          other.hitCount == this.hitCount);
}

class CategoryRulesCompanion extends UpdateCompanion<CategoryRuleRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<String> pattern;
  final Value<String> categoryId;
  final Value<int> hitCount;
  final Value<int> rowid;
  const CategoryRulesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.pattern = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryRulesCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required String pattern,
    required String categoryId,
    this.hitCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       pattern = Value(pattern),
       categoryId = Value(categoryId);
  static Insertable<CategoryRuleRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? pattern,
    Expression<String>? categoryId,
    Expression<int>? hitCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (pattern != null) 'pattern': pattern,
      if (categoryId != null) 'category_id': categoryId,
      if (hitCount != null) 'hit_count': hitCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryRulesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<String>? pattern,
    Value<String>? categoryId,
    Value<int>? hitCount,
    Value<int>? rowid,
  }) {
    return CategoryRulesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      pattern: pattern ?? this.pattern,
      categoryId: categoryId ?? this.categoryId,
      hitCount: hitCount ?? this.hitCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $CategoryRulesTable.$converterclientUpdatedAt.toSql(
          clientUpdatedAt.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $CategoryRulesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $CategoryRulesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $CategoryRulesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRulesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('pattern: $pattern, ')
          ..write('categoryId: $categoryId, ')
          ..write('hitCount: $hitCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthlySummariesTable extends MonthlySummaries
    with TableInfo<$MonthlySummariesTable, MonthlySummaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverSeqMeta = const VerificationMeta(
    'serverSeq',
  );
  @override
  late final GeneratedColumn<int> serverSeq = GeneratedColumn<int>(
    'server_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($MonthlySummariesTable.$converterclientUpdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MonthlySummariesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MonthlySummariesTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> deletedAt =
      GeneratedColumn<String>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MonthlySummariesTable.$converterdeletedAtn);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, Object?>, String>
  stats = GeneratedColumn<String>(
    'stats',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Map<String, Object?>>($MonthlySummariesTable.$converterstats);
  static const VerificationMeta _narrativeMeta = const VerificationMeta(
    'narrative',
  );
  @override
  late final GeneratedColumn<String> narrative = GeneratedColumn<String>(
    'narrative',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataHashMeta = const VerificationMeta(
    'dataHash',
  );
  @override
  late final GeneratedColumn<String> dataHash = GeneratedColumn<String>(
    'data_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiModelMeta = const VerificationMeta(
    'aiModel',
  );
  @override
  late final GeneratedColumn<String> aiModel = GeneratedColumn<String>(
    'ai_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    month,
    stats,
    narrative,
    dataHash,
    aiModel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlySummaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_seq')) {
      context.handle(
        _serverSeqMeta,
        serverSeq.isAcceptableOrUnknown(data['server_seq']!, _serverSeqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('narrative')) {
      context.handle(
        _narrativeMeta,
        narrative.isAcceptableOrUnknown(data['narrative']!, _narrativeMeta),
      );
    }
    if (data.containsKey('data_hash')) {
      context.handle(
        _dataHashMeta,
        dataHash.isAcceptableOrUnknown(data['data_hash']!, _dataHashMeta),
      );
    }
    if (data.containsKey('ai_model')) {
      context.handle(
        _aiModelMeta,
        aiModel.isAcceptableOrUnknown(data['ai_model']!, _aiModelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonthlySummaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlySummaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      serverSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_seq'],
      ),
      clientUpdatedAt: $MonthlySummariesTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      createdAt: $MonthlySummariesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $MonthlySummariesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deletedAt: $MonthlySummariesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      stats: $MonthlySummariesTable.$converterstats.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stats'],
        )!,
      ),
      narrative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrative'],
      ),
      dataHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_hash'],
      ),
      aiModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_model'],
      ),
    );
  }

  @override
  $MonthlySummariesTable createAlias(String alias) {
    return $MonthlySummariesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime, String> $converterdeletedAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
  static TypeConverter<Map<String, Object?>, String> $converterstats =
      const JsonMapConverter();
}

class MonthlySummaryRow extends DataClass
    implements Insertable<MonthlySummaryRow> {
  /// 기기에서 만드는 UUIDv7.
  final String id;

  /// 마지막으로 확인한 서버 버전. 서버에 올린 적이 없으면 0.
  final int version;

  /// 서버가 매긴 변경 순번. 서버에 올린 적이 없으면 null.
  final int? serverSeq;

  /// 기기에서 마지막으로 고친 시각.
  final DateTime clientUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 삭제 표시. 삭제도 다른 기기로 전파된다.
  final DateTime? deletedAt;
  final String ledgerId;

  /// 'YYYY-MM'
  final String month;
  final Map<String, Object?> stats;
  final String? narrative;
  final String? dataHash;
  final String? aiModel;
  const MonthlySummaryRow({
    required this.id,
    required this.version,
    this.serverSeq,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.ledgerId,
    required this.month,
    required this.stats,
    this.narrative,
    this.dataHash,
    this.aiModel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || serverSeq != null) {
      map['server_seq'] = Variable<int>(serverSeq);
    }
    {
      map['client_updated_at'] = Variable<String>(
        $MonthlySummariesTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    {
      map['created_at'] = Variable<String>(
        $MonthlySummariesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $MonthlySummariesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(
        $MonthlySummariesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    map['ledger_id'] = Variable<String>(ledgerId);
    map['month'] = Variable<String>(month);
    {
      map['stats'] = Variable<String>(
        $MonthlySummariesTable.$converterstats.toSql(stats),
      );
    }
    if (!nullToAbsent || narrative != null) {
      map['narrative'] = Variable<String>(narrative);
    }
    if (!nullToAbsent || dataHash != null) {
      map['data_hash'] = Variable<String>(dataHash);
    }
    if (!nullToAbsent || aiModel != null) {
      map['ai_model'] = Variable<String>(aiModel);
    }
    return map;
  }

  MonthlySummariesCompanion toCompanion(bool nullToAbsent) {
    return MonthlySummariesCompanion(
      id: Value(id),
      version: Value(version),
      serverSeq: serverSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(serverSeq),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ledgerId: Value(ledgerId),
      month: Value(month),
      stats: Value(stats),
      narrative: narrative == null && nullToAbsent
          ? const Value.absent()
          : Value(narrative),
      dataHash: dataHash == null && nullToAbsent
          ? const Value.absent()
          : Value(dataHash),
      aiModel: aiModel == null && nullToAbsent
          ? const Value.absent()
          : Value(aiModel),
    );
  }

  factory MonthlySummaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlySummaryRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      serverSeq: serializer.fromJson<int?>(json['serverSeq']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      month: serializer.fromJson<String>(json['month']),
      stats: serializer.fromJson<Map<String, Object?>>(json['stats']),
      narrative: serializer.fromJson<String?>(json['narrative']),
      dataHash: serializer.fromJson<String?>(json['dataHash']),
      aiModel: serializer.fromJson<String?>(json['aiModel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'serverSeq': serializer.toJson<int?>(serverSeq),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'month': serializer.toJson<String>(month),
      'stats': serializer.toJson<Map<String, Object?>>(stats),
      'narrative': serializer.toJson<String?>(narrative),
      'dataHash': serializer.toJson<String?>(dataHash),
      'aiModel': serializer.toJson<String?>(aiModel),
    };
  }

  MonthlySummaryRow copyWith({
    String? id,
    int? version,
    Value<int?> serverSeq = const Value.absent(),
    DateTime? clientUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? ledgerId,
    String? month,
    Map<String, Object?>? stats,
    Value<String?> narrative = const Value.absent(),
    Value<String?> dataHash = const Value.absent(),
    Value<String?> aiModel = const Value.absent(),
  }) => MonthlySummaryRow(
    id: id ?? this.id,
    version: version ?? this.version,
    serverSeq: serverSeq.present ? serverSeq.value : this.serverSeq,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ledgerId: ledgerId ?? this.ledgerId,
    month: month ?? this.month,
    stats: stats ?? this.stats,
    narrative: narrative.present ? narrative.value : this.narrative,
    dataHash: dataHash.present ? dataHash.value : this.dataHash,
    aiModel: aiModel.present ? aiModel.value : this.aiModel,
  );
  MonthlySummaryRow copyWithCompanion(MonthlySummariesCompanion data) {
    return MonthlySummaryRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      serverSeq: data.serverSeq.present ? data.serverSeq.value : this.serverSeq,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      month: data.month.present ? data.month.value : this.month,
      stats: data.stats.present ? data.stats.value : this.stats,
      narrative: data.narrative.present ? data.narrative.value : this.narrative,
      dataHash: data.dataHash.present ? data.dataHash.value : this.dataHash,
      aiModel: data.aiModel.present ? data.aiModel.value : this.aiModel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlySummaryRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('month: $month, ')
          ..write('stats: $stats, ')
          ..write('narrative: $narrative, ')
          ..write('dataHash: $dataHash, ')
          ..write('aiModel: $aiModel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    serverSeq,
    clientUpdatedAt,
    createdAt,
    updatedAt,
    deletedAt,
    ledgerId,
    month,
    stats,
    narrative,
    dataHash,
    aiModel,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlySummaryRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.serverSeq == this.serverSeq &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.ledgerId == this.ledgerId &&
          other.month == this.month &&
          other.stats == this.stats &&
          other.narrative == this.narrative &&
          other.dataHash == this.dataHash &&
          other.aiModel == this.aiModel);
}

class MonthlySummariesCompanion extends UpdateCompanion<MonthlySummaryRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<int?> serverSeq;
  final Value<DateTime> clientUpdatedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> ledgerId;
  final Value<String> month;
  final Value<Map<String, Object?>> stats;
  final Value<String?> narrative;
  final Value<String?> dataHash;
  final Value<String?> aiModel;
  final Value<int> rowid;
  const MonthlySummariesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.month = const Value.absent(),
    this.stats = const Value.absent(),
    this.narrative = const Value.absent(),
    this.dataHash = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthlySummariesCompanion.insert({
    required String id,
    this.version = const Value.absent(),
    this.serverSeq = const Value.absent(),
    required DateTime clientUpdatedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String ledgerId,
    required String month,
    required Map<String, Object?> stats,
    this.narrative = const Value.absent(),
    this.dataHash = const Value.absent(),
    this.aiModel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       ledgerId = Value(ledgerId),
       month = Value(month),
       stats = Value(stats);
  static Insertable<MonthlySummaryRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<int>? serverSeq,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? ledgerId,
    Expression<String>? month,
    Expression<String>? stats,
    Expression<String>? narrative,
    Expression<String>? dataHash,
    Expression<String>? aiModel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (serverSeq != null) 'server_seq': serverSeq,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (month != null) 'month': month,
      if (stats != null) 'stats': stats,
      if (narrative != null) 'narrative': narrative,
      if (dataHash != null) 'data_hash': dataHash,
      if (aiModel != null) 'ai_model': aiModel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthlySummariesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<int?>? serverSeq,
    Value<DateTime>? clientUpdatedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? ledgerId,
    Value<String>? month,
    Value<Map<String, Object?>>? stats,
    Value<String?>? narrative,
    Value<String?>? dataHash,
    Value<String?>? aiModel,
    Value<int>? rowid,
  }) {
    return MonthlySummariesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      serverSeq: serverSeq ?? this.serverSeq,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ledgerId: ledgerId ?? this.ledgerId,
      month: month ?? this.month,
      stats: stats ?? this.stats,
      narrative: narrative ?? this.narrative,
      dataHash: dataHash ?? this.dataHash,
      aiModel: aiModel ?? this.aiModel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverSeq.present) {
      map['server_seq'] = Variable<int>(serverSeq.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $MonthlySummariesTable.$converterclientUpdatedAt.toSql(
          clientUpdatedAt.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $MonthlySummariesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $MonthlySummariesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(
        $MonthlySummariesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (stats.present) {
      map['stats'] = Variable<String>(
        $MonthlySummariesTable.$converterstats.toSql(stats.value),
      );
    }
    if (narrative.present) {
      map['narrative'] = Variable<String>(narrative.value);
    }
    if (dataHash.present) {
      map['data_hash'] = Variable<String>(dataHash.value);
    }
    if (aiModel.present) {
      map['ai_model'] = Variable<String>(aiModel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlySummariesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('serverSeq: $serverSeq, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('month: $month, ')
          ..write('stats: $stats, ')
          ..write('narrative: $narrative, ')
          ..write('dataHash: $dataHash, ')
          ..write('aiModel: $aiModel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String>
  clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DateTime>($OutboxTable.$converterclientUpdatedAt);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    ledgerId,
    targetTable,
    rowId,
    op,
    baseVersion,
    clientUpdatedAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseVersionMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {targetTable, rowId},
  ];
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      )!,
      clientUpdatedAt: $OutboxTable.$converterclientUpdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}client_updated_at'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterclientUpdatedAt =
      const UtcDateTimeConverter();
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int seq;
  final String ledgerId;

  /// 서버 테이블 이름.
  final String targetTable;
  final String rowId;

  /// upsert · delete
  final String op;

  /// 이 변경을 만들 때 알고 있던 서버 버전.
  final int baseVersion;
  final DateTime clientUpdatedAt;

  /// 서버가 거절한 횟수. 여러 번 거절된 변경은 보내기를 멈추고 설정 화면에 알린다.
  final int attempts;
  final String? lastError;
  const OutboxRow({
    required this.seq,
    required this.ledgerId,
    required this.targetTable,
    required this.rowId,
    required this.op,
    required this.baseVersion,
    required this.clientUpdatedAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['ledger_id'] = Variable<String>(ledgerId);
    map['target_table'] = Variable<String>(targetTable);
    map['row_id'] = Variable<String>(rowId);
    map['op'] = Variable<String>(op);
    map['base_version'] = Variable<int>(baseVersion);
    {
      map['client_updated_at'] = Variable<String>(
        $OutboxTable.$converterclientUpdatedAt.toSql(clientUpdatedAt),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      ledgerId: Value(ledgerId),
      targetTable: Value(targetTable),
      rowId: Value(rowId),
      op: Value(op),
      baseVersion: Value(baseVersion),
      clientUpdatedAt: Value(clientUpdatedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      op: serializer.fromJson<String>(json['op']),
      baseVersion: serializer.fromJson<int>(json['baseVersion']),
      clientUpdatedAt: serializer.fromJson<DateTime>(json['clientUpdatedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'targetTable': serializer.toJson<String>(targetTable),
      'rowId': serializer.toJson<String>(rowId),
      'op': serializer.toJson<String>(op),
      'baseVersion': serializer.toJson<int>(baseVersion),
      'clientUpdatedAt': serializer.toJson<DateTime>(clientUpdatedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxRow copyWith({
    int? seq,
    String? ledgerId,
    String? targetTable,
    String? rowId,
    String? op,
    int? baseVersion,
    DateTime? clientUpdatedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxRow(
    seq: seq ?? this.seq,
    ledgerId: ledgerId ?? this.ledgerId,
    targetTable: targetTable ?? this.targetTable,
    rowId: rowId ?? this.rowId,
    op: op ?? this.op,
    baseVersion: baseVersion ?? this.baseVersion,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      op: data.op.present ? data.op.value : this.op,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('seq: $seq, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    ledgerId,
    targetTable,
    rowId,
    op,
    baseVersion,
    clientUpdatedAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.seq == this.seq &&
          other.ledgerId == this.ledgerId &&
          other.targetTable == this.targetTable &&
          other.rowId == this.rowId &&
          other.op == this.op &&
          other.baseVersion == this.baseVersion &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> seq;
  final Value<String> ledgerId;
  final Value<String> targetTable;
  final Value<String> rowId;
  final Value<String> op;
  final Value<int> baseVersion;
  final Value<DateTime> clientUpdatedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.op = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String ledgerId,
    required String targetTable,
    required String rowId,
    required String op,
    required int baseVersion,
    required DateTime clientUpdatedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : ledgerId = Value(ledgerId),
       targetTable = Value(targetTable),
       rowId = Value(rowId),
       op = Value(op),
       baseVersion = Value(baseVersion),
       clientUpdatedAt = Value(clientUpdatedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? ledgerId,
    Expression<String>? targetTable,
    Expression<String>? rowId,
    Expression<String>? op,
    Expression<int>? baseVersion,
    Expression<String>? clientUpdatedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (targetTable != null) 'target_table': targetTable,
      if (rowId != null) 'row_id': rowId,
      if (op != null) 'op': op,
      if (baseVersion != null) 'base_version': baseVersion,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? ledgerId,
    Value<String>? targetTable,
    Value<String>? rowId,
    Value<String>? op,
    Value<int>? baseVersion,
    Value<DateTime>? clientUpdatedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      ledgerId: ledgerId ?? this.ledgerId,
      targetTable: targetTable ?? this.targetTable,
      rowId: rowId ?? this.rowId,
      op: op ?? this.op,
      baseVersion: baseVersion ?? this.baseVersion,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(
        $OutboxTable.$converterclientUpdatedAt.toSql(clientUpdatedAt.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('op: $op, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetTableMeta = const VerificationMeta(
    'targetTable',
  );
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
    'target_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, Object?>, String>
  loser = GeneratedColumn<String>(
    'loser',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Map<String, Object?>>($SyncConflictsTable.$converterloser);
  static const VerificationMeta _loserSideMeta = const VerificationMeta(
    'loserSide',
  );
  @override
  late final GeneratedColumn<String> loserSide = GeneratedColumn<String>(
    'loser_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> detectedAt =
      GeneratedColumn<String>(
        'detected_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($SyncConflictsTable.$converterdetectedAt);
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    ledgerId,
    targetTable,
    rowId,
    loser,
    loserSide,
    detectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
        _targetTableMeta,
        targetTable.isAcceptableOrUnknown(
          data['target_table']!,
          _targetTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('loser_side')) {
      context.handle(
        _loserSideMeta,
        loserSide.isAcceptableOrUnknown(data['loser_side']!, _loserSideMeta),
      );
    } else if (isInserting) {
      context.missing(_loserSideMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      targetTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_table'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      loser: $SyncConflictsTable.$converterloser.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}loser'],
        )!,
      ),
      loserSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loser_side'],
      )!,
      detectedAt: $SyncConflictsTable.$converterdetectedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}detected_at'],
        )!,
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, Object?>, String> $converterloser =
      const JsonMapConverter();
  static TypeConverter<DateTime, String> $converterdetectedAt =
      const UtcDateTimeConverter();
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final int seq;
  final String ledgerId;
  final String targetTable;
  final String rowId;

  /// 진 쪽 행(JSON).
  final Map<String, Object?> loser;

  /// local: 이 기기의 값이 졌다. remote: 다른 기기의 값이 졌다.
  final String loserSide;
  final DateTime detectedAt;
  const SyncConflictRow({
    required this.seq,
    required this.ledgerId,
    required this.targetTable,
    required this.rowId,
    required this.loser,
    required this.loserSide,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['ledger_id'] = Variable<String>(ledgerId);
    map['target_table'] = Variable<String>(targetTable);
    map['row_id'] = Variable<String>(rowId);
    {
      map['loser'] = Variable<String>(
        $SyncConflictsTable.$converterloser.toSql(loser),
      );
    }
    map['loser_side'] = Variable<String>(loserSide);
    {
      map['detected_at'] = Variable<String>(
        $SyncConflictsTable.$converterdetectedAt.toSql(detectedAt),
      );
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      seq: Value(seq),
      ledgerId: Value(ledgerId),
      targetTable: Value(targetTable),
      rowId: Value(rowId),
      loser: Value(loser),
      loserSide: Value(loserSide),
      detectedAt: Value(detectedAt),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      seq: serializer.fromJson<int>(json['seq']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      rowId: serializer.fromJson<String>(json['rowId']),
      loser: serializer.fromJson<Map<String, Object?>>(json['loser']),
      loserSide: serializer.fromJson<String>(json['loserSide']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'targetTable': serializer.toJson<String>(targetTable),
      'rowId': serializer.toJson<String>(rowId),
      'loser': serializer.toJson<Map<String, Object?>>(loser),
      'loserSide': serializer.toJson<String>(loserSide),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  SyncConflictRow copyWith({
    int? seq,
    String? ledgerId,
    String? targetTable,
    String? rowId,
    Map<String, Object?>? loser,
    String? loserSide,
    DateTime? detectedAt,
  }) => SyncConflictRow(
    seq: seq ?? this.seq,
    ledgerId: ledgerId ?? this.ledgerId,
    targetTable: targetTable ?? this.targetTable,
    rowId: rowId ?? this.rowId,
    loser: loser ?? this.loser,
    loserSide: loserSide ?? this.loserSide,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  SyncConflictRow copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      targetTable: data.targetTable.present
          ? data.targetTable.value
          : this.targetTable,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      loser: data.loser.present ? data.loser.value : this.loser,
      loserSide: data.loserSide.present ? data.loserSide.value : this.loserSide,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('seq: $seq, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('loser: $loser, ')
          ..write('loserSide: $loserSide, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    ledgerId,
    targetTable,
    rowId,
    loser,
    loserSide,
    detectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.seq == this.seq &&
          other.ledgerId == this.ledgerId &&
          other.targetTable == this.targetTable &&
          other.rowId == this.rowId &&
          other.loser == this.loser &&
          other.loserSide == this.loserSide &&
          other.detectedAt == this.detectedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<int> seq;
  final Value<String> ledgerId;
  final Value<String> targetTable;
  final Value<String> rowId;
  final Value<Map<String, Object?>> loser;
  final Value<String> loserSide;
  final Value<DateTime> detectedAt;
  const SyncConflictsCompanion({
    this.seq = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.rowId = const Value.absent(),
    this.loser = const Value.absent(),
    this.loserSide = const Value.absent(),
    this.detectedAt = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.seq = const Value.absent(),
    required String ledgerId,
    required String targetTable,
    required String rowId,
    required Map<String, Object?> loser,
    required String loserSide,
    required DateTime detectedAt,
  }) : ledgerId = Value(ledgerId),
       targetTable = Value(targetTable),
       rowId = Value(rowId),
       loser = Value(loser),
       loserSide = Value(loserSide),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflictRow> custom({
    Expression<int>? seq,
    Expression<String>? ledgerId,
    Expression<String>? targetTable,
    Expression<String>? rowId,
    Expression<String>? loser,
    Expression<String>? loserSide,
    Expression<String>? detectedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (targetTable != null) 'target_table': targetTable,
      if (rowId != null) 'row_id': rowId,
      if (loser != null) 'loser': loser,
      if (loserSide != null) 'loser_side': loserSide,
      if (detectedAt != null) 'detected_at': detectedAt,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? seq,
    Value<String>? ledgerId,
    Value<String>? targetTable,
    Value<String>? rowId,
    Value<Map<String, Object?>>? loser,
    Value<String>? loserSide,
    Value<DateTime>? detectedAt,
  }) {
    return SyncConflictsCompanion(
      seq: seq ?? this.seq,
      ledgerId: ledgerId ?? this.ledgerId,
      targetTable: targetTable ?? this.targetTable,
      rowId: rowId ?? this.rowId,
      loser: loser ?? this.loser,
      loserSide: loserSide ?? this.loserSide,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (loser.present) {
      map['loser'] = Variable<String>(
        $SyncConflictsTable.$converterloser.toSql(loser.value),
      );
    }
    if (loserSide.present) {
      map['loser_side'] = Variable<String>(loserSide.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<String>(
        $SyncConflictsTable.$converterdetectedAt.toSql(detectedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('seq: $seq, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('targetTable: $targetTable, ')
          ..write('rowId: $rowId, ')
          ..write('loser: $loser, ')
          ..write('loserSide: $loserSide, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }
}

class $InputBatchesTable extends InputBatches
    with TableInfo<$InputBatchesTable, InputBatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InputBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<String> ledgerId = GeneratedColumn<String>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> createdAt =
      GeneratedColumn<String>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($InputBatchesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<TxSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxSource>($InputBatchesTable.$convertersource);
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> undoneAt =
      GeneratedColumn<String>(
        'undone_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($InputBatchesTable.$converterundoneAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    createdAt,
    source,
    itemCount,
    undoneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'input_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<InputBatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InputBatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InputBatchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_id'],
      )!,
      createdAt: $InputBatchesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      source: $InputBatchesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      undoneAt: $InputBatchesTable.$converterundoneAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}undone_at'],
        ),
      ),
    );
  }

  @override
  $InputBatchesTable createAlias(String alias) {
    return $InputBatchesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $convertercreatedAt =
      const UtcDateTimeConverter();
  static TypeConverter<TxSource, String> $convertersource =
      const TxSourceConverter();
  static TypeConverter<DateTime, String> $converterundoneAt =
      const UtcDateTimeConverter();
  static TypeConverter<DateTime?, String?> $converterundoneAtn =
      NullAwareTypeConverter.wrap($converterundoneAt);
}

class InputBatchRow extends DataClass implements Insertable<InputBatchRow> {
  final String id;
  final String ledgerId;
  final DateTime createdAt;

  /// 어떤 경로로 들어왔는지.
  final TxSource source;
  final int itemCount;

  /// 되돌린 때. null이면 되돌리지 않았다.
  final DateTime? undoneAt;
  const InputBatchRow({
    required this.id,
    required this.ledgerId,
    required this.createdAt,
    required this.source,
    required this.itemCount,
    this.undoneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ledger_id'] = Variable<String>(ledgerId);
    {
      map['created_at'] = Variable<String>(
        $InputBatchesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['source'] = Variable<String>(
        $InputBatchesTable.$convertersource.toSql(source),
      );
    }
    map['item_count'] = Variable<int>(itemCount);
    if (!nullToAbsent || undoneAt != null) {
      map['undone_at'] = Variable<String>(
        $InputBatchesTable.$converterundoneAtn.toSql(undoneAt),
      );
    }
    return map;
  }

  InputBatchesCompanion toCompanion(bool nullToAbsent) {
    return InputBatchesCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      createdAt: Value(createdAt),
      source: Value(source),
      itemCount: Value(itemCount),
      undoneAt: undoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(undoneAt),
    );
  }

  factory InputBatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InputBatchRow(
      id: serializer.fromJson<String>(json['id']),
      ledgerId: serializer.fromJson<String>(json['ledgerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      source: serializer.fromJson<TxSource>(json['source']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      undoneAt: serializer.fromJson<DateTime?>(json['undoneAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ledgerId': serializer.toJson<String>(ledgerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'source': serializer.toJson<TxSource>(source),
      'itemCount': serializer.toJson<int>(itemCount),
      'undoneAt': serializer.toJson<DateTime?>(undoneAt),
    };
  }

  InputBatchRow copyWith({
    String? id,
    String? ledgerId,
    DateTime? createdAt,
    TxSource? source,
    int? itemCount,
    Value<DateTime?> undoneAt = const Value.absent(),
  }) => InputBatchRow(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    createdAt: createdAt ?? this.createdAt,
    source: source ?? this.source,
    itemCount: itemCount ?? this.itemCount,
    undoneAt: undoneAt.present ? undoneAt.value : this.undoneAt,
  );
  InputBatchRow copyWithCompanion(InputBatchesCompanion data) {
    return InputBatchRow(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      source: data.source.present ? data.source.value : this.source,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      undoneAt: data.undoneAt.present ? data.undoneAt.value : this.undoneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InputBatchRow(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('source: $source, ')
          ..write('itemCount: $itemCount, ')
          ..write('undoneAt: $undoneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ledgerId, createdAt, source, itemCount, undoneAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InputBatchRow &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.createdAt == this.createdAt &&
          other.source == this.source &&
          other.itemCount == this.itemCount &&
          other.undoneAt == this.undoneAt);
}

class InputBatchesCompanion extends UpdateCompanion<InputBatchRow> {
  final Value<String> id;
  final Value<String> ledgerId;
  final Value<DateTime> createdAt;
  final Value<TxSource> source;
  final Value<int> itemCount;
  final Value<DateTime?> undoneAt;
  final Value<int> rowid;
  const InputBatchesCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.source = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.undoneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InputBatchesCompanion.insert({
    required String id,
    required String ledgerId,
    required DateTime createdAt,
    required TxSource source,
    required int itemCount,
    this.undoneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ledgerId = Value(ledgerId),
       createdAt = Value(createdAt),
       source = Value(source),
       itemCount = Value(itemCount);
  static Insertable<InputBatchRow> custom({
    Expression<String>? id,
    Expression<String>? ledgerId,
    Expression<String>? createdAt,
    Expression<String>? source,
    Expression<int>? itemCount,
    Expression<String>? undoneAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (createdAt != null) 'created_at': createdAt,
      if (source != null) 'source': source,
      if (itemCount != null) 'item_count': itemCount,
      if (undoneAt != null) 'undone_at': undoneAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InputBatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? ledgerId,
    Value<DateTime>? createdAt,
    Value<TxSource>? source,
    Value<int>? itemCount,
    Value<DateTime?>? undoneAt,
    Value<int>? rowid,
  }) {
    return InputBatchesCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      itemCount: itemCount ?? this.itemCount,
      undoneAt: undoneAt ?? this.undoneAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<String>(ledgerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(
        $InputBatchesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $InputBatchesTable.$convertersource.toSql(source.value),
      );
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (undoneAt.present) {
      map['undone_at'] = Variable<String>(
        $InputBatchesTable.$converterundoneAtn.toSql(undoneAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InputBatchesCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('createdAt: $createdAt, ')
          ..write('source: $source, ')
          ..write('itemCount: $itemCount, ')
          ..write('undoneAt: $undoneAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InputBatchItemsTable extends InputBatchItems
    with TableInfo<$InputBatchItemsTable, InputBatchItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InputBatchItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _txIdMeta = const VerificationMeta('txId');
  @override
  late final GeneratedColumn<String> txId = GeneratedColumn<String>(
    'tx_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> stamp =
      GeneratedColumn<String>(
        'stamp',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($InputBatchItemsTable.$converterstamp);
  @override
  List<GeneratedColumn> get $columns => [batchId, txId, kind, stamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'input_batch_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InputBatchItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('tx_id')) {
      context.handle(
        _txIdMeta,
        txId.isAcceptableOrUnknown(data['tx_id']!, _txIdMeta),
      );
    } else if (isInserting) {
      context.missing(_txIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {batchId, txId};
  @override
  InputBatchItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InputBatchItemRow(
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      )!,
      txId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tx_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      stamp: $InputBatchItemsTable.$converterstamp.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stamp'],
        )!,
      ),
    );
  }

  @override
  $InputBatchItemsTable createAlias(String alias) {
    return $InputBatchItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterstamp =
      const UtcDateTimeConverter();
}

class InputBatchItemRow extends DataClass
    implements Insertable<InputBatchItemRow> {
  final String batchId;
  final String txId;

  /// created: 묶음이 만든 거래. canceled: 묶음이 취소 처리한 원 거래.
  final String kind;

  /// 저장했을 때 그 거래의 client_updated_at. 그 뒤에 고쳤는지 가리는 데 쓴다.
  final DateTime stamp;
  const InputBatchItemRow({
    required this.batchId,
    required this.txId,
    required this.kind,
    required this.stamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['batch_id'] = Variable<String>(batchId);
    map['tx_id'] = Variable<String>(txId);
    map['kind'] = Variable<String>(kind);
    {
      map['stamp'] = Variable<String>(
        $InputBatchItemsTable.$converterstamp.toSql(stamp),
      );
    }
    return map;
  }

  InputBatchItemsCompanion toCompanion(bool nullToAbsent) {
    return InputBatchItemsCompanion(
      batchId: Value(batchId),
      txId: Value(txId),
      kind: Value(kind),
      stamp: Value(stamp),
    );
  }

  factory InputBatchItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InputBatchItemRow(
      batchId: serializer.fromJson<String>(json['batchId']),
      txId: serializer.fromJson<String>(json['txId']),
      kind: serializer.fromJson<String>(json['kind']),
      stamp: serializer.fromJson<DateTime>(json['stamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'batchId': serializer.toJson<String>(batchId),
      'txId': serializer.toJson<String>(txId),
      'kind': serializer.toJson<String>(kind),
      'stamp': serializer.toJson<DateTime>(stamp),
    };
  }

  InputBatchItemRow copyWith({
    String? batchId,
    String? txId,
    String? kind,
    DateTime? stamp,
  }) => InputBatchItemRow(
    batchId: batchId ?? this.batchId,
    txId: txId ?? this.txId,
    kind: kind ?? this.kind,
    stamp: stamp ?? this.stamp,
  );
  InputBatchItemRow copyWithCompanion(InputBatchItemsCompanion data) {
    return InputBatchItemRow(
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      txId: data.txId.present ? data.txId.value : this.txId,
      kind: data.kind.present ? data.kind.value : this.kind,
      stamp: data.stamp.present ? data.stamp.value : this.stamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InputBatchItemRow(')
          ..write('batchId: $batchId, ')
          ..write('txId: $txId, ')
          ..write('kind: $kind, ')
          ..write('stamp: $stamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(batchId, txId, kind, stamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InputBatchItemRow &&
          other.batchId == this.batchId &&
          other.txId == this.txId &&
          other.kind == this.kind &&
          other.stamp == this.stamp);
}

class InputBatchItemsCompanion extends UpdateCompanion<InputBatchItemRow> {
  final Value<String> batchId;
  final Value<String> txId;
  final Value<String> kind;
  final Value<DateTime> stamp;
  final Value<int> rowid;
  const InputBatchItemsCompanion({
    this.batchId = const Value.absent(),
    this.txId = const Value.absent(),
    this.kind = const Value.absent(),
    this.stamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InputBatchItemsCompanion.insert({
    required String batchId,
    required String txId,
    required String kind,
    required DateTime stamp,
    this.rowid = const Value.absent(),
  }) : batchId = Value(batchId),
       txId = Value(txId),
       kind = Value(kind),
       stamp = Value(stamp);
  static Insertable<InputBatchItemRow> custom({
    Expression<String>? batchId,
    Expression<String>? txId,
    Expression<String>? kind,
    Expression<String>? stamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (batchId != null) 'batch_id': batchId,
      if (txId != null) 'tx_id': txId,
      if (kind != null) 'kind': kind,
      if (stamp != null) 'stamp': stamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InputBatchItemsCompanion copyWith({
    Value<String>? batchId,
    Value<String>? txId,
    Value<String>? kind,
    Value<DateTime>? stamp,
    Value<int>? rowid,
  }) {
    return InputBatchItemsCompanion(
      batchId: batchId ?? this.batchId,
      txId: txId ?? this.txId,
      kind: kind ?? this.kind,
      stamp: stamp ?? this.stamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (txId.present) {
      map['tx_id'] = Variable<String>(txId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (stamp.present) {
      map['stamp'] = Variable<String>(
        $InputBatchItemsTable.$converterstamp.toSql(stamp.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InputBatchItemsCompanion(')
          ..write('batchId: $batchId, ')
          ..write('txId: $txId, ')
          ..write('kind: $kind, ')
          ..write('stamp: $stamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelFilesTable extends ModelFiles
    with TableInfo<$ModelFilesTable, ModelFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ModelFilesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    fileName,
    path,
    sizeBytes,
    downloadedBytes,
    sha256,
    status,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelFileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: $ModelFilesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ModelFilesTable createAlias(String alias) {
    return $ModelFilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterupdatedAt =
      const UtcDateTimeConverter();
}

class ModelFileRow extends DataClass implements Insertable<ModelFileRow> {
  /// 카탈로그의 ID.
  final String id;

  /// text · vision · mmproj
  final String kind;
  final String fileName;
  final String path;
  final int sizeBytes;
  final int downloadedBytes;
  final String sha256;

  /// downloading · ready · failed
  final String status;
  final DateTime updatedAt;
  const ModelFileRow({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.downloadedBytes,
    required this.sha256,
    required this.status,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['file_name'] = Variable<String>(fileName);
    map['path'] = Variable<String>(path);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['sha256'] = Variable<String>(sha256);
    map['status'] = Variable<String>(status);
    {
      map['updated_at'] = Variable<String>(
        $ModelFilesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ModelFilesCompanion toCompanion(bool nullToAbsent) {
    return ModelFilesCompanion(
      id: Value(id),
      kind: Value(kind),
      fileName: Value(fileName),
      path: Value(path),
      sizeBytes: Value(sizeBytes),
      downloadedBytes: Value(downloadedBytes),
      sha256: Value(sha256),
      status: Value(status),
      updatedAt: Value(updatedAt),
    );
  }

  factory ModelFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelFileRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      fileName: serializer.fromJson<String>(json['fileName']),
      path: serializer.fromJson<String>(json['path']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      sha256: serializer.fromJson<String>(json['sha256']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'fileName': serializer.toJson<String>(fileName),
      'path': serializer.toJson<String>(path),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'sha256': serializer.toJson<String>(sha256),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ModelFileRow copyWith({
    String? id,
    String? kind,
    String? fileName,
    String? path,
    int? sizeBytes,
    int? downloadedBytes,
    String? sha256,
    String? status,
    DateTime? updatedAt,
  }) => ModelFileRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    fileName: fileName ?? this.fileName,
    path: path ?? this.path,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    sha256: sha256 ?? this.sha256,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ModelFileRow copyWithCompanion(ModelFilesCompanion data) {
    return ModelFileRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      path: data.path.present ? data.path.value : this.path,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelFileRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    fileName,
    path,
    sizeBytes,
    downloadedBytes,
    sha256,
    status,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelFileRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.fileName == this.fileName &&
          other.path == this.path &&
          other.sizeBytes == this.sizeBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.sha256 == this.sha256 &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt);
}

class ModelFilesCompanion extends UpdateCompanion<ModelFileRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> fileName;
  final Value<String> path;
  final Value<int> sizeBytes;
  final Value<int> downloadedBytes;
  final Value<String> sha256;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ModelFilesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.fileName = const Value.absent(),
    this.path = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelFilesCompanion.insert({
    required String id,
    required String kind,
    required String fileName,
    required String path,
    required int sizeBytes,
    this.downloadedBytes = const Value.absent(),
    required String sha256,
    required String status,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       fileName = Value(fileName),
       path = Value(path),
       sizeBytes = Value(sizeBytes),
       sha256 = Value(sha256),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ModelFileRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? fileName,
    Expression<String>? path,
    Expression<int>? sizeBytes,
    Expression<int>? downloadedBytes,
    Expression<String>? sha256,
    Expression<String>? status,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (fileName != null) 'file_name': fileName,
      if (path != null) 'path': path,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (sha256 != null) 'sha256': sha256,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? fileName,
    Value<String>? path,
    Value<int>? sizeBytes,
    Value<int>? downloadedBytes,
    Value<String>? sha256,
    Value<String>? status,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModelFilesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      fileName: fileName ?? this.fileName,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $ModelFilesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelFilesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('fileName: $fileName, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('sha256: $sha256, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LedgersTable ledgers = $LedgersTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $LedgerTransactionsTable ledgerTransactions =
      $LedgerTransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $RecurringRulesTable recurringRules = $RecurringRulesTable(this);
  late final $CategoryRulesTable categoryRules = $CategoryRulesTable(this);
  late final $MonthlySummariesTable monthlySummaries = $MonthlySummariesTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $InputBatchesTable inputBatches = $InputBatchesTable(this);
  late final $InputBatchItemsTable inputBatchItems = $InputBatchItemsTable(
    this,
  );
  late final $ModelFilesTable modelFiles = $ModelFilesTable(this);
  late final Index transactionsLedgerDate = Index(
    'transactions_ledger_date',
    'CREATE INDEX transactions_ledger_date ON transactions (ledger_id, occurred_on)',
  );
  late final Index transactionsLedgerDedup = Index(
    'transactions_ledger_dedup',
    'CREATE INDEX transactions_ledger_dedup ON transactions (ledger_id, dedup_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ledgers,
    profiles,
    accounts,
    categories,
    ledgerTransactions,
    budgets,
    recurringRules,
    categoryRules,
    monthlySummaries,
    outbox,
    syncState,
    syncConflicts,
    inputBatches,
    inputBatchItems,
    modelFiles,
    transactionsLedgerDate,
    transactionsLedgerDedup,
  ];
}

typedef $$LedgersTableCreateCompanionBuilder = LedgersCompanion Function({
  required String id,
  Value<int> version,
  Value<int?> serverSeq,
  required DateTime clientUpdatedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> ownerId,
  required String name,
  Value<String> currency,
  Value<int> rowid,
});
typedef $$LedgersTableUpdateCompanionBuilder = LedgersCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<int?> serverSeq,
  Value<DateTime> clientUpdatedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> ownerId,
  Value<String> name,
  Value<String> currency,
  Value<int> rowid,
});

class $$LedgersTableFilterComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgersTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgersTable> {
  $$LedgersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$LedgersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgersTable,
          LedgerRow,
          $$LedgersTableFilterComposer,
          $$LedgersTableOrderingComposer,
          $$LedgersTableAnnotationComposer,
          $$LedgersTableCreateCompanionBuilder,
          $$LedgersTableUpdateCompanionBuilder,
          (LedgerRow, BaseReferences<_$AppDatabase, $LedgersTable, LedgerRow>),
          LedgerRow,
          PrefetchHooks Function()
        > {
  $$LedgersTableTableManager(_$AppDatabase db, $LedgersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgersCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ownerId: ownerId,
                name: name,
                currency: currency,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> ownerId = const Value.absent(),
                required String name,
                Value<String> currency = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgersCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ownerId: ownerId,
                name: name,
                currency: currency,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgersTable, LedgerRow>(table),
                  BaseReferences<_$AppDatabase, $LedgersTable, LedgerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgersTable,
      LedgerRow,
      $$LedgersTableFilterComposer,
      $$LedgersTableOrderingComposer,
      $$LedgersTableAnnotationComposer,
      $$LedgersTableCreateCompanionBuilder,
      $$LedgersTableUpdateCompanionBuilder,
      (LedgerRow, BaseReferences<_$AppDatabase, $LedgersTable, LedgerRow>),
      LedgerRow,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  Value<int> version,
  Value<int?> serverSeq,
  required DateTime clientUpdatedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String ledgerId,
  Value<String?> displayName,
  Value<int> monthStartDay,
  Value<String?> defaultAccountId,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<int?> serverSeq,
  Value<DateTime> clientUpdatedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> ledgerId,
  Value<String?> displayName,
  Value<int> monthStartDay,
  Value<String?> defaultAccountId,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultAccountId => $composableBuilder(
    column: $table.defaultAccountId,
    builder: (column) => column,
  );
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> monthStartDay = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                displayName: displayName,
                monthStartDay: monthStartDay,
                defaultAccountId: defaultAccountId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                Value<String?> displayName = const Value.absent(),
                Value<int> monthStartDay = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                displayName: displayName,
                monthStartDay: monthStartDay,
                defaultAccountId: defaultAccountId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  Value<int> version,
  Value<int?> serverSeq,
  required DateTime clientUpdatedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String ledgerId,
  required String name,
  required AccountKind kind,
  Value<String?> institution,
  Value<List<String>> matchHints,
  Value<int> openingBalance,
  Value<int?> billingDay,
  Value<String?> paymentAccountId,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<int?> serverSeq,
  Value<DateTime> clientUpdatedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> ledgerId,
  Value<String> name,
  Value<AccountKind> kind,
  Value<String?> institution,
  Value<List<String>> matchHints,
  Value<int> openingBalance,
  Value<int?> billingDay,
  Value<String?> paymentAccountId,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountKind, AccountKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get matchHints => $composableBuilder(
    column: $table.matchHints,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentAccountId => $composableBuilder(
    column: $table.paymentAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchHints => $composableBuilder(
    column: $table.matchHints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentAccountId => $composableBuilder(
    column: $table.paymentAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get matchHints =>
      $composableBuilder(
        column: $table.matchHints,
        builder: (column) => column,
      );

  GeneratedColumn<int> get openingBalance => $composableBuilder(
    column: $table.openingBalance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentAccountId => $composableBuilder(
    column: $table.paymentAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountKind> kind = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<List<String>> matchHints = const Value.absent(),
                Value<int> openingBalance = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<String?> paymentAccountId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                name: name,
                kind: kind,
                institution: institution,
                matchHints: matchHints,
                openingBalance: openingBalance,
                billingDay: billingDay,
                paymentAccountId: paymentAccountId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required String name,
                required AccountKind kind,
                Value<String?> institution = const Value.absent(),
                Value<List<String>> matchHints = const Value.absent(),
                Value<int> openingBalance = const Value.absent(),
                Value<int?> billingDay = const Value.absent(),
                Value<String?> paymentAccountId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                name: name,
                kind: kind,
                institution: institution,
                matchHints: matchHints,
                openingBalance: openingBalance,
                billingDay: billingDay,
                paymentAccountId: paymentAccountId,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, AccountRow>(table),
                  BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  Value<int> version,
  Value<int?> serverSeq,
  required DateTime clientUpdatedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String ledgerId,
  required CategoryKind kind,
  required String name,
  Value<String?> parentId,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<int?> serverSeq,
  Value<DateTime> clientUpdatedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> ledgerId,
  Value<CategoryKind> kind,
  Value<String> name,
  Value<String?> parentId,
  Value<String?> icon,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<CategoryKind> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                kind: kind,
                name: name,
                parentId: parentId,
                icon: icon,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required CategoryKind kind,
                required String name,
                Value<String?> parentId = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                kind: kind,
                name: name,
                parentId: parentId,
                icon: icon,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$AppDatabase, $CategoriesTable, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $$LedgerTransactionsTableCreateCompanionBuilder =
    LedgerTransactionsCompanion Function({
      required String id,
      Value<int> version,
      Value<int?> serverSeq,
      required DateTime clientUpdatedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String ledgerId,
      required TxType type,
      required LocalDate occurredOn,
      Value<String?> occurredTime,
      required int amount,
      Value<String?> currency,
      Value<double?> originalAmount,
      required String accountId,
      Value<String?> toAccountId,
      Value<String?> sender,
      Value<String?> receiver,
      Value<String?> categoryId,
      Value<String?> memo,
      Value<List<String>> tags,
      Value<int?> installmentMonths,
      Value<int?> balanceAfter,
      Value<DateTime?> canceledAt,
      Value<TxSource> source,
      Value<String?> aiModel,
      Value<TxStatus> status,
      Value<String?> dedupKey,
      Value<int> rowid,
    });
typedef $$LedgerTransactionsTableUpdateCompanionBuilder =
    LedgerTransactionsCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<int?> serverSeq,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> ledgerId,
      Value<TxType> type,
      Value<LocalDate> occurredOn,
      Value<String?> occurredTime,
      Value<int> amount,
      Value<String?> currency,
      Value<double?> originalAmount,
      Value<String> accountId,
      Value<String?> toAccountId,
      Value<String?> sender,
      Value<String?> receiver,
      Value<String?> categoryId,
      Value<String?> memo,
      Value<List<String>> tags,
      Value<int?> installmentMonths,
      Value<int?> balanceAfter,
      Value<DateTime?> canceledAt,
      Value<TxSource> source,
      Value<String?> aiModel,
      Value<TxStatus> status,
      Value<String?> dedupKey,
      Value<int> rowid,
    });

class $$LedgerTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxType, TxType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get occurredOn =>
      $composableBuilder(
        column: $table.occurredOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get occurredTime => $composableBuilder(
    column: $table.occurredTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get originalAmount => $composableBuilder(
    column: $table.originalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiver => $composableBuilder(
    column: $table.receiver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get installmentMonths => $composableBuilder(
    column: $table.installmentMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get canceledAt =>
      $composableBuilder(
        column: $table.canceledAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TxSource, TxSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxStatus, TxStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredOn => $composableBuilder(
    column: $table.occurredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredTime => $composableBuilder(
    column: $table.occurredTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get originalAmount => $composableBuilder(
    column: $table.originalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiver => $composableBuilder(
    column: $table.receiver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installmentMonths => $composableBuilder(
    column: $table.installmentMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canceledAt => $composableBuilder(
    column: $table.canceledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupKey => $composableBuilder(
    column: $table.dedupKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerTransactionsTable> {
  $$LedgerTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get occurredOn =>
      $composableBuilder(
        column: $table.occurredOn,
        builder: (column) => column,
      );

  GeneratedColumn<String> get occurredTime => $composableBuilder(
    column: $table.occurredTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get originalAmount => $composableBuilder(
    column: $table.originalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get receiver =>
      $composableBuilder(column: $table.receiver, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get installmentMonths => $composableBuilder(
    column: $table.installmentMonths,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get canceledAt =>
      $composableBuilder(
        column: $table.canceledAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<TxSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get aiModel =>
      $composableBuilder(column: $table.aiModel, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get dedupKey =>
      $composableBuilder(column: $table.dedupKey, builder: (column) => column);
}

class $$LedgerTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerTransactionsTable,
          TxRow,
          $$LedgerTransactionsTableFilterComposer,
          $$LedgerTransactionsTableOrderingComposer,
          $$LedgerTransactionsTableAnnotationComposer,
          $$LedgerTransactionsTableCreateCompanionBuilder,
          $$LedgerTransactionsTableUpdateCompanionBuilder,
          (
            TxRow,
            BaseReferences<_$AppDatabase, $LedgerTransactionsTable, TxRow>,
          ),
          TxRow,
          PrefetchHooks Function()
        > {
  $$LedgerTransactionsTableTableManager(
    _$AppDatabase db,
    $LedgerTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<TxType> type = const Value.absent(),
                Value<LocalDate> occurredOn = const Value.absent(),
                Value<String?> occurredTime = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<double?> originalAmount = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> sender = const Value.absent(),
                Value<String?> receiver = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<int?> installmentMonths = const Value.absent(),
                Value<int?> balanceAfter = const Value.absent(),
                Value<DateTime?> canceledAt = const Value.absent(),
                Value<TxSource> source = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<TxStatus> status = const Value.absent(),
                Value<String?> dedupKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerTransactionsCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                type: type,
                occurredOn: occurredOn,
                occurredTime: occurredTime,
                amount: amount,
                currency: currency,
                originalAmount: originalAmount,
                accountId: accountId,
                toAccountId: toAccountId,
                sender: sender,
                receiver: receiver,
                categoryId: categoryId,
                memo: memo,
                tags: tags,
                installmentMonths: installmentMonths,
                balanceAfter: balanceAfter,
                canceledAt: canceledAt,
                source: source,
                aiModel: aiModel,
                status: status,
                dedupKey: dedupKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required TxType type,
                required LocalDate occurredOn,
                Value<String?> occurredTime = const Value.absent(),
                required int amount,
                Value<String?> currency = const Value.absent(),
                Value<double?> originalAmount = const Value.absent(),
                required String accountId,
                Value<String?> toAccountId = const Value.absent(),
                Value<String?> sender = const Value.absent(),
                Value<String?> receiver = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<int?> installmentMonths = const Value.absent(),
                Value<int?> balanceAfter = const Value.absent(),
                Value<DateTime?> canceledAt = const Value.absent(),
                Value<TxSource> source = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<TxStatus> status = const Value.absent(),
                Value<String?> dedupKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerTransactionsCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                type: type,
                occurredOn: occurredOn,
                occurredTime: occurredTime,
                amount: amount,
                currency: currency,
                originalAmount: originalAmount,
                accountId: accountId,
                toAccountId: toAccountId,
                sender: sender,
                receiver: receiver,
                categoryId: categoryId,
                memo: memo,
                tags: tags,
                installmentMonths: installmentMonths,
                balanceAfter: balanceAfter,
                canceledAt: canceledAt,
                source: source,
                aiModel: aiModel,
                status: status,
                dedupKey: dedupKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerTransactionsTable, TxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LedgerTransactionsTable,
                    TxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerTransactionsTable,
      TxRow,
      $$LedgerTransactionsTableFilterComposer,
      $$LedgerTransactionsTableOrderingComposer,
      $$LedgerTransactionsTableAnnotationComposer,
      $$LedgerTransactionsTableCreateCompanionBuilder,
      $$LedgerTransactionsTableUpdateCompanionBuilder,
      (TxRow, BaseReferences<_$AppDatabase, $LedgerTransactionsTable, TxRow>),
      TxRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required String id,
  Value<int> version,
  Value<int?> serverSeq,
  required DateTime clientUpdatedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String ledgerId,
  required String month,
  Value<String?> categoryId,
  required int amount,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<int?> serverSeq,
  Value<DateTime> clientUpdatedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> ledgerId,
  Value<String> month,
  Value<String?> categoryId,
  Value<int> amount,
  Value<int> rowid,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
          BudgetRow,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                month: month,
                categoryId: categoryId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required String month,
                Value<String?> categoryId = const Value.absent(),
                required int amount,
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                month: month,
                categoryId: categoryId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, BudgetRow>(table),
                  BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
      BudgetRow,
      PrefetchHooks Function()
    >;
typedef $$RecurringRulesTableCreateCompanionBuilder =
    RecurringRulesCompanion Function({
      required String id,
      Value<int> version,
      Value<int?> serverSeq,
      required DateTime clientUpdatedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String ledgerId,
      required Map<String, Object?> template,
      required String frequency,
      Value<int> intervalCount,
      required LocalDate nextRunOn,
      Value<LocalDate?> endOn,
      Value<bool> autoPost,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$RecurringRulesTableUpdateCompanionBuilder =
    RecurringRulesCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<int?> serverSeq,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> ledgerId,
      Value<Map<String, Object?>> template,
      Value<String> frequency,
      Value<int> intervalCount,
      Value<LocalDate> nextRunOn,
      Value<LocalDate?> endOn,
      Value<bool> autoPost,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$RecurringRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, Object?>,
    Map<String, Object>,
    String
  >
  get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get nextRunOn =>
      $composableBuilder(
        column: $table.nextRunOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<LocalDate?, LocalDate, String> get endOn =>
      $composableBuilder(
        column: $table.endOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get autoPost => $composableBuilder(
    column: $table.autoPost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextRunOn => $composableBuilder(
    column: $table.nextRunOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endOn => $composableBuilder(
    column: $table.endOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoPost => $composableBuilder(
    column: $table.autoPost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringRulesTable> {
  $$RecurringRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, Object?>, String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get intervalCount => $composableBuilder(
    column: $table.intervalCount,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<LocalDate, String> get nextRunOn =>
      $composableBuilder(column: $table.nextRunOn, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate?, String> get endOn =>
      $composableBuilder(column: $table.endOn, builder: (column) => column);

  GeneratedColumn<bool> get autoPost =>
      $composableBuilder(column: $table.autoPost, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$RecurringRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringRulesTable,
          RecurringRuleRow,
          $$RecurringRulesTableFilterComposer,
          $$RecurringRulesTableOrderingComposer,
          $$RecurringRulesTableAnnotationComposer,
          $$RecurringRulesTableCreateCompanionBuilder,
          $$RecurringRulesTableUpdateCompanionBuilder,
          (
            RecurringRuleRow,
            BaseReferences<
              _$AppDatabase,
              $RecurringRulesTable,
              RecurringRuleRow
            >,
          ),
          RecurringRuleRow,
          PrefetchHooks Function()
        > {
  $$RecurringRulesTableTableManager(
    _$AppDatabase db,
    $RecurringRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<Map<String, Object?>> template = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<int> intervalCount = const Value.absent(),
                Value<LocalDate> nextRunOn = const Value.absent(),
                Value<LocalDate?> endOn = const Value.absent(),
                Value<bool> autoPost = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringRulesCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                template: template,
                frequency: frequency,
                intervalCount: intervalCount,
                nextRunOn: nextRunOn,
                endOn: endOn,
                autoPost: autoPost,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required Map<String, Object?> template,
                required String frequency,
                Value<int> intervalCount = const Value.absent(),
                required LocalDate nextRunOn,
                Value<LocalDate?> endOn = const Value.absent(),
                Value<bool> autoPost = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringRulesCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                template: template,
                frequency: frequency,
                intervalCount: intervalCount,
                nextRunOn: nextRunOn,
                endOn: endOn,
                autoPost: autoPost,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecurringRulesTable, RecurringRuleRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RecurringRulesTable,
                    RecurringRuleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringRulesTable,
      RecurringRuleRow,
      $$RecurringRulesTableFilterComposer,
      $$RecurringRulesTableOrderingComposer,
      $$RecurringRulesTableAnnotationComposer,
      $$RecurringRulesTableCreateCompanionBuilder,
      $$RecurringRulesTableUpdateCompanionBuilder,
      (
        RecurringRuleRow,
        BaseReferences<_$AppDatabase, $RecurringRulesTable, RecurringRuleRow>,
      ),
      RecurringRuleRow,
      PrefetchHooks Function()
    >;
typedef $$CategoryRulesTableCreateCompanionBuilder =
    CategoryRulesCompanion Function({
      required String id,
      Value<int> version,
      Value<int?> serverSeq,
      required DateTime clientUpdatedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String ledgerId,
      required String pattern,
      required String categoryId,
      Value<int> hitCount,
      Value<int> rowid,
    });
typedef $$CategoryRulesTableUpdateCompanionBuilder =
    CategoryRulesCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<int?> serverSeq,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> ledgerId,
      Value<String> pattern,
      Value<String> categoryId,
      Value<int> hitCount,
      Value<int> rowid,
    });

class $$CategoryRulesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoryRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);
}

class $$CategoryRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryRulesTable,
          CategoryRuleRow,
          $$CategoryRulesTableFilterComposer,
          $$CategoryRulesTableOrderingComposer,
          $$CategoryRulesTableAnnotationComposer,
          $$CategoryRulesTableCreateCompanionBuilder,
          $$CategoryRulesTableUpdateCompanionBuilder,
          (
            CategoryRuleRow,
            BaseReferences<_$AppDatabase, $CategoryRulesTable, CategoryRuleRow>,
          ),
          CategoryRuleRow,
          PrefetchHooks Function()
        > {
  $$CategoryRulesTableTableManager(_$AppDatabase db, $CategoryRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryRulesCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                pattern: pattern,
                categoryId: categoryId,
                hitCount: hitCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required String pattern,
                required String categoryId,
                Value<int> hitCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryRulesCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                pattern: pattern,
                categoryId: categoryId,
                hitCount: hitCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryRulesTable, CategoryRuleRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CategoryRulesTable,
                    CategoryRuleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoryRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryRulesTable,
      CategoryRuleRow,
      $$CategoryRulesTableFilterComposer,
      $$CategoryRulesTableOrderingComposer,
      $$CategoryRulesTableAnnotationComposer,
      $$CategoryRulesTableCreateCompanionBuilder,
      $$CategoryRulesTableUpdateCompanionBuilder,
      (
        CategoryRuleRow,
        BaseReferences<_$AppDatabase, $CategoryRulesTable, CategoryRuleRow>,
      ),
      CategoryRuleRow,
      PrefetchHooks Function()
    >;
typedef $$MonthlySummariesTableCreateCompanionBuilder =
    MonthlySummariesCompanion Function({
      required String id,
      Value<int> version,
      Value<int?> serverSeq,
      required DateTime clientUpdatedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      required String ledgerId,
      required String month,
      required Map<String, Object?> stats,
      Value<String?> narrative,
      Value<String?> dataHash,
      Value<String?> aiModel,
      Value<int> rowid,
    });
typedef $$MonthlySummariesTableUpdateCompanionBuilder =
    MonthlySummariesCompanion Function({
      Value<String> id,
      Value<int> version,
      Value<int?> serverSeq,
      Value<DateTime> clientUpdatedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> ledgerId,
      Value<String> month,
      Value<Map<String, Object?>> stats,
      Value<String?> narrative,
      Value<String?> dataHash,
      Value<String?> aiModel,
      Value<int> rowid,
    });

class $$MonthlySummariesTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, Object?>,
    Map<String, Object>,
    String
  >
  get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataHash => $composableBuilder(
    column: $table.dataHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MonthlySummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSeq => $composableBuilder(
    column: $table.serverSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataHash => $composableBuilder(
    column: $table.dataHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiModel => $composableBuilder(
    column: $table.aiModel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MonthlySummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get serverSeq =>
      $composableBuilder(column: $table.serverSeq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, Object?>, String> get stats =>
      $composableBuilder(column: $table.stats, builder: (column) => column);

  GeneratedColumn<String> get narrative =>
      $composableBuilder(column: $table.narrative, builder: (column) => column);

  GeneratedColumn<String> get dataHash =>
      $composableBuilder(column: $table.dataHash, builder: (column) => column);

  GeneratedColumn<String> get aiModel =>
      $composableBuilder(column: $table.aiModel, builder: (column) => column);
}

class $$MonthlySummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlySummariesTable,
          MonthlySummaryRow,
          $$MonthlySummariesTableFilterComposer,
          $$MonthlySummariesTableOrderingComposer,
          $$MonthlySummariesTableAnnotationComposer,
          $$MonthlySummariesTableCreateCompanionBuilder,
          $$MonthlySummariesTableUpdateCompanionBuilder,
          (
            MonthlySummaryRow,
            BaseReferences<
              _$AppDatabase,
              $MonthlySummariesTable,
              MonthlySummaryRow
            >,
          ),
          MonthlySummaryRow,
          PrefetchHooks Function()
        > {
  $$MonthlySummariesTableTableManager(
    _$AppDatabase db,
    $MonthlySummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlySummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthlySummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthlySummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<Map<String, Object?>> stats = const Value.absent(),
                Value<String?> narrative = const Value.absent(),
                Value<String?> dataHash = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                month: month,
                stats: stats,
                narrative: narrative,
                dataHash: dataHash,
                aiModel: aiModel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> version = const Value.absent(),
                Value<int?> serverSeq = const Value.absent(),
                required DateTime clientUpdatedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String ledgerId,
                required String month,
                required Map<String, Object?> stats,
                Value<String?> narrative = const Value.absent(),
                Value<String?> dataHash = const Value.absent(),
                Value<String?> aiModel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion.insert(
                id: id,
                version: version,
                serverSeq: serverSeq,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                ledgerId: ledgerId,
                month: month,
                stats: stats,
                narrative: narrative,
                dataHash: dataHash,
                aiModel: aiModel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonthlySummariesTable, MonthlySummaryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MonthlySummariesTable,
                    MonthlySummaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MonthlySummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlySummariesTable,
      MonthlySummaryRow,
      $$MonthlySummariesTableFilterComposer,
      $$MonthlySummariesTableOrderingComposer,
      $$MonthlySummariesTableAnnotationComposer,
      $$MonthlySummariesTableCreateCompanionBuilder,
      $$MonthlySummariesTableUpdateCompanionBuilder,
      (
        MonthlySummaryRow,
        BaseReferences<
          _$AppDatabase,
          $MonthlySummariesTable,
          MonthlySummaryRow
        >,
      ),
      MonthlySummaryRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String ledgerId,
  required String targetTable,
  required String rowId,
  required String op,
  required int baseVersion,
  required DateTime clientUpdatedAt,
  Value<int> attempts,
  Value<String?> lastError,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> ledgerId,
  Value<String> targetTable,
  Value<String> rowId,
  Value<String> op,
  Value<int> baseVersion,
  Value<DateTime> clientUpdatedAt,
  Value<int> attempts,
  Value<String?> lastError,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String>
  get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, String> get clientUpdatedAt =>
      $composableBuilder(
        column: $table.clientUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<int> baseVersion = const Value.absent(),
                Value<DateTime> clientUpdatedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                ledgerId: ledgerId,
                targetTable: targetTable,
                rowId: rowId,
                op: op,
                baseVersion: baseVersion,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String ledgerId,
                required String targetTable,
                required String rowId,
                required String op,
                required int baseVersion,
                required DateTime clientUpdatedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                ledgerId: ledgerId,
                targetTable: targetTable,
                rowId: rowId,
                op: op,
                baseVersion: baseVersion,
                clientUpdatedAt: clientUpdatedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> seq,
      required String ledgerId,
      required String targetTable,
      required String rowId,
      required Map<String, Object?> loser,
      required String loserSide,
      required DateTime detectedAt,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> seq,
      Value<String> ledgerId,
      Value<String> targetTable,
      Value<String> rowId,
      Value<Map<String, Object?>> loser,
      Value<String> loserSide,
      Value<DateTime> detectedAt,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, Object?>,
    Map<String, Object>,
    String
  >
  get loser => $composableBuilder(
    column: $table.loser,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get loserSide => $composableBuilder(
    column: $table.loserSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get detectedAt =>
      $composableBuilder(
        column: $table.detectedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loser => $composableBuilder(
    column: $table.loser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loserSide => $composableBuilder(
    column: $table.loserSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
    column: $table.targetTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, Object?>, String> get loser =>
      $composableBuilder(column: $table.loser, builder: (column) => column);

  GeneratedColumn<String> get loserSide =>
      $composableBuilder(column: $table.loserSide, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get detectedAt =>
      $composableBuilder(
        column: $table.detectedAt,
        builder: (column) => column,
      );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflictRow,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<String> targetTable = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<Map<String, Object?>> loser = const Value.absent(),
                Value<String> loserSide = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
              }) => SyncConflictsCompanion(
                seq: seq,
                ledgerId: ledgerId,
                targetTable: targetTable,
                rowId: rowId,
                loser: loser,
                loserSide: loserSide,
                detectedAt: detectedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String ledgerId,
                required String targetTable,
                required String rowId,
                required Map<String, Object?> loser,
                required String loserSide,
                required DateTime detectedAt,
              }) => SyncConflictsCompanion.insert(
                seq: seq,
                ledgerId: ledgerId,
                targetTable: targetTable,
                rowId: rowId,
                loser: loser,
                loserSide: loserSide,
                detectedAt: detectedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflictRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncConflictsTable,
                    SyncConflictRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflictRow,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;
typedef $$InputBatchesTableCreateCompanionBuilder =
    InputBatchesCompanion Function({
      required String id,
      required String ledgerId,
      required DateTime createdAt,
      required TxSource source,
      required int itemCount,
      Value<DateTime?> undoneAt,
      Value<int> rowid,
    });
typedef $$InputBatchesTableUpdateCompanionBuilder =
    InputBatchesCompanion Function({
      Value<String> id,
      Value<String> ledgerId,
      Value<DateTime> createdAt,
      Value<TxSource> source,
      Value<int> itemCount,
      Value<DateTime?> undoneAt,
      Value<int> rowid,
    });

class $$InputBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $InputBatchesTable> {
  $$InputBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TxSource, TxSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get undoneAt =>
      $composableBuilder(
        column: $table.undoneAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$InputBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $InputBatchesTable> {
  $$InputBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get undoneAt => $composableBuilder(
    column: $table.undoneAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InputBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InputBatchesTable> {
  $$InputBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get undoneAt =>
      $composableBuilder(column: $table.undoneAt, builder: (column) => column);
}

class $$InputBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InputBatchesTable,
          InputBatchRow,
          $$InputBatchesTableFilterComposer,
          $$InputBatchesTableOrderingComposer,
          $$InputBatchesTableAnnotationComposer,
          $$InputBatchesTableCreateCompanionBuilder,
          $$InputBatchesTableUpdateCompanionBuilder,
          (
            InputBatchRow,
            BaseReferences<_$AppDatabase, $InputBatchesTable, InputBatchRow>,
          ),
          InputBatchRow,
          PrefetchHooks Function()
        > {
  $$InputBatchesTableTableManager(_$AppDatabase db, $InputBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InputBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InputBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InputBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ledgerId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<TxSource> source = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<DateTime?> undoneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InputBatchesCompanion(
                id: id,
                ledgerId: ledgerId,
                createdAt: createdAt,
                source: source,
                itemCount: itemCount,
                undoneAt: undoneAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ledgerId,
                required DateTime createdAt,
                required TxSource source,
                required int itemCount,
                Value<DateTime?> undoneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InputBatchesCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                createdAt: createdAt,
                source: source,
                itemCount: itemCount,
                undoneAt: undoneAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InputBatchesTable, InputBatchRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $InputBatchesTable,
                    InputBatchRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InputBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InputBatchesTable,
      InputBatchRow,
      $$InputBatchesTableFilterComposer,
      $$InputBatchesTableOrderingComposer,
      $$InputBatchesTableAnnotationComposer,
      $$InputBatchesTableCreateCompanionBuilder,
      $$InputBatchesTableUpdateCompanionBuilder,
      (
        InputBatchRow,
        BaseReferences<_$AppDatabase, $InputBatchesTable, InputBatchRow>,
      ),
      InputBatchRow,
      PrefetchHooks Function()
    >;
typedef $$InputBatchItemsTableCreateCompanionBuilder =
    InputBatchItemsCompanion Function({
      required String batchId,
      required String txId,
      required String kind,
      required DateTime stamp,
      Value<int> rowid,
    });
typedef $$InputBatchItemsTableUpdateCompanionBuilder =
    InputBatchItemsCompanion Function({
      Value<String> batchId,
      Value<String> txId,
      Value<String> kind,
      Value<DateTime> stamp,
      Value<int> rowid,
    });

class $$InputBatchItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InputBatchItemsTable> {
  $$InputBatchItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get txId => $composableBuilder(
    column: $table.txId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get stamp =>
      $composableBuilder(
        column: $table.stamp,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$InputBatchItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InputBatchItemsTable> {
  $$InputBatchItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get txId => $composableBuilder(
    column: $table.txId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stamp => $composableBuilder(
    column: $table.stamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InputBatchItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InputBatchItemsTable> {
  $$InputBatchItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get txId =>
      $composableBuilder(column: $table.txId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get stamp =>
      $composableBuilder(column: $table.stamp, builder: (column) => column);
}

class $$InputBatchItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InputBatchItemsTable,
          InputBatchItemRow,
          $$InputBatchItemsTableFilterComposer,
          $$InputBatchItemsTableOrderingComposer,
          $$InputBatchItemsTableAnnotationComposer,
          $$InputBatchItemsTableCreateCompanionBuilder,
          $$InputBatchItemsTableUpdateCompanionBuilder,
          (
            InputBatchItemRow,
            BaseReferences<
              _$AppDatabase,
              $InputBatchItemsTable,
              InputBatchItemRow
            >,
          ),
          InputBatchItemRow,
          PrefetchHooks Function()
        > {
  $$InputBatchItemsTableTableManager(
    _$AppDatabase db,
    $InputBatchItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InputBatchItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InputBatchItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InputBatchItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> batchId = const Value.absent(),
                Value<String> txId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> stamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InputBatchItemsCompanion(
                batchId: batchId,
                txId: txId,
                kind: kind,
                stamp: stamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String batchId,
                required String txId,
                required String kind,
                required DateTime stamp,
                Value<int> rowid = const Value.absent(),
              }) => InputBatchItemsCompanion.insert(
                batchId: batchId,
                txId: txId,
                kind: kind,
                stamp: stamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InputBatchItemsTable, InputBatchItemRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $InputBatchItemsTable,
                    InputBatchItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InputBatchItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InputBatchItemsTable,
      InputBatchItemRow,
      $$InputBatchItemsTableFilterComposer,
      $$InputBatchItemsTableOrderingComposer,
      $$InputBatchItemsTableAnnotationComposer,
      $$InputBatchItemsTableCreateCompanionBuilder,
      $$InputBatchItemsTableUpdateCompanionBuilder,
      (
        InputBatchItemRow,
        BaseReferences<_$AppDatabase, $InputBatchItemsTable, InputBatchItemRow>,
      ),
      InputBatchItemRow,
      PrefetchHooks Function()
    >;
typedef $$ModelFilesTableCreateCompanionBuilder = ModelFilesCompanion Function({
  required String id,
  required String kind,
  required String fileName,
  required String path,
  required int sizeBytes,
  Value<int> downloadedBytes,
  required String sha256,
  required String status,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ModelFilesTableUpdateCompanionBuilder = ModelFilesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> fileName,
  Value<String> path,
  Value<int> sizeBytes,
  Value<int> downloadedBytes,
  Value<String> sha256,
  Value<String> status,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ModelFilesTableFilterComposer
    extends Composer<_$AppDatabase, $ModelFilesTable> {
  $$ModelFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ModelFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelFilesTable> {
  $$ModelFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelFilesTable> {
  $$ModelFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModelFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelFilesTable,
          ModelFileRow,
          $$ModelFilesTableFilterComposer,
          $$ModelFilesTableOrderingComposer,
          $$ModelFilesTableAnnotationComposer,
          $$ModelFilesTableCreateCompanionBuilder,
          $$ModelFilesTableUpdateCompanionBuilder,
          (
            ModelFileRow,
            BaseReferences<_$AppDatabase, $ModelFilesTable, ModelFileRow>,
          ),
          ModelFileRow,
          PrefetchHooks Function()
        > {
  $$ModelFilesTableTableManager(_$AppDatabase db, $ModelFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelFilesCompanion(
                id: id,
                kind: kind,
                fileName: fileName,
                path: path,
                sizeBytes: sizeBytes,
                downloadedBytes: downloadedBytes,
                sha256: sha256,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String fileName,
                required String path,
                required int sizeBytes,
                Value<int> downloadedBytes = const Value.absent(),
                required String sha256,
                required String status,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelFilesCompanion.insert(
                id: id,
                kind: kind,
                fileName: fileName,
                path: path,
                sizeBytes: sizeBytes,
                downloadedBytes: downloadedBytes,
                sha256: sha256,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelFilesTable, ModelFileRow>(table),
                  BaseReferences<_$AppDatabase, $ModelFilesTable, ModelFileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelFilesTable,
      ModelFileRow,
      $$ModelFilesTableFilterComposer,
      $$ModelFilesTableOrderingComposer,
      $$ModelFilesTableAnnotationComposer,
      $$ModelFilesTableCreateCompanionBuilder,
      $$ModelFilesTableUpdateCompanionBuilder,
      (
        ModelFileRow,
        BaseReferences<_$AppDatabase, $ModelFilesTable, ModelFileRow>,
      ),
      ModelFileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db, _db.ledgers);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$LedgerTransactionsTableTableManager get ledgerTransactions =>
      $$LedgerTransactionsTableTableManager(_db, _db.ledgerTransactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$RecurringRulesTableTableManager get recurringRules =>
      $$RecurringRulesTableTableManager(_db, _db.recurringRules);
  $$CategoryRulesTableTableManager get categoryRules =>
      $$CategoryRulesTableTableManager(_db, _db.categoryRules);
  $$MonthlySummariesTableTableManager get monthlySummaries =>
      $$MonthlySummariesTableTableManager(_db, _db.monthlySummaries);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$InputBatchesTableTableManager get inputBatches =>
      $$InputBatchesTableTableManager(_db, _db.inputBatches);
  $$InputBatchItemsTableTableManager get inputBatchItems =>
      $$InputBatchItemsTableTableManager(_db, _db.inputBatchItems);
  $$ModelFilesTableTableManager get modelFiles =>
      $$ModelFilesTableTableManager(_db, _db.modelFiles);
}
