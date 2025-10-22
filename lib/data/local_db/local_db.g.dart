// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $ThreadsTable extends Threads with TableInfo<$ThreadsTable, Thread> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThreadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageDateMeta = const VerificationMeta(
    'lastMessageDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageDate =
      GeneratedColumn<DateTime>(
        'last_message_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _participantsCacheMeta = const VerificationMeta(
    'participantsCache',
  );
  @override
  late final GeneratedColumn<String> participantsCache =
      GeneratedColumn<String>(
        'participants_cache',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _historyIdMeta = const VerificationMeta(
    'historyId',
  );
  @override
  late final GeneratedColumn<String> historyId = GeneratedColumn<String>(
    'history_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectLatestMeta = const VerificationMeta(
    'subjectLatest',
  );
  @override
  late final GeneratedColumn<String> subjectLatest = GeneratedColumn<String>(
    'subject_latest',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  @override
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snippet,
    lastMessageDate,
    participantsCache,
    historyId,
    subjectLatest,
    messageCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'threads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Thread> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    }
    if (data.containsKey('last_message_date')) {
      context.handle(
        _lastMessageDateMeta,
        lastMessageDate.isAcceptableOrUnknown(
          data['last_message_date']!,
          _lastMessageDateMeta,
        ),
      );
    }
    if (data.containsKey('participants_cache')) {
      context.handle(
        _participantsCacheMeta,
        participantsCache.isAcceptableOrUnknown(
          data['participants_cache']!,
          _participantsCacheMeta,
        ),
      );
    }
    if (data.containsKey('history_id')) {
      context.handle(
        _historyIdMeta,
        historyId.isAcceptableOrUnknown(data['history_id']!, _historyIdMeta),
      );
    }
    if (data.containsKey('subject_latest')) {
      context.handle(
        _subjectLatestMeta,
        subjectLatest.isAcceptableOrUnknown(
          data['subject_latest']!,
          _subjectLatestMeta,
        ),
      );
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Thread map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Thread(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet'],
      ),
      lastMessageDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_date'],
      ),
      participantsCache: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participants_cache'],
      ),
      historyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history_id'],
      ),
      subjectLatest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_latest'],
      ),
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
    );
  }

  @override
  $ThreadsTable createAlias(String alias) {
    return $ThreadsTable(attachedDatabase, alias);
  }
}

class Thread extends DataClass implements Insertable<Thread> {
  final String id;
  final String? snippet;
  final DateTime? lastMessageDate;
  final String? participantsCache;
  final String? historyId;
  final String? subjectLatest;
  final int messageCount;
  const Thread({
    required this.id,
    this.snippet,
    this.lastMessageDate,
    this.participantsCache,
    this.historyId,
    this.subjectLatest,
    required this.messageCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || snippet != null) {
      map['snippet'] = Variable<String>(snippet);
    }
    if (!nullToAbsent || lastMessageDate != null) {
      map['last_message_date'] = Variable<DateTime>(lastMessageDate);
    }
    if (!nullToAbsent || participantsCache != null) {
      map['participants_cache'] = Variable<String>(participantsCache);
    }
    if (!nullToAbsent || historyId != null) {
      map['history_id'] = Variable<String>(historyId);
    }
    if (!nullToAbsent || subjectLatest != null) {
      map['subject_latest'] = Variable<String>(subjectLatest);
    }
    map['message_count'] = Variable<int>(messageCount);
    return map;
  }

