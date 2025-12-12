import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import '../utils/constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.dbName);
    return await openDatabase(
      path,
      version: 3, // Incremented for token tracking
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableNameChats} (
        id TEXT PRIMARY KEY,
        title TEXT,
        created_at TEXT,
        updated_at TEXT,
        system_prompt TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE ${AppConstants.tableNameMessages} (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        role TEXT,
        content TEXT,
        timestamp TEXT,
        attachment_path TEXT,
        attachment_type TEXT,
        prompt_tokens INTEGER,
        completion_tokens INTEGER,
        is_edited INTEGER DEFAULT 0,
        FOREIGN KEY (chat_id) REFERENCES ${AppConstants.tableNameChats} (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameChats})');
       final hasColumn = columns.any((column) => column['name'] == 'system_prompt');
       if (!hasColumn) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameChats} ADD COLUMN system_prompt TEXT');
       }
    }
    if (oldVersion < 3) {
       // Add token tracking and edit columns
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameMessages})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('prompt_tokens')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN prompt_tokens INTEGER');
       }
       if (!columnNames.contains('completion_tokens')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN completion_tokens INTEGER');
       }
       if (!columnNames.contains('is_edited')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN is_edited INTEGER DEFAULT 0');
       }
    }
  }

  // Chat Operations
  Future<List<ChatSession>> getChats() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableNameChats,
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => ChatSession.fromMap(maps[i]));
  }

  Future<void> insertChat(ChatSession chat) async {
    if (chat.isTemp) return; // Do not save temp chats
    final db = await database;
    await db.insert(
      AppConstants.tableNameChats,
      chat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateChat(ChatSession chat) async {
    if (chat.isTemp) return;
    final db = await database;
    await db.update(
      AppConstants.tableNameChats,
      chat.toMap(),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> deleteChat(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableNameChats,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> renameChat(String id, String newTitle) async {
    final db = await database;
    await db.update(
        AppConstants.tableNameChats,
        {'title': newTitle},
        where: 'id = ?',
        whereArgs: [id],
    );
  }

  // Message Operations
  Future<List<Message>> getMessages(String chatId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableNameMessages,
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => Message.fromMap(maps[i]));
  }

  /// Get analytics data - total messages and token counts across all chats
  Future<Map<String, int>> getAnalyticsData() async {
    final db = await database;
    
    // Count all messages
    final messageCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tableNameMessages}'
    );
    final totalMessages = Sqflite.firstIntValue(messageCountResult) ?? 0;
    
    // Sum all tokens
    final tokenResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(prompt_tokens), 0) as promptTokens,
        COALESCE(SUM(completion_tokens), 0) as completionTokens
      FROM ${AppConstants.tableNameMessages}
    ''');
    
    final promptTokens = tokenResult.isNotEmpty 
        ? (tokenResult[0]['promptTokens'] as int? ?? 0) 
        : 0;
    final completionTokens = tokenResult.isNotEmpty 
        ? (tokenResult[0]['completionTokens'] as int? ?? 0) 
        : 0;
    
    return {
      'totalMessages': totalMessages,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
    };
  }

  Future<void> insertMessage(Message message, bool isTempChat) async {
    if (isTempChat) return;
    final db = await database;
    await db.insert(
      AppConstants.tableNameMessages,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Update chat timestamp
    await db.execute('''
      UPDATE ${AppConstants.tableNameChats} 
      SET updated_at = ? 
      WHERE id = ?
    ''', [message.timestamp.toIso8601String(), message.chatId]);
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete(
      AppConstants.tableNameMessages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMessage(Message message) async {
    final db = await database;
    await db.update(
      AppConstants.tableNameMessages,
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<void> deleteMessagesAfter(String chatId, DateTime afterTimestamp) async {
    final db = await database;
    await db.delete(
      AppConstants.tableNameMessages,
      where: 'chat_id = ? AND timestamp > ?',
      whereArgs: [chatId, afterTimestamp.toIso8601String()],
    );
  }
}
