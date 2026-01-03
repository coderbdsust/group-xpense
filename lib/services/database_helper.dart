import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('group_xpense.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Persons table
    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        avatar TEXT,
        groupId TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        paidById TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Expense participants table (many-to-many)
    await db.execute('''
      CREATE TABLE expense_participants (
        expenseId TEXT NOT NULL,
        personId TEXT NOT NULL,
        PRIMARY KEY (expenseId, personId),
        FOREIGN KEY (expenseId) REFERENCES expenses (id) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES persons (id) ON DELETE CASCADE
      )
    ''');

    // Expense splits table
    await db.execute('''
      CREATE TABLE expense_splits (
        expenseId TEXT NOT NULL,
        personId TEXT NOT NULL,
        amount REAL NOT NULL,
        PRIMARY KEY (expenseId, personId),
        FOREIGN KEY (expenseId) REFERENCES expenses (id) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES persons (id) ON DELETE CASCADE
      )
    ''');
  }

  // Group CRUD operations
  Future<void> insertGroup(Group group) async {
    final db = await database;
    await db.insert('groups', {
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'createdAt': group.createdAt.toIso8601String(),
    });

    // Insert group members
    for (var member in group.members) {
      await db.insert('persons', {
        'id': member.id,
        'name': member.name,
        'email': member.email,
        'avatar': member.avatar,
        'groupId': group.id,
      });
    }
  }

  // Add after insertGroup method
  Future<void> updateGroup(Group group) async {
    final db = await database;

    await db.update(
      'groups',
      {
        'name': group.name,
        'description': group.description,
      },
      where: 'id = ?',
      whereArgs: [group.id],
    );

    // Delete existing members and re-insert
    await db.delete('persons', where: 'groupId = ?', whereArgs: [group.id]);

    for (var member in group.members) {
      await db.insert('persons', {
        'id': member.id,
        'name': member.name,
        'email': member.email,
        'avatar': member.avatar,
        'groupId': group.id,
      });
    }
  }

// Add after insertExpense method
  Future<void> updateExpense(Expense expense) async {
    final db = await database;

    await db.update(
      'expenses',
      {
        'description': expense.description,
        'amount': expense.amount,
        'paidById': expense.paidBy.id,
        'date': expense.date.toIso8601String(),
        'category': expense.category,
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );

    // Delete and re-insert participants
    await db.delete('expense_participants', where: 'expenseId = ?', whereArgs: [expense.id]);
    for (var participant in expense.participants) {
      await db.insert('expense_participants', {
        'expenseId': expense.id,
        'personId': participant.id,
      });
    }

    // Delete and re-insert splits
    await db.delete('expense_splits', where: 'expenseId = ?', whereArgs: [expense.id]);
    for (var entry in expense.splits.entries) {
      await db.insert('expense_splits', {
        'expenseId': expense.id,
        'personId': entry.key,
        'amount': entry.value,
      });
    }
  }

  Future<List<Group>> getAllGroups() async {
    final db = await database;
    final groupMaps = await db.query('groups', orderBy: 'createdAt DESC');

    List<Group> groups = [];
    for (var groupMap in groupMaps) {
      final memberMaps = await db.query(
        'persons',
        where: 'groupId = ?',
        whereArgs: [groupMap['id']],
      );

      final members = memberMaps
          .map(
            (m) => Person(
              id: m['id'] as String,
              name: m['name'] as String,
              email: m['email'] as String?,
              avatar: m['avatar'] as String?,
            ),
          )
          .toList();

      groups.add(
        Group(
          id: groupMap['id'] as String,
          name: groupMap['name'] as String,
          description: groupMap['description'] as String?,
          members: members,
          createdAt: DateTime.parse(groupMap['createdAt'] as String),
        ),
      );
    }

    return groups;
  }

  Future<Group?> getGroup(String groupId) async {
    final db = await database;
    final groupMaps = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [groupId],
      limit: 1,
    );

    if (groupMaps.isEmpty) return null;

    final groupMap = groupMaps.first;
    final memberMaps = await db.query(
      'persons',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );

    final members = memberMaps
        .map(
          (m) => Person(
            id: m['id'] as String,
            name: m['name'] as String,
            email: m['email'] as String?,
            avatar: m['avatar'] as String?,
          ),
        )
        .toList();

    return Group(
      id: groupMap['id'] as String,
      name: groupMap['name'] as String,
      description: groupMap['description'] as String?,
      members: members,
      createdAt: DateTime.parse(groupMap['createdAt'] as String),
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await database;
    await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    // Cascading deletes will handle persons, expenses, etc.
  }

  // Expense CRUD operations
  Future<void> insertExpense(Expense expense) async {
    final db = await database;

    await db.insert('expenses', {
      'id': expense.id,
      'groupId': expense.groupId,
      'description': expense.description,
      'amount': expense.amount,
      'paidById': expense.paidBy.id,
      'date': expense.date.toIso8601String(),
      'category': expense.category,
    });

    // Insert participants
    for (var participant in expense.participants) {
      await db.insert('expense_participants', {
        'expenseId': expense.id,
        'personId': participant.id,
      });
    }

    // Insert splits
    for (var entry in expense.splits.entries) {
      await db.insert('expense_splits', {
        'expenseId': expense.id,
        'personId': entry.key,
        'amount': entry.value,
      });
    }
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    final db = await database;
    final expenseMaps = await db.query(
      'expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'date DESC',
    );

    final group = await getGroup(groupId);
    if (group == null) return [];

    List<Expense> expenses = [];
    for (var expenseMap in expenseMaps) {
      final expenseId = expenseMap['id'] as String;

      // Get participants
      final participantMaps = await db.rawQuery(
        '''
        SELECT p.* FROM persons p
        INNER JOIN expense_participants ep ON p.id = ep.personId
        WHERE ep.expenseId = ?
      ''',
        [expenseId],
      );

      final participants = participantMaps
          .map(
            (m) => Person(
              id: m['id'] as String,
              name: m['name'] as String,
              email: m['email'] as String?,
              avatar: m['avatar'] as String?,
            ),
          )
          .toList();

      // Get splits
      final splitMaps = await db.query(
        'expense_splits',
        where: 'expenseId = ?',
        whereArgs: [expenseId],
      );

      final splits = <String, double>{};
      for (var split in splitMaps) {
        splits[split['personId'] as String] = split['amount'] as double;
      }

      // Get paid by person
      final paidById = expenseMap['paidById'] as String;
      final paidBy = group.members.firstWhere((m) => m.id == paidById);

      expenses.add(
        Expense(
          id: expenseId,
          groupId: groupId,
          description: expenseMap['description'] as String,
          amount: expenseMap['amount'] as double,
          paidBy: paidBy,
          participants: participants,
          splits: splits,
          date: DateTime.parse(expenseMap['date'] as String),
          category: expenseMap['category'] as String?,
        ),
      );
    }

    return expenses;
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
    // Cascading deletes will handle participants and splits
  }

  // Add after updateGroup method
  Future<void> addMemberToGroup(String groupId, Person person) async {
    final db = await database;
    await db.insert('persons', {
      'id': person.id,
      'name': person.name,
      'email': person.email,
      'avatar': person.avatar,
      'groupId': groupId,
    });
  }

  Future<void> removeMemberFromGroup(String groupId, String personId) async {
    final db = await database;
    await db.delete(
      'persons',
      where: 'id = ? AND groupId = ?',
      whereArgs: [personId, groupId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }


}