  ThreadsCompanion toCompanion(bool nullToAbsent) {
    return ThreadsCompanion(
      id: Value(id),
      snippet: snippet == null && nullToAbsent
          ? const Value.absent()
          : Value(snippet),
      lastMessageDate: lastMessageDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageDate),
      participantsCache: participantsCache == null && nullToAbsent
          ? const Value.absent()
          : Value(participantsCache),
      historyId: historyId == null && nullToAbsent
          ? const Value.absent()
          : Value(historyId),
      subjectLatest: subjectLatest == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectLatest),
      messageCount: Value(messageCount),
    );
  }

  factory Thread.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Thread(
      id: serializer.fromJson<String>(json['id']),
      snippet: serializer.fromJson<String?>(json['snippet']),
      lastMessageDate: serializer.fromJson<DateTime?>(json['lastMessageDate']),
      participantsCache: serializer.fromJson<String?>(
        json['participantsCache'],
      ),
      historyId: serializer.fromJson<String?>(json['historyId']),
      subjectLatest: serializer.fromJson<String?>(json['subjectLatest']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'snippet': serializer.toJson<String?>(snippet),
      'lastMessageDate': serializer.toJson<DateTime?>(lastMessageDate),
      'participantsCache': serializer.toJson<String?>(participantsCache),
      'historyId': serializer.toJson<String?>(historyId),
      'subjectLatest': serializer.toJson<String?>(subjectLatest),
      'messageCount': serializer.toJson<int>(messageCount),
    };
  }

  Thread copyWith({
    String? id,
    Value<String?> snippet = const Value.absent(),
    Value<DateTime?> lastMessageDate = const Value.absent(),
    Value<String?> participantsCache = const Value.absent(),
    Value<String?> historyId = const Value.absent(),
    Value<String?> subjectLatest = const Value.absent(),
    int? messageCount,
  }) => Thread(
    id: id ?? this.id,
    snippet: snippet.present ? snippet.value : this.snippet,
    lastMessageDate: lastMessageDate.present
        ? lastMessageDate.value
        : this.lastMessageDate,
    participantsCache: participantsCache.present
        ? participantsCache.value
        : this.participantsCache,
    historyId: historyId.present ? historyId.value : this.historyId,
    subjectLatest: subjectLatest.present
        ? subjectLatest.value
        : this.subjectLatest,
    messageCount: messageCount ?? this.messageCount,
  );
  Thread copyWithCompanion(ThreadsCompanion data) {
    return Thread(
      id: data.id.present ? data.id.value : this.id,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      lastMessageDate: data.lastMessageDate.present
          ? data.lastMessageDate.value
          : this.lastMessageDate,
      participantsCache: data.participantsCache.present
          ? data.participantsCache.value
          : this.participantsCache,
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      subjectLatest: data.subjectLatest.present
          ? data.subjectLatest.value
          : this.subjectLatest,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Thread(')
          ..write('id: $id, ')
          ..write('snippet: $snippet, ')
          ..write('lastMessageDate: $lastMessageDate, ')
          ..write('participantsCache: $participantsCache, ')
          ..write('historyId: $historyId, ')
          ..write('subjectLatest: $subjectLatest, ')
          ..write('messageCount: $messageCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snippet,
    lastMessageDate,
    participantsCache,
    historyId,
    subjectLatest,
    messageCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Thread &&
          other.id == this.id &&
          other.snippet == this.snippet &&
          other.lastMessageDate == this.lastMessageDate &&
          other.participantsCache == this.participantsCache &&
          other.historyId == this.historyId &&
          other.subjectLatest == this.subjectLatest &&
          other.messageCount == this.messageCount);
}

class ThreadsCompanion extends UpdateCompanion<Thread> {
  final Value<String> id;
  final Value<String?> snippet;
  final Value<DateTime?> lastMessageDate;
  final Value<String?> participantsCache;
  final Value<String?> historyId;
  final Value<String?> subjectLatest;
  final Value<int> messageCount;
  final Value<int> rowid;
  const ThreadsCompanion({
    this.id = const Value.absent(),
    this.snippet = const Value.absent(),
    this.lastMessageDate = const Value.absent(),
    this.participantsCache = const Value.absent(),
    this.historyId = const Value.absent(),
    this.subjectLatest = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThreadsCompanion.insert({
    required String id,
    this.snippet = const Value.absent(),
    this.lastMessageDate = const Value.absent(),
    this.participantsCache = const Value.absent(),
    this.historyId = const Value.absent(),
    this.subjectLatest = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Thread> custom({
    Expression<String>? id,
    Expression<String>? snippet,
    Expression<DateTime>? lastMessageDate,
    Expression<String>? participantsCache,
    Expression<String>? historyId,
    Expression<String>? subjectLatest,
    Expression<int>? messageCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snippet != null) 'snippet': snippet,
      if (lastMessageDate != null) 'last_message_date': lastMessageDate,
      if (participantsCache != null) 'participants_cache': participantsCache,
      if (historyId != null) 'history_id': historyId,
      if (subjectLatest != null) 'subject_latest': subjectLatest,
      if (messageCount != null) 'message_count': messageCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThreadsCompanion copyWith({
    Value<String>? id,
    Value<String?>? snippet,
    Value<DateTime?>? lastMessageDate,
    Value<String?>? participantsCache,
    Value<String?>? historyId,
    Value<String?>? subjectLatest,
    Value<int>? messageCount,
    Value<int>? rowid,
  }) {
    return ThreadsCompanion(
      id: id ?? this.id,
      snippet: snippet ?? this.snippet,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      participantsCache: participantsCache ?? this.participantsCache,
      historyId: historyId ?? this.historyId,
      subjectLatest: subjectLatest ?? this.subjectLatest,
      messageCount: messageCount ?? this.messageCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (lastMessageDate.present) {
      map['last_message_date'] = Variable<DateTime>(lastMessageDate.value);
    }
    if (participantsCache.present) {
      map['participants_cache'] = Variable<String>(participantsCache.value);
    }
    if (historyId.present) {
      map['history_id'] = Variable<String>(historyId.value);
    }
    if (subjectLatest.present) {
      map['subject_latest'] = Variable<String>(subjectLatest.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThreadsCompanion(')
          ..write('id: $id, ')
          ..write('snippet: $snippet, ')
          ..write('lastMessageDate: $lastMessageDate, ')
          ..write('participantsCache: $participantsCache, ')
          ..write('historyId: $historyId, ')
          ..write('subjectLatest: $subjectLatest, ')
          ..write('messageCount: $messageCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _internalDateMeta = const VerificationMeta(
    'internalDate',
  );
  @override
  late final GeneratedColumn<DateTime> internalDate = GeneratedColumn<DateTime>(
    'internal_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromMeta = const VerificationMeta('from');
  @override
  late final GeneratedColumn<String> from = GeneratedColumn<String>(
    'from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toMeta = const VerificationMeta('to');
  @override
  late final GeneratedColumn<String> to = GeneratedColumn<String>(
    'to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyPlainMeta = const VerificationMeta(
    'bodyPlain',
  );
  @override
  late final GeneratedColumn<String> bodyPlain = GeneratedColumn<String>(
    'body_plain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyHtmlMeta = const VerificationMeta(
    'bodyHtml',
  );
  @override
  late final GeneratedColumn<String> bodyHtml = GeneratedColumn<String>(
    'body_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelIdsCsvMeta = const VerificationMeta(
    'labelIdsCsv',
  );
  @override
  late final GeneratedColumn<String> labelIdsCsv = GeneratedColumn<String>(
    'label_ids_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _historyIdMeta = const VerificationMeta(
    'historyId',
  );
  @override
  late final GeneratedColumn<String> historyId = GeneratedColumn<String>(
    'history_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isUnreadMeta = const VerificationMeta(
    'isUnread',
  );
  @override
  late final GeneratedColumn<bool> isUnread = GeneratedColumn<bool>(
    'is_unread',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_unread" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _ccCsvMeta = const VerificationMeta('ccCsv');
  @override
  late final GeneratedColumn<String> ccCsv = GeneratedColumn<String>(
    'cc_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bccCsvMeta = const VerificationMeta('bccCsv');
  @override
  late final GeneratedColumn<String> bccCsv = GeneratedColumn<String>(
    'bcc_csv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<int> direction = GeneratedColumn<int>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _indexInThreadMeta = const VerificationMeta(
    'indexInThread',
  );
  @override
  late final GeneratedColumn<int> indexInThread = GeneratedColumn<int>(
    'index_in_thread',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _counterpartEmailMeta = const VerificationMeta(
    'counterpartEmail',
  );
  @override
  late final GeneratedColumn<String> counterpartEmail = GeneratedColumn<String>(
    'counterpart_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    threadId,
    internalDate,
    from,
    to,
    subject,
    snippet,
    bodyPlain,
    bodyHtml,
    labelIdsCsv,
    historyId,
    isUnread,
    ccCsv,
    bccCsv,
    hasAttachments,
    direction,
    indexInThread,
    counterpartEmail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_threadIdMeta);
    }
    if (data.containsKey('internal_date')) {
      context.handle(
        _internalDateMeta,
        internalDate.isAcceptableOrUnknown(
          data['internal_date']!,
          _internalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_internalDateMeta);
    }
    if (data.containsKey('from')) {
      context.handle(
        _fromMeta,
        from.isAcceptableOrUnknown(data['from']!, _fromMeta),
      );
    }
    if (data.containsKey('to')) {
      context.handle(_toMeta, to.isAcceptableOrUnknown(data['to']!, _toMeta));
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    }
    if (data.containsKey('body_plain')) {
      context.handle(
        _bodyPlainMeta,
        bodyPlain.isAcceptableOrUnknown(data['body_plain']!, _bodyPlainMeta),
      );
    }
    if (data.containsKey('body_html')) {
      context.handle(
        _bodyHtmlMeta,
        bodyHtml.isAcceptableOrUnknown(data['body_html']!, _bodyHtmlMeta),
      );
    }
    if (data.containsKey('label_ids_csv')) {
      context.handle(
        _labelIdsCsvMeta,
        labelIdsCsv.isAcceptableOrUnknown(
          data['label_ids_csv']!,
          _labelIdsCsvMeta,
        ),
      );
    }
    if (data.containsKey('history_id')) {
      context.handle(
        _historyIdMeta,
        historyId.isAcceptableOrUnknown(data['history_id']!, _historyIdMeta),
      );
    }
    if (data.containsKey('is_unread')) {
      context.handle(
        _isUnreadMeta,
        isUnread.isAcceptableOrUnknown(data['is_unread']!, _isUnreadMeta),
      );
    }
    if (data.containsKey('cc_csv')) {
      context.handle(
        _ccCsvMeta,
        ccCsv.isAcceptableOrUnknown(data['cc_csv']!, _ccCsvMeta),
      );
    }
    if (data.containsKey('bcc_csv')) {
      context.handle(
        _bccCsvMeta,
        bccCsv.isAcceptableOrUnknown(data['bcc_csv']!, _bccCsvMeta),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    }
    if (data.containsKey('index_in_thread')) {
      context.handle(
        _indexInThreadMeta,
        indexInThread.isAcceptableOrUnknown(
          data['index_in_thread']!,
          _indexInThreadMeta,
        ),
      );
    }
    if (data.containsKey('counterpart_email')) {
      context.handle(
        _counterpartEmailMeta,
        counterpartEmail.isAcceptableOrUnknown(
          data['counterpart_email']!,
          _counterpartEmailMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      )!,
      internalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}internal_date'],
      )!,
      from: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from'],
      ),
      to: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      snippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet'],
      ),
      bodyPlain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_plain'],
      ),
      bodyHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_html'],
      ),
      labelIdsCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_ids_csv'],
      ),
      historyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history_id'],
      ),
      isUnread: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_unread'],
      )!,
      ccCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc_csv'],
      ),
      bccCsv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bcc_csv'],
      ),
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direction'],
      )!,
      indexInThread: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index_in_thread'],
      )!,
      counterpartEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterpart_email'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String threadId;
  final DateTime internalDate;
  final String? from;
  final String? to;
  final String? subject;
  final String? snippet;
  final String? bodyPlain;
  final String? bodyHtml;
  final String? labelIdsCsv;
  final String? historyId;
  final bool isUnread;
  final String? ccCsv;
  final String? bccCsv;
  final bool hasAttachments;
  final int direction;
  final int indexInThread;

  /// 人ごと一覧用：相手のメールアドレス（正規化）
  final String? counterpartEmail;
  const Message({
    required this.id,
    required this.threadId,
    required this.internalDate,
    this.from,
    this.to,
    this.subject,
    this.snippet,
    this.bodyPlain,
    this.bodyHtml,
    this.labelIdsCsv,
    this.historyId,
    required this.isUnread,
    this.ccCsv,
    this.bccCsv,
    required this.hasAttachments,
    required this.direction,
    required this.indexInThread,
    this.counterpartEmail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['thread_id'] = Variable<String>(threadId);
    map['internal_date'] = Variable<DateTime>(internalDate);
    if (!nullToAbsent || from != null) {
      map['from'] = Variable<String>(from);
    }
    if (!nullToAbsent || to != null) {
      map['to'] = Variable<String>(to);
    }
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || snippet != null) {
      map['snippet'] = Variable<String>(snippet);
    }
    if (!nullToAbsent || bodyPlain != null) {
      map['body_plain'] = Variable<String>(bodyPlain);
    }
    if (!nullToAbsent || bodyHtml != null) {
      map['body_html'] = Variable<String>(bodyHtml);
    }
    if (!nullToAbsent || labelIdsCsv != null) {
      map['label_ids_csv'] = Variable<String>(labelIdsCsv);
    }
    if (!nullToAbsent || historyId != null) {
      map['history_id'] = Variable<String>(historyId);
    }
    map['is_unread'] = Variable<bool>(isUnread);
    if (!nullToAbsent || ccCsv != null) {
      map['cc_csv'] = Variable<String>(ccCsv);
    }
    if (!nullToAbsent || bccCsv != null) {
      map['bcc_csv'] = Variable<String>(bccCsv);
    }
    map['has_attachments'] = Variable<bool>(hasAttachments);
    map['direction'] = Variable<int>(direction);
    map['index_in_thread'] = Variable<int>(indexInThread);
    if (!nullToAbsent || counterpartEmail != null) {
      map['counterpart_email'] = Variable<String>(counterpartEmail);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      threadId: Value(threadId),
      internalDate: Value(internalDate),
      from: from == null && nullToAbsent ? const Value.absent() : Value(from),
      to: to == null && nullToAbsent ? const Value.absent() : Value(to),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      snippet: snippet == null && nullToAbsent
          ? const Value.absent()
          : Value(snippet),
      bodyPlain: bodyPlain == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyPlain),
      bodyHtml: bodyHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyHtml),
      labelIdsCsv: labelIdsCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(labelIdsCsv),
      historyId: historyId == null && nullToAbsent
          ? const Value.absent()
          : Value(historyId),
      isUnread: Value(isUnread),
      ccCsv: ccCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(ccCsv),
      bccCsv: bccCsv == null && nullToAbsent
          ? const Value.absent()
          : Value(bccCsv),
      hasAttachments: Value(hasAttachments),
      direction: Value(direction),
      indexInThread: Value(indexInThread),
      counterpartEmail: counterpartEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(counterpartEmail),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      threadId: serializer.fromJson<String>(json['threadId']),
      internalDate: serializer.fromJson<DateTime>(json['internalDate']),
      from: serializer.fromJson<String?>(json['from']),
      to: serializer.fromJson<String?>(json['to']),
      subject: serializer.fromJson<String?>(json['subject']),
      snippet: serializer.fromJson<String?>(json['snippet']),
      bodyPlain: serializer.fromJson<String?>(json['bodyPlain']),
      bodyHtml: serializer.fromJson<String?>(json['bodyHtml']),
      labelIdsCsv: serializer.fromJson<String?>(json['labelIdsCsv']),
      historyId: serializer.fromJson<String?>(json['historyId']),
      isUnread: serializer.fromJson<bool>(json['isUnread']),
      ccCsv: serializer.fromJson<String?>(json['ccCsv']),
      bccCsv: serializer.fromJson<String?>(json['bccCsv']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      direction: serializer.fromJson<int>(json['direction']),
      indexInThread: serializer.fromJson<int>(json['indexInThread']),
      counterpartEmail: serializer.fromJson<String?>(json['counterpartEmail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'threadId': serializer.toJson<String>(threadId),
      'internalDate': serializer.toJson<DateTime>(internalDate),
      'from': serializer.toJson<String?>(from),
      'to': serializer.toJson<String?>(to),
      'subject': serializer.toJson<String?>(subject),
      'snippet': serializer.toJson<String?>(snippet),
      'bodyPlain': serializer.toJson<String?>(bodyPlain),
      'bodyHtml': serializer.toJson<String?>(bodyHtml),
      'labelIdsCsv': serializer.toJson<String?>(labelIdsCsv),
      'historyId': serializer.toJson<String?>(historyId),
      'isUnread': serializer.toJson<bool>(isUnread),
      'ccCsv': serializer.toJson<String?>(ccCsv),
      'bccCsv': serializer.toJson<String?>(bccCsv),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'direction': serializer.toJson<int>(direction),
      'indexInThread': serializer.toJson<int>(indexInThread),
      'counterpartEmail': serializer.toJson<String?>(counterpartEmail),
    };
  }

  Message copyWith({
    String? id,
    String? threadId,
    DateTime? internalDate,
    Value<String?> from = const Value.absent(),
    Value<String?> to = const Value.absent(),
    Value<String?> subject = const Value.absent(),
    Value<String?> snippet = const Value.absent(),
    Value<String?> bodyPlain = const Value.absent(),
    Value<String?> bodyHtml = const Value.absent(),
    Value<String?> labelIdsCsv = const Value.absent(),
    Value<String?> historyId = const Value.absent(),
    bool? isUnread,
    Value<String?> ccCsv = const Value.absent(),
    Value<String?> bccCsv = const Value.absent(),
    bool? hasAttachments,
    int? direction,
    int? indexInThread,
    Value<String?> counterpartEmail = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    internalDate: internalDate ?? this.internalDate,
    from: from.present ? from.value : this.from,
    to: to.present ? to.value : this.to,
    subject: subject.present ? subject.value : this.subject,
    snippet: snippet.present ? snippet.value : this.snippet,
    bodyPlain: bodyPlain.present ? bodyPlain.value : this.bodyPlain,
    bodyHtml: bodyHtml.present ? bodyHtml.value : this.bodyHtml,
    labelIdsCsv: labelIdsCsv.present ? labelIdsCsv.value : this.labelIdsCsv,
    historyId: historyId.present ? historyId.value : this.historyId,
    isUnread: isUnread ?? this.isUnread,
    ccCsv: ccCsv.present ? ccCsv.value : this.ccCsv,
    bccCsv: bccCsv.present ? bccCsv.value : this.bccCsv,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    direction: direction ?? this.direction,
    indexInThread: indexInThread ?? this.indexInThread,
    counterpartEmail: counterpartEmail.present
        ? counterpartEmail.value
        : this.counterpartEmail,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      internalDate: data.internalDate.present
          ? data.internalDate.value
          : this.internalDate,
      from: data.from.present ? data.from.value : this.from,
      to: data.to.present ? data.to.value : this.to,
      subject: data.subject.present ? data.subject.value : this.subject,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      bodyPlain: data.bodyPlain.present ? data.bodyPlain.value : this.bodyPlain,
      bodyHtml: data.bodyHtml.present ? data.bodyHtml.value : this.bodyHtml,
      labelIdsCsv: data.labelIdsCsv.present
          ? data.labelIdsCsv.value
          : this.labelIdsCsv,
      historyId: data.historyId.present ? data.historyId.value : this.historyId,
      isUnread: data.isUnread.present ? data.isUnread.value : this.isUnread,
      ccCsv: data.ccCsv.present ? data.ccCsv.value : this.ccCsv,
      bccCsv: data.bccCsv.present ? data.bccCsv.value : this.bccCsv,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      direction: data.direction.present ? data.direction.value : this.direction,
      indexInThread: data.indexInThread.present
          ? data.indexInThread.value
          : this.indexInThread,
      counterpartEmail: data.counterpartEmail.present
          ? data.counterpartEmail.value
          : this.counterpartEmail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('internalDate: $internalDate, ')
          ..write('from: $from, ')
          ..write('to: $to, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('bodyPlain: $bodyPlain, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('labelIdsCsv: $labelIdsCsv, ')
          ..write('historyId: $historyId, ')
          ..write('isUnread: $isUnread, ')
          ..write('ccCsv: $ccCsv, ')
          ..write('bccCsv: $bccCsv, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('direction: $direction, ')
          ..write('indexInThread: $indexInThread, ')
          ..write('counterpartEmail: $counterpartEmail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    threadId,
    internalDate,
    from,
    to,
    subject,
    snippet,
    bodyPlain,
    bodyHtml,
    labelIdsCsv,
    historyId,
    isUnread,
    ccCsv,
    bccCsv,
    hasAttachments,
    direction,
    indexInThread,
    counterpartEmail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.threadId == this.threadId &&
          other.internalDate == this.internalDate &&
          other.from == this.from &&
          other.to == this.to &&
          other.subject == this.subject &&
          other.snippet == this.snippet &&
          other.bodyPlain == this.bodyPlain &&
          other.bodyHtml == this.bodyHtml &&
          other.labelIdsCsv == this.labelIdsCsv &&
          other.historyId == this.historyId &&
          other.isUnread == this.isUnread &&
          other.ccCsv == this.ccCsv &&
          other.bccCsv == this.bccCsv &&
          other.hasAttachments == this.hasAttachments &&
          other.direction == this.direction &&
          other.indexInThread == this.indexInThread &&
          other.counterpartEmail == this.counterpartEmail);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> threadId;
  final Value<DateTime> internalDate;
  final Value<String?> from;
  final Value<String?> to;
  final Value<String?> subject;
  final Value<String?> snippet;
  final Value<String?> bodyPlain;
  final Value<String?> bodyHtml;
  final Value<String?> labelIdsCsv;
  final Value<String?> historyId;
  final Value<bool> isUnread;
  final Value<String?> ccCsv;
  final Value<String?> bccCsv;
  final Value<bool> hasAttachments;
  final Value<int> direction;
  final Value<int> indexInThread;
  final Value<String?> counterpartEmail;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.threadId = const Value.absent(),
    this.internalDate = const Value.absent(),
    this.from = const Value.absent(),
    this.to = const Value.absent(),
    this.subject = const Value.absent(),
    this.snippet = const Value.absent(),
    this.bodyPlain = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.labelIdsCsv = const Value.absent(),
    this.historyId = const Value.absent(),
    this.isUnread = const Value.absent(),
    this.ccCsv = const Value.absent(),
    this.bccCsv = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.direction = const Value.absent(),
    this.indexInThread = const Value.absent(),
    this.counterpartEmail = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String threadId,
    required DateTime internalDate,
    this.from = const Value.absent(),
    this.to = const Value.absent(),
    this.subject = const Value.absent(),
    this.snippet = const Value.absent(),
    this.bodyPlain = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.labelIdsCsv = const Value.absent(),
    this.historyId = const Value.absent(),
    this.isUnread = const Value.absent(),
    this.ccCsv = const Value.absent(),
    this.bccCsv = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.direction = const Value.absent(),
    this.indexInThread = const Value.absent(),
    this.counterpartEmail = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       threadId = Value(threadId),
       internalDate = Value(internalDate);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? threadId,
    Expression<DateTime>? internalDate,
    Expression<String>? from,
    Expression<String>? to,
    Expression<String>? subject,
    Expression<String>? snippet,
    Expression<String>? bodyPlain,
    Expression<String>? bodyHtml,
    Expression<String>? labelIdsCsv,
    Expression<String>? historyId,
    Expression<bool>? isUnread,
    Expression<String>? ccCsv,
    Expression<String>? bccCsv,
    Expression<bool>? hasAttachments,
    Expression<int>? direction,
    Expression<int>? indexInThread,
    Expression<String>? counterpartEmail,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadId != null) 'thread_id': threadId,
      if (internalDate != null) 'internal_date': internalDate,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (subject != null) 'subject': subject,
      if (snippet != null) 'snippet': snippet,
      if (bodyPlain != null) 'body_plain': bodyPlain,
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (labelIdsCsv != null) 'label_ids_csv': labelIdsCsv,
      if (historyId != null) 'history_id': historyId,
      if (isUnread != null) 'is_unread': isUnread,
      if (ccCsv != null) 'cc_csv': ccCsv,
      if (bccCsv != null) 'bcc_csv': bccCsv,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (direction != null) 'direction': direction,
      if (indexInThread != null) 'index_in_thread': indexInThread,
      if (counterpartEmail != null) 'counterpart_email': counterpartEmail,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? threadId,
    Value<DateTime>? internalDate,
    Value<String?>? from,
    Value<String?>? to,
    Value<String?>? subject,
    Value<String?>? snippet,
    Value<String?>? bodyPlain,
    Value<String?>? bodyHtml,
    Value<String?>? labelIdsCsv,
    Value<String?>? historyId,
    Value<bool>? isUnread,
    Value<String?>? ccCsv,
    Value<String?>? bccCsv,
    Value<bool>? hasAttachments,
    Value<int>? direction,
    Value<int>? indexInThread,
    Value<String?>? counterpartEmail,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      internalDate: internalDate ?? this.internalDate,
      from: from ?? this.from,
      to: to ?? this.to,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      bodyPlain: bodyPlain ?? this.bodyPlain,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      labelIdsCsv: labelIdsCsv ?? this.labelIdsCsv,
      historyId: historyId ?? this.historyId,
      isUnread: isUnread ?? this.isUnread,
      ccCsv: ccCsv ?? this.ccCsv,
      bccCsv: bccCsv ?? this.bccCsv,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      direction: direction ?? this.direction,
      indexInThread: indexInThread ?? this.indexInThread,
      counterpartEmail: counterpartEmail ?? this.counterpartEmail,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (internalDate.present) {
      map['internal_date'] = Variable<DateTime>(internalDate.value);
    }
    if (from.present) {
      map['from'] = Variable<String>(from.value);
    }
    if (to.present) {
      map['to'] = Variable<String>(to.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (bodyPlain.present) {
      map['body_plain'] = Variable<String>(bodyPlain.value);
    }
    if (bodyHtml.present) {
      map['body_html'] = Variable<String>(bodyHtml.value);
    }
    if (labelIdsCsv.present) {
      map['label_ids_csv'] = Variable<String>(labelIdsCsv.value);
    }
    if (historyId.present) {
      map['history_id'] = Variable<String>(historyId.value);
    }
    if (isUnread.present) {
      map['is_unread'] = Variable<bool>(isUnread.value);
    }
    if (ccCsv.present) {
      map['cc_csv'] = Variable<String>(ccCsv.value);
    }
    if (bccCsv.present) {
      map['bcc_csv'] = Variable<String>(bccCsv.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
    }
    if (indexInThread.present) {
      map['index_in_thread'] = Variable<int>(indexInThread.value);
    }
    if (counterpartEmail.present) {
      map['counterpart_email'] = Variable<String>(counterpartEmail.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('threadId: $threadId, ')
          ..write('internalDate: $internalDate, ')
          ..write('from: $from, ')
          ..write('to: $to, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('bodyPlain: $bodyPlain, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('labelIdsCsv: $labelIdsCsv, ')
          ..write('historyId: $historyId, ')
          ..write('isUnread: $isUnread, ')
          ..write('ccCsv: $ccCsv, ')
          ..write('bccCsv: $bccCsv, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('direction: $direction, ')
          ..write('indexInThread: $indexInThread, ')
          ..write('counterpartEmail: $counterpartEmail, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $ThreadsTable threads = $ThreadsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [threads, messages];
}

typedef $$ThreadsTableCreateCompanionBuilder =
    ThreadsCompanion Function({
      required String id,
      Value<String?> snippet,
      Value<DateTime?> lastMessageDate,
      Value<String?> participantsCache,
      Value<String?> historyId,
      Value<String?> subjectLatest,
      Value<int> messageCount,
      Value<int> rowid,
    });
typedef $$ThreadsTableUpdateCompanionBuilder =
    ThreadsCompanion Function({
      Value<String> id,
      Value<String?> snippet,
      Value<DateTime?> lastMessageDate,
      Value<String?> participantsCache,
      Value<String?> historyId,
      Value<String?> subjectLatest,
      Value<int> messageCount,
      Value<int> rowid,
    });

class $$ThreadsTableFilterComposer extends Composer<_$LocalDb, $ThreadsTable> {
  $$ThreadsTableFilterComposer({
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

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageDate => $composableBuilder(
    column: $table.lastMessageDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantsCache => $composableBuilder(
    column: $table.participantsCache,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectLatest => $composableBuilder(
    column: $table.subjectLatest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThreadsTableOrderingComposer
    extends Composer<_$LocalDb, $ThreadsTable> {
  $$ThreadsTableOrderingComposer({
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

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageDate => $composableBuilder(
    column: $table.lastMessageDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantsCache => $composableBuilder(
    column: $table.participantsCache,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectLatest => $composableBuilder(
    column: $table.subjectLatest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThreadsTableAnnotationComposer
    extends Composer<_$LocalDb, $ThreadsTable> {
  $$ThreadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageDate => $composableBuilder(
    column: $table.lastMessageDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get participantsCache => $composableBuilder(
    column: $table.participantsCache,
    builder: (column) => column,
  );

  GeneratedColumn<String> get historyId =>
      $composableBuilder(column: $table.historyId, builder: (column) => column);

  GeneratedColumn<String> get subjectLatest => $composableBuilder(
    column: $table.subjectLatest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );
}

class $$ThreadsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $ThreadsTable,
          Thread,
          $$ThreadsTableFilterComposer,
          $$ThreadsTableOrderingComposer,
          $$ThreadsTableAnnotationComposer,
          $$ThreadsTableCreateCompanionBuilder,
          $$ThreadsTableUpdateCompanionBuilder,
          (Thread, BaseReferences<_$LocalDb, $ThreadsTable, Thread>),
          Thread,
          PrefetchHooks Function()
        > {
  $$ThreadsTableTableManager(_$LocalDb db, $ThreadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThreadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThreadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThreadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> snippet = const Value.absent(),
                Value<DateTime?> lastMessageDate = const Value.absent(),
                Value<String?> participantsCache = const Value.absent(),
                Value<String?> historyId = const Value.absent(),
                Value<String?> subjectLatest = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThreadsCompanion(
                id: id,
                snippet: snippet,
                lastMessageDate: lastMessageDate,
                participantsCache: participantsCache,
                historyId: historyId,
                subjectLatest: subjectLatest,
                messageCount: messageCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> snippet = const Value.absent(),
                Value<DateTime?> lastMessageDate = const Value.absent(),
                Value<String?> participantsCache = const Value.absent(),
                Value<String?> historyId = const Value.absent(),
                Value<String?> subjectLatest = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThreadsCompanion.insert(
                id: id,
                snippet: snippet,
                lastMessageDate: lastMessageDate,
                participantsCache: participantsCache,
                historyId: historyId,
                subjectLatest: subjectLatest,
                messageCount: messageCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThreadsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $ThreadsTable,
      Thread,
      $$ThreadsTableFilterComposer,
      $$ThreadsTableOrderingComposer,
      $$ThreadsTableAnnotationComposer,
      $$ThreadsTableCreateCompanionBuilder,
      $$ThreadsTableUpdateCompanionBuilder,
      (Thread, BaseReferences<_$LocalDb, $ThreadsTable, Thread>),
      Thread,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String threadId,
      required DateTime internalDate,
      Value<String?> from,
      Value<String?> to,
      Value<String?> subject,
      Value<String?> snippet,
      Value<String?> bodyPlain,
      Value<String?> bodyHtml,
      Value<String?> labelIdsCsv,
      Value<String?> historyId,
      Value<bool> isUnread,
      Value<String?> ccCsv,
      Value<String?> bccCsv,
      Value<bool> hasAttachments,
      Value<int> direction,
      Value<int> indexInThread,
      Value<String?> counterpartEmail,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> threadId,
      Value<DateTime> internalDate,
      Value<String?> from,
      Value<String?> to,
      Value<String?> subject,
      Value<String?> snippet,
      Value<String?> bodyPlain,
      Value<String?> bodyHtml,
      Value<String?> labelIdsCsv,
      Value<String?> historyId,
      Value<bool> isUnread,
      Value<String?> ccCsv,
      Value<String?> bccCsv,
      Value<bool> hasAttachments,
      Value<int> direction,
      Value<int> indexInThread,
      Value<String?> counterpartEmail,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$LocalDb, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get from => $composableBuilder(
    column: $table.from,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get to => $composableBuilder(
    column: $table.to,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyPlain => $composableBuilder(
    column: $table.bodyPlain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelIdsCsv => $composableBuilder(
    column: $table.labelIdsCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUnread => $composableBuilder(
    column: $table.isUnread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ccCsv => $composableBuilder(
    column: $table.ccCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bccCsv => $composableBuilder(
    column: $table.bccCsv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get indexInThread => $composableBuilder(
    column: $table.indexInThread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterpartEmail => $composableBuilder(
    column: $table.counterpartEmail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$LocalDb, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get from => $composableBuilder(
    column: $table.from,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get to => $composableBuilder(
    column: $table.to,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyPlain => $composableBuilder(
    column: $table.bodyPlain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelIdsCsv => $composableBuilder(
    column: $table.labelIdsCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyId => $composableBuilder(
    column: $table.historyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUnread => $composableBuilder(
    column: $table.isUnread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ccCsv => $composableBuilder(
    column: $table.ccCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bccCsv => $composableBuilder(
    column: $table.bccCsv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get indexInThread => $composableBuilder(
    column: $table.indexInThread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterpartEmail => $composableBuilder(
    column: $table.counterpartEmail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$LocalDb, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get from =>
      $composableBuilder(column: $table.from, builder: (column) => column);

  GeneratedColumn<String> get to =>
      $composableBuilder(column: $table.to, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<String> get bodyPlain =>
      $composableBuilder(column: $table.bodyPlain, builder: (column) => column);

  GeneratedColumn<String> get bodyHtml =>
      $composableBuilder(column: $table.bodyHtml, builder: (column) => column);

  GeneratedColumn<String> get labelIdsCsv => $composableBuilder(
    column: $table.labelIdsCsv,
    builder: (column) => column,
  );

  GeneratedColumn<String> get historyId =>
      $composableBuilder(column: $table.historyId, builder: (column) => column);

  GeneratedColumn<bool> get isUnread =>
      $composableBuilder(column: $table.isUnread, builder: (column) => column);

  GeneratedColumn<String> get ccCsv =>
      $composableBuilder(column: $table.ccCsv, builder: (column) => column);

  GeneratedColumn<String> get bccCsv =>
      $composableBuilder(column: $table.bccCsv, builder: (column) => column);

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get indexInThread => $composableBuilder(
    column: $table.indexInThread,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterpartEmail => $composableBuilder(
    column: $table.counterpartEmail,
    builder: (column) => column,
  );
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$LocalDb, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$LocalDb db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> threadId = const Value.absent(),
                Value<DateTime> internalDate = const Value.absent(),
                Value<String?> from = const Value.absent(),
                Value<String?> to = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> snippet = const Value.absent(),
                Value<String?> bodyPlain = const Value.absent(),
                Value<String?> bodyHtml = const Value.absent(),
                Value<String?> labelIdsCsv = const Value.absent(),
                Value<String?> historyId = const Value.absent(),
                Value<bool> isUnread = const Value.absent(),
                Value<String?> ccCsv = const Value.absent(),
                Value<String?> bccCsv = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<int> indexInThread = const Value.absent(),
                Value<String?> counterpartEmail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                threadId: threadId,
                internalDate: internalDate,
                from: from,
                to: to,
                subject: subject,
                snippet: snippet,
                bodyPlain: bodyPlain,
                bodyHtml: bodyHtml,
                labelIdsCsv: labelIdsCsv,
                historyId: historyId,
                isUnread: isUnread,
                ccCsv: ccCsv,
                bccCsv: bccCsv,
                hasAttachments: hasAttachments,
                direction: direction,
                indexInThread: indexInThread,
                counterpartEmail: counterpartEmail,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String threadId,
                required DateTime internalDate,
                Value<String?> from = const Value.absent(),
                Value<String?> to = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> snippet = const Value.absent(),
                Value<String?> bodyPlain = const Value.absent(),
                Value<String?> bodyHtml = const Value.absent(),
                Value<String?> labelIdsCsv = const Value.absent(),
                Value<String?> historyId = const Value.absent(),
                Value<bool> isUnread = const Value.absent(),
                Value<String?> ccCsv = const Value.absent(),
                Value<String?> bccCsv = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<int> indexInThread = const Value.absent(),
                Value<String?> counterpartEmail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                threadId: threadId,
                internalDate: internalDate,
                from: from,
                to: to,
                subject: subject,
                snippet: snippet,
                bodyPlain: bodyPlain,
                bodyHtml: bodyHtml,
                labelIdsCsv: labelIdsCsv,
                historyId: historyId,
                isUnread: isUnread,
                ccCsv: ccCsv,
                bccCsv: bccCsv,
                hasAttachments: hasAttachments,
                direction: direction,
                indexInThread: indexInThread,
                counterpartEmail: counterpartEmail,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$LocalDb, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$ThreadsTableTableManager get threads =>
      $$ThreadsTableTableManager(_db, _db.threads);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
}
