// lib/services/database_helper.dart

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

    return await openDatabase(
      path,
      version: 2, // Updated version for migration
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
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
        notes TEXT,
        isSettlement INTEGER DEFAULT 0,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');

    // Expense payers table (many-to-many for multiple payers)
    await db.execute('''
      CREATE TABLE expense_payers (
        expenseId TEXT NOT NULL,
        personId TEXT NOT NULL,
        amount REAL NOT NULL,
        PRIMARY KEY (expenseId, personId),
        FOREIGN KEY (expenseId) REFERENCES expenses (id) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES persons (id) ON DELETE CASCADE
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

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_persons_groupId ON persons(groupId)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_groupId ON expenses(groupId)
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_date ON expenses(date)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check if columns exist before adding
      final tableInfo = await db.rawQuery('PRAGMA table_info(expenses)');
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();

      // Add notes column if it doesn't exist
      if (!columnNames.contains('notes')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN notes TEXT');
      }

      // Add isSettlement column if it doesn't exist
      if (!columnNames.contains('isSettlement')) {
        await db.execute(
          'ALTER TABLE expenses ADD COLUMN isSettlement INTEGER DEFAULT 0',
        );
      }

      // Create expense_payers table if it doesn't exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='expense_payers'",
      );

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE expense_payers (
            expenseId TEXT NOT NULL,
            personId TEXT NOT NULL,
            amount REAL NOT NULL,
            PRIMARY KEY (expenseId, personId),
            FOREIGN KEY (expenseId) REFERENCES expenses (id) ON DELETE CASCADE,
            FOREIGN KEY (personId) REFERENCES persons (id) ON DELETE CASCADE
          )
        ''');

        // Migrate existing expenses to use expense_payers
        final expenses = await db.query('expenses');
        for (var expense in expenses) {
          final expenseId = expense['id'] as String;
          final paidById = expense['paidById'] as String;
          final amount = expense['amount'] as double;

          await db.insert('expense_payers', {
            'expenseId': expenseId,
            'personId': paidById,
            'amount': amount,
          });
        }
      }
    }
  }

  // Group CRUD operations
  Future<void> insertGroup(Group group) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert('groups', {
        'id': group.id,
        'name': group.name,
        'description': group.description,
        'createdAt': group.createdAt.toIso8601String(),
      });

      // Insert group members
      for (var member in group.members) {
        await txn.insert('persons', {
          'id': member.id,
          'name': member.name,
          'email': member.email,
          'avatar': member.avatar,
          'groupId': group.id,
        });
      }
    });
  }

  Future<void> updateGroup(Group group) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'groups',
        {'name': group.name, 'description': group.description},
        where: 'id = ?',
        whereArgs: [group.id],
      );

      // Delete existing members and re-insert
      await txn.delete('persons', where: 'groupId = ?', whereArgs: [group.id]);

      for (var member in group.members) {
        await txn.insert('persons', {
          'id': member.id,
          'name': member.name,
          'email': member.email,
          'avatar': member.avatar,
          'groupId': group.id,
        });
      }
    });
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

  // Expense CRUD operations
  Future<void> insertExpense(Expense expense) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert('expenses', {
        'id': expense.id,
        'groupId': expense.groupId,
        'description': expense.description,
        'amount': expense.amount,
        'paidById': expense.payers.isNotEmpty
            ? expense.payers.first.person.id
            : '',
        'date': expense.date.toIso8601String(),
        'category': expense.category,
        'notes': expense.notes,
        'isSettlement': expense.isSettlement ? 1 : 0,
      });

      // Insert payers (multiple payers support)
      for (var payer in expense.payers) {
        await txn.insert('expense_payers', {
          'expenseId': expense.id,
          'personId': payer.person.id,
          'amount': payer.amount,
        });
      }

      // Insert participants
      for (var participant in expense.participants) {
        await txn.insert('expense_participants', {
          'expenseId': expense.id,
          'personId': participant.id,
        });
      }

      // Insert splits
      for (var entry in expense.splits.entries) {
        await txn.insert('expense_splits', {
          'expenseId': expense.id,
          'personId': entry.key,
          'amount': entry.value,
        });
      }
    });
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'expenses',
        {
          'description': expense.description,
          'amount': expense.amount,
          'paidById': expense.payers.isNotEmpty
              ? expense.payers.first.person.id
              : '',
          'date': expense.date.toIso8601String(),
          'category': expense.category,
          'notes': expense.notes,
          'isSettlement': expense.isSettlement ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      // Delete and re-insert payers
      await txn.delete(
        'expense_payers',
        where: 'expenseId = ?',
        whereArgs: [expense.id],
      );
      for (var payer in expense.payers) {
        await txn.insert('expense_payers', {
          'expenseId': expense.id,
          'personId': payer.person.id,
          'amount': payer.amount,
        });
      }

      // Delete and re-insert participants
      await txn.delete(
        'expense_participants',
        where: 'expenseId = ?',
        whereArgs: [expense.id],
      );
      for (var participant in expense.participants) {
        await txn.insert('expense_participants', {
          'expenseId': expense.id,
          'personId': participant.id,
        });
      }

      // Delete and re-insert splits
      await txn.delete(
        'expense_splits',
        where: 'expenseId = ?',
        whereArgs: [expense.id],
      );
      for (var entry in expense.splits.entries) {
        await txn.insert('expense_splits', {
          'expenseId': expense.id,
          'personId': entry.key,
          'amount': entry.value,
        });
      }
    });
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

      // Get payers (multiple payers support)
      final payerMaps = await db.rawQuery(
        '''
        SELECT p.*, ep.amount FROM persons p
        INNER JOIN expense_payers ep ON p.id = ep.personId
        WHERE ep.expenseId = ?
        ''',
        [expenseId],
      );

      final payers = payerMaps.map((m) {
        final person = Person(
          id: m['id'] as String,
          name: m['name'] as String,
          email: m['email'] as String?,
          avatar: m['avatar'] as String?,
        );
        return PayerShare(person: person, amount: m['amount'] as double);
      }).toList();

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

      expenses.add(
        Expense(
          id: expenseId,
          groupId: groupId,
          description: expenseMap['description'] as String,
          amount: expenseMap['amount'] as double,
          payers: payers.isNotEmpty
              ? payers
              : [
                  PayerShare(
                    person: group.members.first,
                    amount: expenseMap['amount'] as double,
                  ),
                ],
          participants: participants,
          splits: splits,
          date: DateTime.parse(expenseMap['date'] as String),
          category: expenseMap['category'] as String?,
          notes: expenseMap['notes'] as String?,
          isSettlement: (expenseMap['isSettlement'] as int?) == 1,
        ),
      );
    }

    return expenses;
  }

  Future<Expense?> getExpense(String expenseId) async {
    final db = await database;
    final expenseMaps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );

    if (expenseMaps.isEmpty) return null;

    final expenseMap = expenseMaps.first;
    final groupId = expenseMap['groupId'] as String;
    final group = await getGroup(groupId);

    if (group == null) return null;

    // Get payers
    final payerMaps = await db.rawQuery(
      '''
      SELECT p.*, ep.amount FROM persons p
      INNER JOIN expense_payers ep ON p.id = ep.personId
      WHERE ep.expenseId = ?
      ''',
      [expenseId],
    );

    final payers = payerMaps.map((m) {
      final person = Person(
        id: m['id'] as String,
        name: m['name'] as String,
        email: m['email'] as String?,
        avatar: m['avatar'] as String?,
      );
      return PayerShare(person: person, amount: m['amount'] as double);
    }).toList();

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

    return Expense(
      id: expenseId,
      groupId: groupId,
      description: expenseMap['description'] as String,
      amount: expenseMap['amount'] as double,
      payers: payers,
      participants: participants,
      splits: splits,
      date: DateTime.parse(expenseMap['date'] as String),
      category: expenseMap['category'] as String?,
      notes: expenseMap['notes'] as String?,
      isSettlement: (expenseMap['isSettlement'] as int?) == 1,
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
    // Cascading deletes will handle payers, participants and splits
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expense_splits');
      await txn.delete('expense_participants');
      await txn.delete('expense_payers');
      await txn.delete('expenses');
      await txn.delete('persons');
      await txn.delete('groups');
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Debug method to check database structure
  Future<void> debugPrintSchema() async {
    final db = await database;

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );

    print('=== Database Tables ===');
    for (var table in tables) {
      final tableName = table['name'] as String;
      print('\nTable: $tableName');

      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      for (var col in columns) {
        print('  ${col['name']}: ${col['type']}');
      }
    }
  }
}
