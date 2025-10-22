// lib/data/local_db/local_db.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// ======================
/// テーブル定義
/// ======================

class Threads extends Table {
  TextColumn get id => text()(); // Gmail threadId
  TextColumn get snippet => text().nullable()();
  DateTimeColumn get lastMessageDate => dateTime().nullable()();
  TextColumn get participantsCache =>
      text().nullable()(); // "Alice <a@x>, Bob <b@y>"
  TextColumn get historyId => text().nullable()(); // 最新historyId

  // 一覧表示に使う代表件名・件数
  TextColumn get subjectLatest => text().nullable()();
  IntColumn get messageCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()(); // Gmail messageId
  TextColumn get threadId => text()(); // FK: Threads.id
  DateTimeColumn get internalDate => dateTime()(); // 受信/送信時刻

  TextColumn get from => text().nullable()();
  TextColumn get to => text().nullable()();

  TextColumn get subject => text().nullable()();
  TextColumn get snippet => text().nullable()();

  // 本文キャッシュ
  TextColumn get bodyPlain => text().nullable()();
  TextColumn get bodyHtml => text().nullable()();

  // ラベル/同期情報
  TextColumn get labelIdsCsv => text().nullable()();
  TextColumn get historyId => text().nullable()();
  BoolColumn get isUnread => boolean().withDefault(const Constant(true))();

  // 追加情報
  TextColumn get ccCsv => text().nullable()();
  TextColumn get bccCsv => text().nullable()();
  BoolColumn get hasAttachments =>
      boolean().withDefault(const Constant(false))();
  IntColumn get direction =>
      integer().withDefault(const Constant(0))(); // 0=unknown,1=in,2=out
  IntColumn get indexInThread => integer().withDefault(const Constant(0))();

  /// 人ごと一覧用：相手のメールアドレス（正規化）
  TextColumn get counterpartEmail => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ======================
/// DB 本体
/// ======================

@DriftDatabase(tables: [Threads, Messages])
class LocalDb extends _$LocalDb {
  LocalDb._internal() : super(driftDatabase(name: 'app.sqlite'));
  static final LocalDb instance = LocalDb._internal();

  /// v3: counterpartEmail 列を追加
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(threads, threads.subjectLatest);
        await m.addColumn(threads, threads.messageCount);

        await m.addColumn(messages, messages.ccCsv);
        await m.addColumn(messages, messages.bccCsv);
        await m.addColumn(messages, messages.hasAttachments);
        await m.addColumn(messages, messages.direction);
        await m.addColumn(messages, messages.indexInThread);
      }

      if (from < 3) {
        // ★ どの環境でも動く安全策：生SQLで列追加
        await customStatement(
          'ALTER TABLE messages ADD COLUMN counterpart_email TEXT;',
        );

        // ※ コード生成が新しくなったら、下の addColumn に切替えてOK
        // await m.addColumn(messages, messages.counterpartEmail);
      }
    },
  );

  /// ======================
  /// よく使うクエリ
  /// ======================

  Stream<List<Thread>> watchThreadsByLatest() {
    return (select(
      threads,
    )..orderBy([(t) => OrderingTerm.desc(t.lastMessageDate)])).watch();
  }

  Stream<List<Message>> watchMessagesInThread(String threadId) {
    final q = (select(messages)
      ..where((m) => m.threadId.equals(threadId))
      ..orderBy([
        (m) => OrderingTerm.desc(m.internalDate),
        (m) => OrderingTerm.desc(m.indexInThread),
      ]));
    return q.watch();
  }

  Stream<List<Message>> watchMessagesInThreadAsc(String threadId) {
    final q = (select(messages)
      ..where((m) => m.threadId.equals(threadId))
      ..orderBy([
        (m) => OrderingTerm.asc(m.internalDate),
        (m) => OrderingTerm.asc(m.indexInThread),
      ]));
    return q.watch();
  }

  /// ======================
  /// upsert / 更新系
  /// ======================

  Future<void> upsertThread(ThreadsCompanion data) =>
      into(threads).insert(data, mode: InsertMode.insertOrReplace);

  Future<void> upsertMessage(MessagesCompanion data) =>
      into(messages).insert(data, mode: InsertMode.insertOrReplace);

  Future<void> deleteMessageById(String id) =>
      (delete(messages)..where((m) => m.id.equals(id))).go();
}
