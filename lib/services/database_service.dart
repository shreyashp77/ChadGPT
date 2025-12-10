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
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableNameChats} (
        id TEXT PRIMARY KEY,
        title TEXT,
        created_at TEXT,
        updated_at TEXT
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
        FOREIGN KEY (chat_id) REFERENCES ${AppConstants.tableNameChats} (id) ON DELETE CASCADE
      )
    ''');
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
}
