import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/chat_session.dart';
import '../models/local_model.dart';
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
      version: 11, // Added model_id, is_free, api_key_label to messages
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
        system_prompt TEXT,
        is_pinned INTEGER DEFAULT 0,
        has_unread_messages INTEGER DEFAULT 0,
        folder TEXT
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
        generated_image_url TEXT,
        comfyui_filename TEXT,
        is_truncated INTEGER DEFAULT 0,
        has_error INTEGER DEFAULT 0,
        model_id TEXT,
        is_free INTEGER DEFAULT 0,
        api_key_label TEXT,
        FOREIGN KEY (chat_id) REFERENCES ${AppConstants.tableNameChats} (id) ON DELETE CASCADE
      )
    ''');
    
    // Local models table for on-device inference
    await db.execute('''
      CREATE TABLE local_models (
        id TEXT PRIMARY KEY,
        repo_id TEXT NOT NULL,
        name TEXT NOT NULL,
        filename TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        download_url TEXT NOT NULL,
        local_path TEXT,
        status TEXT NOT NULL,
        parameters INTEGER,
        quantization TEXT,
        description TEXT,
        created_at TEXT NOT NULL
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
    if (oldVersion < 4) {
       // Add is_pinned column for pin chat feature
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameChats})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('is_pinned')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameChats} ADD COLUMN is_pinned INTEGER DEFAULT 0');
       }
    }
    if (oldVersion < 5) {
       // Add has_unread_messages column
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameChats})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('has_unread_messages')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameChats} ADD COLUMN has_unread_messages INTEGER DEFAULT 0');
       }
    }
    if (oldVersion < 6) {
       // Add ComfyUI image generation columns
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameMessages})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('generated_image_url')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN generated_image_url TEXT');
       }
       if (!columnNames.contains('comfyui_filename')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN comfyui_filename TEXT');
       }
    }
    if (oldVersion < 7) {
       // Add is_truncated column for truncation tracking
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameMessages})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('is_truncated')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN is_truncated INTEGER DEFAULT 0');
       }
    }
    if (oldVersion < 8) {
       // Add has_error column for retry functionality
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameMessages})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('has_error')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN has_error INTEGER DEFAULT 0');
       }
    }
    if (oldVersion < 9) {
       // Add folder column to chats for organization
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameChats})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('folder')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameChats} ADD COLUMN folder TEXT');
       }
    }
    if (oldVersion < 10) {
       // Add local_models table for on-device inference
       await db.execute('''
         CREATE TABLE IF NOT EXISTS local_models (
           id TEXT PRIMARY KEY,
           repo_id TEXT NOT NULL,
           name TEXT NOT NULL,
           filename TEXT NOT NULL,
           size_bytes INTEGER NOT NULL,
           download_url TEXT NOT NULL,
           local_path TEXT,
           status TEXT NOT NULL,
           parameters INTEGER,
           quantization TEXT,
           description TEXT,
           created_at TEXT NOT NULL
         )
       ''');
     }
    if (oldVersion < 11) {
       // Add quota tracking columns
       final columns = await db.rawQuery('PRAGMA table_info(${AppConstants.tableNameMessages})');
       final columnNames = columns.map((c) => c['name']).toSet();
       
       if (!columnNames.contains('model_id')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN model_id TEXT');
       }
       if (!columnNames.contains('is_free')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN is_free INTEGER DEFAULT 0');
       }
       if (!columnNames.contains('api_key_label')) {
           await db.execute('ALTER TABLE ${AppConstants.tableNameMessages} ADD COLUMN api_key_label TEXT');
       }
    }
  }

  // Chat Operations
  Future<List<ChatSession>> getChats() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.tableNameChats,
      orderBy: 'is_pinned DESC, updated_at DESC',
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

  Future<void> markChatRead(String chatId) async {
      final db = await database;
      await db.update(
          AppConstants.tableNameChats,
          {'has_unread_messages': 0},
          where: 'id = ?',
          whereArgs: [chatId],
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

  Future<void> updateChatFolder(String chatId, String? folder) async {
    final db = await database;
    await db.update(
      AppConstants.tableNameChats,
      {'folder': folder},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<List<String>> getFolders() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT DISTINCT folder FROM ${AppConstants.tableNameChats} 
      WHERE folder IS NOT NULL AND folder != ''
      ORDER BY folder
    ''');
    return results.map((r) => r['folder'] as String).toList();
  }

  Future<void> togglePinChat(String id, bool isPinned) async {
    final db = await database;
    await db.update(
        AppConstants.tableNameChats,
        {'is_pinned': isPinned ? 1 : 0},
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

  /// Get the number of free messages sent today for a specific API key
  Future<int> getFreeMessagesTodayCount(String apiKeyLabel) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${AppConstants.tableNameMessages}
      WHERE is_free = 1 
      AND api_key_label = ?
      AND timestamp >= ?
    ''', [apiKeyLabel, startOfDay]);
    
    return Sqflite.firstIntValue(result) ?? 0;
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

  // Search across all messages
  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];
    
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        m.id as message_id,
        m.chat_id,
        m.content,
        m.role,
        m.timestamp,
        c.title as chat_title
      FROM ${AppConstants.tableNameMessages} m
      JOIN ${AppConstants.tableNameChats} c ON m.chat_id = c.id
      WHERE m.content LIKE ?
      ORDER BY m.timestamp DESC
      LIMIT 50
    ''', ['%${query.trim()}%']);
    
    return results;
  }

  // Local Model Operations
  Future<List<LocalModel>> getLocalModels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_models',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => LocalModel.fromMap(maps[i]));
  }

  Future<LocalModel?> getLocalModel(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_models',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocalModel.fromMap(maps.first);
  }

  Future<void> insertLocalModel(LocalModel model) async {
    final db = await database;
    final map = model.toMap();
    map['created_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'local_models',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLocalModel(LocalModel model) async {
    final db = await database;
    await db.update(
      'local_models',
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> deleteLocalModel(String id) async {
    final db = await database;
    await db.delete(
      'local_models',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalModel>> getDownloadedModels() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_models',
      where: 'status = ?',
      whereArgs: [LocalModelStatus.downloaded.name],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => LocalModel.fromMap(maps[i]));
  }

  // Privacy & Data Management
  Future<void> clearChatHistory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(AppConstants.tableNameMessages);
      await txn.delete(AppConstants.tableNameChats);
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
       await txn.delete(AppConstants.tableNameMessages);
       await txn.delete(AppConstants.tableNameChats);
       await txn.delete('local_models');
    });
  }
}
